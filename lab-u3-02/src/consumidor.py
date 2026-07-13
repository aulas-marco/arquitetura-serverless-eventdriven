"""Consumidor Kinesis: loga shard + clienteId e demonstra at-least-once."""
import os

from suporte import decodificar_lote

CONSUMIDOR = os.environ.get("CONSUMIDOR", "consumidor")
FALHAR_EM = os.environ.get("FALHAR_EM", "")


class FalhaIntencional(Exception):
    """Levantada intencionalmente para demonstrar at-least-once via retry do ESM."""


def lambda_handler(event, context):
    registros = decodificar_lote(event["Records"])
    for r in registros:
        cliente_id = r["dados"].get("clienteId", "?")
        print(f"[{CONSUMIDOR}] shard={r['shardId']} clienteId={cliente_id}")
        if FALHAR_EM and cliente_id == FALHAR_EM:
            raise FalhaIntencional(f"falha intencional para clienteId={cliente_id!r}")
