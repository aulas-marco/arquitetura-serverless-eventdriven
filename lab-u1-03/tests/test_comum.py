"""Testes das funções compartilhadas: extração do evento e montagem no produtor.

`extrair_evento` precisa aguentar as duas topologias (mensagem direta na fila e
mensagem via SNS), porque a idempotência não depende de como o evento chegou.
"""

import json

import pytest

from comum import extrair_evento, ler_pedido, montar_evento

EVENTO = {"tipo": "PedidoCriado", "pedidoId": "p-7", "valor": 42, "itens": []}


def test_extrai_de_mensagem_direta_na_fila():
    """Produtor envia direto na SQS: o body já é o evento (um json.loads)."""
    registro = {"body": json.dumps(EVENTO)}
    assert extrair_evento(registro) == EVENTO


def test_extrai_de_mensagem_via_sns():
    """Se a fila estiver assinada num tópico SNS, o body é o envelope do SNS."""
    envelope = {"Type": "Notification", "Message": json.dumps(EVENTO)}
    registro = {"body": json.dumps(envelope)}
    assert extrair_evento(registro) == EVENTO


def test_registro_sem_body_falha_explicitamente():
    with pytest.raises(ValueError):
        extrair_evento({})


def test_montar_evento_produz_pedidocriado():
    evento = montar_evento({"pedidoId": "p-3", "valor": 9})
    assert evento["tipo"] == "PedidoCriado"
    assert evento["pedidoId"] == "p-3"


def test_ler_pedido_de_api_gateway_http():
    event = {"body": json.dumps({"pedidoId": "p-4", "valor": 5})}
    assert ler_pedido(event)["pedidoId"] == "p-4"
