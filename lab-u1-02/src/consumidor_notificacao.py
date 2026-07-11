"""Consumidor B — notificação ao cliente.

Segundo assinante do mesmo tópico. Recebe o mesmo `PedidoCriado` que o
consumidor de estoque, de forma independente: se este falhar, o de estoque
não é afetado, e vice-versa. Foi adicionado sem tocar no produtor.
"""

from comum import extrair_evento


def lambda_handler(event, context):
    for registro in event["Records"]:
        pedido = extrair_evento(registro)
        print(f"[NOTIFICACAO] enviando confirmação do pedido {pedido['pedidoId']} "
              f"ao cliente (valor={pedido['valor']})")

    return {"processados": len(event["Records"])}
