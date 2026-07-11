"""Testes das funções compartilhadas: extração do evento e montagem no produtor."""

import json

import pytest

from comum import PedidoInvalido, extrair_evento, ler_corpo, montar_evento

EVENTO = {"tipo": "PedidoCriado", "pedidoId": "p-7", "valor": 42, "itens": []}


def test_extrai_de_mensagem_direta_na_fila():
    assert extrair_evento({"body": json.dumps(EVENTO)}) == EVENTO


def test_extrai_de_mensagem_via_sns():
    envelope = {"Type": "Notification", "Message": json.dumps(EVENTO)}
    assert extrair_evento({"body": json.dumps(envelope)}) == EVENTO


def test_registro_sem_body_e_tratado_como_veneno():
    """Um registro malformado é falha de processamento, não crash — vira
    PedidoInvalido e cai no fluxo de falha parcial/DLQ."""
    with pytest.raises(PedidoInvalido):
        extrair_evento({})


def test_montar_evento_preserva_valor_invalido():
    """O produtor NÃO valida o valor: o veneno precisa chegar à fila para
    exercitar a DLQ. Quem rejeita é o consumidor."""
    evento = montar_evento({"pedidoId": "p-1", "valor": -1})
    assert evento["valor"] == -1


def test_ler_corpo_aceita_lista_de_api_gateway():
    event = {"body": json.dumps([{"pedidoId": "p-1", "valor": 10}, {"pedidoId": "p-2", "valor": 20}])}
    corpo = ler_corpo(event)
    assert isinstance(corpo, list) and len(corpo) == 2
