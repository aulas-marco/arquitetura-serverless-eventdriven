#!/usr/bin/env bash
#
# rotear-por-chave.sh — publica eventos de três clientes e mostra que cada
# clienteId cai sempre na MESMA partição (ordenação por cliente), enquanto
# clientes diferentes se distribuem entre as partições. É o roteamento por
# hash da chave, agora em Kafka real (espelha o U3-LAB01).
#
# Requer: broker no ar (make kafka-up).
# Uso:    ./rotear-por-chave.sh

set -euo pipefail

AQUI="$(cd "$(dirname "$0")" && pwd)"
SRC="$AQUI/../src"
# shellcheck source=comum.sh
source "$AQUI/comum.sh"

exigir_broker

TOPICO="u3kafka-rotear-$$"
criar_topico "$TOPICO"
trap 'apagar_topico "$TOPICO"' EXIT

LOTE='[
  {"clienteId":"cli-001","mensagem":"nao consigo logar"},
  {"clienteId":"cli-002","mensagem":"cobranca errada"},
  {"clienteId":"cli-001","mensagem":"segue o print"},
  {"clienteId":"cli-003","mensagem":"elogio ao suporte"},
  {"clienteId":"cli-002","mensagem":"aguardo retorno"},
  {"clienteId":"cli-001","mensagem":"resolvido?"},
  {"clienteId":"cli-003","mensagem":"obrigado"}
]'

linha
echo " U3-KAFKA — roteamento por chave de partição"
linha
echo "O Kafka distribui as mensagens entre as partições do tópico com base num"
echo "hash da chave (aqui, o clienteId). Vamos publicar mensagens de 3 clientes"
echo "intercaladas e conferir que cada cliente SEMPRE cai na mesma partição."
echo "É isso que garante a ordenação por cliente: dentro de uma partição, os"
echo "offsets crescem na ordem em que as mensagens chegaram."

titulo "Publicando 7 eventos (cli-001 x3, cli-002 x2, cli-003 x2) no tópico $TOPICO"
RESP="$(TOPICO="$TOPICO" python3 "$SRC/produtor.py" "$LOTE")"

RESP="$RESP" python3 - <<'PY'
import collections
import json
import os
import sys

d = json.loads(os.environ["RESP"])
if d["falhas"]:
    print("  ✗ houve falhas de entrega:", d["publicados"])
    sys.exit(1)

por_cliente = collections.defaultdict(list)
print()
print("  clienteId  ->  partição  offset")
for r in d["publicados"]:
    print(f"  {r['clienteId']}   ->  {r['particao']}          {r['offset']}")
    por_cliente[r["clienteId"]].append((r["particao"], r["offset"]))

print()
print("  resumo por cliente:")
todos_ok = True
for cliente, itens in sorted(por_cliente.items()):
    particoes = {p for p, _ in itens}
    offsets = [o for _, o in itens]
    ok = len(particoes) == 1 and offsets == sorted(offsets) and len(set(offsets)) == len(offsets)
    todos_ok = todos_ok and ok
    rotulo = "OK, sempre a mesma partição, offsets crescentes" if ok else "INCONSISTENTE"
    print(f"    {cliente}: {len(particoes)} partição(ões) -> {rotulo}")

usadas = {p for itens in por_cliente.values() for p, _ in itens}
print(f"  partições distintas usadas pelos 3 clientes: {len(usadas)} de 4")
print("  ✓ mesma chave -> mesma partição -> ordenação por cliente" if todos_ok else "  ✗ inesperado")
sys.exit(0 if todos_ok else 1)
PY

linha
echo " A chave de roteamento (clienteId) fixa a partição: ordenação por cliente."
echo " Clientes diferentes podem cair na mesma partição (colisão de hash é normal)"
echo " ou em partições diferentes, e é isso que permite paralelismo entre eles."
linha
