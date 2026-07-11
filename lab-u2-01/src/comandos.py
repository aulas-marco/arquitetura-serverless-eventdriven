"""Lado de comando — decide QUAIS eventos um comando gera, sem I/O.

Cada comando recebe o estado atual (já reconstruído) e devolve o evento que
deve ser gravado, ou levanta uma exceção se viola uma invariante. As regras de
negócio vivem aqui, isoladas do armazenamento: é o que os testes exercitam.
"""

import uuid
from decimal import Decimal


class ComandoInvalido(ValueError):
    """Comando malformado — valor não positivo, titular ausente."""


class SaldoInsuficiente(Exception):
    """Invariante violada: saque maior que o saldo."""


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
