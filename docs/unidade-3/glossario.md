# Glossário — Unidade 3

> 📌 Fonte única de termos e siglas desta unidade. Se o código e este glossário divergirem, o código vence. As âncoras (`#termo`) permitem deep-linking a partir dos demos.

---

<a id="kinesis-data-streams"></a>
### Kinesis Data Streams

Serviço gerenciado da AWS para ingestão e processamento de fluxos contínuos de dados em tempo real. Um stream é dividido em [shards](#shard); cada produtor escreve registros usando uma [PartitionKey](#partition-key) que determina o shard de destino. Os registros são retidos por um período configurável (24h por padrão, até 365 dias) e podem ser relidos — ao contrário do SQS, a leitura não remove o registro.

---

<a id="shard"></a>
### Shard

Unidade de capacidade e ordenação dentro de um stream Kinesis. Cada shard suporta até 1 MB/s de entrada e 2 MB/s de saída. Registros dentro do mesmo shard são estritamente ordenados por tempo de chegada. Análogo à **partição** no Kafka: a [PartitionKey](#partition-key) determina em qual shard o registro cai.

---

<a id="partition-key"></a>
### PartitionKey

String fornecida pelo produtor junto com o registro. O Kinesis calcula o hash MD5 da PartitionKey e mapeia para um [shard](#shard). A consequência: a mesma PartitionKey sempre vai para o mesmo shard, garantindo ordenação por chave. Análoga à **chave de mensagem** no Kafka. No U3-LAB01, a PartitionKey é o `clienteId`.

---

<a id="sequence-number"></a>
### sequenceNumber

Identificador único e opaco de um registro dentro de um [shard](#shard). Cresce monotonicamente dentro do shard — garante ordenação, mas não é um inteiro sequencial como o offset do Kafka. O [Event Source Mapping](#event-source-mapping) usa o sequenceNumber como checkpoint: o avanço do ponteiro de leitura ocorre quando o Lambda processa o lote com sucesso.

---

<a id="retention"></a>
### Retenção (RetentionPeriodHours)

Período em que os registros ficam disponíveis no stream para (re)leitura. O padrão é 24 horas; pode ser estendido até 365 dias. Diferente do SQS, onde a mensagem desaparece após o consumo, o Kinesis mantém o registro disponível durante toda a janela de retenção — permitindo reprocessamento e múltiplos consumidores independentes.

---

<a id="event-source-mapping"></a>
### Event Source Mapping (ESM)

Componente gerenciado da AWS que conecta um stream Kinesis a um Lambda. O ESM faz polling contínuo do stream, agrupa registros em lotes, invoca o Lambda e avança o [checkpoint](#sequence-number) quando a invocação termina com sucesso. Em caso de falha, o mesmo lote é re-invocado — base do comportamento [at-least-once](#at-least-once).

---

<a id="parallelization-factor"></a>
### ParallelizationFactor

Configuração do ESM que permite até N invocações simultâneas do Lambda **por shard** (máximo 10). Multiplica o throughput de processamento de um shard sem adicionar novos shards e sem enviar o mesmo registro para dois Lambdas. Não confundir com múltiplos ESMs (que são consumidores independentes e recebem cada um o stream completo).

---

<a id="bisect-batch-on-function-error"></a>
### BisectBatchOnFunctionError

Opção do ESM que, diante de uma falha do Lambda, divide o lote ao meio e retenta cada metade separadamente. O processo se repete recursivamente até isolar o registro problemático num lote de tamanho 1. Evita que um único registro inválido bloqueie indefinidamente o processamento de todos os registros do shard.

---

<a id="at-least-once"></a>
### At-least-once

Garantia de entrega que assegura que cada registro será processado **pelo menos uma vez** — mas possivelmente mais de uma vez em caso de falha e retry. É o comportamento padrão do ESM Kinesis→Lambda. A contramedida obrigatória é a **idempotência** do consumidor: processar o mesmo registro duas vezes não deve causar efeito duplicado.

---

<a id="consumer-group"></a>
### Consumer group (analogia Kafka)

No Kafka, um consumer group é um conjunto de consumidores que compartilham a leitura de um tópico — cada partição vai para exatamente um membro do grupo. Grupos distintos recebem o tópico completo cada um. No Kinesis, cada Lambda com seu próprio ESM é equivalente a um **consumer group distinto**: recebe todos os eventos, independentemente dos outros Lambdas que também leem o mesmo stream.

---

<a id="offset"></a>
### Offset

Posição de um registro dentro de uma partição Kafka, um inteiro que cresce de forma sequencial a partir de 0. O consumer group guarda, por partição, o último offset confirmado (commit), e é desse ponto que um consumidor reiniciado recomeça. No Kinesis, o análogo é o [sequenceNumber](#sequence-number), que é opaco e não é um inteiro sequencial. Usado na trilha [U3-KAFKA](02-demos/u3-kafka.md).

---

<a id="rebalanceamento"></a>
### Rebalanceamento

Redistribuição das partições de um tópico entre os membros de um consumer group, disparada quando um membro entra, sai ou deixa de responder. Durante o rebalanceamento, os membros revogam as partições que tinham e recebem as novas atribuições. O Event Source Mapping do Kinesis faz a atribuição de shards sem expor esse processo, e a trilha [U3-KAFKA](02-demos/u3-kafka.md) o mostra com 1, 2 e 3 consumidores.

---

<a id="llm"></a>
### LLM (Large Language Model)

Modelo de linguagem de grande porte treinado para geração e compreensão de texto. Nesta unidade, o Claude Haiku (`claude-haiku-4-5`) classifica tickets de suporte. O LLM não tem estado entre invocações — cada chamada é independente. A resposta é probabilística: o mesmo prompt pode gerar respostas ligeiramente diferentes em execuções distintas, daí a necessidade de [parsear e validar](#structured-output) a saída.

---

<a id="prompt-engineering"></a>
### Prompt engineering

Técnica de formular instruções para guiar o comportamento do LLM. Para saída estruturada, a instrução deve ser explícita: "Responda APENAS com JSON válido, sem texto adicional, sem markdown". A ausência de ambiguidade reduz (mas não elimina) a chance de o modelo desviar do formato esperado. Ver [U3-LAB03](02-demos/u3-03.md#5-código-anotado).

---

<a id="structured-output"></a>
### Saída estruturada (structured output)

Resposta do LLM em formato programaticamente parseável — neste lab, JSON com campos `prioridade` e `categoria`. Diferente de texto livre, exige validação explícita após o parse: o modelo pode gerar JSON sintaticamente válido mas com valores fora do domínio esperado. `SemClassificacao` é o tratamento para esses casos.

---

<a id="dynamodb-ttl"></a>
### DynamoDB TTL (Time to Live)

Mecanismo do DynamoDB que remove automaticamente itens cujo atributo TTL (Unix timestamp em segundos) esteja no passado. A exclusão é assíncrona — o item pode continuar visível por alguns minutos após o vencimento, mas a leitura posterior retorna sem ele. No U3-LAB03, o TTL de 24h garante que classificações expiradas não sejam retornadas como cache hit para textos que eventualmente mudem de contexto.

---

<a id="cache-hit"></a>
### Cache hit

Situação em que o item procurado está presente no cache (DynamoDB) e a resposta é devolvida sem chamar a API Anthropic. Latência ~5ms, custo de leitura DynamoDB. Registrado nos logs como `origem=cache`.

---

<a id="cache-miss"></a>
### Cache miss

Situação em que o item não está no cache — o texto ainda não foi classificado ou o TTL expirou. O Lambda chama a API Anthropic, recebe a classificação, salva no DynamoDB e roteia. Latência ~500ms–1s, custo por token. Registrado nos logs como `origem=api`.

---

<a id="sem-classificacao"></a>
### SemClassificacao

Exceção Python definida em `suporte.py`, lançada por `parsear_resposta` quando o LLM retorna JSON inválido ou com valores fora do domínio (`prioridade` ≠ alta/baixa, `categoria` ≠ tecnico/comercial). O `lambda_handler` captura a exceção e roteia o ticket para a fila `u3lab03-sem-classificacao` — preservando o registro para inspeção manual em vez de descartá-lo ou bloquear o processamento.

---

⬅️ [Anterior: Exercícios](exercicios.md) · 📑 [Índice](index.md)
