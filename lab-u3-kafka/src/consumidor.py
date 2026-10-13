"""Consumidor Kafka local — lê o tópico como membro de um consumer group.

Variáveis: GRUPO (obrigatória), CONSUMIDOR (rótulo, padrão "consumidor"),
FALHAR_EM (clienteId que provoca falha antes do commit), KAFKA_BOOTSTRAP
(padrão localhost:9092) e TOPICO (padrão u3kafka-eventos-suporte).

Cada linha de saída leva um marcador: [ATRIBUIDO], [REVOGADO], [PROCESSADO],
[FALHA]. O offset só é confirmado (commit) DEPOIS do processamento, e é isso
que dá at-least-once: um registro que falha antes do commit é entregue de novo.
SIGTERM e SIGINT encerram com close(), que faz o consumidor deixar o grupo.
"""

import json
import os
import signal
import sys

from confluent_kafka import Consumer

from suporte import deve_falhar

BOOTSTRAP = os.environ.get("KAFKA_BOOTSTRAP", "localhost:9092")
TOPICO = os.environ.get("TOPICO", "u3kafka-eventos-suporte")
CONSUMIDOR = os.environ.get("CONSUMIDOR", "consumidor")
FALHAR_EM = os.environ.get("FALHAR_EM", "")

parar = False


def _sinalizar_parada(signum, frame):
    global parar
    parar = True


def _particoes(lista):
    return sorted(p.partition for p in lista)


def main():
    grupo = os.environ.get("GRUPO")
    if not grupo:
        print("GRUPO é obrigatória", file=sys.stderr)
        return 2

    signal.signal(signal.SIGTERM, _sinalizar_parada)
    signal.signal(signal.SIGINT, _sinalizar_parada)

    consumer = Consumer({
        "bootstrap.servers": BOOTSTRAP,
        "group.id": grupo,
        "auto.offset.reset": "earliest",
        "enable.auto.commit": False,
        # O librdkafka tenta [::1] antes de 127.0.0.1 e imprime um aviso a cada
        # recusa. O nível 2 mostra só o que é crítico.
        "log_level": 2,
    })

    def ao_atribuir(_consumer, particoes):
        print(f"[ATRIBUIDO] consumidor={CONSUMIDOR} grupo={grupo} particoes={_particoes(particoes)}", flush=True)

    def ao_revogar(_consumer, particoes):
        print(f"[REVOGADO] consumidor={CONSUMIDOR} grupo={grupo} particoes={_particoes(particoes)}", flush=True)

    consumer.subscribe([TOPICO], on_assign=ao_atribuir, on_revoke=ao_revogar)

    try:
        while not parar:
            msg = consumer.poll(0.5)
            if msg is None:
                continue
            if msg.error():
                print(f"[ERRO] {msg.error()}", file=sys.stderr, flush=True)
                continue

            posicao = f"particao={msg.partition()} offset={msg.offset()}"
            try:
                evento = json.loads(msg.value().decode("utf-8"))
                cliente_id = evento["clienteId"]
            except (ValueError, KeyError, TypeError):
                # Valor que não é um evento de suporte: ignora e confirma, para
                # não travar a partição.
                print(f"[IGNORADO] consumidor={CONSUMIDOR} {posicao} (valor não é um evento)", flush=True)
                consumer.commit(message=msg, asynchronous=False)
                continue

            if deve_falhar(cliente_id, FALHAR_EM):
                print(f"[FALHA] consumidor={CONSUMIDOR} {posicao} clienteId={cliente_id} (sem commit)", flush=True)
                return 1

            print(f"[PROCESSADO] consumidor={CONSUMIDOR} {posicao} clienteId={cliente_id}", flush=True)
            consumer.commit(message=msg, asynchronous=False)
    finally:
        consumer.close()
    return 0


if __name__ == "__main__":
    sys.exit(main())
