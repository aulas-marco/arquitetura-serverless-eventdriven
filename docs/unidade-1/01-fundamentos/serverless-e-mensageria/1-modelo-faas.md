# O modelo FaaS — antes de qualquer serviço

> **Roteiro-fonte:** U1V2 · **Lab:** U1-LAB01, Parte 1 (`fundamentos/src/alo.py`) · **Glossário:** [Serverless](../../glossario.md#serverless) · [FaaS](../../glossario.md#faas)

**Objetivo de aprendizagem:** ao final, você consegue **reconhecer** o que *serverless* significa (e o que não significa), **descrever** o modelo *FaaS* e **diferenciar** a cobrança do Lambda da de um servidor reservado.

Esta série de páginas cobre, uma ideia por vez, os fundamentos que os quatro labs da Unidade 1 exercitam: o modelo FaaS, o ciclo de vida da função, os *runtimes*, os gatilhos, e a mensageria (fan-out, idempotência, DLQ). Antes de abrir qualquer *template.yaml*, vale virar a chave sobre o que muda quando a unidade de implantação deixa de ser um servidor e passa a ser uma função.

---

## A dor que o serverless resolve

Um servidor reservado 24 horas por dia atende tráfego só em parte do tempo. O resto é capacidade paga e ociosa — memória e CPU ligadas sem trabalho. Você paga pela *reserva*, não pelo *uso*.

O serverless inverte isso: você entrega o código, o provedor cuida de provisionamento, escala e disponibilidade, e a cobrança acompanha a execução. Sem chamada, nada roda — e nada é cobrado.

> *Serverless* não quer dizer "sem servidor". Quer dizer **sem gestão de servidor pelo desenvolvedor**. Os servidores existem; você só não os administra.

---

## FaaS: a unidade de implantação é uma função

A forma mais direta de serverless é *FaaS* (*Function as a Service*): você entrega uma função, o provedor cuida do *runtime*, do isolamento e da escala. O [AWS Lambda](../../glossario.md#lambda) é a implementação de referência.

A função só executa quando um [gatilho](../../glossario.md#gatilho) a invoca — HTTP, fila, evento de objeto, agendamento. É o que a Parte 1 do lab implanta: a função mínima que responde e reporta seus próprios metadados.

```python
# fundamentos/src/alo.py
def lambda_handler(event, context):
    print("Alô, serverless! A função executou.")
    return {
        "mensagem": "Alô, serverless!",
        "funcao": context.function_name,
        "memoria_mb": context.memory_limit_in_mb,
        "ms_restantes": context.get_remaining_time_in_millis(),
        "request_id": context.aws_request_id,
    }
```

O `context` carrega a identidade e os limites do ambiente. `get_remaining_time_in_millis()` conta quanto falta até o *timeout* — o Lambda encerra a função à força quando o tempo acaba (teto de 15 min).

---

## O que muda no custo

O faturamento tem duas parcelas: por invocação (preço por milhão de chamadas) e por tempo de computação em [GB-segundo](../../glossario.md#gb-segundo). É diferente de um servidor reservado, que cobra por hora ligada esteja ele ocupado ou não.

| Modelo | Cobrança | Ocioso custa? |
|--------|----------|---------------|
| EC2 reservado | por hora ligada | sim |
| Lambda (*FaaS*) | por invocação + GB·s do *handler* | não |

Consequência: o Lambda ganha onde há **ociosidade** (você não paga parado) e **picos** (escala sem provisionar). Perde em carga **24/7 estável** — aí um servidor reservado costuma sair mais barato.

---

## Quando o Lambda NÃO é a escolha

Reconhecer o modelo inclui reconhecer seus limites:

- Carga constante 24/7 → EC2 *Reserved* tende a custar menos.
- Processamento acima do *timeout* de 15 min.
- Estado interno complexo e duradouro dentro do processo (o Lambda não guarda estado entre invocações — ver [página 2](2-ciclo-de-vida-cold-start.md)).

> **Veja rodando:** a Parte 1 do [U1-LAB01](../../02-demos/u1-01.md) implanta essa função e mostra, na linha `REPORT` do CloudWatch, os campos que materializam o modelo de custo: `Duration`, `Billed Duration` e — só na partida fria — `Init Duration`.

---

⬅️ [Fundamentos da Unidade 1](../../index.md) · 📑 [Índice](../../index.md) · [Próximo: Ciclo de vida e cold start ➡️](2-ciclo-de-vida-cold-start.md)
