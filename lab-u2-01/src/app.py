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


class ContaNaoEncontrada(Exception):
    """Não há nenhum evento gravado para o contaId informado."""


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


def _carregar_conta(contaId):
    """Lê os eventos e reconstrói o estado. Devolve (conta, eventos)."""
    eventos = _carregar(contaId)
    if not eventos:
        raise ContaNaoEncontrada()
    return reconstruir(contaId, eventos), eventos


def _gravar_e_responder(conta, evento, eventos):
    """Grava o evento na próxima sequência e devolve o saldo atualizado."""
    _append(evento, len(eventos) + 1)
    novo_saldo = conta.aplicar(evento).saldo
    return _resp(200, {"contaId": conta.contaId, "saldo": _num(novo_saldo)})


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
            conta, eventos = _carregar_conta(params["contaId"])
            evento = depositar(conta, _dec(corpo["valor"]))
            return _gravar_e_responder(conta, evento, eventos)

        if rota == "POST /contas/{contaId}/saques":
            conta, eventos = _carregar_conta(params["contaId"])
            evento = sacar(conta, _dec(corpo["valor"]))
            return _gravar_e_responder(conta, evento, eventos)

        if rota == "GET /contas/{contaId}":
            conta, eventos = _carregar_conta(params["contaId"])
            return _resp(200, {
                "contaId": conta.contaId,
                "titular": conta.titular,
                "saldo": _num(conta.saldo),
                "eventos": len(eventos),
            })

        return _resp(404, {"erro": f"rota desconhecida: {rota}"})

    except ContaNaoEncontrada:
        return _resp(404, {"erro": "conta não encontrada"})
    except ComandoInvalido as erro:
        return _resp(400, {"erro": str(erro)})
    except SaldoInsuficiente as erro:
        return _resp(422, {"erro": str(erro)})
    except Conflito as erro:
        return _resp(409, {"erro": str(erro)})
