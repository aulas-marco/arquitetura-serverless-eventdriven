# 1 — Serverless e o modelo FaaS

## O problema que serverless resolve

Um servidor reservado 24 horas por dia que atende tráfego só em parte do tempo é capacidade paga e ociosa. Serverless ataca isso: você entrega o código, o provedor cuida de provisionamento, escala e disponibilidade, e a cobrança acompanha a execução.

"Serverless" não quer dizer "sem servidor". Quer dizer **sem gestão de servidor pelo desenvolvedor**. Os servidores existem — você só não os administra.

## FaaS

A forma mais direta de serverless é **FaaS (Function as a Service)**: a unidade de implantação é uma função. Você entrega a função; o provedor cuida do runtime, do isolamento e da escala. [AWS Lambda](../glossario.md#lambda) é a referência.

A função só executa quando chamada por um [gatilho](../glossario.md#gatilho): HTTP, fila, evento de objeto, agendamento. Sem chamada, nada roda — e nada é cobrado.

## O que muda no custo

O faturamento tem duas parcelas: por invocação (preço por milhão) e por tempo de computação em [GB-segundo](../glossario.md#gb-segundo). Isso é radicalmente diferente de um servidor reservado.

| Modelo | Cobrança | Ocioso custa? |
|--------|----------|---------------|
| EC2 reservado | por hora ligada | sim |
| Lambda (FaaS) | por invocação + GB·s do handler | não |

Consequência: Lambda ganha onde há **ociosidade** (você não paga parado) e **picos** (escala sem provisionar). Perde em carga **24/7 estável** — aí um servidor reservado costuma sair mais barato.

## Quando Lambda NÃO é a escolha

- Carga constante 24/7 → EC2 Reserved tende a ser mais barato.
- Processamento acima do timeout de 15 min.
- Estado interno complexo e duradouro dentro do processo.

## No lab

A Parte 1 do [U1-LAB01](../02-demos/u1-01.md) implanta a função mínima e mostra, na linha `REPORT` do CloudWatch, os campos que materializam esse modelo de custo: `Duration`, `Billed Duration` e — só na partida fria — `Init Duration`.

---

📑 [Índice](../index.md) · [Ciclo de vida e cold start ➡️](2-ciclo-de-vida-e-cold-start.md)
