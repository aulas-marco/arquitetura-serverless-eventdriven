"""Lógica pura do lab Kafka local — sem I/O e sem importar confluent_kafka.

`montar_evento` é cópia adaptada de lab-u3-01/src/suporte.py: o lab fica
independente do U3-LAB01. A adaptação exige `clienteId` em texto, porque a
chave de uma mensagem Kafka precisa ser texto ou bytes.
"""


class EventoInvalido(ValueError):
    pass


def montar_evento(bruto):
    """Normaliza um evento de suporte cru. Exige a chave de roteamento."""
    if not isinstance(bruto, dict):
        raise EventoInvalido("evento deve ser um objeto")
    cliente_id = bruto.get("clienteId")
    mensagem = bruto.get("mensagem")
    if not cliente_id:
        raise EventoInvalido("clienteId é obrigatório (é a chave de roteamento)")
    if not isinstance(cliente_id, str):
        raise EventoInvalido("clienteId deve ser texto")
    if not mensagem:
        raise EventoInvalido("mensagem é obrigatória")
    return {"clienteId": cliente_id, "mensagem": mensagem}


def montar_lote(bruto):
    """Aceita um evento ou uma lista e devolve a lista de eventos validados."""
    eventos = bruto if isinstance(bruto, list) else [bruto]
    if not eventos:
        raise EventoInvalido("o lote está vazio")
    return [montar_evento(e) for e in eventos]


def deve_falhar(cliente_id, falhar_em):
    """Regra da falha intencional: só falha quando `falhar_em` está definido
    e coincide com o clienteId do registro."""
    return bool(falhar_em) and cliente_id == falhar_em
