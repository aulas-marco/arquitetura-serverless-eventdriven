"""Consumidor idempotente — processa cada pedido no máximo uma vez.

Estratégia: antes de aplicar o efeito, tenta gravar a chave de idempotência no
DynamoDB com a condição `attribute_not_exists(pedidoId)`. Se a chave é nova, a
gravação passa e o efeito é aplicado. Se a chave já existe (mensagem duplicada),
a condição falha, o DynamoDB levanta `ConditionalCheckFailedException` e o
consumidor **ignora** — sem duplicar o efeito.

A gravação condicional é atômica: dois processamentos concorrentes da mesma
mensagem não conseguem ambos "ganhar". É o que torna a defesa correta sob
concorrência, e não só sob repetição sequencial.
"""

import os
import time

import boto3
from botocore.exceptions import ClientError

from comum import chave_idempotencia, eh_duplicado, extrair_evento, montar_item

dynamodb = boto3.resource("dynamodb")
tabela = dynamodb.Table(os.environ.get("TABELA", ""))


def lambda_handler(event, context):
    novos, duplicados = 0, 0

    for registro in event["Records"]:
        evento = extrair_evento(registro)
        chave = chave_idempotencia(evento)

        try:
            tabela.put_item(
                Item=montar_item(evento, int(time.time())),
                ConditionExpression="attribute_not_exists(pedidoId)",
            )
            # Primeira vez: só aqui o efeito de negócio é aplicado.
            print(f"[PROCESSADO] pedido {chave} gravado (efeito aplicado)")
            novos += 1
        except ClientError as erro:
            codigo = erro.response["Error"]["Code"]
            if eh_duplicado(codigo):
                print(f"[IGNORADO] pedido {chave} já processado (idempotência)")
                duplicados += 1
            else:
                raise

    print(f"[RESUMO] novos={novos} duplicados={duplicados}")
    return {"novos": novos, "duplicados": duplicados}
