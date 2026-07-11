"""Testes do lado de comando: as invariantes de negócio.

Cada comando recebe o estado atual e decide o evento — ou recusa. É aqui que
moram as regras: valor positivo, titular obrigatório, sem saque a descoberto.
"""

from decimal import Decimal

import pytest

from comandos import (
    ComandoInvalido,
    SaldoInsuficiente,
    criar_conta,
    depositar,
    sacar,
)
from dominio import ContaBancaria


def _conta_com_saldo(valor):
    return ContaBancaria("c-1", "Maria", Decimal(valor))


def test_criar_conta_gera_evento_contacriada():
    evento = criar_conta("c-1", "Maria")
    assert evento == {"tipo": "ContaCriada", "contaId": "c-1", "titular": "Maria"}


def test_criar_conta_exige_titular():
    with pytest.raises(ComandoInvalido):
        criar_conta("c-1", "")


def test_deposito_gera_evento():
    evento = depositar(_conta_com_saldo(0), Decimal(100))
    assert evento["tipo"] == "DepositoRealizado"
    assert evento["valor"] == Decimal(100)


def test_deposito_exige_valor_positivo():
    for ruim in (0, -1, Decimal("-0.01")):
        with pytest.raises(ComandoInvalido):
            depositar(_conta_com_saldo(0), ruim)


def test_saque_dentro_do_saldo_gera_evento():
    evento = sacar(_conta_com_saldo(100), Decimal(40))
    assert evento["tipo"] == "SaqueRealizado"
    assert evento["valor"] == Decimal(40)


def test_saque_acima_do_saldo_e_recusado():
    """A invariante central: a conta não pode ficar negativa."""
    with pytest.raises(SaldoInsuficiente):
        sacar(_conta_com_saldo(100), Decimal(150))


def test_saque_exige_valor_positivo():
    with pytest.raises(ComandoInvalido):
        sacar(_conta_com_saldo(100), Decimal(0))
