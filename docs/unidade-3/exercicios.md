# Exercícios — Unidade 3

Desafios cirúrgicos sobre os labs da unidade. Cada um: mude algo, observe, explique.

## U3-LAB01 — Produtor Kinesis

### 1. PartitionKey aleatória

**Faça:** em `suporte.py`, troque `PartitionKey=clienteId` por `PartitionKey=str(uuid.uuid4())`.
**Observe:** execute `make produtor`. O mesmo clienteId vai para shards diferentes em execuções distintas?
**Explique:** por que uma chave aleatória destrói a ordenação por cliente e quando isso pode ser intencional (distribuição uniforme sem garantia de ordem).

### 2. Hot shard artificial

**Faça:** publique 20 eventos todos com `clienteId="cli-unico"`. Consulte o CloudWatch para ver quantos shards foram usados.
**Observe:** um único shard recebeu todos os eventos? Qual é o throughput máximo desse shard?
**Explique:** o que é um hot shard, como ele limita o throughput e como o shard splitting resolve (mas não elimina) o problema se a PartitionKey permanece concentrada.

### 3. Oito shards

**Faça:** no `template.yaml`, mude `ShardCount: 4` para `ShardCount: 8`. Faça o redeploy e repita o `make produtor`.
**Observe:** os clientes que antes estavam no `shardId-000000000001` continuam no mesmo shard? O comportamento muda?
**Explique:** por que o shard de destino muda ao redimensionar o stream e o que isso implica para consumers que guardam checkpoint por shardId.

### 4. Verificar sequência de um cliente

**Faça:** publique 5 eventos de `cli-001`. Consulte o stream com `aws kinesis get-shard-iterator` + `aws kinesis get-records` e liste os sequenceNumbers dos registros de `cli-001`.
**Observe:** os sequenceNumbers crescem monotonicamente? São inteiros consecutivos?
**Explique:** o que o sequenceNumber garante (ordenação dentro do shard) e o que não garante (não é um offset contínuo como no Kafka).

---

## U3-LAB02 — Consumidores Kinesis

### 5. Falha no ConsumidorB

**Faça:** configure `FALHAR_EM=cli-001` no **ConsumidorB** (via `aws lambda update-function-configuration`). Publique 3 eventos de `cli-001` e 2 de `cli-002`.
**Observe:** o ConsumidorA continua processando normalmente? O ConsumidorB bloqueia? Os eventos de `cli-002` no ConsumidorB chegam a ser processados?
**Explique:** por que a falha de um consumidor não afeta o outro e por que, dentro do ConsumidorB, o shard com `cli-001` pode bloquear eventos de outros shards.

### 6. Sem BisectBatchOnFunctionError

**Faça:** no `template.yaml` do ConsumidorA, remova `BisectBatchOnFunctionError: true`. Faça o redeploy, configure `FALHAR_EM=cli-002` e publique um lote com vários clientes.
**Observe:** o que acontece nos logs? O lote inteiro é retentado sem bisect? Por quanto tempo?
**Explique:** o que o `BisectBatchOnFunctionError` evita e em que situação desativá-lo pode ser uma escolha deliberada (ex.: quando se quer bloquear o processamento até resolver a causa raiz).

### 7. Terceiro consumidor

**Faça:** adicione um `ConsumidorCFunction` no `template.yaml` com o mesmo código do ConsumidorA, mas com `CONSUMIDOR: consumidor-c` e sem `ParallelizationFactor`.
**Observe:** o ConsumidorC recebe os mesmos eventos que A e B? Há alguma interferência?
**Explique:** por que adicionar um consumidor não reduz o throughput dos existentes e qual é o limite prático de consumidores num stream Kinesis (dica: número de shards e Enhanced Fan-Out).

### 8. Idempotência no consumidor

**Faça:** simule um retry manual — invoque o Lambda com o mesmo payload de evento (mesmo `eventID`, mesmo `data`) duas vezes seguidas usando `aws lambda invoke`.
**Observe:** a mensagem é logada duas vezes? O que mudaria se o consumidor, em vez de logar, escrevesse num banco de dados?
**Explique:** por que at-least-once exige que o consumidor seja idempotente e como o `eventID` pode ser usado como chave de deduplicação.

---

## U3-LAB03 — Classificador IA

### 9. max_tokens muito baixo

**Faça:** em `classificador.py`, mude `max_tokens=64` para `max_tokens=4` e faça o redeploy. Envie um ticket via SQS.
**Observe:** o que o modelo retorna? O `parsear_resposta` lança `SemClassificacao`? O ticket vai para a fila `sem-classificacao`?
**Explique:** o papel do `max_tokens` no controle da resposta e por que um valor muito baixo causa truncamento do JSON antes do fechamento da chave.

### 10. Mesmo ticket três vezes

**Faça:** envie o mesmo texto de ticket para `u3lab03-tickets` três vezes seguidas (via `aws sqs send-message` em loop).
**Observe:** quantas chamadas à API Anthropic aparecem nos logs? Quantas chegam à fila de destino?
**Explique:** como o cache TTL funciona (a primeira chamada grava, as seguintes leem), e o que mudaria se o TTL fosse de 10 segundos.

### 11. TTL de 1 hora

**Faça:** em `suporte.py`, mude `calcular_ttl(24)` para `calcular_ttl(1)`. Faça o redeploy e envie 5 tickets.
**Observe:** após 1 hora, o item ainda está no DynamoDB? (Use `aws dynamodb get-item` com o hash do texto.) O próximo envio do mesmo ticket chama a API?
**Explique:** como o DynamoDB TTL funciona internamente (exclusão assíncrona, não instantânea) e o impacto de um TTL curto no custo versus frescor da classificação.

### 12. Nova categoria: jurídico

**Faça:** em `suporte.py`, acrescente `"juridico"` como valor válido em `parsear_resposta`. Atualize o `montar_prompt` para incluir a nova opção. Adicione uma fila `u3lab03-juridico` no `template.yaml` e uma nova política de roteamento no `classificador.py`.
**Observe:** os tickets com conteúdo jurídico (ex.: "contrato de licença vencido") são roteados para a nova fila?
**Explique:** por que o modelo pode não reconhecer a nova categoria sem exemplos no prompt (few-shot) e o que mudaria se você incluísse exemplos para cada categoria.

---

📑 [Índice](index.md) · [Glossário ➡️](glossario.md)
