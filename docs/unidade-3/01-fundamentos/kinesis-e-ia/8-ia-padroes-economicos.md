# IA aplicada a eventos — padrões econômicos

> **Pré-requisito:** [IA — casos de uso](7-ia-casos-de-uso.md) · **Conceitual:** roteiro U3V6 · **Demo:** U3-LAB03.

Classificar 10 milhões de eventos por dia com um modelo grande, sem cuidado, faz o custo explodir. Os padrões abaixo mantêm o poder semântico do LLM pagando por ele só quando necessário. O laboratório U3-LAB03 implementa o primeiro deles.

## 1. Cache de classificações

Mesma entrada produz a mesma saída — então o resultado é cacheável. Guarda-se a classificação em DynamoDB com TTL; na segunda ocorrência do mesmo texto, nenhuma chamada à API. É o padrão central do U3-LAB03: `hash(texto)` como chave, consulta ao cache **antes** de chamar o modelo.

## 2. Modelos pequenos primeiro

Um modelo pequeno (ex.: Claude Haiku) resolve os casos simples a uma fração do custo; o modelo grande entra só para os ambíguos que o pequeno não classificou com confiança. O lab usa `claude-haiku-4-5` como o modelo de primeira linha.

## 3. Heurísticas pré-LLM

Regras baratas descartam os casos óbvios antes de qualquer chamada. Se um `assunto` contém "fatura" ou "cobrança", já é comercial — não gasta token. O LLM processa só o que sobra duvidoso.

## 4. Prompt com JSON estrito

Forçar a saída como JSON restrito — `{"prioridade": "alta|baixa", "categoria": "tecnico|comercial"}` — torna o *parsing* barato e sem pós-processamento. Resposta fora do formato cai numa fila de exceção (`sem-classificacao`), não corrompe o fluxo.

## 5. A conta

| Cenário (1 milhão de tickets/mês) | Custo aproximado |
|-----------------------------------|------------------|
| Modelo grande, toda chamada | ~US$ 800 |
| Modelo pequeno + cache (elimina ~80% das chamadas) | ~US$ 40 |

Números como ordem de grandeza — envelhecem com preços e modelos. O ponto é a razão entre as estratégias, não o valor absoluto.

## 6. Alternativa on-premises

Quando latência, custo por chamada ou conformidade de dados pesam mais, um modelo local (ex.: Llama via Ollama) troca o custo por chamada por custo de infraestrutura. É o *tradeoff* que fecha o U3-LAB03.

---

⬅️ [Anterior: IA — casos de uso](7-ia-casos-de-uso.md) · 📑 [Índice](../../index.md) · [Próximo: Classificação com cache DynamoDB](9-classificacao-cache-dynamodb.md) ➡️
