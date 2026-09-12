#!/usr/bin/env bash
#
# enviar-duplicado-e-observar.sh — envia o MESMO pedido DUAS vezes e prova a
# idempotência: o consumidor processa uma vez, ignora a duplicata, e o DynamoDB
# guarda um único item. É o que uma entrega at-least-once faria naturalmente.
#
# Requer: stack u1lab03-idempotencia já implantado (make deploy-idem).
# Uso:    ./enviar-duplicado-e-observar.sh

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STACK="u1lab03-idempotencia"

# Modo de execução: LOCALSTACK=1 usa awslocal apontando para o LocalStack.
LOCALSTACK="${LOCALSTACK:-0}"
if [ "$LOCALSTACK" = "1" ]; then AWS="awslocal"; else AWS="aws"; fi

saida() {
  "$AWS" cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

titulo() { printf '\n▶ %s\n' "$1"; }
nota()   { printf '  %s\n' "$1"; }
linha()  { printf '%s\n' '───────────────────────────────────────────────────────────────────'; }

# enviar_pedido — em modo AWS faz o POST no HttpApi; em modo LocalStack (HttpApi
# é Pro) invoca a Lambda produtora direto com o pedido como payload e devolve o
# mesmo `body` do curl.
enviar_pedido() {
  local corpo="$1"
  if [ "$LOCALSTACK" = "1" ]; then
    "$AWS" lambda invoke --function-name u1lab03-publicar \
      --cli-binary-format raw-in-base64-out --payload "$corpo" \
      /tmp/u1lab03-resp.json >/dev/null
    python3 -c 'import json; print(json.load(open("/tmp/u1lab03-resp.json")).get("body",""))'
  else
    curl -s -X POST "$URL" -H 'Content-Type: application/json' -d "$corpo"
  fi
}

linha
echo " U1-LAB03 — Idempotência: a mesma mensagem entregue duas vezes"
linha
echo "Entregas at-least-once (o padrão do SQS) podem duplicar uma mensagem."
echo "Vamos enviar o MESMO pedido duas vezes e conferir que o consumidor"
echo "processa a primeira, IGNORA a segunda por já conhecer a chave de"
echo "idempotência, e o DynamoDB termina com um único item — nunca dois."

if [ "$LOCALSTACK" != "1" ]; then URL="$(saida UrlHttpApi)"; fi
TABELA="$(saida TabelaNome)"
PEDIDO="p-dup-$(date +%s)"
CORPO="{\"pedidoId\":\"$PEDIDO\",\"valor\":250,\"itens\":[\"livro\",\"caneta\"]}"
INICIO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

titulo "Enviando o pedido $PEDIDO DUAS vezes (mesma identidade)"
for tentativa in 1 2; do
  nota "envio $tentativa: $(enviar_pedido "$CORPO")"
done

titulo "Aguardando o processamento assíncrono…"
sleep 12
nota "concluído."

titulo "O que o consumidor decidiu, segundo os logs"
"$AWS" logs tail /aws/lambda/u1lab03-consumidor --since "$INICIO" --region "$REGION" --format short \
  | grep -E "\[PROCESSADO\]|\[IGNORADO\]" | grep "$PEDIDO" || echo "  (nada ainda — rode de novo)"

titulo "Quantos itens o DynamoDB guardou para $PEDIDO?"
"$AWS" dynamodb get-item --table-name "$TABELA" --region "$REGION" \
  --key "{\"pedidoId\":{\"S\":\"$PEDIDO\"}}" \
  --query 'Item.{pedido:pedidoId.S,valor:valor.N,processadoEm:processadoEm.N}' \
  --output table

linha
echo " Dois envios → um PROCESSADO + um IGNORADO → um único item no DynamoDB."
echo " Isso é idempotência: processar a mesma mensagem 2x tem o mesmo efeito"
echo " que processá-la 1x."
linha
