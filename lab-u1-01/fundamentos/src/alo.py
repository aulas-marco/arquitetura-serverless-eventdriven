"""Parte 1 — Alô Mundo.

A função Lambda mais simples possível. O objetivo não é o que ela faz, e sim
o que o CloudWatch registra sobre ela: a linha REPORT no fim de cada invocação
traz Init Duration (só em cold start), Duration e Billed Duration.

Leia esses campos no CloudWatch Logs depois de invocar.
"""


def lambda_handler(event, context):
    print("Alô, serverless! A função executou.")

    # O context expõe metadados da invocação e do ambiente de execução.
    return {
        "mensagem": "Alô, serverless!",
        "funcao": context.function_name,
        "memoria_mb": context.memory_limit_in_mb,
        "ms_restantes": context.get_remaining_time_in_millis(),
        "request_id": context.aws_request_id,
    }
