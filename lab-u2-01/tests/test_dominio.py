"""Testes do domínio: aplicar eventos e reconstruir estado por replay.

O estado nunca é armazenado — é sempre o resultado de dobrar a sequência de
eventos. Estes testes provam que a mesma sequência sempre reconstrói o mesmo
estado, e que a ordem importa.
"""

from decimal import Decimal

from dominio import ContaBancaria, reconstruir


def test_estado_inicial_tem_saldo_zero():
    conta = ContaBancaria.inicial("c-1")
    assert conta.saldo == Decimal(0)
    assert conta.titular == ""


def test_conta_criada_define_titular():
    conta = ContaBancaria.inicial("c-1").aplicar({"tipo": "ContaCriada", "titular": "Maria"})
    assert conta.titular == "Maria"
    assert conta.saldo == Decimal(0)


def test_deposito_soma_e_saque_subtrai():
    conta = ContaBancaria.inicial("c-1")
    conta = conta.aplicar({"tipo": "DepositoRealizado", "valor": 100})
    conta = conta.aplicar({"tipo": "SaqueRealizado", "valor": 30})
    assert conta.saldo == Decimal(70)


def test_replay_reconstroi_o_estado_atual():
    eventos = [
        {"tipo": "ContaCriada", "titular": "João"},
        {"tipo": "DepositoRealizado", "valor": 200},
        {"tipo": "DepositoRealizado", "valor": 50},
        {"tipo": "SaqueRealizado", "valor": 80},
    ]
    conta = reconstruir("c-9", eventos)
    assert conta.titular == "João"
    assert conta.saldo == Decimal(170)
    assert conta.contaId == "c-9"


def test_replay_e_deterministico():
    """A mesma sequência reconstrói sempre o mesmo estado — base do event sourcing."""
    eventos = [{"tipo": "DepositoRealizado", "valor": 10} for _ in range(5)]
    assert reconstruir("c-1", eventos).saldo == reconstruir("c-1", eventos).saldo == Decimal(50)


def test_aplicar_preserva_imutabilidade():
    """aplicar devolve novo estado; o anterior não muda (frozen)."""
    antes = ContaBancaria.inicial("c-1").aplicar({"tipo": "DepositoRealizado", "valor": 100})
    depois = antes.aplicar({"tipo": "SaqueRealizado", "valor": 40})
    assert antes.saldo == Decimal(100)
    assert depois.saldo == Decimal(60)


def test_dinheiro_sem_imprecisao_de_float():
    """Decimal, não float: 0.1+0.2 tem que dar 0.3 exato."""
    conta = ContaBancaria.inicial("c-1")
    conta = conta.aplicar({"tipo": "DepositoRealizado", "valor": "0.1"})
    conta = conta.aplicar({"tipo": "DepositoRealizado", "valor": "0.2"})
    assert conta.saldo == Decimal("0.3")


def test_evento_desconhecido_falha():
    try:
        ContaBancaria.inicial("c-1").aplicar({"tipo": "Teletransportado"})
        assert False
    except ValueError as erro:
        assert "desconhecido" in str(erro)
