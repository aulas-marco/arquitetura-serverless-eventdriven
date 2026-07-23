#!/usr/bin/env bash
#
# consumir-e-observar.sh — demonstra três conceitos do U3-LAB02:
#
#   1. Dois consumidores independentes recebem TODOS os eventos (≈ consumer
#      groups distintos no Kafka: cada grupo processa o stream inteiro).
#   2. ParallelizationFactor: ConsumidorA usa até 4 invocações simultâneas
#      por shard, ConsumidorB não.
#   3. At-least-once + BisectBatchOnFunctionError: uma falha divide o lote
#      ao meio e retenta — o registro problemático é isolado e reprocessado.
#
# Requer: stacks u3lab01-produtor e u3lab02-consumidores já implantados.
#   make deploy-produtor && make deploy-consumidor

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STACK_PROD="u3lab01-produtor"
FUNC_A="u3lab02-consumidor-a"
FUNC_B="u3lab02-consumidor-b"

# Modo de execução: LOCALSTACK=1 usa awslocal apontando para o LocalStack.
LOCALSTACK="${LOCALSTACK:-0}"
if [ "$LOCALSTACK" = "1" ]; then AWS="awslocal"; else AWS="aws"; fi

_ts_ms() { python3 -c "import time; print(int((time.time() - $1) * 1000))"; }

# publicar_lote — em modo AWS faz o POST no HttpApi; em modo LocalStack (HttpApi
# é Pro) invoca o produtor Kinesis direto com a lista como payload. Devolve o
# mesmo `body` do curl.
publicar_lote() {
  local corpo="$1"
  if [ "$LOCALSTACK" = "1" ]; then
    "$AWS" lambda invoke --function-name u3lab01-produtor \
      --cli-binary-format raw-in-base64-out --payload "$corpo" \
      /tmp/u3lab02-resp.json >/dev/null
    python3 -c 'import json; print(json.load(open("/tmp/u3lab02-resp.json")).get("body",""))'
  else
    curl -s -X POST "$URL" -H 'Content-Type: application/json' -d "$corpo"
  fi
}

if [ "$LOCALSTACK" != "1" ]; then
  URL="$(aws cloudformation describe-stacks --stack-name "$STACK_PROD" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='UrlHttpApi'].OutputValue" --output text)"
fi

# --------------------------------------------------------------------------
echo "== Parte 1: dois consumidores independentes recebem todos os eventos =="
echo "   Publicando 5 eventos (cli-001, cli-002, cli-003)..."
publicar_lote '[
  {"clienteId":"cli-001","mensagem":"nao consigo logar"},
  {"clienteId":"cli-002","mensagem":"cobranca errada"},
  {"clienteId":"cli-001","mensagem":"segue o print"},
  {"clienteId":"cli-003","mensagem":"elogio ao suporte"},
  {"clienteId":"cli-002","mensagem":"aguardo retorno"}
]' | python3 -c "import sys,json; d=json.load(sys.stdin); print('   '+str(len(d['publicados']))+' evento(s) publicados')"

echo "   Aguardando processamento (25s)..."
sleep 25

echo ""
echo "   Logs do CONSUMIDOR-A (ParallelizationFactor=4):"
"$AWS" logs filter-log-events \
  --log-group-name "/aws/lambda/$FUNC_A" \
  --start-time "$(_ts_ms 35)" \
  --filter-pattern "CONSUMIDOR" --region "$REGION" \
  --query 'events[*].message' --output text 2>/dev/null \
  | head -10 || echo "   (sem logs recentes — aguarde um pouco mais)"

echo ""
echo "   Logs do CONSUMIDOR-B (sem paralelização adicional):"
"$AWS" logs filter-log-events \
  --log-group-name "/aws/lambda/$FUNC_B" \
  --start-time "$(_ts_ms 35)" \
  --filter-pattern "CONSUMIDOR" --region "$REGION" \
  --query 'events[*].message' --output text 2>/dev/null \
  | head -10 || echo "   (sem logs recentes)"

echo ""
echo "   Ambos receberam os mesmos eventos — como dois consumer groups distintos no Kafka."
echo "   ConsumidorA pode processar até 4 shards por invocação em paralelo;"
echo "   ConsumidorB processa um shard por vez."

# --------------------------------------------------------------------------
echo ""
echo "== Parte 2: at-least-once — BisectBatchOnFunctionError em ação =="
echo "   Configurando FALHAR_EM=cli-002 no consumidor-a..."
"$AWS" lambda update-function-configuration \
  --function-name "$FUNC_A" \
  --environment "Variables={CONSUMIDOR=consumidor-a,FALHAR_EM=cli-002}" \
  --region "$REGION" > /dev/null
"$AWS" lambda wait function-updated --function-name "$FUNC_A" --region "$REGION"

echo "   Publicando 4 eventos (cli-001 e cli-002 misturados)..."
publicar_lote '[
  {"clienteId":"cli-001","mensagem":"ok 1"},
  {"clienteId":"cli-002","mensagem":"vai falhar"},
  {"clienteId":"cli-001","mensagem":"ok 2"},
  {"clienteId":"cli-002","mensagem":"vai falhar de novo"}
]' > /dev/null

echo "   Aguardando retentativas (45s)..."
sleep 45

echo ""
echo "   Logs do CONSUMIDOR-A (observe bisect e retentativas para cli-002):"
"$AWS" logs filter-log-events \
  --log-group-name "/aws/lambda/$FUNC_A" \
  --start-time "$(_ts_ms 55)" \
  --region "$REGION" \
  --query 'events[*].message' --output text 2>/dev/null \
  | grep -v '^$' | head -30 || echo "   (sem logs)"

echo ""
echo "   Restaurando configuração original do consumidor-a..."
"$AWS" lambda update-function-configuration \
  --function-name "$FUNC_A" \
  --environment "Variables={CONSUMIDOR=consumidor-a}" \
  --region "$REGION" > /dev/null

echo ""
echo "   BisectBatchOnFunctionError bisectou o lote na falha: cli-002 foi isolado"
echo "   e reprocessado separadamente — at-least-once garante que nenhum registro"
echo "   é descartado silenciosamente, mesmo que seja entregue mais de uma vez."
