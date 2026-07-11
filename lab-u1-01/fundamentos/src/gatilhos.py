"""Parte 2 — Gatilhos diversos.

UM único handler ligado a QUATRO fontes de evento no template SAM:
API Gateway (HTTP), SQS, S3 e EventBridge (agendado).

O ponto do exercício: o `event` que chega tem forma diferente conforme a origem.
A mesma função precisa descobrir de onde veio o evento antes de processá-lo.
Aqui só identificamos a origem e imprimimos a forma — para você DIFERENCIAR
os envelopes lado a lado nos logs.
"""

import json


def identificar_origem(event):
    """Deduz a origem do evento pela forma do dicionário.

    Cada serviço da AWS entrega o `event` com uma assinatura própria.
    Reconhecer essas assinaturas é o que permite um handler multiuso.
    """
    if not isinstance(event, dict):
        return "desconhecida", "event não é um dicionário"

    # API Gateway (HTTP API, payload v2): tem requestContext.http
    if "requestContext" in event and "http" in event.get("requestContext", {}):
        metodo = event["requestContext"]["http"].get("method")
        rota = event["requestContext"]["http"].get("path")
        return "API Gateway (HTTP)", f"{metodo} {rota}"

    # SQS: lista Records, cada um com eventSource == aws:sqs
    if _tem_records_de(event, "aws:sqs"):
        n = len(event["Records"])
        return "SQS", f"lote com {n} mensagem(ns)"

    # S3: lista Records, cada um com eventSource == aws:s3
    if _tem_records_de(event, "aws:s3"):
        rec = event["Records"][0]
        bucket = rec["s3"]["bucket"]["name"]
        chave = rec["s3"]["object"]["key"]
        return "S3", f"s3://{bucket}/{chave}"

    # EventBridge (regra agendada): tem detail-type e source
    if "detail-type" in event and "source" in event:
        return "EventBridge", f"{event['source']} / {event['detail-type']}"

    return "desconhecida", "nenhuma assinatura conhecida"


def _tem_records_de(event, event_source):
    records = event.get("Records")
    return (
        isinstance(records, list)
        and len(records) > 0
        and records[0].get("eventSource") == event_source
    )


def lambda_handler(event, context):
    origem, detalhe = identificar_origem(event)

    print(f"[ORIGEM] {origem} — {detalhe}")
    print(f"[FORMA DO EVENT]\n{json.dumps(event, indent=2, default=str)}")

    return {"origem": origem, "detalhe": detalhe}
