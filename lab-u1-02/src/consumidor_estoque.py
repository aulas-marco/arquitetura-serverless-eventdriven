"""Consumidor A — reserva de estoque.

Assina o tópico (via sua fila SQS) e reage ao `PedidoCriado`. Não conhece o
produtor nem os outros consumidores. Recebe a MESMA cópia do evento que o
consumidor de notificação recebe — isso é o fan-out.
"""

from comum import extrair_evento


def lambda_handler(event, context):
    for registro in event["Records"]:
        pedido = extrair_evento(registro)
        print(f"[ESTOQUE] reservando itens do pedido {pedido['pedidoId']} "
              f"(valor={pedido['valor']}, itens={len(pedido['itens'])})")

    return {"processados": len(event["Records"])}
