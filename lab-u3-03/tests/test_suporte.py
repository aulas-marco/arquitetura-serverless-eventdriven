"""Testes da lógica pura do classificador: hash, montagem de prompt e parsing.

Nenhum teste toca na API Anthropic ou em serviços AWS — apenas as funções
de suporte.py, que são testáveis offline com pytest puro.
"""

import json
import time

import pytest

from suporte import SemClassificacao, calcular_ttl, hash_texto, montar_prompt, parsear_resposta


# ---------------------------------------------------------------------------
# hash_texto
# ---------------------------------------------------------------------------

def test_hash_e_deterministico():
    assert hash_texto("mesmo texto") == hash_texto("mesmo texto")


def test_hash_textos_distintos_produzem_hashes_distintos():
    assert hash_texto("ticket A") != hash_texto("ticket B")


def test_hash_retorna_string_hexadecimal():
    h = hash_texto("qualquer coisa")
    assert isinstance(h, str)
    assert all(c in "0123456789abcdef" for c in h)


def test_hash_tem_64_caracteres():
    assert len(hash_texto("sha256 = 256 bits = 64 hex")) == 64


# ---------------------------------------------------------------------------
# montar_prompt
# ---------------------------------------------------------------------------

def test_prompt_contem_o_texto_do_ticket():
    p = montar_prompt("não consigo logar")
    assert "não consigo logar" in p


def test_prompt_instrui_formato_json():
    p = montar_prompt("qualquer coisa")
    assert "JSON" in p or "json" in p


def test_prompt_menciona_prioridade():
    p = montar_prompt("x")
    assert "prioridade" in p


def test_prompt_menciona_categoria():
    p = montar_prompt("x")
    assert "categoria" in p


# ---------------------------------------------------------------------------
# parsear_resposta — casos válidos
# ---------------------------------------------------------------------------

def test_parsear_alta_tecnico():
    resp = json.dumps({"prioridade": "alta", "categoria": "tecnico"})
    dados = parsear_resposta(resp)
    assert dados == {"prioridade": "alta", "categoria": "tecnico"}


def test_parsear_baixa_comercial():
    resp = json.dumps({"prioridade": "baixa", "categoria": "comercial"})
    dados = parsear_resposta(resp)
    assert dados["prioridade"] == "baixa"
    assert dados["categoria"] == "comercial"


def test_parsear_ignora_campos_extras():
    resp = json.dumps({"prioridade": "alta", "categoria": "tecnico", "extra": "ignorado"})
    dados = parsear_resposta(resp)
    assert "extra" not in dados


# ---------------------------------------------------------------------------
# parsear_resposta — casos inválidos
# ---------------------------------------------------------------------------

def test_json_invalido_lanca_sem_classificacao():
    with pytest.raises(SemClassificacao):
        parsear_resposta("não é json")


def test_prioridade_invalida_lanca_sem_classificacao():
    resp = json.dumps({"prioridade": "media", "categoria": "tecnico"})
    with pytest.raises(SemClassificacao):
        parsear_resposta(resp)


def test_categoria_invalida_lanca_sem_classificacao():
    resp = json.dumps({"prioridade": "alta", "categoria": "urgente"})
    with pytest.raises(SemClassificacao):
        parsear_resposta(resp)


def test_campos_ausentes_lanca_sem_classificacao():
    with pytest.raises(SemClassificacao):
        parsear_resposta(json.dumps({}))


# ---------------------------------------------------------------------------
# calcular_ttl
# ---------------------------------------------------------------------------

def test_ttl_e_no_futuro():
    assert calcular_ttl(24) > time.time()


def test_ttl_aproximadamente_24h_a_frente():
    esperado = time.time() + 24 * 3600
    assert abs(calcular_ttl(24) - esperado) < 5


def test_ttl_parametrizavel():
    ttl_48 = calcular_ttl(48)
    ttl_24 = calcular_ttl(24)
    assert ttl_48 > ttl_24
