# 5 — Mensageria e fan-out

## Chamar direto acopla

A saída ingênua para "quando um pedido é criado, baixe o estoque e avise o cliente" é o produtor chamar os dois serviços diretamente:

```
PedidoService → chama → EstoqueService
              → chama → NotificacaoService
```

Três problemas: o produtor precisa **conhecer** cada consumidor; se um estiver fora do ar, a chamada **falha** (ou trava esperando); e adicionar um terceiro consumidor obriga a **alterar o produtor**. É acoplamento ponto-a-ponto, síncrono.

## Publicar um fato desacopla

Inverta: o produtor não chama ninguém — ele **publica um fato**. `PedidoCriado` aconteceu. Quem se interessa que se inscreva. O produtor não sabe quantos consumidores existem nem quais são. Ver [evento vs comando](../glossario.md#evento).

Isso é **fan-out**: uma publicação, N entregas independentes.

## SNS e SQS resolvem metades diferentes

| Serviço | Modelo | Entrega | Papel no fan-out |
|---------|--------|---------|------------------|
| [SNS](../glossario.md#sns) | pub/sub (tópico) | *push* — empurra a todos os assinantes | espalha a mensagem |
| [SQS](../glossario.md#sqs) | fila | *pull* — o consumidor busca no seu ritmo | amortece e isola cada consumidor |

Sozinho, o SNS empurraria direto para cada Lambda — mas sem fila, um pico derruba o consumidor e a mensagem se perde. Sozinha, a SQS não faz fan-out — uma mensagem numa fila é lida por **um** consumidor. O padrão robusto combina os dois: **SNS na frente (fan-out), uma SQS por consumidor (buffer + isolamento)**. É o [fan-out SNS+SQS](../glossario.md#fan-out).

```
                    ┌─ SQS estoque ──→ Lambda estoque
PedidoCriado → SNS ─┤
                    └─ SQS notificação ─→ Lambda notificação
```

## Por que uma fila por consumidor

Poderia haver uma fila só, lida por vários. Mas filas separadas dão **isolamento de falha**: se o consumidor de notificação travar, as mensagens dele empilham **na fila dele** e são reprocessadas quando ele voltar — sem afetar o estoque, que já seguiu em frente na sua própria fila. Cada consumidor tem seu ritmo, seu retry e (no próximo lab) sua [DLQ](../glossario.md#dlq).

## O duplo envelope

Quando o SNS entrega numa fila SQS com a entrega padrão, a mensagem chega **embrulhada duas vezes**: o registro SQS traz no `body` o envelope do SNS, e o evento de domínio está no campo `Message` desse envelope — ainda como string JSON. O consumidor faz dois `json.loads`. É a pegadinha prática que o lab exercita.

```
registro SQS.body  →  { "Type":"Notification", "Message": "<json do evento>" }
                                                   └── json.loads de novo ──→ PedidoCriado
```

## At-least-once: a conta que fica para depois

A SQS entrega *at-least-once* — a mesma mensagem pode chegar duas vezes. Publicar um fato e reagir a ele exige, portanto, que a reação seja segura sob repetição. Esse é o tema do próximo lab: [idempotência](../glossario.md#idempotencia).

## No lab

O [U1-LAB02](../02-demos/u1-02.md) implanta exatamente esta topologia: um produtor HTTP publica `PedidoCriado` no tópico, e dois consumidores independentes reagem — provado pelo log, onde ambos processam o mesmo pedido no mesmo instante, cada um a partir da sua fila.

---

⬅️ [Runtimes e SnapStart](4-runtimes-e-snapstart.md) · [Idempotência e entrega ➡️](6-idempotencia-e-entrega.md)
