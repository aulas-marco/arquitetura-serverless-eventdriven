"""Domínio da conta bancária — Event Sourcing puro, sem I/O.

O coração do Event Sourcing é uma função pura: estado + evento → novo estado.
Nada aqui toca no banco. O estado atual da conta NÃO é armazenado: ele é sempre
reconstruído aplicando, em ordem, a sequência de eventos que aconteceram.

Espelha o domínio da disciplina reativa (mesma ContaBancaria, mesmos eventos) —
o padrão é o mesmo, a plataforma é diferente.
"""

from dataclasses import dataclass, replace
from decimal import Decimal


def _dec(x):
    """Converte para Decimal sem passar por float (evita imprecisão em dinheiro)."""
    return x if isinstance(x, Decimal) else Decimal(str(x))


@dataclass(frozen=True)
class ContaBancaria:
    contaId: str
    titular: str
    saldo: Decimal

    @staticmethod
    def inicial(contaId):
        """O estado de partida, antes de qualquer evento."""
        return ContaBancaria(contaId, "", Decimal(0))

    def aplicar(self, evento):
        """Função pura: aplica um evento e devolve o novo estado (imutável).

        O `evento` é um dicionário com ao menos `tipo`. Campos extras vindos do
        armazenamento (sequencia, criadoEm) são ignorados de propósito."""
        tipo = evento["tipo"]
        if tipo == "ContaCriada":
            return replace(self, titular=evento["titular"])
        if tipo == "DepositoRealizado":
            return replace(self, saldo=self.saldo + _dec(evento["valor"]))
        if tipo == "SaqueRealizado":
            return replace(self, saldo=self.saldo - _dec(evento["valor"]))
        raise ValueError(f"tipo de evento desconhecido: {tipo}")


def reconstruir(contaId, eventos):
    """Reduz a sequência de eventos ao estado atual — o *replay*.

    É o inverso do CRUD: em vez de ler uma linha de estado, dobra-se o histórico
    de fatos desde o início. A ordem importa; por isso os eventos vêm ordenados
    por sequência."""
    estado = ContaBancaria.inicial(contaId)
    for evento in eventos:
        estado = estado.aplicar(evento)
    return estado
