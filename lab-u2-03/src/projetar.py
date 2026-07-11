"""Projeção do saldo — lógica pura da construção do modelo de leitura.

A projeção transforma o fluxo de eventos numa linha otimizada para consulta:
`{contaId, titular, saldo, ultimaSequencia}`. É aplicada evento a evento pelo
consumidor do stream. Guarda a `ultimaSequencia` projetada para ser
**idempotente**: como o DynamoDB Streams pode reentregar um registro, reaplicar
um evento já projetado não pode dobrar o saldo.
"""

from decimal import Decimal

from dominio import ContaBancaria


def _dec(x):
    return x if isinstance(x, Decimal) else Decimal(str(x))


def projetar(linha_atual, evento):
    """Aplica um evento à linha de projeção e devolve a nova linha.

    Se o evento já foi projetado (sequência <= a última projetada), devolve a
    linha atual sem mudança (a mesma referência) — a idempotência que protege
    contra a reentrega do stream."""
    contaId = evento["contaId"]
    seq = int(evento["sequencia"])

    if linha_atual is not None and seq <= int(linha_atual["ultimaSequencia"]):
        return linha_atual  # já projetado — não reaplica

    if linha_atual is None:
        estado = ContaBancaria.inicial(contaId)
    else:
        estado = ContaBancaria(contaId, linha_atual["titular"], _dec(linha_atual["saldo"]))

    novo = estado.aplicar(evento)
    return {
        "contaId": contaId,
        "titular": novo.titular,
        "saldo": novo.saldo,
        "ultimaSequencia": seq,
    }
