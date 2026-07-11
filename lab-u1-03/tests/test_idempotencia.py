"""Testes da lógica de idempotência.

O consumidor delega ao DynamoDB a decisão atômica de "já processei?". O que
sobra de lógica pura — derivar a chave, montar o item com TTL, reconhecer o erro
de duplicata — é o que estes testes cobrem, sem tocar na AWS.
"""

from comum import chave_idempotencia, eh_duplicado, montar_item

EVENTO = {"tipo": "PedidoCriado", "pedidoId": "p-1", "valor": 100, "itens": ["a", "b"]}


def test_chave_e_estavel_para_o_mesmo_pedido():
    """A mesma mensagem (mesmo pedidoId) sempre gera a mesma chave — é isso que
    faz a duplicata colidir com o registro original."""
    assert chave_idempotencia(EVENTO) == chave_idempotencia(dict(EVENTO))
    assert chave_idempotencia(EVENTO) == "p-1"


def test_chave_difere_entre_pedidos():
    """Pedidos distintos não podem compartilhar chave, senão um bloquearia o
    outro."""
    assert chave_idempotencia({"pedidoId": "p-1"}) != chave_idempotencia({"pedidoId": "p-2"})


def test_chave_exige_pedidoId():
    """Sem identidade não há como deduplicar — falha explícita."""
    for invalido in ({}, {"pedidoId": ""}, {"valor": 10}, "nao-dict"):
        try:
            chave_idempotencia(invalido)
            assert False, f"deveria falhar para {invalido!r}"
        except ValueError:
            pass


def test_montar_item_calcula_ttl_a_partir_do_agora():
    """O item carrega um TTL futuro (default 7 dias) para o registro de
    deduplicação expirar sozinho e a tabela não crescer indefinidamente."""
    agora = 1_000_000
    item = montar_item(EVENTO, agora, ttl_dias=7)
    assert item["pedidoId"] == "p-1"
    assert item["processadoEm"] == agora
    assert item["ttl"] == agora + 7 * 86_400


def test_montar_item_preserva_dados_do_pedido():
    """O item guarda o efeito de negócio (valor, itens), não só a chave."""
    item = montar_item(EVENTO, 0)
    assert item["valor"] == 100
    assert item["itens"] == ["a", "b"]


def test_eh_duplicado_reconhece_a_condicao_que_falhou():
    """A duplicata é sinalizada pelo ConditionalCheckFailedException; qualquer
    outro erro NÃO é duplicata e deve propagar (não ser engolido como ignorado)."""
    assert eh_duplicado("ConditionalCheckFailedException") is True
    assert eh_duplicado("ProvisionedThroughputExceededException") is False
    assert eh_duplicado("ThrottlingException") is False
