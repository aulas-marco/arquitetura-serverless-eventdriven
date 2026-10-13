#!/usr/bin/env bash
#
# grupos-e-rebalanceamento.sh — demonstra dois conceitos de consumer groups:
#
#   Parte A. Grupos DIFERENTES recebem TODOS os eventos (espelha a Parte 1 do
#            U3-LAB02, onde cada Lambda com seu ESM é um grupo distinto).
#   Parte B. Membros do MESMO grupo dividem as partições, e a divisão é refeita
#            (rebalanceamento) a cada membro que entra: 1 -> 2 -> 3 consumidores.
#            O ESM do Kinesis não expõe isso, o Kafka sim.
#
# Requer: broker no ar (make kafka-up).
# Uso:    ./grupos-e-rebalanceamento.sh

set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SRC="$AQUI/../src"
# shellcheck source=comum.sh
source "$AQUI/comum.sh"

exigir_broker

TOPICO="u3kafka-grupos-$$"
criar_topico "$TOPICO"
TMP="$(mktemp -d)"
PIDS=""

limpar() {
  if [ -n "$PIDS" ]; then
    # shellcheck disable=SC2086
    encerrar $PIDS
  fi
  apagar_topico "$TOPICO"
  rm -rf "$TMP"
}
trap limpar EXIT

iniciar_consumidor() {  # iniciar_consumidor <rótulo> <grupo> <arquivo-de-log>
  TOPICO="$TOPICO" CONSUMIDOR="$1" GRUPO="$2" python3 "$SRC/consumidor.py" >"$3" 2>&1 &
  LAST_PID=$!
  PIDS="$PIDS $LAST_PID"
}

linha
echo " U3-KAFKA — consumer groups e rebalanceamento"
linha
echo "No Kafka, um consumer group é um conjunto de consumidores que compartilham"
echo "a leitura de um tópico. Grupos diferentes recebem o tópico inteiro cada um."
echo "Dentro de um grupo, cada partição vai para exatamente um membro, e a divisão"
echo "é refeita sempre que um membro entra ou sai."

titulo "Parte A — dois grupos independentes recebem todos os eventos"
nota "Publicando 5 eventos no tópico ${TOPICO}…"
TOPICO="$TOPICO" python3 "$SRC/produtor.py" '[
  {"clienteId":"cli-001","mensagem":"nao consigo logar"},
  {"clienteId":"cli-002","mensagem":"cobranca errada"},
  {"clienteId":"cli-001","mensagem":"segue o print"},
  {"clienteId":"cli-003","mensagem":"elogio ao suporte"},
  {"clienteId":"cli-002","mensagem":"aguardo retorno"}
]' | python3 -c "import sys, json; d = json.load(sys.stdin); print('  ' + str(len(d['publicados'])) + ' evento(s) publicados')"

nota "Iniciando um consumidor no grupo A e outro no grupo B…"
iniciar_consumidor "grupo-a" "ga-$$" "$TMP/a.log"
PID_A="$LAST_PID"
iniciar_consumidor "grupo-b" "gb-$$" "$TMP/b.log"
PID_B="$LAST_PID"
esperar_linhas "$TMP/a.log" "PROCESSADO" 5 30
esperar_linhas "$TMP/b.log" "PROCESSADO" 5 30

titulo "Eventos recebidos pelo GRUPO A"
grep "PROCESSADO" "$TMP/a.log" | sed 's/^/  /'
titulo "Eventos recebidos pelo GRUPO B"
grep "PROCESSADO" "$TMP/b.log" | sed 's/^/  /'
nota "Os dois grupos receberam os mesmos 5 eventos: cada grupo lê o tópico inteiro,"
nota "como cada Lambda com seu próprio ESM lê o stream inteiro no Kinesis."

encerrar "$PID_A" "$PID_B"
PIDS=""

titulo "Parte B — um grupo, 1 -> 2 -> 3 consumidores: as 4 partições são redivididas"
GRUPO_REB="reb-$$"

nota "Entra o consumidor c1 (sozinho no grupo)…"
iniciar_consumidor "c1" "$GRUPO_REB" "$TMP/c1.log"
PID_1="$LAST_PID"
esperar_linhas "$TMP/c1.log" "ATRIBUIDO" 1 30
grep "ATRIBUIDO" "$TMP/c1.log" | tail -1 | sed 's/^/  /'

nota "Entra o consumidor c2: o grupo é rebalanceado…"
# Registra quantas atribuições c1 já tinha, para esperar a PRÓXIMA e nunca ler
# uma atribuição antiga como se fosse a do rebalanceamento atual.
ANTES_1="$(contar_linhas "$TMP/c1.log" "ATRIBUIDO")"
iniciar_consumidor "c2" "$GRUPO_REB" "$TMP/c2.log"
PID_2="$LAST_PID"
esperar_linhas "$TMP/c2.log" "ATRIBUIDO" 1 30
esperar_linhas "$TMP/c1.log" "ATRIBUIDO" "$((ANTES_1 + 1))" 30
grep "ATRIBUIDO" "$TMP/c1.log" | tail -1 | sed 's/^/  /'
grep "ATRIBUIDO" "$TMP/c2.log" | tail -1 | sed 's/^/  /'

nota "Entra o consumidor c3: novo rebalanceamento…"
ANTES_1="$(contar_linhas "$TMP/c1.log" "ATRIBUIDO")"
ANTES_2="$(contar_linhas "$TMP/c2.log" "ATRIBUIDO")"
iniciar_consumidor "c3" "$GRUPO_REB" "$TMP/c3.log"
PID_3="$LAST_PID"
esperar_linhas "$TMP/c3.log" "ATRIBUIDO" 1 30
esperar_linhas "$TMP/c1.log" "ATRIBUIDO" "$((ANTES_1 + 1))" 30
esperar_linhas "$TMP/c2.log" "ATRIBUIDO" "$((ANTES_2 + 1))" 30

titulo "Atribuição final (última linha [ATRIBUIDO] de cada membro)"
for n in 1 2 3; do
  grep "ATRIBUIDO" "$TMP/c$n.log" | tail -1 | sed 's/^/  /'
done

python3 - "$TMP" <<'PY'
import re
import sys

tmp = sys.argv[1]
por_membro = {}
for n in (1, 2, 3):
    ultima = [l for l in open(f"{tmp}/c{n}.log") if "[ATRIBUIDO]" in l][-1]
    por_membro[n] = set(int(x) for x in re.findall(r"\d+", ultima.split("particoes=")[1]))

todas = set().union(*por_membro.values())
somas = sum(len(v) for v in por_membro.values())
sem_sobreposicao = somas == len(todas)
print()
print(f"  partições atribuídas no total: {sorted(todas)}")
if todas == {0, 1, 2, 3} and sem_sobreposicao:
    print("  ✓ as 4 partições estão divididas entre os 3 membros, sem sobreposição")
else:
    print("  ✗ divisão inesperada")
    sys.exit(1)
PY

encerrar "$PID_1" "$PID_2" "$PID_3"
PIDS=""

linha
echo " Grupos diferentes recebem tudo. Membros do mesmo grupo dividem as partições,"
echo " e a divisão é refeita quando alguém entra. Com 4 partições, o grupo usa no"
echo " máximo 4 membros: o quinto ficaria ocioso."
linha
