# Idempotência: chave + DynamoDB TTL

> **Roteiro-fonte:** U1V6 · **Lab:** U1-LAB03 (`src/comum.py`, `src/consumidor.py`, `template.yaml`) · **Glossário:** [Idempotência](../../glossario.md#idempotencia) · [Conditional write](../../glossario.md#conditional-write) · [TTL](../../glossario.md#ttl)

**Objetivo de aprendizagem:** ao final, você consegue **explicar** por que a entrega *at-least-once* obriga o consumidor a ser idempotente, **descrever** o *conditional write* como defesa e **diferenciar** a chave de negócio do `MessageId` da mensagem.

O [fan-out](9-fan-out.md) deixou uma conta em aberto: a SQS entrega *at-least-once*, então a mesma mensagem pode chegar duas vezes. Se processar `PedidoCriado` cobra um cartão, a duplicata cobra de novo. Esta página constrói a defesa canônica.

---

## A garantia que a fila NÃO dá

A [SQS](../../glossario.md#sqs) entrega *at-least-once*: garante que a mensagem chega **pelo menos** uma vez — não **exatamente** uma vez. Um pico de rede, um *visibility timeout* estourado, um *retry* interno: qualquer um duplica a entrega. É o contrato do serviço, não falha rara.

Uma operação é **idempotente** quando aplicá-la N vezes tem o mesmo efeito que aplicá-la uma. `saldo = 100` é idempotente; `saldo += 10` não é. A meta do consumidor: transformar "processar o pedido" numa operação idempotente, mesmo quando o efeito de negócio (cobrar, baixar estoque) não é naturalmente repetível.

---

## A técnica: gravar a chave sob condição

O padrão canônico usa um armazém que sabe dizer, **atomicamente**, "essa operação já foi feita?". No [DynamoDB](../../glossario.md#dynamodb), é a gravação condicional:

```python
# src/consumidor.py
try:
    tabela.put_item(
        Item=montar_item(evento, int(time.time())),
        ConditionExpression="attribute_not_exists(pedidoId)",
    )
    print(f"[PROCESSADO] pedido {chave} gravado (efeito aplicado)")   # 1ª vez
except ClientError as erro:
    if eh_duplicado(erro.response["Error"]["Code"]):
        print(f"[IGNORADO] pedido {chave} já processado")             # duplicata
    else:
        raise                                                          # erro real propaga
```

- **Primeira entrega** — a chave não existe, a condição passa, o item é gravado, o efeito é aplicado.
- **Duplicata** — a chave já existe, a condição falha, o DynamoDB levanta `ConditionalCheckFailedException`, e o consumidor **ignora**.

`eh_duplicado` só aceita esse código de erro específico; qualquer outro `ClientError` propaga — um erro real não pode ser confundido com duplicata.

---

## Por que a atomicidade, não o "check-then-put"

```python
# ERRADO — janela de corrida entre ler e gravar
if not tabela.get_item(...):        # duas entregas concorrentes leem "não existe"
    tabela.put_item(...)            # ambas gravam → efeito duplicado

# CORRETO — teste da condição e gravação são UMA operação atômica
tabela.put_item(Item=..., ConditionExpression="attribute_not_exists(pedidoId)")
```

Duas entregas concorrentes da mesma mensagem não conseguem ambas gravar — uma ganha, a outra recebe o erro de condição. É por isso que a defesa vale sob concorrência, não só sob repetição em sequência.

---

## A chave de idempotência

É o identificador da **operação de negócio**, não da mensagem. Duas entregas da mesma mensagem têm `MessageId` SQS **diferentes** — deduplicar por ele não pegaria nada. A chave certa é algo estável do domínio: aqui, o `pedidoId`.

```python
# src/comum.py
def chave_idempotencia(evento):
    if not evento.get("pedidoId"):
        raise ValueError("evento sem 'pedidoId'")
    return str(evento["pedidoId"])
```

Sem identidade natural, usa-se um `MessageDeduplicationId` explícito ou um *hash* do conteúdo.

---

## O registro não pode crescer para sempre

O armazém de deduplicação acumularia uma linha por operação, indefinidamente. A saída é o **TTL** do DynamoDB: um atributo com o *epoch* de expiração; passado esse instante, o item é removido automaticamente. No lab, `ttl = agora + 7 dias`:

```python
# src/comum.py — SEGUNDOS_POR_DIA = 86_400
def montar_item(evento, agora_epoch, ttl_dias=7):
    return {
        "pedidoId": chave_idempotencia(evento),
        "valor": evento.get("valor", 0),
        "itens": evento.get("itens", []),
        "processadoEm": agora_epoch,
        "ttl": agora_epoch + ttl_dias * SEGUNDOS_POR_DIA,
    }
```

```yaml
# template.yaml — tabela única, chave de partição = pedidoId, on-demand + TTL
TabelaPedidos:
  Type: AWS::DynamoDB::Table
  Properties:
    TableName: u1lab03-pedidos
    BillingMode: PAY_PER_REQUEST
    KeySchema: [ { AttributeName: pedidoId, KeyType: HASH } ]
    TimeToLiveSpecification: { AttributeName: ttl, Enabled: true }
```

Escolhe-se a janela pela realidade da duplicata: se *retries* acontecem em minutos ou horas, dias de TTL sobram.

> **Veja rodando:** o [U1-LAB03](../../02-demos/u1-03.md) envia o **mesmo** `pedidoId` duas vezes (`make idem`) e mostra um `PROCESSADO`, um `IGNORADO` e um único item na tabela.

---

⬅️ [Anterior: Fan-out SNS→SQS](9-fan-out.md) · 📑 [Índice](../../index.md) · [Próximo: DLQ e at-least-once ➡️](11-dlq-at-least-once.md)
