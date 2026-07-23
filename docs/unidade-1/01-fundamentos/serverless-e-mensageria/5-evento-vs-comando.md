# Evento vs comando

> **Roteiro-fonte:** U1V4 · **Glossário:** [Evento vs Comando](../../glossario.md#evento) · [EDA](../../glossario.md#eda)

**Objetivo de aprendizagem:** ao final, você consegue **diferenciar** evento de comando, **descrever** as três dimensões do desacoplamento em EDA e **reconhecer** o acoplamento de *schema* que não desaparece.

Os gatilhos da [página anterior](4-gatilhos-e-eventos.md) responderam *como* a função é ativada. Falta responder *a quê* ela reage. O gatilho mais idiomático em arquiteturas modernas é um **evento** — e a primeira coisa a fazer é distingui-lo de um comando, porque a escolha entre os dois define o grau de acoplamento do sistema inteiro.

---

## A distinção

- **Evento** é o registro de um **fato que já aconteceu**, imutável, no passado: `PedidoCriado`, `PagamentoAprovado`. Quem publica está **anunciando** algo — não sabe (nem quer saber) quem vai reagir, e não espera resposta. O fato é verdadeiro havendo zero, um ou vinte consumidores.
- **Comando** é um **pedido de ação dirigido**, no imperativo: `CrieUmPedido`, `ReserveEstoque`. Quem envia **conhece o destinatário** e geralmente espera que a ação seja executada.

| Aspecto | Evento | Comando |
|---------|--------|---------|
| Tempo verbal | passado (fato) | imperativo (ordem) |
| Conhece o destinatário? | não | sim |
| Espera resposta? | não | geralmente sim |
| Número de consumidores | 0 a N | tipicamente 1 |

---

## Estilos de evento (reconhecer o espectro)

Nem todo evento carrega a mesma informação. A escolha tem consequências de acoplamento e tráfego:

1. **Notificação de evento** — carrega o mínimo: que algo aconteceu e um identificador (`PedidoCriado { pedidoId: 42 }`). Quem precisa de detalhes chama o produtor de volta. Eventos pequenos, mas reintroduz dependência de *runtime*.
2. **Evento carregando estado** (*event-carried state transfer*) — carrega uma cópia do estado relevante (`PedidoCriado { pedidoId, itens, valor, cliente }`). O consumidor não chama ninguém de volta; desacopla mais, ao custo de eventos maiores e cópias que envelhecem.
3. **Event sourcing** — o evento vira a **fonte da verdade**: o estado é a soma de todos os eventos. Aqui basta **reconhecer** o termo; é o tema da Unidade 2.

Os labs desta unidade usam o estilo **carregando estado** — o `PedidoCriado` traz `pedidoId`, `valor` e `itens`, e o consumidor reage sem consultar o produtor.

---

## Desacoplamento — três dimensões

O coração da [EDA](../../glossario.md#eda) é o desacoplamento: quem publica `PedidoCriado` não sabe quem reage. Adicionar um consumidor não exige tocar no produtor. Vale **diferenciar** as três dimensões:

- **Temporal** — produtor e consumidor não precisam estar ativos ao mesmo tempo. A fila/barramento absorve a diferença.
- **De implementação** — o produtor não conhece o tipo, a linguagem ou a localização do consumidor.
- **De cardinalidade** — um evento pode ter zero ou N consumidores; o produtor não muda.

---

## O acoplamento que NÃO desaparece

No momento em que o produtor publica `PedidoCriado { pedidoId, valor, cliente }`, esse formato vira um **contrato**. Todo consumidor depende dele. Se o produtor renomear `valor` para `valorTotal` ou remover um campo, quebra consumidores que nem conhece.

```
antes:  A ──chama──► B        (acoplamento de código, direto)
depois: A ──publica──► [evento {schema}] ──► B, C, D
                            └── o acoplamento migrou para AQUI
```

O acoplamento não foi eliminado — **migrou** da dependência direta de código para a dependência sobre o formato da mensagem. Ignorar isso é o erro mais comum de quem adota EDA achando que "eventos desacoplam tudo".

---

⬅️ [Anterior: Gatilhos e formatos de evento](4-gatilhos-e-eventos.md) · 📑 [Índice](../../index.md) · [Próximo: Coreografia vs orquestração ➡️](6-coreografia-vs-orquestracao.md)
