"""Lado de ESCRITA (CQRS) — só grava eventos no event store. Nunca lê a projeção.

Rotas:
  POST /contas                       cria conta
  POST /contas/{contaId}/depositos   deposita
  POST /contas/{contaId}/saques      saca
  POST /transferencias               saca de uma conta e deposita em outra,
                                      atomicamente (TransactWriteItems)
"""

import json
import os
import time
from decimal import Decimal

import boto3
from boto3.dynamodb.conditions import Key
from boto3.dynamodb.types import TypeSerializer
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

NOME_TABELA = os.environ["TABELA_EVENTOS"]
tabela = boto3.resource("dynamodb").Table(NOME_TABELA)
# Client low-level PURO para a transação: ao contrário do resource.meta.client,
# ele não aplica marshaling — os itens já vêm serializados pelo TypeSerializer.
cliente = boto3.client("dynamodb")
serializer = TypeSerializer()

COND_SEQ = "attribute_not_exists(contaId) AND attribute_not_exists(sequencia)"


class Conflito(Exception):
    pass


class ContaNaoEncontrada(Exception):
    pass


def _dec(x):
    return Decimal(str(x))


def _num(d):
    d = Decimal(d)
    return int(d) if d == d.to_integral_value() else float(d)


def _resp(status, corpo):
    return {"statusCode": status, "body": json.dumps(corpo, default=str)}


def _eventos(contaId):
    # ConsistentRead: o lado de comando PRECISA ver os eventos recém-gravados
    # para calcular a próxima sequência. Sem isso, uma leitura eventualmente
    # consistente pode não ver o último evento e colidir na gravação.
    return tabela.query(
        KeyConditionExpression=Key("contaId").eq(contaId),
        ScanIndexForward=True,
        ConsistentRead=True,
    )["Items"]


def _linha_evento(evento, sequencia):
    return {**evento, "sequencia": sequencia, "criadoEm": int(time.time())}


def _append(evento, sequencia):
    try:
        tabela.put_item(Item=_linha_evento(evento, sequencia), ConditionExpression=COND_SEQ)
    except ClientError as erro:
        if erro.response["Error"]["Code"] == "ConditionalCheckFailedException":
            raise Conflito(f"conflito de sequência {sequencia}")
        raise


def _carregar_conta(contaId):
    """Lê os eventos e reconstrói o estado. Devolve (conta, eventos)."""
    eventos = _eventos(contaId)
    if not eventos:
        raise ContaNaoEncontrada()
    return reconstruir(contaId, eventos), eventos


def _gravar_e_responder(conta, evento, eventos):
    """Grava o evento na próxima sequência e devolve o saldo atualizado."""
    _append(evento, len(eventos) + 1)
    return _resp(200, {"contaId": conta.contaId, "saldo": _num(conta.aplicar(evento).saldo)})


def _serial(item):
    return {k: serializer.serialize(v) for k, v in item.items()}


def _transferir(origem, destino, valor):
    ev_o, ev_d = _eventos(origem), _eventos(destino)
    if not ev_o or not ev_d:
        return _resp(404, {"erro": "conta de origem ou destino não encontrada"})

    conta_o = reconstruir(origem, ev_o)
    if conta_o.saldo < valor:
        return _resp(422, {"erro": f"saldo insuficiente na origem: {conta_o.saldo} < {valor}"})

    saque = _linha_evento({"tipo": "SaqueRealizado", "contaId": origem, "valor": valor}, len(ev_o) + 1)
    deposito = _linha_evento({"tipo": "DepositoRealizado", "contaId": destino, "valor": valor}, len(ev_d) + 1)

    try:
        # Atômico: ou os DOIS eventos são gravados, ou nenhum. Cada um mantém
        # sua própria concorrência otimística pela condição de sequência.
        cliente.transact_write_items(TransactItems=[
            {"Put": {"TableName": NOME_TABELA, "Item": _serial(saque), "ConditionExpression": COND_SEQ}},
            {"Put": {"TableName": NOME_TABELA, "Item": _serial(deposito), "ConditionExpression": COND_SEQ}},
        ])
    except ClientError as erro:
        if "TransactionCanceled" in erro.response["Error"]["Code"]:
            raise Conflito("transferência cancelada (conflito de sequência) — repita")
        raise

    conta_d = reconstruir(destino, ev_d)
    return _resp(200, {
        "origem": {"contaId": origem, "saldo": _num(conta_o.saldo - valor)},
        "destino": {"contaId": destino, "saldo": _num(conta_d.saldo + valor)},
    })


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

        if rota == "POST /transferencias":
            return _transferir(corpo["origem"], corpo["destino"], _dec(corpo["valor"]))

        return _resp(404, {"erro": f"rota desconhecida: {rota}"})

    except ContaNaoEncontrada:
        return _resp(404, {"erro": "conta não encontrada"})
    except ComandoInvalido as erro:
        return _resp(400, {"erro": str(erro)})
    except SaldoInsuficiente as erro:
        return _resp(422, {"erro": str(erro)})
    except Conflito as erro:
        return _resp(409, {"erro": str(erro)})
