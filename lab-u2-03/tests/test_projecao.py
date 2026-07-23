"""Testes da projeção pura: construção incremental e idempotência.

A projeção aplica evento a evento sobre a linha de leitura. O ponto sensível é a
idempotência: como o DynamoDB Streams pode reentregar, reaplicar um evento já
projetado não pode dobrar o saldo.
"""

from decimal import Decimal

from projetar import projetar


def test_primeiro_evento_cria_a_linha():
    linha = projetar(None, {"tipo": "ContaCriada", "contaId": "c-1", "titular": "Maria", "sequencia": 1})
    assert linha["titular"] == "Maria"
    assert linha["saldo"] == Decimal(0)
    assert linha["ultimaSequencia"] == 1


def test_conta_criada_insere_linha_demais_eventos_atualizam():
    """A distinção da Q2 do fórum: ContaCriada é o INSERT que inicializa a linha
    de leitura (saldo zero); os eventos seguintes ATUALIZAM a linha existente."""
    criada = projetar(None, {"tipo": "ContaCriada", "contaId": "c-1", "titular": "Ana", "sequencia": 1})
    atualizada = projetar(criada, {"tipo": "DepositoRealizado", "contaId": "c-1", "valor": 100, "sequencia": 2})
    assert criada["saldo"] == Decimal(0)       # INSERT: linha nova, saldo zero
    assert atualizada["saldo"] == Decimal(100)  # UPDATE: soma sobre a linha existente
    assert atualizada["titular"] == "Ana"       # preserva o titular vindo da criação


def test_projecao_incremental_soma_saldo():
    linha = projetar(None, {"tipo": "ContaCriada", "contaId": "c-1", "titular": "Maria", "sequencia": 1})
    linha = projetar(linha, {"tipo": "DepositoRealizado", "contaId": "c-1", "valor": 100, "sequencia": 2})
    linha = projetar(linha, {"tipo": "SaqueRealizado", "contaId": "c-1", "valor": 30, "sequencia": 3})
    assert linha["saldo"] == Decimal(70)
    assert linha["ultimaSequencia"] == 3


def test_reaplicar_o_mesmo_evento_e_idempotente():
    """Reentrega do stream: aplicar a sequência 2 de novo não muda nada."""
    linha = projetar(None, {"tipo": "ContaCriada", "contaId": "c-1", "titular": "M", "sequencia": 1})
    linha = projetar(linha, {"tipo": "DepositoRealizado", "contaId": "c-1", "valor": 100, "sequencia": 2})

    repetido = projetar(linha, {"tipo": "DepositoRealizado", "contaId": "c-1", "valor": 100, "sequencia": 2})
    assert repetido is linha                 # mesma referência: nada a fazer
    assert repetido["saldo"] == Decimal(100)  # não dobrou


def test_evento_antigo_e_ignorado():
    """Um evento com sequência menor que a projetada não retrocede o estado."""
    linha = projetar(None, {"tipo": "ContaCriada", "contaId": "c-1", "titular": "M", "sequencia": 1})
    linha = projetar(linha, {"tipo": "DepositoRealizado", "contaId": "c-1", "valor": 100, "sequencia": 2})
    linha = projetar(linha, {"tipo": "DepositoRealizado", "contaId": "c-1", "valor": 50, "sequencia": 3})

    atrasado = projetar(linha, {"tipo": "DepositoRealizado", "contaId": "c-1", "valor": 999, "sequencia": 2})
    assert atrasado is linha
    assert atrasado["saldo"] == Decimal(150)
