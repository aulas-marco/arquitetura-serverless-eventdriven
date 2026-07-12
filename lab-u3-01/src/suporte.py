"""Lógica pura do produtor de eventos de suporte — sem I/O, testável sem AWS.

O ponto do lab é o roteamento por chave: o `clienteId` é a chave de partição.
O Kinesis calcula o shard de destino por hash da chave (MD5 → faixa de hash key),
então todos os eventos de um mesmo cliente caem no MESMO shard — e ficam em
ordem. A lógica pura aqui monta e valida o evento e o registro Kinesis; o shard
em si é decidido pelo Kinesis (visível na resposta do put_records).
"""

import json


class EventoInvalido(ValueError):
    pass


def montar_evento(bruto):
    """Normaliza um evento de suporte cru. Exige a chave de roteamento."""
    if not isinstance(bruto, dict):
        raise EventoInvalido("evento deve ser um objeto")
    cliente_id = bruto.get("clienteId")
    mensagem = bruto.get("mensagem")
    if not cliente_id:
        raise EventoInvalido("clienteId é obrigatório (é a chave de roteamento)")
    if not mensagem:
        raise EventoInvalido("mensagem é obrigatória")
    return {"clienteId": cliente_id, "mensagem": mensagem}


def montar_registro(evento):
    """Monta o registro para kinesis.put_records.

    A PartitionKey é o clienteId — é ela que o Kinesis usa para escolher o shard.
    O Data vai como bytes (JSON serializado)."""
    return {
        "PartitionKey": evento["clienteId"],
        "Data": json.dumps(evento).encode("utf-8"),
    }


def ler_corpo(event):
    """Normaliza a entrada: invocação direta (objeto/lista) ou API Gateway HTTP
    (corpo como string JSON em `body`)."""
    if isinstance(event, dict) and "body" in event and isinstance(event["body"], str):
        return json.loads(event["body"])
    return event
