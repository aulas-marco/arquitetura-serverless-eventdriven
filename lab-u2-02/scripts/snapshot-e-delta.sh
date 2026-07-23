#!/usr/bin/env bash
#
# snapshot-e-delta.sh — mostra o snapshot em ação: acumula eventos, tira um
# snapshot, acumula mais alguns e prova que a consulta via snapshot reprocessa
# só o delta (poucos eventos) e chega ao MESMO saldo do replay completo.
#
# Requer: stack u2lab02-snapshots já implantado (make deploy-snapshots).
# Uso:    ./snapshot-e-delta.sh

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STACK="u2lab02-snapshots"

# Modo de execução: LOCALSTACK=1 usa awslocal apontando para o LocalStack.
LOCALSTACK="${LOCALSTACK:-0}"
if [ "$LOCALSTACK" = "1" ]; then AWS="awslocal"; else AWS="aws"; fi

FN="u2lab02-snapshots"

# api — em modo AWS faz curl no HttpApi; em modo LocalStack (HttpApi é Pro)
# invoca a Lambda direto com um evento sintetizado (routeKey + pathParameters +
# body) e devolve o mesmo `body` do curl.
# Uso: api MÉTODO ROTA_TEMPLATE CONTA_ID CORPO_JSON
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
      /tmp/u2lab02-resp.json >/dev/null
    python3 -c 'import json; print(json.load(open("/tmp/u2lab02-resp.json")).get("body",""))'
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

echo "== criar conta e acumular 6 depósitos de 100 =="
CONTA="$(api POST "/contas" "" '{"titular":"Maria"}' | python3 -c 'import sys,json; print(json.load(sys.stdin)["contaId"])')"
for i in $(seq 1 6); do
  api POST "/contas/{contaId}/depositos" "$CONTA" '{"valor":100}' >/dev/null
done
echo "  contaId=$CONTA (7 eventos: 1 criação + 6 depósitos)"

echo "== consulta ANTES do snapshot (reprocessa todos os eventos) =="
api GET "/contas/{contaId}" "$CONTA"; echo

echo "== tirar snapshot do estado atual =="
api POST "/contas/{contaId}/snapshot" "$CONTA"; echo

echo "== mais 2 depósitos de 100 (viram o delta) =="
api POST "/contas/{contaId}/depositos" "$CONTA" '{"valor":100}' >/dev/null
api POST "/contas/{contaId}/depositos" "$CONTA" '{"valor":100}' >/dev/null

echo "== consulta via snapshot (reprocessa só o delta) =="
VIA_SNAP="$(api GET "/contas/{contaId}" "$CONTA")"; echo "  $VIA_SNAP"

echo "== consulta por replay completo (para comparar o saldo) =="
COMPLETO="$(api GET "/contas/{contaId}/completo" "$CONTA")"; echo "  $COMPLETO"

echo "== conferência: os saldos batem? =="
python3 - "$VIA_SNAP" "$COMPLETO" <<'PY'
import json, sys
snap, comp = json.loads(sys.argv[1]), json.loads(sys.argv[2])
igual = snap["saldo"] == comp["saldo"]
print(f"  saldo via snapshot={snap['saldo']} (reprocessou {snap['eventosReprocessados']} evento(s), "
      f"a partir da seq {snap.get('snapshotSequencia')})")
print(f"  saldo replay completo={comp['saldo']} (reprocessou {comp['eventosReprocessados']} eventos)")
print("  ✓ saldos idênticos — snapshot correto, lendo menos eventos" if igual else "  ✗ DIVERGÊNCIA")
PY
echo
echo "Snapshot = estado materializado; consulta parte dele + só o delta."
