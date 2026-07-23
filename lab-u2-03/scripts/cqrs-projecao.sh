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

# Modo de execução: LOCALSTACK=1 usa awslocal apontando para o LocalStack.
LOCALSTACK="${LOCALSTACK:-0}"
if [ "$LOCALSTACK" = "1" ]; then AWS="awslocal"; else AWS="aws"; fi

FN_COMANDO="u2lab03-comando"
FN_CONSULTA="u2lab03-consulta"
FN_REBUILD="u2lab03-rebuild"

saida() {
  "$AWS" cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

# _invoke FN EVENTO_JSON -> imprime o `body` da resposta.
_invoke() {
  "$AWS" lambda invoke --function-name "$1" \
    --cli-binary-format raw-in-base64-out --payload "$2" \
    /tmp/u2lab03-resp.json >/dev/null
  python3 -c 'import json; print(json.load(open("/tmp/u2lab03-resp.json")).get("body",""))'
}

# comando — POST no lado de escrita. Em modo AWS via HttpApi; em LocalStack invoca
# u2lab03-comando com routeKey+pathParameters+body. Uso: comando ROTA CONTA CORPO
comando() {
  local rota="$1" conta="$2" corpo="${3:-}"
  if [ "$LOCALSTACK" = "1" ]; then
    local params="{}"; [ -n "$conta" ] && params="{\"contaId\":\"$conta\"}"
    local body_field="null"
    [ -n "$corpo" ] && body_field="$(python3 -c 'import json,sys; print(json.dumps(sys.argv[1]))' "$corpo")"
    _invoke "$FN_COMANDO" "{\"routeKey\":\"POST $rota\",\"pathParameters\":$params,\"body\":$body_field}"
  else
    local url_final="${rota/\{contaId\}/$conta}"
    curl -s --max-time 60 -X POST "$URL$url_final" -H 'Content-Type: application/json' -d "$corpo"
  fi
}

# consultar — GET no lado de leitura (projeção). Em LocalStack invoca u2lab03-consulta.
consultar() {
  local conta="$1"
  if [ "$LOCALSTACK" = "1" ]; then
    _invoke "$FN_CONSULTA" "{\"routeKey\":\"GET /contas/{contaId}\",\"pathParameters\":{\"contaId\":\"$conta\"},\"body\":null}"
  else
    curl -s "$URL/contas/$conta"
  fi
}

# rebuild — dispara o rebuild da projeção. Em LocalStack invoca u2lab03-rebuild.
rebuild() {
  if [ "$LOCALSTACK" = "1" ]; then
    _invoke "$FN_REBUILD" "{\"routeKey\":\"POST /projecao/rebuild\",\"body\":null}"
  else
    curl -s --max-time 60 -X POST "$URL/projecao/rebuild"
  fi
}

criar() {
  comando "/contas" "" "{\"titular\":\"$1\"}" | python3 -c 'import sys,json; print(json.load(sys.stdin)["contaId"])'
}

# Consulta a projeção repetidamente até o saldo esperado aparecer (ou desistir).
esperar_saldo() {
  local conta="$1" esperado="$2" i saldo
  # O stream recém-criado leva alguns segundos para o ESM começar a consumir;
  # depois disso, cada evento projeta em ~1-3s. Damos folga na primeira espera.
  for i in $(seq 1 30); do
    resp="$(consultar "$conta")"
    saldo="$(echo "$resp" | python3 -c 'import sys,json;d=json.load(sys.stdin);print(d.get("saldo","-"))' 2>/dev/null || echo '-')"
    echo "    tentativa $i: $resp"
    [ "$saldo" = "$esperado" ] && return 0
    sleep 2
  done
  return 1
}

if [ "$LOCALSTACK" != "1" ]; then URL="$(saida UrlHttpApi)"; fi
SALDOS="$(saida TabelaSaldos)"

echo "== criar conta A (Maria) e depositar 100 + 50 =="
A="$(criar Maria)"
comando "/contas/{contaId}/depositos" "$A" '{"valor":100}' >/dev/null
comando "/contas/{contaId}/depositos" "$A" '{"valor":50}' >/dev/null
echo "  A=$A"

echo "== consulta logo após escrever — consistência eventual (pode atrasar) =="
esperar_saldo "$A" 150 && echo "  ✓ projeção convergiu para 150"

echo "== criar conta B (João) e depositar 20 =="
B="$(criar Joao)"
comando "/contas/{contaId}/depositos" "$B" '{"valor":20}' >/dev/null
esperar_saldo "$B" 20 >/dev/null && echo "  B=$B projeção=20"

echo "== transferência atômica A -> B de 30 (TransactWriteItems) =="
comando "/transferencias" "" "{\"origem\":\"$A\",\"destino\":\"$B\",\"valor\":30}"; echo

echo "== projeções após a transferência (A deve cair p/ 120, B subir p/ 50) =="
esperar_saldo "$A" 120 >/dev/null && echo "  ✓ A projetou 120"
esperar_saldo "$B" 50  >/dev/null && echo "  ✓ B projetou 50"

echo "== CQRS: a consulta lê a tabela de projeção, não o event store =="
"$AWS" dynamodb get-item --table-name "$SALDOS" --region "$REGION" \
  --key "{\"contaId\":{\"S\":\"$A\"}}" \
  --query 'Item.{conta:contaId.S,titular:titular.S,saldo:saldo.N,seq:ultimaSequencia.N}' --output table

echo "== rebuild: apagar a projeção de A e reconstruí-la do event store =="
"$AWS" dynamodb delete-item --table-name "$SALDOS" --region "$REGION" --key "{\"contaId\":{\"S\":\"$A\"}}"
echo "  projeção de A apagada; consulta agora:"
consultar "$A"; echo
echo "  disparando rebuild:"
rebuild; echo
echo "  consulta de A após o rebuild (deve voltar a 120):"
consultar "$A"; echo
echo
echo "Escrita grava eventos; projeção assíncrona alimenta a leitura; rebuild reconstrói do store."
