"""Produtor — envia um lote de pedidos para a fila SQS.

Aceita um pedido único ou uma lista, para o script poder injetar de uma vez um
lote com pedidos bons e um veneno, demonstrando a falha parcial de lote.
"""

import json
import os

import boto3

from comum import ler_corpo, montar_entrada_batch, montar_evento

sqs = boto3.client("sqs")
FILA_URL = os.environ.get("FILA_URL", "")


def lambda_handler(event, context):
    corpo = ler_corpo(event)
    pedidos = corpo if isinstance(corpo, list) else [corpo]

    entradas = [
        montar_entrada_batch(i, montar_evento(p)) for i, p in enumerate(pedidos)
    ]
    sqs.send_message_batch(QueueUrl=FILA_URL, Entries=entradas)

    ids = [p.get("pedidoId") for p in pedidos]
    print(f"[ENVIADO] {len(entradas)} pedido(s) → SQS: {ids}")

    return {"statusCode": 202, "body": json.dumps({"enviados": ids})}
