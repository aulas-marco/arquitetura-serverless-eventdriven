#!/usr/bin/env bash
#
# veneno-e-dlq.sh — envia um lote com 2 pedidos bons e 1 veneno (valor -1).
# Prova duas coisas: (1) falha parcial — os bons são processados na 1ª vez e não
# voltam; (2) DLQ — o veneno é reentregue até maxReceiveCount e cai na DLQ.
#
# Requer: stack u1lab04-dlq já implantado (make deploy-dlq).
# Uso:    ./veneno-e-dlq.sh

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STACK="u1lab04-dlq"

saida() {
  aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

URL="$(saida UrlHttpApi)"
DLQ="$(saida DLQUrl)"
SUFIXO="$(date +%s)"
BOM1="bom-a-$SUFIXO"; BOM2="bom-b-$SUFIXO"; VENENO="veneno-$SUFIXO"

echo "== enviando lote: 2 bons + 1 veneno (valor -1) =="
curl -s -X POST "$URL" -H 'Content-Type: application/json' -d "[
  {\"pedidoId\":\"$BOM1\",\"valor\":100},
  {\"pedidoId\":\"$VENENO\",\"valor\":-1},
  {\"pedidoId\":\"$BOM2\",\"valor\":200}
]"; echo

echo "== aguardando processamento + reentregas do veneno (maxReceiveCount=3) =="
sleep 45

echo "== o que o consumidor fez (bons uma vez, veneno tentado 1→2→3) =="
aws logs tail /aws/lambda/u1lab04-consumidor --since 3m --region "$REGION" --format short \
  | grep -E "\[OK\]|\[FALHA\]" | grep "$SUFIXO" || echo "  (nada ainda — rode de novo)"

echo "== a DLQ recebeu o veneno? =="
aws sqs get-queue-attributes --queue-url "$DLQ" --region "$REGION" \
  --attribute-names ApproximateNumberOfMessages \
  --query 'Attributes.ApproximateNumberOfMessages' --output text | \
  xargs -I{} echo "  mensagens na DLQ: {}"

echo "== conteúdo do veneno na DLQ =="
aws sqs receive-message --queue-url "$DLQ" --region "$REGION" \
  --max-number-of-messages 1 --visibility-timeout 1 \
  --query 'Messages[0].Body' --output text || echo "  (nada visível — rode de novo)"

echo
echo "Bons processados 1x e apagados; veneno tentado 3x e movido para a DLQ."
