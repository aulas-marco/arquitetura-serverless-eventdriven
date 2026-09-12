#!/usr/bin/env bash
#
# veneno-e-dlq.sh — envia um lote com 2 pedidos bons e 1 veneno (valor -1).
# Prova duas coisas: (1) falha parcial — os bons são processados na 1ª vez e não
# voltam; (2) DLQ — o veneno é reentregue até maxReceiveCount e cai na DLQ.
#
# Requer: stack u1lab04-dlq já implantado (make deploy-dlq).
# Uso:    ./veneno-e-dlq.sh

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STACK="u1lab04-dlq"

# Modo de execução: LOCALSTACK=1 usa awslocal apontando para o LocalStack.
LOCALSTACK="${LOCALSTACK:-0}"
if [ "$LOCALSTACK" = "1" ]; then AWS="awslocal"; else AWS="aws"; fi

saida() {
  "$AWS" cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

titulo() { printf '\n▶ %s\n' "$1"; }
nota()   { printf '  %s\n' "$1"; }
linha()  { printf '%s\n' '───────────────────────────────────────────────────────────────────'; }

# enviar_lote — em modo AWS faz o POST no HttpApi; em modo LocalStack (HttpApi é
# Pro) invoca a Lambda produtora direto com a LISTA de pedidos como payload.
enviar_lote() {
  local corpo="$1"
  if [ "$LOCALSTACK" = "1" ]; then
    "$AWS" lambda invoke --function-name u1lab04-publicar \
      --cli-binary-format raw-in-base64-out --payload "$corpo" \
      /tmp/u1lab04-resp.json >/dev/null
    python3 -c 'import json; print(json.load(open("/tmp/u1lab04-resp.json")).get("body",""))'
  else
    curl -s -X POST "$URL" -H 'Content-Type: application/json' -d "$corpo"
  fi
}

linha
echo " U1-LAB04 — Resiliência e Dead Letter Queue"
linha
echo "Vamos enviar um lote com 2 pedidos bons e 1 'veneno' (valor inválido,"
echo "que sempre falha ao processar). Isso prova duas coisas: (1) falha"
echo "parcial — os bons são processados e não voltam à fila; (2) o veneno é"
echo "reentregue até maxReceiveCount e então cai na DLQ, sem travar a fila"
echo "principal nem perder as mensagens boas."

DLQ="$(saida DLQUrl)"
if [ "$LOCALSTACK" != "1" ]; then URL="$(saida UrlHttpApi)"; fi
# No modo LocalStack precisamos da URL da fila de origem para o redrive degradado.
FILA_ORIGEM="$(saida FilaUrl 2>/dev/null || true)"
SUFIXO="$(date +%s)"
BOM1="bom-a-$SUFIXO"; BOM2="bom-b-$SUFIXO"; VENENO="veneno-$SUFIXO"
INICIO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

titulo "Enviando lote: 2 bons + 1 veneno (valor -1)"
enviar_lote "[
  {\"pedidoId\":\"$BOM1\",\"valor\":100},
  {\"pedidoId\":\"$VENENO\",\"valor\":-1},
  {\"pedidoId\":\"$BOM2\",\"valor\":200}
]"
echo

titulo "Aguardando processamento + reentregas do veneno (maxReceiveCount=3)…"
sleep 45
nota "concluído."

titulo "O que o consumidor fez (bons uma vez, veneno tentado 1→2→3)"
"$AWS" logs tail /aws/lambda/u1lab04-consumidor --since "$INICIO" --region "$REGION" --format short \
  | grep -E "\[OK\]|\[FALHA\]" | grep "$SUFIXO" || echo "  (nada ainda — rode de novo)"

titulo "A DLQ recebeu o veneno?"
"$AWS" sqs get-queue-attributes --queue-url "$DLQ" --region "$REGION" \
  --attribute-names ApproximateNumberOfMessages \
  --query 'Attributes.ApproximateNumberOfMessages' --output text | \
  xargs -I{} echo "  mensagens na DLQ: {}"

titulo "Conteúdo do veneno na DLQ"
"$AWS" sqs receive-message --queue-url "$DLQ" --region "$REGION" \
  --max-number-of-messages 1 --visibility-timeout 1 \
  --query 'Messages[0].Body' --output text || echo "  (nada visível — rode de novo)"

linha
echo " Parte 1 concluída: bons processados 1x e apagados; veneno tentado 3x"
echo " e movido para a DLQ."
linha

# ---------------------------------------------------------------------------
# Parte 2 — redrive: devolver o que está na DLQ ao fluxo de origem.
# start-message-move-task é a API nativa de redrive da SQS: move as mensagens
# da DLQ de volta para a fila de origem (inferida pela RedrivePolicy). É a ação
# do operador para "fechar o ciclo" DEPOIS de corrigir a causa raiz.
# ---------------------------------------------------------------------------
echo
linha
echo " Parte 2 — Redrive: devolver o veneno da DLQ ao fluxo"
linha
echo "Redrive é a ação do operador para reprocessar o que ficou na DLQ,"
echo "normalmente DEPOIS de corrigir a causa raiz do erro. Aqui, como o"
echo "veneno continua com valor inválido, esperamos que ele falhe de novo e"
echo "volte para a DLQ — isso ilustra que redrive por si só não conserta nada."

DLQ_ARN="$("$AWS" sqs get-queue-attributes --queue-url "$DLQ" --region "$REGION" \
  --attribute-names QueueArn --query 'Attributes.QueueArn' --output text)"

titulo "Iniciando o redrive"
if [ "$LOCALSTACK" = "1" ]; then
  # start-message-move-task existe no build do LocalStack Community mas o redrive
  # nativo é instável (nem sempre reenfileira de fato). Fazemos o redrive de forma
  # DEGRADADA e determinística: drenar a DLQ com receive-message e reenviar cada
  # mensagem à fila de origem com send-message. Efeito equivalente ao operador
  # "fechar o ciclo" — a mensagem volta ao fluxo e é reprocessada.
  nota "[LocalStack] redrive degradado: receive-message na DLQ + send-message p/ origem"
  # Espera a mensagem ficar visível de novo (a checagem anterior a recebeu com
  # visibility-timeout curto) e drena a DLQ em algumas passadas.
  sleep 3
  MOVIDAS=0
  for _ in $(seq 1 8); do
    CORPO_MSG="$("$AWS" sqs receive-message --queue-url "$DLQ" --region "$REGION" \
      --max-number-of-messages 1 --wait-time-seconds 2 --visibility-timeout 30 \
      --query 'Messages[0].{Body:Body,RH:ReceiptHandle}' --output json 2>/dev/null)"
    if [ "$CORPO_MSG" = "null" ] || [ -z "$CORPO_MSG" ]; then
      [ "$MOVIDAS" -gt 0 ] && break
      sleep 2; continue
    fi
    BODY="$(echo "$CORPO_MSG" | python3 -c 'import json,sys; print(json.load(sys.stdin)["Body"])')"
    RH="$(echo "$CORPO_MSG" | python3 -c 'import json,sys; print(json.load(sys.stdin)["RH"])')"
    "$AWS" sqs send-message --queue-url "$FILA_ORIGEM" --message-body "$BODY" --region "$REGION" >/dev/null
    "$AWS" sqs delete-message --queue-url "$DLQ" --receipt-handle "$RH" --region "$REGION" >/dev/null
    MOVIDAS=$((MOVIDAS + 1))
  done
  nota "$MOVIDAS mensagem(ns) redrivada(s) da DLQ para a fila de origem"
else
  nota "chamando start-message-move-task (redrive nativo da SQS)…"
  aws sqs start-message-move-task --source-arn "$DLQ_ARN" --region "$REGION" \
    --query 'TaskHandle' --output text \
    | xargs -I{} echo "  task de redrive iniciada" >/dev/null || true
fi

titulo "Aguardando o veneno ser reentregue e falhar de novo (maxReceiveCount=3)…"
sleep 45
nota "concluído."

titulo "O consumidor tentou o veneno outra vez?"
"$AWS" logs tail /aws/lambda/u1lab04-consumidor --since "$INICIO" --region "$REGION" --format short \
  | grep -E "\[FALHA\]" | grep "$VENENO" || echo "  (sem logs novos — rode de novo)"

titulo "A DLQ recebeu o veneno de volta?"
"$AWS" sqs get-queue-attributes --queue-url "$DLQ" --region "$REGION" \
  --attribute-names ApproximateNumberOfMessages \
  --query 'Attributes.ApproximateNumberOfMessages' --output text | \
  xargs -I{} echo "  mensagens na DLQ: {}"

linha
echo " Redrive é replay, não conserto: devolve a mensagem à fila, mas não muda"
echo " a causa. Como valor<=0 falha sempre, o veneno voltou para a DLQ. Em"
echo " produção, o operador corrige a causa (deploy do fix ou dado corrigido)"
echo " ANTES de redrivar — só então o redrive termina em sucesso."
linha
