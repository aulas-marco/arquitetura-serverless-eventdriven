"""Produtor Kafka local — publica eventos de suporte com key=clienteId.

Entrada: um evento ou uma lista, em JSON, pelo primeiro argumento ou pela
entrada padrão. Saída (stdout): uma linha JSON com a partição e o offset de
cada registro, ou o erro de entrega.

Variáveis: KAFKA_BOOTSTRAP (padrão localhost:9092) e TOPICO (padrão
u3kafka-eventos-suporte). Códigos de saída: 0 ok, 1 falha de entrega,
2 entrada inválida.
"""

import json
import os
import sys

from confluent_kafka import Producer

from suporte import EventoInvalido, montar_lote

BOOTSTRAP = os.environ.get("KAFKA_BOOTSTRAP", "localhost:9092")
TOPICO = os.environ.get("TOPICO", "u3kafka-eventos-suporte")


def main(argv, entrada):
    texto = argv[1] if len(argv) > 1 else entrada.read()
    try:
        eventos = montar_lote(json.loads(texto))
    except json.JSONDecodeError as erro:
        print(f"entrada inválida: JSON malformado ({erro})", file=sys.stderr)
        return 2
    except EventoInvalido as erro:
        print(f"entrada inválida: {erro}", file=sys.stderr)
        return 2

    # message.timeout.ms curto: com o broker fora do ar, a falha aparece em
    # ~10 s em vez dos 300 s padrão do librdkafka. log_level 2 silencia as
    # dezenas de linhas de reconexão que o librdkafka imprime nesse caso: o
    # erro de entrega já sai no JSON.
    producer = Producer({
        "bootstrap.servers": BOOTSTRAP,
        "message.timeout.ms": 10000,
        "log_level": 2,
    })
    publicados = [None] * len(eventos)

    def ao_entregar(indice, evento):
        def callback(erro, msg):
            if erro is not None:
                publicados[indice] = {"clienteId": evento["clienteId"], "erro": str(erro)}
            else:
                publicados[indice] = {
                    "clienteId": evento["clienteId"],
                    "particao": msg.partition(),
                    "offset": msg.offset(),
                }
        return callback

    for i, evento in enumerate(eventos):
        # A key é o clienteId: o particionador do cliente calcula o hash da
        # chave e fixa a partição de destino.
        producer.produce(
            TOPICO,
            key=evento["clienteId"],
            value=json.dumps(evento, ensure_ascii=False),
            on_delivery=ao_entregar(i, evento),
        )
    producer.flush(30)

    for i, resultado in enumerate(publicados):
        if resultado is None:
            publicados[i] = {"clienteId": eventos[i]["clienteId"], "erro": "sem confirmação do broker"}

    falhas = sum(1 for r in publicados if "erro" in r)
    print(json.dumps({"publicados": publicados, "falhas": falhas}, ensure_ascii=False))
    return 1 if falhas else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv, sys.stdin))
