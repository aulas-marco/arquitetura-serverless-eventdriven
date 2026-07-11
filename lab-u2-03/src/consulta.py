"""Lado de LEITURA (CQRS) — lê SÓ a projeção `saldos`. Nunca toca no event store.

Essa é a regra de ouro do CQRS: a consulta não faz replay nem conhece eventos.
Lê a linha pronta do modelo de leitura, em O(1). O preço é a consistência
eventual — logo após uma escrita, a projeção pode ainda não ter atualizado.

Rota:
  GET /contas/{contaId}   devolve o saldo projetado (ou 404 se ainda não projetado)
"""

import json
import os
from decimal import Decimal

import boto3

saldos = boto3.resource("dynamodb").Table(os.environ["TABELA_SALDOS"])


def _num(d):
    d = Decimal(d)
    return int(d) if d == d.to_integral_value() else float(d)


def _resp(status, corpo):
    return {"statusCode": status, "body": json.dumps(corpo, default=str)}


def lambda_handler(event, context):
    contaId = (event.get("pathParameters") or {}).get("contaId")
    linha = saldos.get_item(Key={"contaId": contaId}).get("Item")

    if not linha:
        return _resp(404, {"erro": "conta ainda não projetada (consistência eventual)"})

    return _resp(200, {
        "contaId": linha["contaId"],
        "titular": linha["titular"],
        "saldo": _num(linha["saldo"]),
        "ultimaSequencia": int(linha["ultimaSequencia"]),
        "fonte": "projecao",
    })
