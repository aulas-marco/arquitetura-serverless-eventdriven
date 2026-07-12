#!/usr/bin/env bash
#
# publicar-e-rotear.sh — publica eventos de vários clientes e mostra que cada
# clienteId cai sempre no MESMO shard (ordenação por cliente), enquanto clientes
# diferentes se distribuem entre os shards. É o roteamento por hash da chave.
#
# Requer: stack u3lab01-produtor já implantado (make deploy-produtor).
# Uso:    ./publicar-e-rotear.sh

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STACK="u3lab01-produtor"

URL="$(aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
  --query "Stacks[0].Outputs[?OutputKey=='UrlHttpApi'].OutputValue" --output text)"

echo "== publicar 7 eventos (cli-001 x3, cli-002 x2, cli-003 x2) =="
RESP="$(curl -s -X POST "$URL" -H 'Content-Type: application/json' -d '[
  {"clienteId":"cli-001","mensagem":"nao consigo logar"},
  {"clienteId":"cli-002","mensagem":"cobranca errada"},
  {"clienteId":"cli-001","mensagem":"segue o print"},
  {"clienteId":"cli-003","mensagem":"elogio ao suporte"},
  {"clienteId":"cli-002","mensagem":"aguardo retorno"},
  {"clienteId":"cli-001","mensagem":"resolvido?"},
  {"clienteId":"cli-003","mensagem":"obrigado"}
]')"

echo "$RESP" | python3 -c '
import sys, json, collections
d = json.load(sys.stdin)
por_cliente = collections.defaultdict(set)
print()
print("  clienteId  ->  shardId                                    (seq)")
for r in d["publicados"]:
    seq = r.get("sequenceNumber", "")[:16]
    print(f"  {r[\"clienteId\"]}   ->  {r[\"shardId\"]}  {seq}...")
    por_cliente[r["clienteId"]].add(r["shardId"])
print()
print("  resumo por cliente:")
todos_ok = True
for cliente, shards in sorted(por_cliente.items()):
    ok = len(shards) == 1
    todos_ok = todos_ok and ok
    print(f"    {cliente}: {len(shards)} shard(s) -> {\"OK, sempre o mesmo (ordem garantida)\" if ok else \"ESPALHADO\"}")
shards_usados = {s for ss in por_cliente.values() for s in ss}
print(f"  shards distintos usados pelos 3 clientes: {len(shards_usados)}")
print("  ✓ mesma chave -> mesmo shard -> ordenacao por cliente" if todos_ok else "  ✗ inesperado")
'
echo
echo "Chave de roteamento (clienteId) fixa o shard: ordenacao por cliente, como no Kafka."
