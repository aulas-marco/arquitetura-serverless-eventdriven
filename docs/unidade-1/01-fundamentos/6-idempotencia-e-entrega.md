# 6 — Idempotência e entrega at-least-once

## A garantia que a fila NÃO dá

A [SQS](../glossario.md#sqs) entrega *at-least-once*: garante que a mensagem chega **pelo menos** uma vez — não que chega **exatamente** uma vez. Um pico de rede, um *visibility timeout* estourado, um retry interno: qualquer um faz a mesma mensagem ser entregue duas vezes. Não é falha rara a se ignorar; é o contrato do serviço.

Consequência direta: se processar `PedidoCriado` cobra o cartão, um processamento duplicado **cobra duas vezes**. O código do consumidor tem que absorver a repetição.

## Idempotência: o mesmo efeito, não importa quantas vezes

Uma operação é [idempotente](../glossario.md#idempotencia) quando aplicá-la N vezes tem o mesmo efeito que aplicá-la uma. `saldo = 100` é idempotente; `saldo += 10` não é. A meta do consumidor: transformar "processar o pedido" numa operação idempotente, mesmo quando o efeito de negócio (cobrar, baixar estoque) não é naturalmente repetível.

## A técnica: gravar a chave sob condição

O padrão canônico usa um armazém que sabe dizer, atomicamente, "essa operação já foi feita?". No [DynamoDB](../glossario.md#dynamodb):

```python
tabela.put_item(
    Item={"pedidoId": chave, ...},
    ConditionExpression="attribute_not_exists(pedidoId)",
)
```

- **Primeira entrega** — a chave não existe, a condição passa, o item é gravado e o efeito é aplicado.
- **Duplicata** — a chave já existe, a condição falha, o DynamoDB levanta `ConditionalCheckFailedException`, e o consumidor **ignora**.

O que torna isso correto não é o "verificar antes de gravar" (dois passos abrem uma janela de corrida), e sim a **atomicidade**: o teste da condição e a gravação são uma operação só. Duas entregas concorrentes da mesma mensagem não conseguem ambas gravar — uma ganha, a outra recebe o erro de condição.

## A chave de idempotência

É o identificador da **operação de negócio**, não da mensagem. Duas entregas da mesma mensagem têm `MessageId` SQS **diferentes** — deduplicar por ele não pegaria nada. A chave certa é algo estável do domínio: aqui, o `pedidoId`. Sem identidade natural, usa-se um `MessageDeduplicationId` explícito ou um hash do conteúdo.

## O registro não pode crescer para sempre

O armazém de deduplicação acumularia uma linha por operação, indefinidamente. A saída é o **TTL** do DynamoDB: um atributo com o *epoch* de expiração; passado esse instante, o item é removido automaticamente. Escolhe-se a janela pela realidade da duplicata — se retries acontecem em minutos ou horas, dias de TTL sobram.

## No lab

O [U1-LAB03](../02-demos/u1-03.md) implanta produtor → SQS → consumidor idempotente → DynamoDB. O script envia o **mesmo** `pedidoId` duas vezes (o que a entrega *at-least-once* faria) e mostra o log com um `PROCESSADO` e um `IGNORADO`, e a tabela com um único item. O próximo lab fecha a trilha de resiliência: quando o processamento **falha** de vez, para onde vai a mensagem — [DLQ](../glossario.md#dlq).

---

⬅️ [Mensageria e fan-out](5-mensageria-e-fanout.md) · [DLQ e resiliência ➡️](7-dlq-e-resiliencia.md)
