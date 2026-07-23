# Projeções e consistência eventual

> **Pré-requisito:** [CQRS — comando e consulta](4-cqrs-comando-consulta.md) · **Demo:** U2-LAB03 · **Script:** `cqrs-projecao.sh`

O lado de consulta do CQRS lê de uma projeção. Mas como essa projeção se mantém atualizada? A resposta envolve um componente assíncrono — o projetor — e uma consequência arquitetural que precisa ser entendida antes de ir para o código: **consistência eventual**.

---

## O problema: quem atualiza a projeção?

O lado de comando grava eventos no event store. O lado de consulta lê de `saldos`. Ninguém faz essa ponte de forma direta — e é exatamente isso o que se quer. A ponte é um consumidor de [DynamoDB Streams](../../glossario.md#dynamodb-streams) que opera de forma assíncrona, sem estar no caminho crítico da requisição de comando.

O DynamoDB Streams é o equivalente serverless de um tópico Kafka: cada gravação no event store emite um registro de stream que dispara o Lambda de projeção. O produtor (escrita) não chama o projetor; grava o evento, e o stream entrega.

## O princípio: fold do stream de eventos

Uma projeção é o resultado de **aplicar uma função acumuladora ao fluxo de eventos relevantes**: parte do estado inicial (vazio), processa evento a evento e materializa o estado atual num modelo de leitura otimizado. É o mesmo *left fold* do Event Sourcing — só que o resultado vai para a tabela `saldos`, não para um objeto de domínio em memória.

O **projetor** opera esse fold de forma incremental: a cada evento novo no stream, atualiza a linha da projeção. A atualização é idempotente por sequência — reaplicar um evento já projetado não muda nada.

## Como funciona no lab (U2-LAB03)

### A lógica pura da projeção — `projetar`

A projeção incremental é uma função pura, testável sem AWS. Ela distingue o evento de criação (que **insere** a linha) dos demais (que **atualizam**) e protege contra reentrega pela `ultimaSequencia`:

```python
# projetar.py — fiel ao que está em lab-u2-03
def projetar(linha_atual, evento):
    contaId = evento["contaId"]
    seq = int(evento["sequencia"])

    if linha_atual is not None and seq <= int(linha_atual["ultimaSequencia"]):
        return linha_atual  # já projetado — não reaplica

    if evento["tipo"] == "ContaCriada":
        estado = ContaBancaria.inicial(contaId).aplicar(evento)
        return {"contaId": contaId, "titular": estado.titular,
                "saldo": estado.saldo, "ultimaSequencia": seq}

    if linha_atual is None:
        estado = ContaBancaria.inicial(contaId)
    else:
        estado = ContaBancaria(contaId, linha_atual["titular"], _dec(linha_atual["saldo"]))

    novo = estado.aplicar(evento)
    return {"contaId": contaId, "titular": novo.titular,
            "saldo": novo.saldo, "ultimaSequencia": seq}
```

`ContaCriada` é o único evento que cria a linha de leitura — a projeção o trata como um *insert*. Depósito e saque pressupõem uma conta já projetada e **atualizam** a linha existente.

### O consumidor do stream — `projecao`

O gatilho do DynamoDB Streams recebe os registros, filtra só os `INSERT` (o event store é append-only) e grava a linha nova só quando ela muda:

```python
# projecao.py — fiel ao que está em lab-u2-03
def lambda_handler(event, context):
    projetados = 0
    for registro in event["Records"]:
        if registro["eventName"] != "INSERT":
            continue  # event store é append-only; só INSERT interessa

        evento = _para_dict(registro["dynamodb"]["NewImage"])
        atual = _linha(evento["contaId"])
        nova = projetar(atual, evento)

        if nova is atual:
            continue  # idempotência: evento já projetado

        saldos.put_item(Item=nova)
        projetados += 1
    return {"projetados": projetados}
```

O `if nova is atual: continue` fecha a idempotência: quando `projetar` devolve a mesma referência (evento já projetado), nada é gravado. É o que torna a reentrega do stream inofensiva.

## Consistência eventual — o contrato com o cliente

Porque o projetor opera de forma assíncrona, há um intervalo entre a gravação do evento e a atualização da projeção. Durante esse intervalo, uma consulta a `GET /contas/{contaId}` retorna o estado anterior — ou o 404 "ainda não projetada" — e isso é o comportamento correto.

| Situação             | Tolerância ao atraso                         |
| -------------------- | -------------------------------------------- |
| Dashboard analítico  | Alta — segundos são aceitáveis               |
| Saldo exibido no app | Média — depende do domínio                   |
| Validação de saque   | Nenhuma — usar o event store, não a projeção |

> **Ponto de atenção:** a projeção desatualizada não é um bug — é o contrato. Onde o negócio não tolera o *lag*, lê-se do lado de escrita (replay) — mas aí se abre mão da separação. O bug seria o *lag* crescer indefinidamente sem convergir.

---

⬅️ [Anterior: CQRS — comando e consulta](4-cqrs-comando-consulta.md) · 📑 [Índice](../../index.md) · [Próximo: ES + CQRS combinados](6-es-cqrs-combinados.md) ➡️
