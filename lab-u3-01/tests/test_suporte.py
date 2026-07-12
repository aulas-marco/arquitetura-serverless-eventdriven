"""Testes da lógica pura do produtor: montagem/validação do evento e do registro.

O shard de destino é decisão do Kinesis (hash da chave) — não testável offline.
O que é nosso, e testável, é montar o registro com a PartitionKey correta e
validar o evento antes de publicar.
"""

import json

import pytest

from suporte import EventoInvalido, ler_corpo, montar_evento, montar_registro


def test_montar_evento_normaliza():
    evento = montar_evento({"clienteId": "cli-001", "mensagem": "não consigo logar", "extra": "x"})
    assert evento == {"clienteId": "cli-001", "mensagem": "não consigo logar"}


def test_evento_exige_cliente_id():
    """clienteId é a chave de roteamento — sem ela não há ordenação por cliente."""
    with pytest.raises(EventoInvalido):
        montar_evento({"mensagem": "sem cliente"})


def test_evento_exige_mensagem():
    with pytest.raises(EventoInvalido):
        montar_evento({"clienteId": "cli-001"})


def test_registro_usa_cliente_id_como_partition_key():
    """A PartitionKey precisa ser o clienteId: é ela que fixa o shard."""
    registro = montar_registro({"clienteId": "cli-007", "mensagem": "oi"})
    assert registro["PartitionKey"] == "cli-007"


def test_registro_serializa_o_evento_em_bytes():
    evento = {"clienteId": "cli-007", "mensagem": "oi"}
    registro = montar_registro(evento)
    assert isinstance(registro["Data"], bytes)
    assert json.loads(registro["Data"].decode("utf-8")) == evento


def test_ler_corpo_lista_de_api_gateway():
    event = {"body": json.dumps([{"clienteId": "c1", "mensagem": "m1"}])}
    corpo = ler_corpo(event)
    assert isinstance(corpo, list) and corpo[0]["clienteId"] == "c1"


def test_ler_corpo_invocacao_direta():
    assert ler_corpo({"clienteId": "c1", "mensagem": "m"}) == {"clienteId": "c1", "mensagem": "m"}
