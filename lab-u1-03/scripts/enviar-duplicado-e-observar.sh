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

if [ "$LOCALSTACK" != "1" ]; then URL="$(saida UrlHttpApi)"; fi
TABELA="$(saida TabelaNome)"
PEDIDO="p-dup-$(date +%s)"
CORPO="{\"pedidoId\":\"$PEDIDO\",\"valor\":250,\"itens\":[\"livro\",\"caneta\"]}"

echo "== enviando o pedido $PEDIDO DUAS vezes (mesma identidade) =="
for tentativa in 1 2; do
  echo "  envio $tentativa:"
  enviar_pedido "$CORPO"; echo
done

echo "== aguardando o processamento assíncrono =="
sleep 12

echo "== o que o consumidor decidiu (logs) =="
"$AWS" logs tail /aws/lambda/u1lab03-consumidor --since 3m --region "$REGION" --format short \
  | grep -E "\[PROCESSADO\]|\[IGNORADO\]" | grep "$PEDIDO" || echo "  (nada ainda — rode de novo)"

echo "== quantos itens o DynamoDB guardou para $PEDIDO? =="
"$AWS" dynamodb get-item --table-name "$TABELA" --region "$REGION" \
  --key "{\"pedidoId\":{\"S\":\"$PEDIDO\"}}" \
  --query 'Item.{pedido:pedidoId.S,valor:valor.N,processadoEm:processadoEm.N}' \
  --output table

echo
echo "Dois envios → um PROCESSADO + um IGNORADO → um único item. Isso é idempotência."
