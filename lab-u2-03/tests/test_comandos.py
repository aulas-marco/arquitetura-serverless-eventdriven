"""Testes das invariantes de comando (herdadas do U2-LAB01)."""

from decimal import Decimal

import pytest

from comandos import ComandoInvalido, SaldoInsuficiente, criar_conta, depositar, sacar
from dominio import ContaBancaria


def _conta(saldo):
    return ContaBancaria("c-1", "Maria", Decimal(saldo))


def test_criar_conta_exige_titular():
    with pytest.raises(ComandoInvalido):
        criar_conta("c-1", "")


def test_deposito_exige_valor_positivo():
    with pytest.raises(ComandoInvalido):
        depositar(_conta(0), Decimal(-1))


def test_saque_acima_do_saldo_e_recusado():
    with pytest.raises(SaldoInsuficiente):
        sacar(_conta(100), Decimal(150))


def test_saque_dentro_do_saldo_gera_evento():
    assert sacar(_conta(100), Decimal(40))["tipo"] == "SaqueRealizado"
