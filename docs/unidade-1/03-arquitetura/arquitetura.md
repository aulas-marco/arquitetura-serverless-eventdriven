# Arquitetura — Unidade 1

Visão de arquitetura dos recursos exercitados no U1-LAB01.

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

---

⬅️ [Demo U1-LAB01](../02-demos/u1-01.md) · 📑 [Índice](../index.md) · [Exercícios ➡️](../exercicios.md)
