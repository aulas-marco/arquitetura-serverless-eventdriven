"""Testes do lado produtor: montar o evento e ler o pedido de entrada.

São as duas funções puras que o handler `publicar` usa antes de chamar o SNS.
Testá-las isola a lógica de domínio do I/O (o `sns.publish` fica no handler).
"""

import json

import pytest

from comum import ler_pedido, montar_evento


def test_montar_evento_produz_o_tipo_pedidocriado():
    """O produtor publica um FATO no passado: PedidoCriado."""
    evento = montar_evento({"pedidoId": "p-9", "valor": 50})
    assert evento["tipo"] == "PedidoCriado"
    assert evento["pedidoId"] == "p-9"
    assert evento["valor"] == 50


def test_montar_evento_preenche_defaults():
    """Pedido só com id ainda gera evento válido (valor 0, sem itens)."""
    evento = montar_evento({"pedidoId": "p-1"})
    assert evento["valor"] == 0
    assert evento["itens"] == []


def test_montar_evento_exige_pedidoId():
    """Sem identidade não há evento — falha explícita."""
    with pytest.raises(ValueError):
        montar_evento({"valor": 10})


def test_ler_pedido_de_invocacao_direta():
    """Invocação direta: o event já é o próprio pedido."""
    pedido = {"pedidoId": "p-2", "valor": 30}
    assert ler_pedido(pedido) == pedido


def test_ler_pedido_de_api_gateway_http():
    """API Gateway HTTP: o pedido vem como string JSON no campo body."""
    event = {"body": json.dumps({"pedidoId": "p-3", "valor": 70})}
    pedido = ler_pedido(event)
    assert pedido["pedidoId"] == "p-3"
    assert pedido["valor"] == 70
