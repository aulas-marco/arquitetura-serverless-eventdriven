#!/usr/bin/env bash
#
# disparar-gatilhos.sh — Parte 2. Dispara os 3 gatilhos sob demanda da
# GatilhosFunction (HTTP, SQS, S3) e mostra, nos logs, como a MESMA função
# reconhece cada origem pela forma do `event`. O 4º gatilho (EventBridge,
# agendado a cada 5 min) roda sozinho e não é acionado por este script.
#
# Requer: stack u1lab01-partes1a3 já implantado (make deploy-fundamentos).
# Uso:    ./disparar-gatilhos.sh

set -euo pipefail

REGION="${AWS_DEFAULT_REGION:-us-east-1}"
STACK="u1lab01-partes1a3"

# Modo de execução: LOCALSTACK=1 usa awslocal apontando para o LocalStack
# (http://localhost:4566); o padrão usa a AWS real.
LOCALSTACK="${LOCALSTACK:-0}"
if [ "$LOCALSTACK" = "1" ]; then AWS="awslocal"; else AWS="aws"; fi

saida() {
  "$AWS" cloudformation describe-stacks --stack-name "$STACK" --region "$REGION" \
    --query "Stacks[0].Outputs[?OutputKey=='$1'].OutputValue" --output text
}

titulo() { printf '\n▶ %s\n' "$1"; }
nota()   { printf '  %s\n' "$1"; }
linha()  { printf '%s\n' '───────────────────────────────────────────────────────────────────'; }

linha
echo " U1-LAB01 · Parte 2 — Uma função, quatro gatilhos"
linha
echo "A GatilhosFunction está ligada a 4 fontes de evento diferentes. Este"
echo "script dispara 3 delas sob demanda (HTTP, SQS, S3); a 4ª (EventBridge,"
echo "a cada 5 min) roda sozinha em segundo plano. No fim, os logs mostram"
echo "como a MESMA função reconheceu cada origem, sem handlers separados."

FILA="$(saida FilaGatilhoUrl)"
BUCKET="$(saida BucketGatilhoNome)"

# Marca o início para filtrar, no fim, só os logs desta execução — sem
# misturar com disparos de rodadas anteriores.
INICIO="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

titulo "(a) HTTP — POST na API Gateway"
nota "Requisição HTTP direta: o jeito mais comum de acionar uma função."
if [ "$LOCALSTACK" = "1" ]; then
  # HttpApi (API Gateway v2) é Pro — indisponível no LocalStack Community.
  # Invoca a Lambda direto com um evento sintetizado no formato do payload v2.
  "$AWS" lambda invoke --function-name u1lab01-gatilhos \
    --cli-binary-format raw-in-base64-out \
    --payload '{"requestContext":{"http":{"method":"POST","path":"/disparar"}}}' \
    /tmp/u1lab01-http-resp.json >/dev/null
  RESPOSTA="$(cat /tmp/u1lab01-http-resp.json)"
else
  URL="$(saida UrlHttpApi)"
  RESPOSTA="$(curl -s -X POST "$URL")"
fi
nota "Resposta síncrona da função: $RESPOSTA"

titulo "(b) SQS — mensagem numa fila"
nota "A função também está inscrita numa fila; toda mensagem vira um evento."
ID_MENSAGEM="$("$AWS" sqs send-message --queue-url "$FILA" --message-body '{"pedido":"123"}' \
  --region "$REGION" --query 'MessageId' --output text)"
nota "Mensagem enviada (ID: $ID_MENSAGEM). Processamento é assíncrono — sem resposta imediata."

titulo "(c) S3 — upload de objeto"
nota "Todo objeto criado no bucket também dispara a função."
tmp="$(mktemp)"; echo "conteudo de teste" > "$tmp"
"$AWS" s3 cp "$tmp" "s3://$BUCKET/teste-lab.txt" --region "$REGION" --only-show-errors
rm -f "$tmp"
nota "Objeto enviado: s3://$BUCKET/teste-lab.txt. Processamento também é assíncrono."

titulo "Aguardando os gatilhos assíncronos (SQS/S3) serem processados…"
sleep 12
nota "concluído."

titulo "Origens identificadas nos logs da função"
nota "Cada linha veio da MESMA função — ela reconheceu a origem pela forma"
nota "do event recebido, sem precisar de um handler por gatilho:"
echo
"$AWS" logs tail /aws/lambda/u1lab01-gatilhos --since "$INICIO" --region "$REGION" --format short \
  | grep -E '\[ORIGEM\]' | sort -u

linha
echo " Fim da demo. O 4º gatilho (EventBridge) dispara sozinho a cada 5 min."
echo " Para vê-lo, aguarde o próximo ciclo e rode:"
echo "   aws logs tail /aws/lambda/u1lab01-gatilhos --since 10m | grep EventBridge"
linha
