"""Produtor — envia um `PedidoCriado` para a fila SQS.

Exposto por HTTP. Aceita o `pedidoId` no corpo de propósito: assim o script de
demonstração pode enviar o MESMO pedido duas vezes e provar a idempotência
(o que uma entrega *at-least-once* faria naturalmente).
"""

import json
import os

import boto3

from comum import ler_pedido, montar_evento

sqs = boto3.client("sqs")
FILA_URL = os.environ.get("FILA_URL", "")


def lambda_handler(event, context):
    pedido = ler_pedido(event)
    evento = montar_evento(pedido)

    resposta = sqs.send_message(QueueUrl=FILA_URL, MessageBody=json.dumps(evento))

    print(f"[ENVIADO] {evento['tipo']} pedido={evento['pedidoId']} "
          f"→ SQS (MessageId={resposta['MessageId']})")

    return {
        "statusCode": 202,
        "body": json.dumps({"enviado": evento, "messageId": resposta["MessageId"]}),
    }
