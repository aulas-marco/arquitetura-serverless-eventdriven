# DLQ e at-least-once

> **Roteiro-fonte:** U1V6 · **Lab:** U1-LAB04 (`src/comum.py`, `src/consumidor.py`, `template.yaml`) · **Glossário:** [DLQ](../../glossario.md#dlq)

**Objetivo de aprendizagem:** ao final, você consegue **explicar** o que é uma mensagem veneno, **descrever** a *redrive policy* (`maxReceiveCount` → DLQ) e **diferenciar** falhar o lote inteiro de reportar só os itens falhados.

A [idempotência](10-idempotencia.md) tratou a mensagem que chega **duas vezes**. Falta o oposto: a mensagem que, por mais que chegue, **nunca** processa. Um pedido com valor negativo, um JSON corrompido, um campo faltando. Reprocessar não muda nada — é a mensagem *veneno* (*poison message*).

---

## Sem defesa, o veneno vira loop

A SQS reentrega, o consumidor falha, a mensagem volta para a fila, reentrega de novo. A fila trava girando no mesmo erro, e as mensagens boas atrás dela ficam presas.

A saída é dar um **limite de tentativas** e um **destino**. A *redrive policy* da SQS faz as duas coisas:

```yaml
# template.yaml — FilaPedidos
RedrivePolicy:
  deadLetterTargetArn: !GetAtt FilaDLQ.Arn
  maxReceiveCount: 3
```

Depois de a mensagem ser recebida `maxReceiveCount` vezes sem ser apagada (sem ser processada com sucesso), a SQS a move **sozinha** para a [DLQ](../../glossario.md#dlq) — nenhum código nosso faz isso. A DLQ é uma SQS comum; o que a torna DLQ é ser o alvo de uma *redrive policy* e, por convenção, não ter consumidor: seu papel é **reter**, não processar.

```
1ª tentativa → falha → volta (invisível pelo visibility timeout)
2ª tentativa → falha → volta
3ª tentativa → falha → maxReceiveCount esgotado → SQS move para a DLQ
```

---

## Falha parcial de lote

O Lambda recebe da SQS em **lotes** (`event["Records"]`). Por padrão, se o *handler* levanta exceção, o lote **inteiro** é considerado falho e reentregue — inclusive as mensagens que já tinham sido processadas. Numa fila com idempotência isso é tolerável; sem ela, é reprocessamento à toa.

`ReportBatchItemFailures` conserta isso: o *handler* devolve só os identificadores que falharam.

```python
# src/consumidor.py
for registro in event["Records"]:
    try:
        evento = validar_pedido(extrair_evento(registro))
        print(f"[OK] pedido {evento['pedidoId']} processado")
    except Exception:
        falhas.append(registro["messageId"])          # só este volta
return montar_resposta_lote(falhas)   # {"batchItemFailures": [{"itemIdentifier": id}, ...]}
```

Habilitado no *template.yaml* pela *event source mapping*:

```yaml
# template.yaml — consumidor
Events:
  Fila:
    Type: SQS
    Properties:
      Queue: !GetAtt FilaPedidos.Arn
      FunctionResponseTypes: [ ReportBatchItemFailures ]
```

A SQS apaga as bem-sucedidas e reentrega **apenas** as listadas:

```
lote [bom, veneno, bom]
   ├─ bom    → sucesso → apagada
   ├─ veneno → falha   → batchItemFailures → reentregue (até virar DLQ)
   └─ bom    → sucesso → apagada
```

O que é "veneno" é uma decisão pura e testável — `pedidoId` ausente ou `valor <= 0` levanta `PedidoInvalido`.

---

## O timeout de visibilidade amarra tudo

Entre uma tentativa e a próxima, a mensagem fica invisível pelo *visibility timeout* da fila. Duas regras práticas:

- **≥ timeout da função** — senão a mensagem reaparece e é entregue a uma segunda invocação enquanto a primeira ainda roda, gerando processamento concorrente. No lab: função de 5 s, visibilidade de 10 s (a AWS recomenda ~6×).
- Curto demais acelera *retries* mas arrisca a concorrência acima; longo demais atrasa a chegada à DLQ.

---

## Redrive: reprocessar da DLQ depois de corrigir

Corrigido o *bug*, as mensagens na DLQ podem voltar à fila principal. Em AWS real, a API nativa é `aws sqs start-message-move-task --source-arn <ARN da DLQ>`, que infere o destino pela *redrive policy*. Redrive é *replay*, não conserto: se a causa não mudou (`valor <= 0` sempre falha), o veneno volta à DLQ.

> **Veja rodando:** o [U1-LAB04](../../02-demos/u1-04.md) envia um lote (2 bons + 1 veneno) com `make dlq`; os bons são processados uma vez, o veneno é tentado 1→2→3 e cai na DLQ, de onde o script lê o corpo.

---

⬅️ [Anterior: Idempotência](10-idempotencia.md) · 📑 [Índice](../../index.md) · [Próximo: Referência ➡️](referencia.md)
