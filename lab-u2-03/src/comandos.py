"""Lado de comando — invariantes de negócio, sem I/O (herdado do U2-LAB01)."""

import uuid
from decimal import Decimal


class ComandoInvalido(ValueError):
    pass


class SaldoInsuficiente(Exception):
    pass


def gerar_id():
    return str(uuid.uuid4())


def _exigir_positivo(valor):
    if not isinstance(valor, (int, float, Decimal)) or valor <= 0:
        raise ComandoInvalido(f"valor deve ser positivo: {valor!r}")


def criar_conta(contaId, titular):
    if not titular:
        raise ComandoInvalido("titular é obrigatório")
    return {"tipo": "ContaCriada", "contaId": contaId, "titular": titular}


def depositar(conta, valor):
    _exigir_positivo(valor)
    return {"tipo": "DepositoRealizado", "contaId": conta.contaId, "valor": valor}


def sacar(conta, valor):
    _exigir_positivo(valor)
    if conta.saldo < valor:
        raise SaldoInsuficiente(f"saldo insuficiente: {conta.saldo} < {valor}")
    return {"tipo": "SaqueRealizado", "contaId": conta.contaId, "valor": valor}
