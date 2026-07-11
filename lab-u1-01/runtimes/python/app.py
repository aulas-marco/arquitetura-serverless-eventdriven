"""Parte 4 — Runtime Python 3.12.

Função equivalente às versões Java e Go: recebe qualquer evento, responde de
imediato. Deliberadamente trivial — o que se mede aqui é o Init Duration da
partida fria, não o trabalho do handler.
"""


def lambda_handler(event, context):
    return {"runtime": "python3.12", "ok": True}
