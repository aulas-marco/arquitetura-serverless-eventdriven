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

saida() {
  aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

URL="$(saida UrlHttpApi)"
TABELA="$(saida TabelaNome)"
PEDIDO="p-dup-$(date +%s)"
CORPO="{\"pedidoId\":\"$PEDIDO\",\"valor\":250,\"itens\":[\"livro\",\"caneta\"]}"

echo "== enviando o pedido $PEDIDO DUAS vezes (mesma identidade) =="
for tentativa in 1 2; do
  echo "  envio $tentativa:"
  curl -s -X POST "$URL" -H 'Content-Type: application/json' -d "$CORPO"; echo
done

echo "== aguardando o processamento assíncrono =="
sleep 12

echo "== o que o consumidor decidiu (logs) =="
aws logs tail /aws/lambda/u1lab03-consumidor --since 3m --region "$REGION" --format short \
  | grep -E "\[PROCESSADO\]|\[IGNORADO\]" | grep "$PEDIDO" || echo "  (nada ainda — rode de novo)"

echo "== quantos itens o DynamoDB guardou para $PEDIDO? =="
aws dynamodb get-item --table-name "$TABELA" --region "$REGION" \
  --key "{\"pedidoId\":{\"S\":\"$PEDIDO\"}}" \
  --query 'Item.{pedido:pedidoId.S,valor:valor.N,processadoEm:processadoEm.N}' \
  --output table

echo
echo "Dois envios → um PROCESSADO + um IGNORADO → um único item. Isso é idempotência."
