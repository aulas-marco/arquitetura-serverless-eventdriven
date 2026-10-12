"""Handler HTTP com replay acelerado por snapshot.

Duas tabelas: o event store (append-only, do U2-LAB01) e uma de snapshots. Um
snapshot materializa o estado do agregado numa dada sequência. A consulta padrão
carrega o snapshot mais recente e reprocessa **só os eventos posteriores** (o
delta) — em vez de reler a história inteira.

Rotas:
  POST /contas                       cria a conta
  POST /contas/{contaId}/depositos   deposita
  POST /contas/{contaId}/saques      saca
  POST /contas/{contaId}/snapshot    materializa o estado atual num snapshot
  GET  /contas/{contaId}             consulta via snapshot + delta
  GET  /contas/{contaId}/completo    consulta por replay completo (para comparar)
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
from dominio import (
    estado_para_snapshot,
    reconstruir,
    reconstruir_a_partir_de,
    snapshot_para_estado,
)

dynamodb = boto3.resource("dynamodb")
tabela_eventos = dynamodb.Table(os.environ["TABELA_EVENTOS"])
tabela_snapshots = dynamodb.Table(os.environ["TABELA_SNAPSHOTS"])


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


def _eventos(contaId, apos_sequencia=None):
    cond = Key("contaId").eq(contaId)
    if apos_sequencia is not None:
        cond = cond & Key("sequencia").gt(apos_sequencia)
    return tabela_eventos.query(KeyConditionExpression=cond, ScanIndexForward=True)["Items"]


def _append(evento, sequencia):
    item = {**evento, "sequencia": sequencia, "criadoEm": int(time.time())}
    try:
        tabela_eventos.put_item(
            Item=item,
            ConditionExpression="attribute_not_exists(contaId) AND attribute_not_exists(sequencia)",
        )
    except ClientError as erro:
        if erro.response["Error"]["Code"] == "ConditionalCheckFailedException":
            raise Conflito(f"conflito de sequência {sequencia}")
        raise
    return item


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


def _gravar_snapshot(contaId):
    eventos = _eventos(contaId)
    if not eventos:
        return _resp(404, {"erro": "conta não encontrada"})
    conta = reconstruir(contaId, eventos)
    ultima = int(eventos[-1]["sequencia"])
    tabela_snapshots.put_item(Item={
        "contaId": contaId,
        "estado": estado_para_snapshot(conta),
        "ultimaSequencia": ultima,
        "criadoEm": int(time.time()),
    })
    print(f"[SNAPSHOT] contaId={contaId} até seq={ultima} saldo={conta.saldo}")
    return _resp(200, {"contaId": contaId, "snapshotSequencia": ultima, "saldo": _num(conta.saldo)})


def _consultar_com_snapshot(contaId):
    snap = tabela_snapshots.get_item(Key={"contaId": contaId}).get("Item")
    if snap:
        base = snapshot_para_estado(contaId, snap["estado"])
        delta = _eventos(contaId, apos_sequencia=int(snap["ultimaSequencia"]))
        conta = reconstruir_a_partir_de(base, delta)
        return conta, {
            "viaSnapshot": True,
            "snapshotSequencia": int(snap["ultimaSequencia"]),
            "eventosReprocessados": len(delta),
        }
    eventos = _eventos(contaId)
    if not eventos:
        return None, None
    return reconstruir(contaId, eventos), {"viaSnapshot": False, "eventosReprocessados": len(eventos)}


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

        if rota == "POST /contas/{contaId}/snapshot":
            return _gravar_snapshot(params["contaId"])

        if rota == "GET /contas/{contaId}":
            conta, meta = _consultar_com_snapshot(params["contaId"])
            if conta is None:
                return _resp(404, {"erro": "conta não encontrada"})
            return _resp(200, {"contaId": conta.contaId, "titular": conta.titular,
                               "saldo": _num(conta.saldo), **meta})

        if rota == "GET /contas/{contaId}/completo":
            eventos = _eventos(params["contaId"])
            if not eventos:
                return _resp(404, {"erro": "conta não encontrada"})
            conta = reconstruir(params["contaId"], eventos)
            return _resp(200, {"contaId": conta.contaId, "titular": conta.titular,
                               "saldo": _num(conta.saldo), "viaSnapshot": False,
                               "eventosReprocessados": len(eventos)})

        return _resp(404, {"erro": f"rota desconhecida: {rota}"})

    except ContaNaoEncontrada:
        return _resp(404, {"erro": "conta não encontrada"})
    except ComandoInvalido as erro:
        return _resp(400, {"erro": str(erro)})
    except SaldoInsuficiente as erro:
        return _resp(422, {"erro": str(erro)})
    except Conflito as erro:
        return _resp(409, {"erro": str(erro)})
