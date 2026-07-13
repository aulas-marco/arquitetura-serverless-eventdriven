# 3 — IA Generativa e Cache

## Lambda como orquestrador de IA

Um Lambda que chama um modelo de linguagem não é diferente de um Lambda que chama uma API REST: recebe um evento, monta uma requisição, interpreta a resposta, toma uma decisão. A diferença está na **natureza da resposta** — probabilística, em linguagem natural, não determinística.

O padrão é:

```
evento (SQS) → Lambda → prompt → API Anthropic → resposta (texto) → parse → ação
```

O Lambda orquestra; o modelo classifica. A lógica de negócio (o que fazer com a classificação, para onde rotear) permanece no código — não no modelo.

## Anthropic SDK

O SDK oficial Python é o ponto de entrada:

```python
import anthropic

claude = anthropic.Anthropic()  # lê ANTHROPIC_API_KEY do ambiente

resp = claude.messages.create(
    model="claude-haiku-4-5",
    max_tokens=64,
    messages=[{"role": "user", "content": prompt}],
)
texto = resp.content[0].text
```

`claude-haiku-4-5` é o modelo mais rápido e econômico da família Claude 4. Para classificação de tickets — tarefa de compreensão simples — é o choice certo: latência < 1s, custo baixo por chamada.

`max_tokens=64` limita o tamanho da resposta. Uma classificação em JSON cabe em ~20 tokens; o teto previne respostas longas indesejadas e mantém a latência baixa.

## Prompt engineering para saída estruturada

Modelos de linguagem geram texto livre por padrão. Para parseamento programático, o prompt precisa instruir o modelo a responder **apenas com JSON válido**, sem preâmbulo, sem markdown, sem explicação:

```python
def montar_prompt(texto):
    return (
        "Classifique este ticket de suporte. Responda APENAS com JSON válido, "
        "sem texto adicional, sem markdown:\n\n"
        f'"{texto}"\n\n'
        "Formato obrigatório: "
        '{"prioridade": "alta" ou "baixa", "categoria": "tecnico" ou "comercial"}'
    )
```

A instrução é repetida em dois lugares (antes e depois do texto) para reforço. O modelo pode ainda assim desviar — daí a validação obrigatória na etapa seguinte.

## Parsing e validação

A resposta do modelo é texto. Antes de usá-la como dado estruturado, é preciso validar:

```python
def parsear_resposta(texto_llm):
    dados = json.loads(texto_llm.strip())          # pode falhar: JSON inválido
    if dados.get("prioridade") not in ("alta", "baixa"):
        raise SemClassificacao(...)
    if dados.get("categoria") not in ("tecnico", "comercial"):
        raise SemClassificacao(...)
    return dados
```

`SemClassificacao` é o caminho de falha controlado: o registro vai para a fila de casos não classificados em vez de bloquear o processamento ou ser silenciosamente descartado.

## Cache DynamoDB com TTL

Chamar a API a cada ticket tem custo e latência. Para tickets com texto idêntico ou muito similar, a classificação é determinística — faz sentido guardar o resultado.

O [cache DynamoDB](../glossario.md#dynamodb-ttl) usa o SHA-256 do texto como chave primária. SHA-256 é determinístico (mesmo texto → mesmo hash), tem baixa probabilidade de colisão e tamanho fixo (64 hex chars):

```python
def hash_texto(texto):
    return hashlib.sha256(texto.encode("utf-8")).hexdigest()
```

O [TTL](../glossario.md#dynamodb-ttl) é um campo Unix timestamp. O DynamoDB exclui automaticamente o item após a expiração — sem job de limpeza, sem scan de varredura:

```python
def calcular_ttl(horas=24):
    return int(time.time()) + horas * 3600
```

O fluxo completo com cache:

```
hash_texto(texto)
    ├── DynamoDB.get_item → hit  → usa classificação salva (zero custo de API)
    └── miss → chama Anthropic → parsear → DynamoDB.put_item (salva para próxima vez)
```

## Trade-offs

| | Cache hit | Cache miss |
|---|---|---|
| Latência | ~5ms (DynamoDB) | 500ms–1s (Anthropic API) |
| Custo | Leitura DynamoDB (~$0) | Custo por token Haiku |
| Risco | Hash collision (improvável) | Resposta inválida do modelo |
| Validade | TTL configurável | N/A |

O cache é especialmente eficaz quando há textos recorrentes (mesmas dúvidas de suporte) ou quando a mesma mensagem é reenviada por retry.

## No lab

O [U3-LAB03](../02-demos/u3-03.md) mostra o contraste: na primeira rodada, 10 tickets distintos geram 10 chamadas à API (logs mostram `origem=api`). Na segunda rodada com os mesmos textos, zero chamadas são feitas (logs mostram `origem=cache`).

---

⬅️ [Consumidores e at-least-once](2-consumidores-e-at-least-once.md) · 📑 [Índice](../index.md) · [Demo: U3-LAB03](../02-demos/u3-03.md)
