#!/usr/bin/env bash
#
# publicar-e-observar.sh — publica UM pedido no tópico e mostra que os DOIS
# consumidores reagiram, cada um a partir da sua própria fila. É a prova visual
# do fan-out: uma publicação, dois processamentos independentes.
#
# Requer: stack u1lab02-fanout já implantado (make deploy-fanout).
# Uso:    ./publicar-e-observar.sh

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STACK="u1lab02-fanout"

# Modo de execução: LOCALSTACK=1 usa awslocal apontando para o LocalStack
# (http://localhost:4566); o padrão usa a AWS real.
LOCALSTACK="${LOCALSTACK:-0}"
if [ "$LOCALSTACK" = "1" ]; then AWS="awslocal"; else AWS="aws"; fi

saida() {
  "$AWS" cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

# publicar_pedido — em modo AWS faz o POST no HttpApi (curl); em modo LocalStack
# (HttpApi é Pro, indisponível no Community) invoca a Lambda produtora direto com
# o pedido como payload e devolve o mesmo `body` que o curl devolveria.
publicar_pedido() {
  local corpo="$1"
  if [ "$LOCALSTACK" = "1" ]; then
    "$AWS" lambda invoke --function-name u1lab02-publicar \
      --cli-binary-format raw-in-base64-out --payload "$corpo" \
      /tmp/u1lab02-resp.json >/dev/null
    python3 -c 'import json,sys; print(json.load(open("/tmp/u1lab02-resp.json")).get("body",""))'
  else
    curl -s -X POST "$URL" -H 'Content-Type: application/json' -d "$corpo"
  fi
}

if [ "$LOCALSTACK" != "1" ]; then URL="$(saida UrlHttpApi)"; fi
PEDIDO="p-$(date +%s)"

echo "== publicando 1 pedido ($PEDIDO) no tópico =="
publicar_pedido "{\"pedidoId\":\"$PEDIDO\",\"valor\":250,\"itens\":[\"livro\",\"caneta\"]}"
echo

echo "== aguardando o fan-out e o processamento assíncrono =="
sleep 12

echo "== [ESTOQUE] reagiu? =="
"$AWS" logs tail /aws/lambda/u1lab02-consumidor-estoque --since 3m --region "$REGION" --format short \
  | grep -E '\[ESTOQUE\]' | grep "$PEDIDO" || echo "  (nada ainda — rode de novo em alguns segundos)"

echo "== [NOTIFICACAO] reagiu? =="
"$AWS" logs tail /aws/lambda/u1lab02-consumidor-notificacao --since 3m --region "$REGION" --format short \
  | grep -E '\[NOTIFICACAO\]' | grep "$PEDIDO" || echo "  (nada ainda — rode de novo em alguns segundos)"

echo
echo "Uma publicação → dois consumidores independentes. Isso é fan-out."
