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

saida() {
  aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

URL="$(saida UrlHttpApi)"
PEDIDO="p-$(date +%s)"

echo "== publicando 1 pedido ($PEDIDO) no tópico =="
curl -s -X POST "$URL" \
  -H 'Content-Type: application/json' \
  -d "{\"pedidoId\":\"$PEDIDO\",\"valor\":250,\"itens\":[\"livro\",\"caneta\"]}"
echo

echo "== aguardando o fan-out e o processamento assíncrono =="
sleep 12

echo "== [ESTOQUE] reagiu? =="
aws logs tail /aws/lambda/u1lab02-consumidor-estoque --since 3m --region "$REGION" --format short \
  | grep -E '\[ESTOQUE\]' | grep "$PEDIDO" || echo "  (nada ainda — rode de novo em alguns segundos)"

echo "== [NOTIFICACAO] reagiu? =="
aws logs tail /aws/lambda/u1lab02-consumidor-notificacao --since 3m --region "$REGION" --format short \
  | grep -E '\[NOTIFICACAO\]' | grep "$PEDIDO" || echo "  (nada ainda — rode de novo em alguns segundos)"

echo
echo "Uma publicação → dois consumidores independentes. Isso é fan-out."
