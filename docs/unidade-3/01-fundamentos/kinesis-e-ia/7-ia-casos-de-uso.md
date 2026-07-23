# IA aplicada a eventos — casos de uso

> **Pré-requisito:** [At-least-once e bisect](6-at-least-once-bisect.md) · **Conceitual:** roteiro U3V5.

Eventos carregam sinais — volume, conteúdo, padrões temporais. Um modelo de linguagem transforma esses sinais em decisões automatizadas sobre texto livre, ambíguo e de alto volume — onde regras rígidas quebram. Esta página lista os casos de uso e as três abordagens de classificação.

## 1. Classificação e priorização

O LLM identifica categoria e urgência de tickets, alertas e e-mails. É o caso do laboratório U3-LAB03: um e-mail de suporte entra, o modelo devolve `{prioridade, categoria}` e o evento é roteado. Caso real: a Klarna relatou automatizar dois terços do atendimento com um assistente de IA.

## 2. Análise de logs

O LLM lê fluxos de *logs* e sintetiza padrões em linguagem natural — de "milhares de linhas" para "há um pico de timeouts no serviço X desde as 14h". Exemplos de mercado: AWS DevOps Guru, Datadog Watchdog.

## 3. Otimização e ajuste de recursos

- **Alocação**: dado o histórico de eventos, o modelo aponta shards subutilizados, filas sempre vazias, Lambdas com cold start excessivo.
- **Ajuste dinâmico**: observa sazonalidade e recomenda *pre-warming* — "pico previsto às 18h nas sextas".

## 4. Apoio à definição arquitetural

Como co-piloto: dado um fluxo de eventos, sugere padrões (ES+CQRS vs. saga vs. coreografia) e antecipa *tradeoffs*. Apoio à decisão, não decisão automática.

## 5. Três abordagens para classificar

| Abordagem | Força | Fraqueza |
|-----------|-------|----------|
| Regras (if/else, regex) | rápida, barata, determinística | frágil; quebra com texto ambíguo |
| ML clássico | boa acurácia | exige dataset rotulado e treino |
| LLM | poder semântico imediato, zero-shot | custo por chamada; latência |

A escolha raramente é uma só — a próxima página mostra como combiná-las para conter custo.

---

⬅️ [Anterior: At-least-once e bisect](6-at-least-once-bisect.md) · 📑 [Índice](../../index.md) · [Próximo: IA — padrões econômicos](8-ia-padroes-economicos.md) ➡️
