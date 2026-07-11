"""Handler HTTP do event store — a única camada com I/O (DynamoDB).

Fluxo de todo comando que muda estado: carregar os eventos → reconstruir o
estado → decidir o novo evento → gravar em append-only com concorrência
otimística. A gravação usa um conditional write na chave (contaId, sequencia):
se dois comandos concorrentes tentam a MESMA próxima sequência, um grava e o
outro recebe ConditionalCheckFailedException — que vira 409 Conflito.

Rotas:
  POST /contas                       cria a conta (evento ContaCriada)
  POST /contas/{contaId}/depositos   deposita
  POST /contas/{contaId}/saques      saca (rejeita se saldo insuficiente)
  GET  /contas/{contaId}             reconstrói e devolve o estado atual
"""

import json
import os
import time
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key
from botocore.exceptions import ClientError

from comandos import (
    ComandoInvalido,
    SaldoInsuficiente,
    criar_conta,
    depositar,
    gerar_id,
    sacar,
)
from dominio import reconstruir

tabela = boto3.resource("dynamodb").Table(os.environ["TABELA"])


class Conflito(Exception):
    """Conflito de sequência — outro comando gravou a mesma posição primeiro."""


def _dec(x):
    return Decimal(str(x))


def _num(d):
    """Decimal → int quando inteiro, senão float (JSON não serializa Decimal)."""
    d = Decimal(d)
    return int(d) if d == d.to_integral_value() else float(d)


def _resp(status, corpo):
    return {"statusCode": status, "body": json.dumps(corpo, default=str)}


def _carregar(contaId):
    resp = tabela.query(
        KeyConditionExpression=Key("contaId").eq(contaId),
        ScanIndexForward=True,  # ordem crescente de sequência: o replay depende disso
    )
    return resp["Items"]


def _append(evento, sequencia):
    item = {**evento, "sequencia": sequencia, "criadoEm": int(time.time())}
    try:
        tabela.put_item(
            Item=item,
            ConditionExpression="attribute_not_exists(contaId) AND attribute_not_exists(sequencia)",
        )
    except ClientError as erro:
        if erro.response["Error"]["Code"] == "ConditionalCheckFailedException":
            raise Conflito(f"conflito de sequência {sequencia} para {evento['contaId']}")
        raise
    print(f"[APPEND] {evento['tipo']} contaId={evento['contaId']} seq={sequencia}")
    return item


def _comando(contaId, decidir):
    eventos = _carregar(contaId)
    if not eventos:
        return _resp(404, {"erro": "conta não encontrada"})
    conta = reconstruir(contaId, eventos)
    evento = decidir(conta)
    _append(evento, len(eventos) + 1)
    novo_saldo = conta.aplicar(evento).saldo
    return _resp(200, {"contaId": contaId, "saldo": _num(novo_saldo)})


def lambda_handler(event, context):
    rota = event.get("routeKey", "")
    corpo = json.loads(event["body"]) if event.get("body") else {}
    params = event.get("pathParameters") or {}

    try:
        if rota == "POST /contas":
            contaId = gerar_id()
            _append(criar_conta(contaId, corpo.get("titular")), 1)
            return _resp(201, {"contaId": contaId})

        if rota == "POST /contas/{contaId}/depositos":
            return _comando(params["contaId"], lambda conta: depositar(conta, _dec(corpo["valor"])))

        if rota == "POST /contas/{contaId}/saques":
            return _comando(params["contaId"], lambda conta: sacar(conta, _dec(corpo["valor"])))

        if rota == "GET /contas/{contaId}":
            eventos = _carregar(params["contaId"])
            if not eventos:
                return _resp(404, {"erro": "conta não encontrada"})
            conta = reconstruir(params["contaId"], eventos)
            return _resp(200, {
                "contaId": conta.contaId,
                "titular": conta.titular,
                "saldo": _num(conta.saldo),
                "eventos": len(eventos),
            })

        return _resp(404, {"erro": f"rota desconhecida: {rota}"})

    except ComandoInvalido as erro:
        return _resp(400, {"erro": str(erro)})
    except SaldoInsuficiente as erro:
        return _resp(422, {"erro": str(erro)})
    except Conflito as erro:
        return _resp(409, {"erro": str(erro)})
