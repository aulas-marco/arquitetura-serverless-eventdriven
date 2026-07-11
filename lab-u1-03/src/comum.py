"""Lógica pura do consumidor idempotente — sem I/O, testável sem AWS.

O consumidor recebe eventos de uma fila SQS (entrega *at-least-once*) e precisa
processar cada pedido **uma única vez**, mesmo que a mensagem chegue duplicada.
A defesa é um *conditional write* no DynamoDB: grava a chave só se ela ainda não
existir. As funções aqui isolam as decisões puras dessa estratégia:

- `extrair_evento`  — lê o evento do registro SQS (com ou sem envelope SNS).
- `chave_idempotencia` — deriva a chave que identifica a operação de negócio.
- `montar_item` — monta o item do DynamoDB, com TTL para o registro expirar.
- `eh_duplicado` — reconhece o erro de condição que sinaliza "já processado".
"""

import json

SEGUNDOS_POR_DIA = 86_400


def extrair_evento(registro_sqs):
    """Lê o evento de domínio do registro SQS.

    Se a mensagem veio direto na fila, o `body` já é o evento. Se veio via SNS
    (entrega padrão), o `body` é o envelope do SNS e o evento está em `Message`.
    Trata os dois para o lab não ficar preso a uma topologia.
    """
    corpo = registro_sqs.get("body")
    if corpo is None:
        raise ValueError("registro SQS sem 'body'")

    envelope = json.loads(corpo)
    if isinstance(envelope, dict) and envelope.get("Type") == "Notification":
        return json.loads(envelope["Message"])
    return envelope


def chave_idempotencia(evento):
    """Deriva a chave que identifica a operação — a unidade de deduplicação.

    Aqui é o `pedidoId`: reprocessar o mesmo pedido não pode duplicar o efeito.
    Numa operação sem identidade natural, usaria-se um `MessageDeduplicationId`
    ou um hash do conteúdo.
    """
    if not isinstance(evento, dict) or not evento.get("pedidoId"):
        raise ValueError("evento sem 'pedidoId' — não há chave de idempotência")
    return str(evento["pedidoId"])


def montar_item(evento, agora_epoch, ttl_dias=7):
    """Monta o item a gravar no DynamoDB.

    Inclui um `ttl` (epoch em segundos) para o registro de idempotência expirar
    sozinho — a tabela de deduplicação não deve crescer para sempre. O `agora`
    entra por parâmetro para a função ser determinística no teste.
    """
    return {
        "pedidoId": chave_idempotencia(evento),
        "valor": evento.get("valor", 0),
        "itens": evento.get("itens", []),
        "processadoEm": agora_epoch,
        "ttl": agora_epoch + ttl_dias * SEGUNDOS_POR_DIA,
    }


def eh_duplicado(codigo_erro):
    """True quando o erro do DynamoDB é a condição de idempotência que falhou.

    O *conditional write* (`attribute_not_exists`) levanta
    `ConditionalCheckFailedException` quando a chave já existe — ou seja, quando
    a mensagem é uma duplicata que já foi processada.
    """
    return codigo_erro == "ConditionalCheckFailedException"


def montar_evento(pedido):
    """Lado produtor: monta o `PedidoCriado` a partir de um pedido cru."""
    if not isinstance(pedido, dict) or "pedidoId" not in pedido:
        raise ValueError("pedido precisa de ao menos 'pedidoId'")
    return {
        "tipo": "PedidoCriado",
        "pedidoId": pedido["pedidoId"],
        "valor": pedido.get("valor", 0),
        "itens": pedido.get("itens", []),
    }


def ler_pedido(event):
    """Lado produtor: normaliza a entrada (API Gateway HTTP ou invocação direta)."""
    if isinstance(event, dict) and "body" in event and isinstance(event["body"], str):
        return json.loads(event["body"])
    return event
