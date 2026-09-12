#!/usr/bin/env bash
#
# classificar-e-rotear.sh — demonstra dois conceitos do U3-LAB03:
#
#   1. Classificação via IA: tickets entram pela fila SQS, o Lambda chama
#      Claude Haiku e os distribui entre alta-prioridade, baixa-prioridade
#      e sem-classificação conforme a resposta do modelo.
#
#   2. Cache DynamoDB com TTL: na segunda rodada, os mesmos tickets retornam
#      classificados sem chamar a API — cache hit por hash SHA-256 do texto.
#
# Requer: stack u3lab03-classificador implantado (make deploy-classificador).

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STACK="u3lab03-classificador"

# Modo de execução: LOCALSTACK=1 usa awslocal apontando para o LocalStack.
# NOTA: o modo LocalStack cobre a INFRA deste lab (filas SQS, roteamento,
# tabela de cache DynamoDB), mas a chamada ao LLM continua sendo REAL — o
# classificador chama a API Anthropic (Claude Haiku) e exige ANTHROPIC_API_KEY.
# Por isso o entrypoint é o mesmo em ambos os modos (SQS, não HttpApi); só o
# binário AWS muda. Não há caminho totalmente offline para este lab.
LOCALSTACK="${LOCALSTACK:-0}"
if [ "$LOCALSTACK" = "1" ]; then AWS="awslocal"; else AWS="aws"; fi

titulo() { printf '\n▶ %s\n' "$1"; }
nota()   { printf '  %s\n' "$1"; }
linha()  { printf '%s\n' '───────────────────────────────────────────────────────────────────'; }

_output() {
  "$AWS" cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

FILA_IN="$(_output FilaTicketsUrl)"
FILA_ALTA="$(_output FilaAltaUrl)"
FILA_BAIXA="$(_output FilaBaixaUrl)"
FILA_SEM="$(_output FilaSemUrl)"

TICKETS=(
  '{"texto":"Sistema fora do ar, clientes não conseguem acessar a plataforma"}'
  '{"texto":"Quero cancelar meu plano e solicitar reembolso"}'
  '{"texto":"Erro 500 na API de pagamentos em produção"}'
  '{"texto":"Dúvida sobre valor da fatura do mês passado"}'
  '{"texto":"Banco de dados travou, dados podem estar corrompidos"}'
  '{"texto":"Como altero a forma de pagamento?"}'
  '{"texto":"CPU 100% no servidor de produção há 30 minutos"}'
  '{"texto":"Quero upgrade para o plano Enterprise"}'
  '{"texto":"Integração com ERP não sincroniza há 2 horas"}'
  '{"texto":"Elogio ao atendimento do suporte ontem"}'
)

_contar() {
  "$AWS" sqs get-queue-attributes --queue-url "$1" \
    --attribute-names ApproximateNumberOfMessages \
    --region "$REGION" \
    --query 'Attributes.ApproximateNumberOfMessages' \
    --output text 2>/dev/null || echo "0"
}

_limpar_filas() {
  for url in "$FILA_ALTA" "$FILA_BAIXA" "$FILA_SEM"; do
    "$AWS" sqs purge-queue --queue-url "$url" --region "$REGION" 2>/dev/null || true
  done
  sleep 3
}

_enviar_tickets() {
  for t in "${TICKETS[@]}"; do
    "$AWS" sqs send-message --queue-url "$FILA_IN" \
      --message-body "$t" --region "$REGION" > /dev/null
  done
}

_ts_ms() { python3 -c "import time; print(int((time.time() - $1) * 1000))"; }

_mostrar_roteamento() {
  local alta baixa sem total
  alta=$(_contar "$FILA_ALTA")
  baixa=$(_contar "$FILA_BAIXA")
  sem=$(_contar "$FILA_SEM")
  total=$((alta + baixa + sem))
  nota "fila alta-prioridade:    $alta mensagem(ns)"
  nota "fila baixa-prioridade:   $baixa mensagem(ns)"
  nota "fila sem-classificação:  $sem mensagem(ns)"
  nota "total roteado: $total / ${#TICKETS[@]}"
}

linha
echo " U3-LAB03 — Classificador com IA e cache"
linha
echo "Cada ticket que entra na fila é classificado pelo Claude Haiku e"
echo "roteado para uma de três filas de saída. A segunda parte prova o"
echo "cache: reenviar os MESMOS textos não deve gerar nenhuma nova chamada"
echo "à API — o hash SHA-256 do texto já resolve pela tabela DynamoDB."

titulo "Parte 1 — ${#TICKETS[@]} tickets distintos → chamadas à API Anthropic"
_limpar_filas
_enviar_tickets
nota "${#TICKETS[@]} tickets enviados. Aguardando classificação (45s)…"
sleep 45
_mostrar_roteamento

titulo "Logs (note 'api' — cada ticket chamou o Claude Haiku)"
"$AWS" logs filter-log-events \
  --log-group-name "/aws/lambda/u3lab03-classificador" \
  --start-time "$(_ts_ms 55)" \
  --filter-pattern "CLASSIFICADO" --region "$REGION" \
  --query 'events[*].message' --output text 2>/dev/null | head -12 \
  || echo "  (sem logs recentes)"

titulo "Parte 2 — os mesmos ${#TICKETS[@]} tickets → 0 chamadas à API (cache)"
_limpar_filas
_enviar_tickets
nota "${#TICKETS[@]} tickets enviados. Aguardando (30s)…"
sleep 30
_mostrar_roteamento

titulo "Logs (note 'cache' — nenhuma chamada à API Anthropic foi feita)"
"$AWS" logs filter-log-events \
  --log-group-name "/aws/lambda/u3lab03-classificador" \
  --start-time "$(_ts_ms 40)" \
  --filter-pattern "CLASSIFICADO" --region "$REGION" \
  --query 'events[*].message' --output text 2>/dev/null | head -12 \
  || echo "  (sem logs recentes)"

linha
echo " Cache DynamoDB (SHA-256 do texto, TTL 24h) eliminou as ${#TICKETS[@]}"
echo " chamadas à API na segunda rodada — mesma classificação, custo zero de LLM."
linha
