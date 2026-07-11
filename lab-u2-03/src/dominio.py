"""Domínio da conta bancária — Event Sourcing puro (herdado do U2-LAB01)."""

from dataclasses import dataclass, replace
from decimal import Decimal


def _dec(x):
    return x if isinstance(x, Decimal) else Decimal(str(x))


@dataclass(frozen=True)
class ContaBancaria:
    contaId: str
    titular: str
    saldo: Decimal

    @staticmethod
    def inicial(contaId):
        return ContaBancaria(contaId, "", Decimal(0))

    def aplicar(self, evento):
        tipo = evento["tipo"]
        if tipo == "ContaCriada":
            return replace(self, titular=evento["titular"])
        if tipo == "DepositoRealizado":
            return replace(self, saldo=self.saldo + _dec(evento["valor"]))
        if tipo == "SaqueRealizado":
            return replace(self, saldo=self.saldo - _dec(evento["valor"]))
        raise ValueError(f"tipo de evento desconhecido: {tipo}")


def reconstruir(contaId, eventos):
    estado = ContaBancaria.inicial(contaId)
    for evento in eventos:
        estado = estado.aplicar(evento)
    return estado
