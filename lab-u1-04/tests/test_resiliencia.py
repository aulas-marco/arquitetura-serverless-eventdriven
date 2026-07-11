"""Testes da resiliência: validação (o que é veneno) e falha parcial de lote.

A SQS cuida do retry e do redirecionamento à DLQ; o que é lógica nossa —
decidir se um pedido é processável e montar a resposta de falha parcial — é o
que estes testes cobrem, sem tocar na AWS.
"""

import pytest

from comum import (
    PedidoInvalido,
    montar_entrada_batch,
    montar_resposta_lote,
    validar_pedido,
)


def test_pedido_valido_passa():
    evento = {"pedidoId": "p-1", "valor": 100}
    assert validar_pedido(evento) is evento


def test_valor_nao_positivo_e_veneno():
    """Regra de negócio: valor <= 0 falha SEMPRE — é o que justifica a DLQ,
    porque reprocessar não muda o resultado."""
    for ruim in (0, -1, -50):
        with pytest.raises(PedidoInvalido):
            validar_pedido({"pedidoId": "p-x", "valor": ruim})


def test_sem_pedidoId_e_veneno():
    with pytest.raises(PedidoInvalido):
        validar_pedido({"valor": 10})


def test_valor_nao_numerico_e_veneno():
    with pytest.raises(PedidoInvalido):
        validar_pedido({"pedidoId": "p-1", "valor": "cem"})


def test_lote_todo_processado_nao_reentrega_nada():
    """Lista de falhas vazia → batchItemFailures vazio → a SQS apaga o lote."""
    assert montar_resposta_lote([]) == {"batchItemFailures": []}


def test_falha_parcial_reentrega_so_os_falhados():
    """O ponto do ReportBatchItemFailures: as boas seguem, só as ruins voltam."""
    resposta = montar_resposta_lote(["id-2", "id-5"])
    assert resposta == {
        "batchItemFailures": [
            {"itemIdentifier": "id-2"},
            {"itemIdentifier": "id-5"},
        ]
    }


def test_entrada_batch_tem_id_e_corpo():
    entrada = montar_entrada_batch(3, {"pedidoId": "p-9", "valor": 5})
    assert entrada["Id"] == "3"
    assert '"pedidoId": "p-9"' in entrada["MessageBody"]
