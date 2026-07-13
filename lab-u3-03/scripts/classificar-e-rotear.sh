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

_output() {
  aws cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
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
  aws sqs get-queue-attributes --queue-url "$1" \
    --attribute-names ApproximateNumberOfMessages \
    --region "$REGION" \
    --query 'Attributes.ApproximateNumberOfMessages' \
    --output text 2>/dev/null || echo "0"
}

_limpar_filas() {
  for url in "$FILA_ALTA" "$FILA_BAIXA" "$FILA_SEM"; do
    aws sqs purge-queue --queue-url "$url" --region "$REGION" 2>/dev/null || true
  done
  sleep 3
}

_enviar_tickets() {
  for t in "${TICKETS[@]}"; do
    aws sqs send-message --queue-url "$FILA_IN" \
      --message-body "$t" --region "$REGION" > /dev/null
  done
}

_ts_ms() { python3 -c "import time; print(int((time.time() - $1) * 1000))"; }

# --------------------------------------------------------------------------
echo "== Parte 1: ${#TICKETS[@]} tickets distintos → chamadas à API Anthropic =="
_limpar_filas
_enviar_tickets
echo "   ${#TICKETS[@]} tickets enviados. Aguardando classificação (45s)..."
sleep 45

ALTA=$(_contar "$FILA_ALTA")
BAIXA=$(_contar "$FILA_BAIXA")
SEM=$(_contar "$FILA_SEM")
TOTAL=$((ALTA + BAIXA + SEM))

echo ""
echo "   Fila alta-prioridade:    $ALTA mensagem(ns)"
echo "   Fila baixa-prioridade:   $BAIXA mensagem(ns)"
echo "   Fila sem-classificação:  $SEM mensagem(ns)"
echo "   Total roteado: $TOTAL / ${#TICKETS[@]}"
echo ""
echo "   Logs (note 'api' — cada ticket chamou o Claude Haiku):"
aws logs filter-log-events \
  --log-group-name "/aws/lambda/u3lab03-classificador" \
  --start-time "$(_ts_ms 55)" \
  --filter-pattern "CLASSIFICADO" --region "$REGION" \
  --query 'events[*].message' --output text 2>/dev/null | head -12 \
  || echo "   (sem logs recentes)"

# --------------------------------------------------------------------------
echo ""
echo "== Parte 2: os mesmos ${#TICKETS[@]} tickets → 0 chamadas à API (cache) =="
_limpar_filas
_enviar_tickets
echo "   ${#TICKETS[@]} tickets enviados. Aguardando (30s)..."
sleep 30

ALTA=$(_contar "$FILA_ALTA")
BAIXA=$(_contar "$FILA_BAIXA")
SEM=$(_contar "$FILA_SEM")
TOTAL=$((ALTA + BAIXA + SEM))

echo ""
echo "   Fila alta-prioridade:    $ALTA mensagem(ns)"
echo "   Fila baixa-prioridade:   $BAIXA mensagem(ns)"
echo "   Fila sem-classificação:  $SEM mensagem(ns)"
echo "   Total roteado: $TOTAL / ${#TICKETS[@]}"
echo ""
echo "   Logs (note 'cache' — nenhuma chamada à API Anthropic foi feita):"
aws logs filter-log-events \
  --log-group-name "/aws/lambda/u3lab03-classificador" \
  --start-time "$(_ts_ms 40)" \
  --filter-pattern "CLASSIFICADO" --region "$REGION" \
  --query 'events[*].message' --output text 2>/dev/null | head -12 \
  || echo "   (sem logs recentes)"

echo ""
echo "Cache DynamoDB (SHA-256 do texto, TTL 24h) eliminou as ${#TICKETS[@]} chamadas"
echo "à API na segunda rodada — mesma classificação, custo zero de LLM."
