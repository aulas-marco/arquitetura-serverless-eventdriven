"""Produtor Kinesis — publica eventos de suporte roteados por clienteId.

Aceita um evento ou uma lista. Usa put_records (lote) e devolve, por registro,
o shard de destino e o sequence number — evidência de que o mesmo clienteId cai
sempre no mesmo shard (ordenação por cliente), e clientes diferentes se
distribuem entre shards.
"""

import json
import os

import boto3

from suporte import EventoInvalido, ler_corpo, montar_evento, montar_registro

kinesis = boto3.client("kinesis")
STREAM = os.environ["STREAM"]


def _resp(status, corpo):
    return {"statusCode": status, "body": json.dumps(corpo)}


def lambda_handler(event, context):
    try:
        corpo = ler_corpo(event)
        brutos = corpo if isinstance(corpo, list) else [corpo]
        eventos = [montar_evento(b) for b in brutos]
    except EventoInvalido as erro:
        return _resp(400, {"erro": str(erro)})

    resposta = kinesis.put_records(
        StreamName=STREAM, Records=[montar_registro(e) for e in eventos]
    )

    publicados = []
    for evento, registro in zip(eventos, resposta["Records"]):
        if "ShardId" in registro:
            publicados.append({
                "clienteId": evento["clienteId"],
                "shardId": registro["ShardId"],
                "sequenceNumber": registro["SequenceNumber"],
            })
        else:
            publicados.append({"clienteId": evento["clienteId"], "erro": registro.get("ErrorCode")})

    print(f"[PUBLICADO] {len(eventos)} evento(s), falhas={resposta['FailedRecordCount']}")
    return _resp(202, {"publicados": publicados, "falhas": resposta["FailedRecordCount"]})
