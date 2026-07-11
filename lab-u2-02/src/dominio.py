"""Domínio da conta bancária + suporte a snapshot — tudo puro, sem I/O.

Herda o agregado do U2-LAB01 e acrescenta duas coisas para os snapshots:

- `reconstruir_a_partir_de` — replay que parte de um estado-base qualquer (o do
  snapshot), não do zero. É o que permite reprocessar só o *delta* de eventos.
- `estado_para_snapshot` / `snapshot_para_estado` — serializam o estado do
  agregado para gravar e ler o snapshot.
"""

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


def reconstruir_a_partir_de(estado_base, eventos):
    """Replay genérico: dobra os eventos sobre um estado-base.

    Com `estado_base` = estado inicial, é o replay completo. Com o estado de um
    snapshot, processa só os eventos posteriores (o delta)."""
    estado = estado_base
    for evento in eventos:
        estado = estado.aplicar(evento)
    return estado


def reconstruir(contaId, eventos):
    """Replay completo, do zero — atalho para o caso sem snapshot."""
    return reconstruir_a_partir_de(ContaBancaria.inicial(contaId), eventos)


def estado_para_snapshot(conta):
    """Serializa o estado do agregado para gravar no snapshot."""
    return {"titular": conta.titular, "saldo": conta.saldo}


def snapshot_para_estado(contaId, estado):
    """Reconstrói o agregado a partir do estado gravado no snapshot."""
    return ContaBancaria(contaId, estado["titular"], _dec(estado["saldo"]))
