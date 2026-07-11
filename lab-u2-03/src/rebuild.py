"""Rebuild da projeção — reprocessa o event store inteiro e reescreve `saldos`.

Prova que a projeção é DERIVADA e descartável: o event store é a fonte da
verdade. Se a projeção corromper, mudar de formato ou precisar de um novo campo,
basta reconstruí-la reprocessando os eventos. Aqui, um scan do event store,
agrupado por conta, com replay de cada agregado.

Rota:
  POST /projecao/rebuild   reconstrói toda a projeção a partir dos eventos
"""

import json
import os

import boto3

from dominio import reconstruir

eventos = boto3.resource("dynamodb").Table(os.environ["TABELA_EVENTOS"])
saldos = boto3.resource("dynamodb").Table(os.environ["TABELA_SALDOS"])


def _todos_os_eventos():
    itens, inicio = [], None
    while True:
        kwargs = {"ExclusiveStartKey": inicio} if inicio else {}
        pagina = eventos.scan(ConsistentRead=True, **kwargs)
        itens.extend(pagina["Items"])
        inicio = pagina.get("LastEvaluatedKey")
        if not inicio:
            return itens


def lambda_handler(event, context):
    por_conta = {}
    for item in _todos_os_eventos():
        por_conta.setdefault(item["contaId"], []).append(item)

    contas = 0
    for contaId, lista in por_conta.items():
        lista.sort(key=lambda e: int(e["sequencia"]))
        conta = reconstruir(contaId, lista)
        saldos.put_item(Item={
            "contaId": contaId,
            "titular": conta.titular,
            "saldo": conta.saldo,
            "ultimaSequencia": int(lista[-1]["sequencia"]),
        })
        contas += 1

    print(f"[REBUILD] {contas} conta(s) reprojetada(s)")
    return {"statusCode": 200, "body": json.dumps({"contasReprojetadas": contas})}
