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

URL="$(aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='UrlHttpApi'].OutputValue" --output text)"

echo "== criar conta e acumular 6 depósitos de 100 =="
CONTA="$(curl -s -X POST "$URL/contas" -H 'Content-Type: application/json' \
  -d '{"titular":"Maria"}' | python3 -c 'import sys,json; print(json.load(sys.stdin)["contaId"])')"
for i in $(seq 1 6); do
  curl -s -o /dev/null -X POST "$URL/contas/$CONTA/depositos" \
    -H 'Content-Type: application/json' -d '{"valor":100}'
done
echo "  contaId=$CONTA (7 eventos: 1 criação + 6 depósitos)"

echo "== consulta ANTES do snapshot (reprocessa todos os eventos) =="
curl -s "$URL/contas/$CONTA"; echo

echo "== tirar snapshot do estado atual =="
curl -s -X POST "$URL/contas/$CONTA/snapshot"; echo

echo "== mais 2 depósitos de 100 (viram o delta) =="
curl -s -o /dev/null -X POST "$URL/contas/$CONTA/depositos" -H 'Content-Type: application/json' -d '{"valor":100}'
curl -s -o /dev/null -X POST "$URL/contas/$CONTA/depositos" -H 'Content-Type: application/json' -d '{"valor":100}'

echo "== consulta via snapshot (reprocessa só o delta) =="
VIA_SNAP="$(curl -s "$URL/contas/$CONTA")"; echo "  $VIA_SNAP"

echo "== consulta por replay completo (para comparar o saldo) =="
COMPLETO="$(curl -s "$URL/contas/$CONTA/completo")"; echo "  $COMPLETO"

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
