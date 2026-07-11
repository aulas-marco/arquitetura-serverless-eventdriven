#!/usr/bin/env bash
#
# conta-e-replay.sh — exercita o event store: cria conta, deposita, saca,
# reconstrói o estado por replay, rejeita saque a descoberto e mostra o log
# append-only de eventos. No fim, dispara depósitos concorrentes para observar
# a concorrência otimística (alguns podem conflitar com 409).
#
# Requer: stack u2lab01-eventstore já implantado (make deploy-eventstore).
# Uso:    ./conta-e-replay.sh

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STACK="u2lab01-eventstore"

saida() {
  aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

URL="$(saida UrlHttpApi)"
TABELA="$(saida TabelaNome)"

echo "== criar conta (titular Maria) =="
CONTA="$(curl -s -X POST "$URL/contas" -H 'Content-Type: application/json' \
  -d '{"titular":"Maria"}' | python3 -c 'import sys,json; print(json.load(sys.stdin)["contaId"])')"
echo "  contaId=$CONTA"

echo "== depositar 100, depositar 50, sacar 30 =="
curl -s -X POST "$URL/contas/$CONTA/depositos" -H 'Content-Type: application/json' -d '{"valor":100}'; echo
curl -s -X POST "$URL/contas/$CONTA/depositos" -H 'Content-Type: application/json' -d '{"valor":50}';  echo
curl -s -X POST "$URL/contas/$CONTA/saques"    -H 'Content-Type: application/json' -d '{"valor":30}';  echo

echo "== estado reconstruído por replay (esperado: saldo 120, 4 eventos) =="
curl -s "$URL/contas/$CONTA"; echo

echo "== saque a descoberto (esperado: 422 saldo insuficiente) =="
curl -s -o /dev/null -w '  HTTP %{http_code}\n' -X POST "$URL/contas/$CONTA/saques" \
  -H 'Content-Type: application/json' -d '{"valor":1000}'

echo "== log append-only no DynamoDB (sequência de fatos) =="
aws dynamodb query --table-name "$TABELA" --region "$REGION" \
  --key-condition-expression "contaId = :c" \
  --expression-attribute-values "{\":c\":{\"S\":\"$CONTA\"}}" \
  --query 'Items[].{seq:sequencia.N,tipo:tipo.S}' --output table

echo "== prova do guard: regravar a sequência 1 direto no DynamoDB (deve falhar) =="
GUARD="$(aws dynamodb put-item --table-name "$TABELA" --region "$REGION" \
     --item "{\"contaId\":{\"S\":\"$CONTA\"},\"sequencia\":{\"N\":\"1\"},\"tipo\":{\"S\":\"Duplicata\"}}" \
     --condition-expression "attribute_not_exists(contaId) AND attribute_not_exists(sequencia)" 2>&1 || true)"
if echo "$GUARD" | grep -q "ConditionalCheckFailed"; then
  echo "  ✓ rejeitado: ConditionalCheckFailedException — a sequência 1 é imutável"
else
  echo "  (inesperado: a gravação passou) — $GUARD"
fi

echo "== concorrência otimística: 5 depósitos de 10 em paralelo =="
for i in 1 2 3 4 5; do
  curl -s -o /dev/null -w "  req$i: HTTP %{http_code}\n" -X POST "$URL/contas/$CONTA/depositos" \
    -H 'Content-Type: application/json' -d '{"valor":10}' &
done
wait
echo "  (200 = gravou; 409 = perdeu a corrida pela sequência e deve repetir)"

echo "== estado final (append-only: nenhum update perdido) =="
curl -s "$URL/contas/$CONTA"; echo
echo
echo "Estado sempre reconstruído dos eventos; sequência imutável; conflito vira 409."
