# 3 — CQRS e projeção

## O replay não escala para leitura

Nos labs anteriores, consultar o saldo custava um replay (ou snapshot + delta). Para uma tela que mostra o saldo de milhares de contas a cada segundo, refazer contas a cada leitura é caro — mesmo com snapshot. Escrita e leitura têm necessidades opostas: a escrita quer o log imutável de eventos; a leitura quer o valor pronto, agora.

## CQRS: dois modelos

[CQRS](../glossario.md#cqrs) (Command Query Responsibility Segregation) separa os dois lados:

- **Comando** (escrita) — recebe comandos, valida invariantes, grava eventos no event store. É a fonte da verdade.
- **Consulta** (leitura) — lê uma [projeção](../glossario.md#projecao): uma tabela com o estado já materializado, otimizada para consulta. **Não faz replay, não conhece eventos.**

A regra de ouro: o lado de leitura nunca toca no event store, e o lado de escrita nunca lê a projeção. Modelos distintos, evoluindo separados.

## A projeção

A projeção transforma o fluxo de eventos numa visão de leitura. A cada evento novo, uma linha da tabela `saldos` é atualizada: `ContaCriada` cria a linha, `DepositoRealizado` soma, `SaqueRealizado` subtrai. Consultar vira um `get_item` em O(1) — sem reprocessar nada.

A projeção é **derivada e descartável**: pode ser apagada e reconstruída a qualquer momento a partir do event store (ver [rebuild](#rebuild)). Ela não é a verdade; é um índice de leitura da verdade.

## O elo assíncrono: DynamoDB Streams

Como a projeção fica sabendo dos eventos novos? Por [DynamoDB Streams](../glossario.md#dynamodb-streams): cada gravação no event store emite um registro de stream que dispara o Lambda de projeção. É o equivalente serverless de um tópico Kafka — o produtor (escrita) não chama o projetor; publica o evento, e o stream entrega.

```
comando → grava evento → [DynamoDB Stream] → Lambda de projeção → tabela saldos
```

## Consistência eventual

Como o elo é assíncrono, há um **lag**: entre gravar o evento e a projeção refletir a mudança passam-se milissegundos a segundos. Uma consulta feita imediatamente após a escrita pode ver o estado **antigo** — ou nem ver a conta ainda. Isso é [consistência eventual](../glossario.md#consistencia-eventual): a leitura não é imediatamente consistente com a escrita, mas **converge**.

Não é bug; é o trade-off do CQRS assíncrono. Aceita-se o lag em troca de leitura barata e escala independente. Onde o negócio não tolera lag, lê-se do lado de escrita (replay) — mas aí se abre mão da separação.

A projeção precisa ser **idempotente**: o stream entrega *at-least-once*, então reaplicar um evento não pode dobrar o saldo. A defesa é guardar a `ultimaSequencia` projetada e ignorar eventos com sequência menor ou igual — o mesmo raciocínio da [idempotência](../../unidade-1/glossario.md#idempotencia) da Unidade 1.

## Rebuild

Como a projeção é derivada, ela pode ser **reconstruída** reprocessando o event store inteiro: varre-se todos os eventos, agrupa por conta, faz replay de cada uma e reescreve a tabela de leitura. Serve para: corrigir uma projeção corrompida, mudar o formato do modelo de leitura, ou criar uma projeção nova (outra visão dos mesmos eventos). É a prova prática de que o event store — e não a projeção — é a fonte da verdade.

## Transferência atômica

Mover saldo entre duas contas é um saque numa e um depósito noutra — dois eventos em dois agregados que precisam ser gravados **juntos ou não gravados**. No DynamoDB, [`TransactWriteItems`](../glossario.md#transacao) grava os dois de forma atômica, cada um com sua própria condição de sequência. Ou os dois entram, ou nenhum — sem meio-caminho onde o dinheiro saiu de uma conta e não chegou na outra.

## No lab

O [U2-LAB03](../02-demos/u2-03.md) implanta quatro Lambdas — comando, projeção (gatilho do stream), consulta e rebuild — sobre o event store com Streams e a tabela `saldos`. O script mostra a projeção convergindo após a escrita (consistência eventual), a consulta lendo só a projeção, a transferência atômica e o rebuild reconstruindo a projeção apagada.

---

⬅️ [Replay e snapshots](2-replay-e-snapshots.md) · 📑 [Índice](../index.md) · [Demo: U2-LAB03 ➡️](../02-demos/u2-03.md)
