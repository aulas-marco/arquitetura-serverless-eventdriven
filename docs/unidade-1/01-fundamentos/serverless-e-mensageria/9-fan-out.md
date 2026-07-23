# Fan-out SNS→SQS

> **Roteiro-fonte:** U1V6 · **Lab:** U1-LAB02 (`src/comum.py`, `template.yaml`) · **Glossário:** [Fan-out](../../glossario.md#fan-out)

**Objetivo de aprendizagem:** ao final, você consegue **descrever** o padrão *fan-out*, **explicar** por que uma fila por consumidor dá isolamento de falha e **identificar** o duplo envelope SNS→SQS no código.

A [página anterior](8-fila-vs-pubsub.md) fechou em "combine os dois". Esta é a combinação: o padrão robusto de *fan-out*, e a pegadinha prática que ele traz — o duplo envelope que o consumidor precisa desembrulhar.

---

## O padrão

Uma publicação, N entregas independentes. SNS na frente espalha; uma SQS por consumidor amortece e isola:

```
                    ┌─ SQS estoque ──────► Lambda estoque
PedidoCriado → SNS ─┤
                    └─ SQS notificação ──► Lambda notificação
```

O produtor publica **uma vez** e não sabe quem lê:

```python
# src/publicar.py
def lambda_handler(event, context):
    pedido = ler_pedido(event)            # normaliza API GW / invocação direta
    evento = montar_evento(pedido)        # vira o fato PedidoCriado
    sns.publish(TopicArn=TOPICO_ARN, Message=json.dumps(evento), ...)
```

Entre produtor e consumidores não há referência direta. O SNS é o ponto de desacoplamento; as filas dão o *buffer* e o isolamento.

---

## Por que uma fila por consumidor

Poderia haver uma fila só, lida por vários. Mas filas separadas dão **isolamento de falha**: se o consumidor de notificação travar, as mensagens dele empilham **na fila dele** e são reprocessadas quando ele voltar — sem afetar o estoque, que já seguiu na sua própria fila. Cada consumidor tem seu ritmo, seu *retry* e (no [lab de DLQ](11-dlq-at-least-once.md)) sua própria quarentena.

A autorização também é explícita: uma `AWS::SQS::QueuePolicy` no *template.yaml* precisa liberar `sns.amazonaws.com` a publicar na fila — sem ela, o SNS publica e a mensagem "some" sem erro visível ao produtor.

---

## O duplo envelope — a pegadinha central

Na entrega padrão SNS→SQS (sem `RawMessageDelivery`), a mensagem chega **embrulhada duas vezes**: o `body` do registro SQS é o envelope do SNS, e o evento de domínio está no campo `Message` desse envelope — ainda como *string* JSON. O consumidor faz dois `json.loads`.

```
registro SQS.body  →  { "Type":"Notification", "Message": "<string JSON do evento>" }
                                                    └── json.loads de novo ──► PedidoCriado
```

O código que desembrulha, no lab:

```python
# src/comum.py
def extrair_evento(registro_sqs):
    envelope = json.loads(registro_sqs["body"])       # 1º: body do SQS = envelope SNS
    if isinstance(envelope, dict) and envelope.get("Type") == "Notification":
        return json.loads(envelope["Message"])         # 2º: Message = evento de domínio
    return envelope                                     # raw delivery: já é o evento
```

O `template.yaml` do lab **não** define `RawMessageDelivery: true` nas assinaturas — de propósito. Desligar o *raw delivery* força o aluno a desembrulhar os dois níveis; ligá-lo reduziria a um só. Um consumidor que assume um nível de envelope quebra com `KeyError: 'Message'`.

---

## O que o fan-out prova

Os dois consumidores compartilham o código-base e diferem só no *handler*. Cada um itera `event["Records"]` da **sua** fila e reage ao mesmo `PedidoCriado` — no mesmo instante, com o mesmo `pedidoId`. Uma publicação, duas reações independentes: isso é o *fan-out*.

> **Veja rodando:** o [U1-LAB02](../../02-demos/u1-02.md) implanta essa topologia (`make deploy-fanout` / `make fanout`) e mostra ambos os consumidores reagindo ao mesmo pedido, cada um a partir da sua fila.

---

⬅️ [Anterior: Fila (SQS) vs pub/sub (SNS)](8-fila-vs-pubsub.md) · 📑 [Índice](../../index.md) · [Próximo: Idempotência ➡️](10-idempotencia.md)
