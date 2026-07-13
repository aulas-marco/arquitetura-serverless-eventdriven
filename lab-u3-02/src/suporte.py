"""Lógica pura do consumidor: decodifica registros Kinesis sem tocar em AWS."""
import base64
import json


def decodificar_registro(registro):
    """Extrai shardId e dados JSON de um registro Kinesis.

    O eventID tem o formato  shardId-000000000000:sequenceNumber
    — o shardId é a parte antes do primeiro ':'.
    """
    shard_id = registro["eventID"].split(":")[0]
    dados = json.loads(base64.b64decode(registro["kinesis"]["data"]).decode("utf-8"))
    return {"shardId": shard_id, "dados": dados}


def decodificar_lote(registros):
    """Decodifica todos os registros de um lote Kinesis, preservando a ordem."""
    return [decodificar_registro(r) for r in registros]
