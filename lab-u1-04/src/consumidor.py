"""Consumidor resiliente — falha parcial de lote + DLQ.

Para cada registro do lote: tenta processar. Se falha, NÃO derruba o lote todo —
registra o `messageId` na lista de falhas e devolve só esses no final
(`ReportBatchItemFailures`). A SQS reentrega apenas os falhados; os bons são
apagados. Uma mensagem que falha em toda tentativa é reentregue até o
`maxReceiveCount` e então movida para a DLQ pela própria SQS — sem código nosso.

O log imprime a tentativa (`ApproximateReceiveCount`) para o veneno ser visto
subindo 1 → 2 → 3 antes de cair na DLQ.
"""

from comum import extrair_evento, montar_resposta_lote, validar_pedido


def lambda_handler(event, context):
    falhas = []

    for registro in event["Records"]:
        tentativa = registro.get("attributes", {}).get("ApproximateReceiveCount", "?")

        try:
            evento = extrair_evento(registro)
        except Exception as erro:
            falhas.append(registro["messageId"])
            print(f"[FALHA] tentativa {tentativa} — registro {registro['messageId']} ilegível: {erro}")
            continue

        try:
            validar_pedido(evento)
            print(f"[OK] pedido {evento['pedidoId']} processado (valor={evento['valor']})")
        except Exception as erro:
            falhas.append(registro["messageId"])
            print(f"[FALHA] tentativa {tentativa} — pedido {evento.get('pedidoId')}: {erro}")

    resposta = montar_resposta_lote(falhas)
    print(f"[RESUMO] lote={len(event['Records'])} falhas={len(falhas)}")
    return resposta
