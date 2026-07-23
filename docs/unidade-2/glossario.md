# Glossário — Unidade 2

> 📌 Fonte única de termos e siglas desta unidade. Se o código e este glossário divergirem, o código vence. As âncoras (`#termo`) permitem deep-linking a partir dos demos.

---

<a id="event-sourcing"></a>
### Event Sourcing

Padrão em que o estado de um agregado é gravado como uma sequência de eventos imutáveis, em vez de uma linha sobrescrita. O estado atual é derivado aplicando os eventos em ordem ([replay](#replay)). Preserva a história inteira — auditoria e reconstrução de qualquer estado passado saem de graça.

---

<a id="append-only"></a>
### Append-only

Propriedade do [event store](#event-store): eventos só são **anexados**, nunca atualizados ou apagados. É o que garante a imutabilidade da história. No DynamoDB, o *conditional write* na sequência impede reescrever uma posição já ocupada.

---

<a id="event-store"></a>
### Event store

O armazém dos eventos. Neste lab, uma tabela [DynamoDB](#dynamodb) com chave composta `(contaId, sequencia)`: a partição agrupa os eventos de um agregado, a ordenação dá a sequência temporal. É [append-only](#append-only).

---

<a id="replay"></a>
### Replay

Reconstruir o estado atual (ou passado) dobrando a sequência de eventos com uma [função pura](#funcao-pura) `aplicar`, do estado inicial em diante. Determinístico: a mesma sequência sempre produz o mesmo estado.

---

<a id="agregado"></a>
### Agregado

A unidade de consistência do domínio — aqui, a `ContaBancaria`. Todos os eventos de um agregado compartilham a mesma partição no event store e são versionados por uma sequência própria. As invariantes (ex.: saldo não-negativo) valem dentro do agregado.

---

<a id="concorrencia-otimista"></a>
### Concorrência otimística

Estratégia que assume que conflitos são raros: não trava o registro; deixa dois comandos tentarem gravar e rejeita o segundo quando colidem. No event store, a chave `(contaId, sequencia)` com `attribute_not_exists` faz a gravação da sequência N falhar se N já existe (`ConditionalCheckFailedException`). O comando perdedor recarrega e repete. Oposto da trava pessimista.

---

<a id="funcao-pura"></a>
### Função pura

Função cujo resultado depende só das entradas, sem efeito colateral (não toca banco, rede, relógio). `aplicar(estado, evento)` é pura — o que a torna trivial de testar sem AWS e determinística no [replay](#replay).

---

<a id="cqrs"></a>
### CQRS (Command Query Responsibility Segregation)

Separar o modelo de **escrita** (comandos que geram eventos) do modelo de **leitura** (consultas sobre uma projeção otimizada). Os dois lados têm modelos e, às vezes, bancos distintos. Tratado no U2-LAB03.

---

<a id="projecao"></a>
### Projeção

Visão de leitura construída a partir do fluxo de eventos — p. ex. uma tabela `saldos` atualizada a cada evento. É descartável e reconstruível (rebuild) reprocessando o event store. Tratada no U2-LAB03.

---

<a id="consistencia-eventual"></a>
### Consistência eventual

Entre gravar o evento (escrita) e a [projeção](#projecao) refletir a mudança (leitura) há um lag. A leitura fica momentaneamente desatualizada, mas converge. É o preço de separar leitura de escrita de forma assíncrona. Tratada no U2-LAB03.

---

<a id="snapshot"></a>
### Snapshot

Estado do agregado materializado numa dada sequência, para evitar [replay](#replay) do histórico inteiro: carrega-se o snapshot mais recente e aplicam-se só os eventos posteriores. Tratado no U2-LAB02.

---

<a id="dynamodb"></a>
### DynamoDB

Banco NoSQL gerenciado da AWS. Nesta unidade é o [event store](#event-store) (modo *on-demand*, sem capacidade a provisionar). A chave composta e o *conditional write* dão, respectivamente, a ordenação da sequência e a [concorrência otimística](#concorrencia-otimista).

---

<a id="dynamodb-streams"></a>
### DynamoDB Streams

Fluxo de mudanças da tabela (INSERT/MODIFY/REMOVE) que dispara um Lambda. Na Unidade 2 é o gatilho da [projeção](#projecao) — cada evento anexado ao store alimenta o modelo de leitura. Entrega *at-least-once* (daí a projeção precisar ser idempotente). Tratado no U2-LAB03.

---

<a id="rebuild"></a>
### Rebuild

Reconstruir a [projeção](#projecao) do zero, reprocessando o [event store](#event-store) inteiro. Prova que a projeção é derivada e descartável: serve para corrigir uma projeção corrompida, mudar seu formato ou criar uma visão nova dos mesmos eventos. Tratado no U2-LAB03.

---

<a id="transacao"></a>
### Transação (TransactWriteItems)

Operação do DynamoDB que grava vários itens de forma atômica — ou todos, ou nenhum —, cada um podendo ter sua própria condição. No U2-LAB03, a transferência grava o `SaqueRealizado` de uma conta e o `DepositoRealizado` da outra numa transação só: impossível o dinheiro sair de uma e não chegar na outra.

---

⬅️ [Anterior: Exercícios](exercicios.md) · 📑 [Índice](index.md)
