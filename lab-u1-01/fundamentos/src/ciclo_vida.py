"""Parte 3 — Ciclo de vida: fase Init e reúso de container.

Tudo que está FORA do handler roda uma única vez por ambiente de execução,
na fase Init (a partida fria). O que fica em memória global SOBREVIVE entre
invocações no mesmo ambiente — é a partida quente.

Este arquivo prova os dois fatos ao vivo:
  1. `carregado_em` é gravado na Init: some e reaparece igual em invocações
     quentes; muda quando um novo ambiente é criado (cold start).
  2. `invocacoes_neste_ambiente` conta quantas vezes ESTE ambiente já atendeu —
     começa em 0 a cada cold start e cresce nas partidas quentes.
"""

import os
import time

# ---------------------------------------------------------------------------
# BLOCO INIT — executa uma vez por ambiente de execução (fase Init / cold start)
# ---------------------------------------------------------------------------
# Simula trabalho caro de inicialização (abrir conexão, carregar config...).
# Em produção, é aqui que você cria o cliente boto3 e abre pools — pagando o
# custo uma vez por ambiente, não uma vez por invocação.
carregado_em = time.time()
invocacoes_neste_ambiente = 0

print(f"[INIT] Ambiente inicializado. carregado_em={carregado_em:.3f}")
# ---------------------------------------------------------------------------


def lambda_handler(event, context):
    global invocacoes_neste_ambiente
    invocacoes_neste_ambiente += 1

    ambiente_id = os.environ.get("AWS_LAMBDA_LOG_STREAM_NAME", "local")
    idade_s = time.time() - carregado_em

    if invocacoes_neste_ambiente == 1:
        tipo = "PARTIDA FRIA (cold start) — este ambiente nasceu agora"
    else:
        tipo = "PARTIDA QUENTE (warm) — reúso do mesmo ambiente"

    print(
        f"[HANDLER] {tipo}\n"
        f"          invocacoes_neste_ambiente={invocacoes_neste_ambiente}\n"
        f"          idade_do_ambiente={idade_s:.1f}s\n"
        f"          ambiente={ambiente_id}"
    )

    return {
        "invocacoes_neste_ambiente": invocacoes_neste_ambiente,
        "idade_do_ambiente_s": round(idade_s, 1),
        "carregado_em": carregado_em,
    }
