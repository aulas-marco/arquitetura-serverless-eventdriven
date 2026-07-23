"""Testes de replay a partir de base e de snapshots.

A propriedade central: reconstruir via snapshot + delta tem que dar EXATAMENTE
o mesmo estado que o replay completo. Se divergir, o snapshot está corrompendo
a verdade — pior que não ter snapshot.
"""

from decimal import Decimal

from dominio import (
    ContaBancaria,
    estado_para_snapshot,
    reconstruir,
    reconstruir_a_partir_de,
    snapshot_para_estado,
)

EVENTOS = [
    {"tipo": "ContaCriada", "titular": "Maria"},
    {"tipo": "DepositoRealizado", "valor": 100},
    {"tipo": "DepositoRealizado", "valor": 50},
    {"tipo": "SaqueRealizado", "valor": 30},
    {"tipo": "DepositoRealizado", "valor": 80},
]


def test_reconstruir_a_partir_de_base_soma_so_o_delta():
    base = ContaBancaria("c-1", "Maria", Decimal(120))
    delta = [{"tipo": "DepositoRealizado", "valor": 80}]
    conta = reconstruir_a_partir_de(base, delta)
    assert conta.saldo == Decimal(200)
    assert conta.titular == "Maria"


def test_snapshot_round_trip_preserva_estado():
    original = ContaBancaria("c-1", "João", Decimal("150.75"))
    estado = estado_para_snapshot(original)
    voltou = snapshot_para_estado("c-1", estado)
    assert voltou == original


def test_snapshot_mais_delta_igual_replay_completo():
    """A invariante do lab: as duas rotas de reconstrução convergem."""
    completo = reconstruir("c-1", EVENTOS)

    # snapshot tirado após os 3 primeiros eventos...
    base = reconstruir("c-1", EVENTOS[:3])
    estado = estado_para_snapshot(base)
    # ...e o delta são só os eventos seguintes
    via_snapshot = reconstruir_a_partir_de(snapshot_para_estado("c-1", estado), EVENTOS[3:])

    assert via_snapshot == completo
    assert via_snapshot.saldo == Decimal(200)


def test_snapshot_em_qualquer_ponto_converge():
    """Independe de ONDE o snapshot foi tirado — o resultado é sempre o mesmo."""
    completo = reconstruir("c-1", EVENTOS)
    for corte in range(len(EVENTOS) + 1):
        base = snapshot_para_estado("c-1", estado_para_snapshot(reconstruir("c-1", EVENTOS[:corte])))
        via_snapshot = reconstruir_a_partir_de(base, EVENTOS[corte:])
        assert via_snapshot == completo


def test_delta_vazio_devolve_o_proprio_snapshot():
    """Sem eventos novos desde o snapshot, o estado é o do snapshot."""
    base = ContaBancaria("c-1", "Ana", Decimal(500))
    assert reconstruir_a_partir_de(base, []) == base


def test_replay_e_idempotente():
    """Replay é função pura da história: reprocessar a MESMA lista de eventos
    quantas vezes for dá sempre o mesmo estado. É o que garante que a consulta
    não depende de quantas vezes o agregado foi reconstruído."""
    primeiro = reconstruir("c-1", EVENTOS)
    segundo = reconstruir("c-1", EVENTOS)
    assert primeiro == segundo
    assert primeiro.saldo == Decimal(200)
