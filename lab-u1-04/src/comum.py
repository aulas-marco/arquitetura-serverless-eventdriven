"""Lógica pura de resiliência — sem I/O, testável sem AWS.

Dois mecanismos protegem o consumidor de mensagens que falham:

- **Falha parcial de lote** — o Lambda recebe um lote da SQS. Se uma mensagem
  falha, não se pode falhar o lote inteiro (as boas seriam reentregues à toa).
  Com `ReportBatchItemFailures`, o handler devolve só os `itemIdentifier` que
  falharam; a SQS reentrega apenas esses. `montar_resposta_lote` monta essa
  resposta.
- **DLQ** — a mensagem "veneno" (que sempre falha) é reentregue até
  `maxReceiveCount` e então movida para a dead-letter queue. `validar_pedido` é
  quem decide se um pedido é processável; o veneno é o que ela rejeita sempre.
"""

import json


class PedidoInvalido(ValueError):
    """Pedido que não pode ser processado — o 'veneno' que vai parar na DLQ."""


def extrair_evento(registro_sqs):
    """Lê o evento de domínio do registro SQS (mensagem direta ou via SNS)."""
    corpo = registro_sqs.get("body")
    if corpo is None:
        raise PedidoInvalido("registro SQS sem 'body'")

    envelope = json.loads(corpo)
    if isinstance(envelope, dict) and envelope.get("Type") == "Notification":
        return json.loads(envelope["Message"])
    return envelope


def validar_pedido(evento):
    """Rejeita o pedido inprocessável. Levanta PedidoInvalido no veneno.

    Regras de negócio mínimas: precisa de identidade e de valor positivo. Um
    pedido que viole isso vai falhar em TODA tentativa — é o que caracteriza o
    veneno, e o que justifica a DLQ (reprocessar não adianta)."""
    if not isinstance(evento, dict) or not evento.get("pedidoId"):
        raise PedidoInvalido("sem 'pedidoId'")
    valor = evento.get("valor", 0)
    if not isinstance(valor, (int, float)) or valor <= 0:
        raise PedidoInvalido(f"valor inválido: {valor!r}")
    return evento


def montar_resposta_lote(ids_falhados):
    """Monta a resposta de falha parcial esperada pelo ReportBatchItemFailures.

    Lista vazia = lote todo processado (a SQS apaga tudo). Cada id na lista é
    uma mensagem que a SQS deve reentregar; as demais são apagadas."""
    return {"batchItemFailures": [{"itemIdentifier": i} for i in ids_falhados]}


def montar_entrada_batch(indice, evento):
    """Monta uma entrada para sqs.send_message_batch (lado produtor)."""
    return {"Id": str(indice), "MessageBody": json.dumps(evento)}


def montar_evento(pedido):
    """Lado produtor: monta o PedidoCriado a partir de um pedido cru.

    Não valida o valor: um pedido com valor inválido PRECISA passar aqui para
    falhar no consumidor — é assim que o veneno chega à fila e exercita a DLQ."""
    if not isinstance(pedido, dict) or "pedidoId" not in pedido:
        raise ValueError("pedido precisa de ao menos 'pedidoId'")
    return {
        "tipo": "PedidoCriado",
        "pedidoId": pedido["pedidoId"],
        "valor": pedido.get("valor", 0),
        "itens": pedido.get("itens", []),
    }


def ler_corpo(event):
    """Lado produtor: normaliza a entrada e devolve o corpo já em objeto.

    Aceita invocação direta (o event é o pedido ou a lista) ou API Gateway HTTP
    (o corpo vem como string JSON em `body`)."""
    if isinstance(event, dict) and "body" in event and isinstance(event["body"], str):
        return json.loads(event["body"])
    return event
