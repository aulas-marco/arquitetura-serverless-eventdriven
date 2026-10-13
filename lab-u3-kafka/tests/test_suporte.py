"""Testes da lógica pura do lab Kafka local — rodam sem broker e sem Docker."""

import pytest

from suporte import EventoInvalido, deve_falhar, montar_evento, montar_lote


# ---------------------------------------------------------------------------
# montar_evento
# ---------------------------------------------------------------------------

def test_monta_evento_valido():
    assert montar_evento({"clienteId": "cli-001", "mensagem": "oi"}) == {
        "clienteId": "cli-001",
        "mensagem": "oi",
    }


def test_descarta_campos_extras():
    evento = montar_evento({"clienteId": "cli-001", "mensagem": "oi", "extra": 1})
    assert set(evento) == {"clienteId", "mensagem"}


@pytest.mark.parametrize("bruto", ["texto", 5, None, [1, 2]])
def test_evento_que_nao_e_objeto_e_rejeitado(bruto):
    with pytest.raises(EventoInvalido, match="objeto"):
        montar_evento(bruto)


def test_cliente_id_ausente_e_rejeitado():
    with pytest.raises(EventoInvalido, match="clienteId"):
        montar_evento({"mensagem": "oi"})


def test_cliente_id_vazio_e_rejeitado():
    with pytest.raises(EventoInvalido, match="clienteId"):
        montar_evento({"clienteId": "", "mensagem": "oi"})


def test_cliente_id_que_nao_e_texto_e_rejeitado():
    with pytest.raises(EventoInvalido, match="texto"):
        montar_evento({"clienteId": 123, "mensagem": "oi"})


def test_mensagem_ausente_e_rejeitada():
    with pytest.raises(EventoInvalido, match="mensagem"):
        montar_evento({"clienteId": "cli-001"})


def test_mensagem_com_acentos_e_preservada():
    evento = montar_evento({"clienteId": "cli-001", "mensagem": "não consigo logar"})
    assert evento["mensagem"] == "não consigo logar"


# ---------------------------------------------------------------------------
# montar_lote
# ---------------------------------------------------------------------------

def test_objeto_unico_vira_lote_de_um():
    lote = montar_lote({"clienteId": "cli-001", "mensagem": "oi"})
    assert lote == [{"clienteId": "cli-001", "mensagem": "oi"}]


def test_lista_preserva_a_ordem():
    lote = montar_lote([
        {"clienteId": "cli-002", "mensagem": "b"},
        {"clienteId": "cli-001", "mensagem": "a"},
    ])
    assert [e["clienteId"] for e in lote] == ["cli-002", "cli-001"]


def test_lote_vazio_e_rejeitado():
    with pytest.raises(EventoInvalido, match="vazio"):
        montar_lote([])


def test_um_evento_invalido_rejeita_o_lote_inteiro():
    with pytest.raises(EventoInvalido):
        montar_lote([
            {"clienteId": "cli-001", "mensagem": "ok"},
            {"clienteId": "cli-002"},
        ])


# ---------------------------------------------------------------------------
# deve_falhar
# ---------------------------------------------------------------------------

def test_falha_quando_o_cliente_coincide():
    assert deve_falhar("cli-002", "cli-002") is True


def test_nao_falha_quando_o_cliente_difere():
    assert deve_falhar("cli-001", "cli-002") is False


def test_nao_falha_quando_falhar_em_e_vazio():
    assert deve_falhar("cli-001", "") is False


def test_cliente_ausente_com_falhar_em_vazio_nao_falha():
    assert deve_falhar(None, "") is False
