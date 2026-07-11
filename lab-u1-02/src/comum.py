"""Lógica pura compartilhada do fan-out — sem I/O, testável sem AWS.

Duas peças ligam o produtor aos consumidores:

- `montar_evento` (lado produtor): transforma um pedido cru no evento de
  domínio `PedidoCriado` que será publicado no SNS.
- `extrair_evento` (lado consumidor): desembrulha o **duplo envelope** que
  chega na fila. Quando o SNS entrega numa fila SQS com a entrega padrão
  (RawMessageDelivery=false), o `body` do registro SQS é o envelope do SNS,
  e o evento de domínio está dentro do campo `Message` (uma string JSON).
  São dois `json.loads` aninhados — e é a pegadinha central deste lab.
"""

import json


def montar_evento(pedido):
    """Monta o evento de domínio a partir de um pedido cru.

    O produtor não sabe (nem precisa saber) quem vai consumir. Ele só publica
    o fato `PedidoCriado` — quem reage é problema dos assinantes do tópico.
    """
    if not isinstance(pedido, dict) or "pedidoId" not in pedido:
        raise ValueError("pedido precisa de ao menos 'pedidoId'")
    return {
        "tipo": "PedidoCriado",
        "pedidoId": pedido["pedidoId"],
        "valor": pedido.get("valor", 0),
        "itens": pedido.get("itens", []),
    }


def ler_pedido(event):
    """Extrai o pedido do `event` de entrada do produtor.

    O produtor pode ser chamado de duas formas: por invocação direta (o
    `event` já é o pedido) ou por API Gateway HTTP (o pedido vem como string
    JSON no campo `body`). Normaliza as duas em um dicionário.
    """
    if isinstance(event, dict) and "body" in event and isinstance(event["body"], str):
        return json.loads(event["body"])
    return event


def extrair_evento(registro_sqs):
    """Desembrulha o duplo envelope SQS → SNS → evento de domínio.

    Com a entrega padrão do SNS para SQS, cada registro SQS tem no `body` o
    envelope do SNS (`{"Type": "Notification", "Message": "<json>", ...}`), e o
    evento real é o `Message`, ainda como string JSON. Se a fila receber a
    mensagem direta (RawMessageDelivery=true ou envio direto na fila), o `body`
    já é o próprio evento.
    """
    corpo = registro_sqs.get("body")
    if corpo is None:
        raise ValueError("registro SQS sem 'body'")

    envelope = json.loads(corpo)

    # Entrega padrão do SNS: desembrulha o segundo nível.
    if isinstance(envelope, dict) and envelope.get("Type") == "Notification":
        return json.loads(envelope["Message"])

    # Mensagem já crua na fila (raw delivery ou envio direto).
    return envelope
