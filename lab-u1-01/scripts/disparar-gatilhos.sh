#!/usr/bin/env bash
#
# disparar-gatilhos.sh — Parte 2. Dispara os 4 gatilhos da GatilhosFunction e
# mostra cada origem identificada nos logs. Lê os outputs do stack.
#
# Requer: stack u1lab01-partes1a3 já implantado (make deploy-fundamentos).
# Uso:    ./disparar-gatilhos.sh

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STACK="u1lab01-partes1a3"

saida() {
  aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

URL="$(saida UrlHttpApi)"
FILA="$(saida FilaGatilhoUrl)"
BUCKET="$(saida BucketGatilhoNome)"

echo "== (a) HTTP =="
curl -s -X POST "$URL"; echo

echo "== (b) SQS =="
aws sqs send-message --queue-url "$FILA" --message-body '{"pedido":"123"}' \
  --region "$REGION" --query 'MessageId' --output text

echo "== (c) S3 =="
tmp="$(mktemp)"; echo "conteudo de teste" > "$tmp"
aws s3 cp "$tmp" "s3://$BUCKET/teste-lab.txt" --region "$REGION"
rm -f "$tmp"

echo "== aguardando processamento assíncrono (SQS/S3) =="
sleep 12

echo "== origens identificadas nos logs =="
aws logs tail /aws/lambda/u1lab01-gatilhos --since 5m --region "$REGION" --format short \
  | grep -E '\[ORIGEM\]' | sort -u
