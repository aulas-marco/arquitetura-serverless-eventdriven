# Classificação com LLM + cache DynamoDB

> **Pré-requisito:** [IA — padrões econômicos](8-ia-padroes-economicos.md) · **Demo:** U3-LAB03 · **Script:** `classificar-e-rotear.sh`

Esta página amarra os padrões econômicos ao código real do U3-LAB03: uma Lambda que recebe tickets via SQS, classifica com Claude Haiku, cacheia em DynamoDB e roteia por prioridade — chamando o modelo só no *cache miss*.

## 1. O fluxo

```
  SQS FilaTickets ─▶ Lambda classificador
                        │ 1. hash(texto) → consulta cache DynamoDB
                        │ 2. hit?  ─── sim ──▶ usa classificação salva (0 chamadas)
                        │          └─ não ──▶ chama Anthropic (Claude Haiku)
                        │ 3. valida JSON estrito
                        │ 4. salva no cache (TTL 24h)
                        ▼
              roteia para SQS por prioridade
     alta ─▶ u3lab03-alta-prioridade
     baixa ─▶ u3lab03-baixa-prioridade
     inválida ─▶ u3lab03-sem-classificacao
```

## 2. Cache antes da chamada

O `lambda_handler` (`lab-u3-03/src/classificador.py`) consulta o cache **antes** de tocar na API — a ordem que garante a economia:

```python
chave = _hash(texto)
cache = _buscar_cache(chave)          # DynamoDB antes do LLM
if cache:
    return _rotear(cache)             # cache hit → 0 chamadas
resposta = claude.messages.create(model="claude-haiku-4-5", max_tokens=64, ...)
classificacao = parsear_resposta(resposta)   # JSON estrito
_salvar_cache(chave, classificacao)   # com ttl = calcular_ttl(24)
```

## 3. JSON estrito e a fila de exceção

`parsear_resposta` (`src/suporte.py`) exige `prioridade ∈ {alta, baixa}` e `categoria ∈ {tecnico, comercial}`; qualquer desvio levanta `SemClassificacao`, e o ticket vai para `u3lab03-sem-classificacao` — o formato inválido não contamina as filas de prioridade.

## 4. TTL no cache

O item de cache carrega o atributo `ttl` (`calcular_ttl(24)` → agora + 24h); a tabela tem `TimeToLiveSpecification` em `ttl`, então o DynamoDB expira entradas velhas sozinho. Sem TTL, o cache cresceria sem limite.

## 5. A demonstração da economia

`classificar-e-rotear.sh` roda o mesmo conjunto de tickets duas vezes: na primeira, N chamadas à API (cache frio); na segunda, zero (todos *cache hit*). É a prova concreta do padrão de cache da página anterior.

> **Nota LocalStack:** a infraestrutura (SQS, DynamoDB, Lambda) roda em LocalStack com `LOCALSTACK=1`, mas a chamada de classificação é à **Anthropic API real** — exige `ANTHROPIC_API_KEY` no ambiente.

---

⬅️ [Anterior: IA — padrões econômicos](8-ia-padroes-economicos.md) · 📑 [Índice](../../index.md) · [Próximo: Referências](referencia.md) ➡️
