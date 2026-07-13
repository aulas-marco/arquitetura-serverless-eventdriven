"""Testes da lógica pura do consumidor: decodificação de registros Kinesis.

O ESM entrega um lote de registros; cada um traz os dados em base64 e o
eventID no formato  shardId-000000000000:sequenceNumber.  A lógica pura
extrai o shardId e deserializa o JSON — o que é testável sem AWS.
"""

import base64
import json

import pytest

from suporte import decodificar_lote, decodificar_registro


# ---------------------------------------------------------------------------
# helpers
# ---------------------------------------------------------------------------

def _make_registro(cliente_id, mensagem, shard_id="shardId-000000000000", seq="123"):
    dados = {"clienteId": cliente_id, "mensagem": mensagem}
    return {
        "kinesis": {
            "data": base64.b64encode(json.dumps(dados).encode()).decode(),
            "sequenceNumber": seq,
        },
        "eventID": f"{shard_id}:{seq}",
        "eventSource": "aws:kinesis",
    }


# ---------------------------------------------------------------------------
# decodificar_registro
# ---------------------------------------------------------------------------

def test_extrai_shard_id():
    r = _make_registro("cli-001", "oi", shard_id="shardId-000000000003")
    dec = decodificar_registro(r)
    assert dec["shardId"] == "shardId-000000000003"


def test_shard_id_e_a_parte_antes_dos_dois_pontos():
    """O eventID tem formato  shardId-XXX:seqNum — só a parte antes de ':' é o shard."""
    r = _make_registro("cli-001", "oi", shard_id="shardId-000000000001", seq="999:extra")
    dec = decodificar_registro(r)
    assert dec["shardId"] == "shardId-000000000001"


def test_decodifica_cliente_id():
    r = _make_registro("cli-007", "ticket")
    dec = decodificar_registro(r)
    assert dec["dados"]["clienteId"] == "cli-007"


def test_decodifica_mensagem():
    r = _make_registro("cli-001", "não consigo logar")
    dec = decodificar_registro(r)
    assert dec["dados"]["mensagem"] == "não consigo logar"


def test_dados_sao_dict():
    r = _make_registro("cli-002", "cobrança errada")
    assert isinstance(decodificar_registro(r)["dados"], dict)


# ---------------------------------------------------------------------------
# decodificar_lote
# ---------------------------------------------------------------------------

def test_lote_com_tres_registros():
    registros = [
        _make_registro("cli-001", "m1", seq="1"),
        _make_registro("cli-002", "m2", seq="2"),
        _make_registro("cli-003", "m3", seq="3"),
    ]
    assert len(decodificar_lote(registros)) == 3


def test_lote_preserva_ordem():
    registros = [
        _make_registro("cli-001", "primeiro", seq="1"),
        _make_registro("cli-002", "segundo", seq="2"),
    ]
    lote = decodificar_lote(registros)
    assert lote[0]["dados"]["mensagem"] == "primeiro"
    assert lote[1]["dados"]["mensagem"] == "segundo"


def test_lote_vazio():
    assert decodificar_lote([]) == []


def test_lote_shards_distintos_por_registro():
    registros = [
        _make_registro("cli-001", "m", shard_id="shardId-000000000000"),
        _make_registro("cli-002", "m", shard_id="shardId-000000000001"),
    ]
    lote = decodificar_lote(registros)
    assert lote[0]["shardId"] != lote[1]["shardId"]
