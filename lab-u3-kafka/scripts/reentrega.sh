#!/usr/bin/env bash
#
# reentrega.sh — demonstra at-least-once com commit depois do processamento:
# o consumidor falha ao chegar no registro de cli-002, ANTES de confirmar o
# offset. Ao reiniciar no mesmo grupo, o Kafka entrega o registro de novo.
# É o análogo local do retry do ESM no U3-LAB02 (sem o bisect).
#
# Requer: broker no ar (make kafka-up).
# Uso:    ./reentrega.sh

set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SRC="$AQUI/../src"
# shellcheck source=comum.sh
source "$AQUI/comum.sh"

exigir_broker

TOPICO="u3kafka-reentrega-$$"
GRUPO="ree-$$"
criar_topico "$TOPICO"
TMP="$(mktemp -d)"
PID=""

limpar() {
  if [ -n "$PID" ]; then
    encerrar "$PID"
  fi
  apagar_topico "$TOPICO"
  rm -rf "$TMP"
}
trap limpar EXIT

linha
echo " U3-KAFKA — at-least-once: falha antes do commit e reentrega"
linha
echo "O Kafka guarda, por grupo e partição, o último offset CONFIRMADO. O consumidor"
echo "desta demo só confirma depois de processar. Se ele cair no meio, o próximo"
echo "consumidor do mesmo grupo recomeça do último offset confirmado, e o registro"
echo "que falhou chega de novo. Nenhum registro se perde, e alguns podem repetir."

titulo "Publicando 4 eventos (cli-002 é o que vai provocar a falha)"
TOPICO="$TOPICO" python3 "$SRC/produtor.py" '[
  {"clienteId":"cli-001","mensagem":"ok 1"},
  {"clienteId":"cli-002","mensagem":"vai falhar"},
  {"clienteId":"cli-001","mensagem":"ok 2"},
  {"clienteId":"cli-003","mensagem":"ok 3"}
]' | python3 -c "import sys, json; d = json.load(sys.stdin); print('  ' + str(len(d['publicados'])) + ' evento(s) publicados')"

titulo "Execução 1 — consumidor com FALHAR_EM=cli-002"
TOPICO="$TOPICO" CONSUMIDOR="exec-1" GRUPO="$GRUPO" FALHAR_EM="cli-002" \
  python3 "$SRC/consumidor.py" >"$TMP/run1.log" 2>&1 &
PID=$!
if ! esperar_fim "$PID" 40; then
  echo "O consumidor não falhou no prazo, o que não era esperado." >&2
  exit 1
fi
RC=0
wait "$PID" || RC=$?
PID=""
grep -E "PROCESSADO|FALHA" "$TMP/run1.log" | sed 's/^/  /'
nota "O processo terminou com código $RC: a falha ocorreu antes do commit do cli-002."

FALHA="$(grep "FALHA" "$TMP/run1.log" | head -1 | sed -E 's/.*(particao=[0-9]+ offset=[0-9]+).*/\1/')"
if [ -z "$FALHA" ]; then
  echo "Nenhuma linha [FALHA] encontrada na execução 1." >&2
  exit 1
fi

titulo "Execução 2 — mesmo grupo, sem falha intencional"
TOPICO="$TOPICO" CONSUMIDOR="exec-2" GRUPO="$GRUPO" \
  python3 "$SRC/consumidor.py" >"$TMP/run2.log" 2>&1 &
PID=$!
esperar_linhas "$TMP/run2.log" "PROCESSADO.*clienteId=cli-002" 1 30
sleep 3
encerrar "$PID"
PID=""
grep "PROCESSADO" "$TMP/run2.log" | sed 's/^/  /'

echo
if grep -q "PROCESSADO.*$FALHA" "$TMP/run2.log"; then
  echo "  ✓ o registro de cli-002 ($FALHA) falhou antes do commit e foi entregue de novo"
else
  echo "  ✗ o registro que falhou ($FALHA) não reapareceu na execução 2"
  exit 1
fi

linha
echo " Commit depois do processamento dá at-least-once: o registro que falhou volta."
echo " Registros posteriores na mesma partição também podem voltar, por isso o"
echo " processamento precisa ser idempotente (ver U1-LAB03)."
echo " No Kinesis, o ESM faz esse retry por conta própria, e o"
echo " BisectBatchOnFunctionError isola o registro venenoso dentro do lote."
linha
