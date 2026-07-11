"""Testes do desembrulho do duplo envelope SQS → SNS → evento.

O coração testável do fan-out é `extrair_evento`: uma função pura que recebe um
registro SQS e devolve o evento de domínio. A pegadinha é o duplo `json.loads` —
o registro SQS embrulha o envelope do SNS, que embrulha o evento. Cada teste
monta um envelope mínimo e verifica que a função chega ao evento correto.

Rodar só este arquivo:
    python3 -m pytest tests/test_envelope.py -v
"""

import json

from comum import extrair_evento

EVENTO = {"tipo": "PedidoCriado", "pedidoId": "p-1", "valor": 100, "itens": ["a"]}


def _registro_sns_em_sqs(evento):
    """Reproduz o que a SQS entrega quando o SNS publica nela (entrega padrão):
    o `body` do SQS é o envelope do SNS, com o evento serializado em `Message`."""
    envelope_sns = {
        "Type": "Notification",
        "MessageId": "abc-123",
        "TopicArn": "arn:aws:sns:us-east-1:000000000000:u1lab02-pedidos",
        "Message": json.dumps(evento),
    }
    return {"body": json.dumps(envelope_sns)}


def test_desembrulha_o_duplo_envelope_do_sns():
    """Caminho principal: SNS→SQS com entrega padrão exige dois json.loads."""
    registro = _registro_sns_em_sqs(EVENTO)
    assert extrair_evento(registro) == EVENTO


def test_preserva_todos_os_campos_do_evento():
    """O evento chega íntegro ao consumidor, não só o tipo."""
    pedido = extrair_evento(_registro_sns_em_sqs(EVENTO))
    assert pedido["pedidoId"] == "p-1"
    assert pedido["valor"] == 100
    assert pedido["itens"] == ["a"]


def test_mensagem_crua_na_fila_e_lida_direto():
    """Raw delivery (ou envio direto na fila): o body já é o evento, sem
    envelope do SNS. A função não pode exigir o segundo nível."""
    registro = {"body": json.dumps(EVENTO)}
    assert extrair_evento(registro) == EVENTO


def test_registro_sem_body_falha_explicitamente():
    """Robustez: um registro malformado falha com mensagem clara, não com
    KeyError obscuro no meio do processamento."""
    try:
        extrair_evento({})
        assert False, "deveria ter levantado ValueError"
    except ValueError as erro:
        assert "body" in str(erro)
