"""Consumidor da projeção — gatilho do DynamoDB Streams do event store.

Cada evento novo (INSERT) no event store chega aqui pelo stream. O handler
aplica o evento à linha de projeção na tabela `saldos`. É o elo assíncrono do
CQRS: a escrita gravou o evento; a projeção atualiza o modelo de leitura depois
(consistência eventual). Idempotente pela `ultimaSequencia` — o stream pode
reentregar, e reaplicar não pode dobrar o saldo.
"""

import os

import boto3
from boto3.dynamodb.types import TypeDeserializer

from projetar import projetar

saldos = boto3.resource("dynamodb").Table(os.environ["TABELA_SALDOS"])
deserializer = TypeDeserializer()


def _linha(contaId):
    return saldos.get_item(Key={"contaId": contaId}).get("Item")


def _para_dict(imagem):
    return {chave: deserializer.deserialize(valor) for chave, valor in imagem.items()}


def lambda_handler(event, context):
    projetados = 0
    for registro in event["Records"]:
        if registro["eventName"] != "INSERT":
            continue  # event store é append-only; só INSERT interessa

        evento = _para_dict(registro["dynamodb"]["NewImage"])
        atual = _linha(evento["contaId"])
        nova = projetar(atual, evento)

        if nova is atual:
            continue  # idempotência: evento já projetado

        saldos.put_item(Item=nova)
        projetados += 1
        print(f"[PROJETADO] contaId={nova['contaId']} saldo={nova['saldo']} "
              f"seq={nova['ultimaSequencia']}")

    return {"projetados": projetados}
