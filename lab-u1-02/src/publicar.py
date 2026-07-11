"""Produtor — publica um `PedidoCriado` no tópico SNS.

Uma única publicação. O SNS faz o fan-out: entrega uma cópia a CADA fila
assinante, sem o produtor saber quantas são nem quais. Adicionar um novo
consumidor é assinar o tópico — este código não muda.
"""

import json
import os

import boto3

from comum import ler_pedido, montar_evento

sns = boto3.client("sns")
TOPICO_ARN = os.environ.get("TOPICO_ARN", "")


def lambda_handler(event, context):
    pedido = ler_pedido(event)
    evento = montar_evento(pedido)

    resposta = sns.publish(
        TopicArn=TOPICO_ARN,
        Message=json.dumps(evento),
        MessageAttributes={
            "tipo": {"DataType": "String", "StringValue": evento["tipo"]}
        },
    )

    print(f"[PUBLICADO] {evento['tipo']} pedido={evento['pedidoId']} "
          f"→ SNS (MessageId={resposta['MessageId']})")

    return {
        "statusCode": 202,
        "body": json.dumps({"publicado": evento, "messageId": resposta["MessageId"]}),
    }
