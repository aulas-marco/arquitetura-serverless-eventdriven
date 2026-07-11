#!/usr/bin/env bash
#
# cqrs-projecao.sh — mostra o CQRS ponta a ponta: escrita grava eventos; a
# projeção (via DynamoDB Streams) atualiza o modelo de leitura de forma
# assíncrona (consistência eventual); a consulta lê só a projeção; a
# transferência move saldo entre contas atomicamente; e o rebuild reconstrói a
# projeção a partir do event store.
#
# Requer: stack u2lab03-cqrs já implantado (make deploy-cqrs).
# Uso:    ./cqrs-projecao.sh

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STACK="u2lab03-cqrs"

saida() {
  aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

URL="$(saida UrlHttpApi)"
SALDOS="$(saida TabelaSaldos)"

criar() {
  curl -s -X POST "$URL/contas" -H 'Content-Type: application/json' \
    -d "{\"titular\":\"$1\"}" | python3 -c 'import sys,json; print(json.load(sys.stdin)["contaId"])'
}

# Consulta a projeção repetidamente até o saldo esperado aparecer (ou desistir).
esperar_saldo() {
  local conta="$1" esperado="$2" i saldo
  # O stream recém-criado leva alguns segundos para o ESM começar a consumir;
  # depois disso, cada evento projeta em ~1-3s. Damos folga na primeira espera.
  for i in $(seq 1 30); do
    resp="$(curl -s "$URL/contas/$conta")"
    saldo="$(echo "$resp" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("saldo","-"))' 2>/dev/null || echo '-')"
    echo "    tentativa $i: $resp"
    [ "$saldo" = "$esperado" ] && return 0
    sleep 2
  done
  return 1
}

echo "== criar conta A (Maria) e depositar 100 + 50 =="
A="$(criar Maria)"
curl -s -o /dev/null -X POST "$URL/contas/$A/depositos" -H 'Content-Type: application/json' -d '{"valor":100}'
curl -s -o /dev/null -X POST "$URL/contas/$A/depositos" -H 'Content-Type: application/json' -d '{"valor":50}'
echo "  A=$A"

echo "== consulta logo após escrever — consistência eventual (pode atrasar) =="
esperar_saldo "$A" 150 && echo "  ✓ projeção convergiu para 150"

echo "== criar conta B (João) e depositar 20 =="
B="$(criar Joao)"
curl -s -o /dev/null -X POST "$URL/contas/$B/depositos" -H 'Content-Type: application/json' -d '{"valor":20}'
esperar_saldo "$B" 20 >/dev/null && echo "  B=$B projeção=20"

echo "== transferência atômica A -> B de 30 (TransactWriteItems) =="
curl -s --max-time 60 -X POST "$URL/transferencias" -H 'Content-Type: application/json' \
  -d "{\"origem\":\"$A\",\"destino\":\"$B\",\"valor\":30}"; echo

echo "== projeções após a transferência (A deve cair p/ 120, B subir p/ 50) =="
esperar_saldo "$A" 120 >/dev/null && echo "  ✓ A projetou 120"
esperar_saldo "$B" 50  >/dev/null && echo "  ✓ B projetou 50"

echo "== CQRS: a consulta lê a tabela de projeção, não o event store =="
aws dynamodb get-item --table-name "$SALDOS" --region "$REGION" \
  --key "{\"contaId\":{\"S\":\"$A\"}}" \
  --query 'Item.{conta:contaId.S,titular:titular.S,saldo:saldo.N,seq:ultimaSequencia.N}' --output table

echo "== rebuild: apagar a projeção de A e reconstruí-la do event store =="
aws dynamodb delete-item --table-name "$SALDOS" --region "$REGION" --key "{\"contaId\":{\"S\":\"$A\"}}"
echo "  projeção de A apagada; consulta agora:"
curl -s "$URL/contas/$A"; echo
echo "  disparando rebuild:"
curl -s --max-time 60 -X POST "$URL/projecao/rebuild"; echo
echo "  consulta de A após o rebuild (deve voltar a 120):"
curl -s "$URL/contas/$A"; echo
echo
echo "Escrita grava eventos; projeção assíncrona alimenta a leitura; rebuild reconstrói do store."
