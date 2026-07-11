"""Parte 4 — Teste do runtime Python.

A função é trivial (o que se mede no lab é o cold start, não a lógica), mas o
teste garante o contrato: responde identificando o runtime.

Rodar:
    python3 -m pytest test_app.py -v
"""

import app


def test_handler_responde_identificando_o_runtime():
    resultado = app.lambda_handler({}, None)
    assert resultado == {"runtime": "python3.12", "ok": True}
