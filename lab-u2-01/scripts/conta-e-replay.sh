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

FN="u2lab01-eventstore"

# api — em modo AWS faz curl no HttpApi; em modo LocalStack (HttpApi é Pro)
# invoca a Lambda de comando direto com um evento sintetizado
# (routeKey + pathParameters + body). Devolve o mesmo `body` que o curl.
# Uso: api MÉTODO ROTA_TEMPLATE CONTA_ID CORPO_JSON
#   ex.: api POST "/contas/{contaId}/depositos" "$CONTA" '{"valor":100}'
#        api GET  "/contas/{contaId}"           "$CONTA"
#        api POST "/contas"                      ""       '{"titular":"Maria"}'
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
      /tmp/u2lab01-resp.json >/dev/null
    python3 -c 'import json; print(json.load(open("/tmp/u2lab01-resp.json")).get("body",""))'
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

# api_status — igual a api, mas devolve só o código HTTP (para os 422/409).
api_status() {
  local metodo="$1" rota="$2" conta="$3" corpo="${4:-}"
  if [ "$LOCALSTACK" = "1" ]; then
    local params="{}"
    [ -n "$conta" ] && params="{\"contaId\":\"$conta\"}"
    local body_field="null"
    [ -n "$corpo" ] && body_field="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$corpo")"
    local evento="{\"routeKey\":\"$metodo $rota\",\"pathParameters\":$params,\"body\":$body_field}"
    "$AWS" lambda invoke --function-name "$FN" \
      --cli-binary-format raw-in-base64-out --payload "$evento" \
      /tmp/u2lab01-resp.json >/dev/null
    python3 -c 'import json; print(json.load(open("/tmp/u2lab01-resp.json")).get("statusCode",""))'
  else
    local url_final="${rota/\{contaId\}/$conta}"
    curl -s -o /dev/null -w '%{http_code}' -X "$metodo" "$URL$url_final" \
      -H 'Content-Type: application/json' -d "$corpo"
  fi
}

linha
echo " U2-LAB01 — Event store: estado é sempre reconstruído dos eventos"
linha
echo "Nada aqui guarda 'o saldo atual' diretamente. Cada operação (criar,"
echo "depositar, sacar) grava um FATO imutável e sequencial; o saldo é"
echo "sempre recalculado a partir do histórico completo (replay). Vamos"
echo "provar isso, mais a regra de imutabilidade e a concorrência otimística."

if [ "$LOCALSTACK" != "1" ]; then URL="$(saida UrlHttpApi)"; fi
TABELA="$(saida TabelaNome)"

titulo "Criando conta (titular Maria)"
CONTA="$(api POST "/contas" "" '{"titular":"Maria"}' | python3 -c 'import sys,json; print(json.load(sys.stdin)["contaId"])')"
nota "contaId=$CONTA"

titulo "Depositando 100, depositando 50, sacando 30"
api POST "/contas/{contaId}/depositos" "$CONTA" '{"valor":100}'; echo
api POST "/contas/{contaId}/depositos" "$CONTA" '{"valor":50}';  echo
api POST "/contas/{contaId}/saques"    "$CONTA" '{"valor":30}';  echo

titulo "Estado reconstruído por replay (esperado: saldo 120, 4 eventos)"
api GET "/contas/{contaId}" "$CONTA"; echo

titulo "Saque a descoberto (esperado: 422 saldo insuficiente)"
nota "HTTP $(api_status POST "/contas/{contaId}/saques" "$CONTA" '{"valor":1000}')"

titulo "Log append-only no DynamoDB (sequência de fatos)"
"$AWS" dynamodb query --table-name "$TABELA" --region "$REGION" \
  --key-condition-expression "contaId = :c" \
  --expression-attribute-values "{\":c\":{\"S\":\"$CONTA\"}}" \
  --query 'Items[].{seq:sequencia.N,tipo:tipo.S}' --output table

titulo "Prova do guard: regravar a sequência 1 direto no DynamoDB (deve falhar)"
GUARD="$("$AWS" dynamodb put-item --table-name "$TABELA" --region "$REGION" \
     --item "{\"contaId\":{\"S\":\"$CONTA\"},\"sequencia\":{\"N\":\"1\"},\"tipo\":{\"S\":\"Duplicata\"}}" \
     --condition-expression "attribute_not_exists(contaId) AND attribute_not_exists(sequencia)" 2>&1 || true)"
if echo "$GUARD" | grep -q "ConditionalCheckFailed"; then
  nota "✓ rejeitado: ConditionalCheckFailedException — a sequência 1 é imutável"
else
  nota "(inesperado: a gravação passou) — $GUARD"
fi

titulo "Concorrência otimística: 5 depósitos de 10 em paralelo"
for i in 1 2 3 4 5; do
  ( echo "  req$i: HTTP $(api_status POST "/contas/{contaId}/depositos" "$CONTA" '{"valor":10}')" ) &
done
wait
nota "(200 = gravou; 409 = perdeu a corrida pela sequência e deve repetir)"

titulo "Estado final (append-only: nenhum update perdido)"
api GET "/contas/{contaId}" "$CONTA"; echo

linha
echo " Estado sempre reconstruído dos eventos; sequência imutável; conflito"
echo " de escrita concorrente vira 409, nunca uma sobrescrita silenciosa."
linha
