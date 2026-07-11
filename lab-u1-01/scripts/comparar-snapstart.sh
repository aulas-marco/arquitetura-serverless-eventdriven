#!/usr/bin/env bash
#
# comparar-snapstart.sh — Parte 5. Compara a partida fria SEM SnapStart
# (Init Duration) contra COM SnapStart (Restore Duration, no alias :live).
#
# Requer: stack u1lab01-snapstart já implantado (make deploy-snapstart).
# Uso:    ./comparar-snapstart.sh

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"

decode() {
  aws lambda invoke --function-name "$1" --region "$REGION" \
    --log-type Tail --query 'LogResult' --output text /dev/null \
    | python3 -c 'import sys,base64; sys.stdout.write(base64.b64decode(sys.stdin.read()).decode())'
}

echo "========== SEM SnapStart (força cold start) =========="
aws lambda update-function-configuration --function-name u1lab01-snapstart-off \
  --environment "Variables={NONCE=$RANDOM}" --region "$REGION" >/dev/null
aws lambda wait function-updated --function-name u1lab01-snapstart-off --region "$REGION"
decode u1lab01-snapstart-off | grep -E 'INIT|REPORT'

echo
echo "========== COM SnapStart (alias :live, restaura snapshot) =========="
for i in 1 2; do
  decode u1lab01-snapstart-on:live | grep -E 'RESTORE_REPORT|REPORT'
done
