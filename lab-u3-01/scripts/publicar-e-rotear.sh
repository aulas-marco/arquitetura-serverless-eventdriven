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

# Modo de execução: LOCALSTACK=1 usa awslocal apontando para o LocalStack.
LOCALSTACK="${LOCALSTACK:-0}"
if [ "$LOCALSTACK" = "1" ]; then AWS="awslocal"; else AWS="aws"; fi

titulo() { printf '\n▶ %s\n' "$1"; }
nota()   { printf '  %s\n' "$1"; }
linha()  { printf '%s\n' '───────────────────────────────────────────────────────────────────'; }

LOTE='[
  {"clienteId":"cli-001","mensagem":"nao consigo logar"},
  {"clienteId":"cli-002","mensagem":"cobranca errada"},
  {"clienteId":"cli-001","mensagem":"segue o print"},
  {"clienteId":"cli-003","mensagem":"elogio ao suporte"},
  {"clienteId":"cli-002","mensagem":"aguardo retorno"},
  {"clienteId":"cli-001","mensagem":"resolvido?"},
  {"clienteId":"cli-003","mensagem":"obrigado"}
]'

# publicar_lote — em modo AWS faz o POST no HttpApi; em modo LocalStack (HttpApi
# é Pro) invoca o produtor Kinesis direto com a LISTA como payload. Devolve o
# mesmo `body` do curl (JSON com "publicados").
publicar_lote() {
  if [ "$LOCALSTACK" = "1" ]; then
    "$AWS" lambda invoke --function-name u3lab01-produtor \
      --cli-binary-format raw-in-base64-out --payload "$LOTE" \
      /tmp/u3lab01-resp.json >/dev/null
    python3 -c 'import json; print(json.load(open("/tmp/u3lab01-resp.json")).get("body",""))'
  else
    curl -s -X POST "$URL" -H 'Content-Type: application/json' -d "$LOTE"
  fi
}

if [ "$LOCALSTACK" != "1" ]; then
  URL="$(aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='UrlHttpApi'].OutputValue" --output text)"
fi

linha
echo " U3-LAB01 — Kinesis: roteamento por chave de partição"
linha
echo "Kinesis distribui registros entre shards com base num hash da chave de"
echo "partição (aqui, o clienteId). Vamos publicar mensagens de 3 clientes"
echo "intercaladas e conferir que cada cliente SEMPRE cai no mesmo shard —"
echo "é isso que garante ordenação por cliente, como partições no Kafka."

titulo "Publicando 7 eventos (cli-001 x3, cli-002 x2, cli-003 x2)"
RESP="$(publicar_lote)"

python3 -c '
import sys, json, collections
d = json.load(sys.stdin)
por_cliente = collections.defaultdict(set)
print()
print("  clienteId  ->  shardId                                    (seq)")
for r in d["publicados"]:
    seq = r.get("sequenceNumber", "")[:16]
    cid = r["clienteId"]; sid = r["shardId"]
    print(f"  {cid}   ->  {sid}  {seq}...")
    por_cliente[cid].add(sid)
print()
print("  resumo por cliente:")
todos_ok = True
for cliente, shards in sorted(por_cliente.items()):
    ok = len(shards) == 1
    todos_ok = todos_ok and ok
    rotulo = "OK, sempre o mesmo (ordem garantida)" if ok else "ESPALHADO"
    print(f"    {cliente}: {len(shards)} shard(s) -> {rotulo}")
shards_usados = {s for ss in por_cliente.values() for s in ss}
print(f"  shards distintos usados pelos 3 clientes: {len(shards_usados)}")
print("  ✓ mesma chave -> mesmo shard -> ordenacao por cliente" if todos_ok else "  ✗ inesperado")
' <<<"$RESP"

linha
echo " Chave de roteamento (clienteId) fixa o shard: ordenação por cliente,"
echo " como no Kafka. Clientes diferentes podem cair em shards diferentes —"
echo " e é isso que permite paralelismo entre eles."
linha
