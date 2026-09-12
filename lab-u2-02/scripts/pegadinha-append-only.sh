#!/usr/bin/env bash
#
# pegadinha-append-only.sh — por que o event store PRECISA de ConditionExpression.
#
# Demonstra ao vivo o ponto central do U2V8: sem a condição de escrita, um
# put_item sobre uma chave que já existe vira um UPDATE silencioso e sobrescreve
# um evento histórico — corrompendo a auditoria. Com a condição
# `attribute_not_exists(...)`, o DynamoDB recusa a escrita e o append-only é
# preservado.
#
# Requer: stack u2lab02-snapshots já implantado (make deploy-snapshots).
# Uso:    ./pegadinha-append-only.sh

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STACK="u2lab02-snapshots"
TABELA="u2lab02-eventos"

# Modo de execução: LOCALSTACK=1 usa awslocal apontando para o LocalStack.
LOCALSTACK="${LOCALSTACK:-0}"
if [ "$LOCALSTACK" = "1" ]; then AWS="awslocal"; else AWS="aws"; fi

titulo() { printf '\n▶ %s\n' "$1"; }
nota()   { printf '  %s\n' "$1"; }
linha()  { printf '%s\n' '───────────────────────────────────────────────────────────────────'; }

FN="u2lab02-snapshots"

# api — em modo AWS faz curl no HttpApi; em modo LocalStack (HttpApi é Pro)
# invoca a Lambda direto com evento sintetizado. Uso: api MÉTODO ROTA CONTA CORPO
api() {
  local metodo="$1" rota="$2" conta="$3" corpo="${4:-}"
  if [ "$LOCALSTACK" = "1" ]; then
    local params="{}"
    [ -n "$conta" ] && params="{\"contaId\":\"$conta\"}"
    local body_field="null"
    [ -n "$corpo" ] && body_field="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$corpo")"
    local evento="{\"routeKey\":\"$metodo $rota\",\"pathParameters\":$params,\"body\":$body_field}"
    "$AWS" lambda invoke --function-name "$FN" \
      --cli-binary-format raw-in-base64-out --payload "$evento" \
      /tmp/u2lab02p-resp.json >/dev/null
    python3 -c 'import json; print(json.load(open("/tmp/u2lab02p-resp.json")).get("body",""))'
  else
    local url_final="${rota/\{contaId\}/$conta}"
    if [ "$metodo" = "GET" ]; then
      curl -s "$URL$url_final"
    elif [ -n "$corpo" ]; then
      curl -s -X "$metodo" "$URL$url_final" -H 'Content-Type: application/json' -d "$corpo"
    else
      curl -s -X "$metodo" "$URL$url_final"
    fi
  fi
}

if [ "$LOCALSTACK" != "1" ]; then
  URL="$(aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='UrlHttpApi'].OutputValue" --output text)"
fi

linha
echo " U2-LAB02 — Pegadinha ao vivo: por que ConditionExpression é obrigatória"
linha
echo "Um put_item no DynamoDB, por padrão, é um UPSERT: se a chave já existe,"
echo "ele SOBRESCREVE em vez de rejeitar. Num event store, isso significa"
echo "reescrever a história. Vamos corromper um evento de propósito, sem a"
echo "condição de escrita, e depois mostrar a proteção que o lab usa de verdade."

titulo "Criando conta + 2 depósitos de 100 (eventos seq 1, 2, 3)"
CONTA="$(api POST "/contas" "" '{"titular":"Maria"}' | python3 -c 'import sys,json; print(json.load(sys.stdin)["contaId"])')"
api POST "/contas/{contaId}/depositos" "$CONTA" '{"valor":100}' >/dev/null
api POST "/contas/{contaId}/depositos" "$CONTA" '{"valor":100}' >/dev/null
nota "contaId=$CONTA"

titulo "Saldo por replay completo (esperado: 200)"
api GET "/contas/{contaId}/completo" "$CONTA"; echo

titulo "PEGADINHA: sobrescrever o evento seq 2 SEM ConditionExpression"
nota "trocando o depósito de 100 por 999999 — o DynamoDB aceita como UPDATE:"
"$AWS" dynamodb put-item --table-name "$TABELA" --region "$REGION" --item "{
  \"contaId\":{\"S\":\"$CONTA\"},
  \"sequencia\":{\"N\":\"2\"},
  \"tipo\":{\"S\":\"DepositoRealizado\"},
  \"valor\":{\"N\":\"999999\"},
  \"criadoEm\":{\"N\":\"0\"}
}"
nota "gravação aceita silenciosamente — o evento histórico foi substituído."

titulo "Saldo por replay completo agora (corrompido)"
api GET "/contas/{contaId}/completo" "$CONTA"; echo
nota "a história mudou: sem proteção, o append-only foi violado."

titulo "A proteção: repetir a escrita COM a condição do lab"
if "$AWS" dynamodb put-item --table-name "$TABELA" --region "$REGION" \
  --condition-expression "attribute_not_exists(contaId) AND attribute_not_exists(sequencia)" \
  --item "{
    \"contaId\":{\"S\":\"$CONTA\"},
    \"sequencia\":{\"N\":\"2\"},
    \"tipo\":{\"S\":\"DepositoRealizado\"},
    \"valor\":{\"N\":\"1\"},
    \"criadoEm\":{\"N\":\"0\"}
  }" 2>/dev/null; then
  nota "✗ inesperado: a escrita passou (não deveria)"
else
  nota "✓ ConditionalCheckFailedException — o DynamoDB recusou sobrescrever."
fi

linha
echo " Sem ConditionExpression, put_item é um UPSERT: sobrescreve o evento e"
echo " corrompe o event store. É por isso que o _append do lab SEMPRE usa"
echo " attribute_not_exists — é o que garante o append-only e a auditoria íntegra."
linha
