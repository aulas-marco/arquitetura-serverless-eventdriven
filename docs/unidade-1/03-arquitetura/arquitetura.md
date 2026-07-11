# Arquitetura — Unidade 1

Visão de arquitetura dos recursos exercitados nos laboratórios da unidade (U1-LAB01 e U1-LAB02).

## Contexto (C4 nível 1)

```mermaid
C4Context
    title U1-LAB01 — Contexto
    Person(aluno, "Aluno", "Implanta, invoca e mede")
    System_Boundary(aws, "AWS us-east-1") {
        System(lambda, "AWS Lambda", "Funções Python/Java/Go")
        System(gatilhos, "Fontes de gatilho", "API GW · SQS · S3 · EventBridge")
        System(cw, "CloudWatch Logs", "REPORT: Init/Duration/Billed")
    }
    Rel(aluno, lambda, "sam deploy / invoke")
    Rel(gatilhos, lambda, "dispara")
    Rel(lambda, cw, "emite logs")
    Rel(aluno, cw, "lê métricas")
```

## Ciclo de vida (sequência)

```mermaid
sequenceDiagram
    participant E as Evento
    participant P as Plataforma Lambda
    participant A as Ambiente de execução
    participant H as Handler

    E->>P: invocação
    alt ambiente quente existe
        P->>H: Invoke (partida quente)
    else nenhum ambiente
        P->>A: Init — cria microVM + runtime + código fora do handler
        Note over A: PARTIDA FRIA (Init Duration)
        A->>H: Invoke
    end
    Note over H: faturamento (Duration)
    H-->>P: retorno
    Note over A: congela e espera (reúso) → eventual Shutdown
```

## Topologia de gatilhos (Parte 2)

```mermaid
flowchart LR
    AG[API Gateway] & SQS[SQS] & S3[S3] & EB[EventBridge] --> H{{gatilhos.lambda_handler}}
    H --> CW[[CloudWatch: ORIGEM identificada]]
```

## Topologia de fan-out (U1-LAB02)

Um produtor publica; o SNS espalha; cada consumidor tem sua própria fila.

```mermaid
flowchart LR
    P[publicar] -- PedidoCriado --> T((SNS pedidos))
    T --> QE[SQS estoque] --> CE{{consumidor_estoque}}
    T --> QN[SQS notificação] --> CN{{consumidor_notificacao}}
```

Entre produtor e consumidores não há referência direta — o tópico desacopla, as filas isolam falhas.

## Topologia de idempotência (U1-LAB03)

A duplicata da fila é absorvida por uma gravação condicional no DynamoDB.

```mermaid
flowchart LR
    P[publicar] --> Q[SQS fila-pedidos]
    Q -- at-least-once --> K{{consumidor}}
    K -- "put if attribute_not_exists" --> D[(DynamoDB pedidos + TTL)]
    D -- passou --> OK[PROCESSADO]
    D -- falhou --> DUP[IGNORADO]
```

A decisão "processar ou ignorar" é o resultado atômico da gravação, não um `if` no código.

## Topologia de DLQ (U1-LAB04)

Mensagem boa é apagada; veneno é reentregue até o limite e movido à DLQ.

```mermaid
flowchart LR
    P[publicar lote] --> Q[SQS fila-pedidos]
    Q -- lote --> K{{consumidor<br/>ReportBatchItemFailures}}
    K -- sucesso --> DEL[(apagada)]
    K -- batchItemFailures --> Q
    Q -- "recebida > maxReceiveCount" --> DLQ[SQS DLQ]
```

A SQS move o veneno para a DLQ sozinha, pela *redrive policy* — sem código nosso.

## Componentes por parte

| Recurso | P1 alô | P2 gatilhos | P3 ciclo | P4 runtimes | P5 SnapStart |
|---------|:------:|:-----------:|:--------:|:-----------:|:------------:|
| Lambda Python | ✓ | ✓ | ✓ | ✓ | — |
| Lambda Java 21 | — | — | — | ✓ | ✓ |
| Lambda Go | — | — | — | ✓ | — |
| API Gateway (HTTP) | — | ✓ | — | — | — |
| SQS | — | ✓ | — | — | — |
| S3 | — | ✓ | — | — | — |
| EventBridge | — | ✓ | — | — | — |
| Alias + versão (SnapStart) | — | — | — | — | ✓ |

## Decisões de arquitetura registradas

- **3 stacks separados** — cada parte é implantada e removida isoladamente; falha em uma não derruba as outras.
- **Sem `ReservedConcurrentExecutions`** — contas AWS novas têm teto de concorrência 10; reservar sob o piso é rejeitado. O reúso de container é observável sem reservar.
- **arm64 + 512 MB uniformes na Parte 4** — comparação justa entre runtimes; só o runtime varia.
- **Init pesada simulada na Parte 5** — sem custo real de inicialização, o SnapStart não teria o que amortizar e a demonstração falharia.
- **Uma fila SQS por consumidor no fan-out (U1-LAB02)** — não uma fila compartilhada. Filas separadas isolam falha: um consumidor travado empilha na sua própria fila sem afetar os demais.
- **Entrega padrão SNS→SQS (não *raw*) no U1-LAB02** — o duplo envelope é conteúdo pedagógico; desligar o *raw delivery* força o aluno a desembrulhar os dois níveis.
- **DynamoDB on-demand + TTL no U1-LAB03** — `PAY_PER_REQUEST` evita provisionar/limpar capacidade; o TTL expira os registros de deduplicação sem job de limpeza.
- **Idempotência por *conditional write*, não *check-then-put* (U1-LAB03)** — a atomicidade da gravação condicional fecha a janela de corrida que o "ler depois gravar" abriria sob concorrência.
- **DLQ com `maxReceiveCount=3` e `VisibilityTimeout` (10s) > timeout da função (5s) no U1-LAB04** — a visibilidade acima do timeout evita entrega concorrente da mesma mensagem; o limite baixo faz o veneno chegar à DLQ rápido para a demo.
- **`ReportBatchItemFailures` em vez de falhar o lote todo (U1-LAB04)** — devolver só os `itemIdentifier` falhados evita reprocessar as mensagens boas do mesmo lote.

---

⬅️ [Demo U1-LAB01](../02-demos/u1-01.md) · 📑 [Índice](../index.md) · [Exercícios ➡️](../exercicios.md)
