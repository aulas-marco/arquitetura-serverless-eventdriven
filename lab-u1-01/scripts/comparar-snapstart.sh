#!/usr/bin/env bash
#
# comparar-snapstart.sh — Parte 5. Compara a partida fria SEM SnapStart
# (Init Duration) contra COM SnapStart (Restore Duration, no alias :live).
#
# Requer: stack u1lab01-snapstart já implantado (make deploy-snapstart).
# Uso:    ./comparar-snapstart.sh

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"

titulo() { printf '\n▶ %s\n' "$1"; }
linha()  { printf '%s\n' '───────────────────────────────────────────────────────────────────'; }

decode() {
  aws lambda invoke --function-name "$1" --region "$REGION" \
    --log-type Tail --query 'LogResult' --output text /dev/null \
    | python3 -c 'import sys,base64; sys.stdout.write(base64.b64decode(sys.stdin.read()).decode())'
}

linha
echo " U1-LAB01 · Parte 5 — SnapStart: trocar Init por Restore"
linha
echo "Uma partida fria (cold start) normal paga a fase Init inteira antes de"
echo "processar o primeiro evento. Com SnapStart, a AWS tira um snapshot do"
echo "ambiente já inicializado e o RESTAURA em vez de reexecutar o Init —"
echo "vamos comparar as duas durações lado a lado."

titulo "SEM SnapStart — forçando um cold start real"
aws lambda update-function-configuration --function-name u1lab01-snapstart-off \
  --environment "Variables={NONCE=$RANDOM}" --region "$REGION" >/dev/null
aws lambda wait function-updated --function-name u1lab01-snapstart-off --region "$REGION"
decode u1lab01-snapstart-off | grep -E 'INIT|REPORT'

titulo "COM SnapStart — alias :live, restaura o snapshot"
for i in 1 2; do
  decode u1lab01-snapstart-on:live | grep -E 'RESTORE_REPORT|REPORT'
done

linha
echo " Compare 'Init Duration' (sem SnapStart) com 'Restore Duration' (com"
echo " SnapStart) nas linhas acima: o Restore tende a ser bem mais rápido,"
echo " porque reaproveita um ambiente já pronto em vez de inicializar do zero."
linha
