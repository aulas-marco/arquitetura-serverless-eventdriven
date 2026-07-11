# Exercícios — Unidade 1

Desafios cirúrgicos sobre os labs da unidade. Cada um: mude algo, observe, explique.

## 1. Cold start vs warm — na prática

**Faça:** invoque `u1lab01-alo` uma vez, espere alguns minutos sem invocar, invoque de novo.
**Observe:** o `Init Duration` reaparece na segunda?
**Explique:** qual das três causas de partida fria você acionou?

## 2. Forçar reciclagem do ambiente

**Faça:** rode `make invoke-ciclo` (contador chega a 3). Depois mude `NONCE` no `template.yaml` da Parte 3 (`v1` → `v2`), `make deploy-fundamentos`, e rode `make invoke-ciclo` de novo.
**Observe:** o contador volta a 1? O `carregado_em` muda?
**Explique:** por que atualizar a configuração recicla o ambiente.

## 3. Diferenciar SQS de S3

**Faça:** monte à mão dois dicionários `event` — um de SQS e um de S3 — e passe ambos por `identificar_origem` (pode ser no pytest).
**Observe:** o que os separa, já que ambos têm `Records`?
**Explique:** por que decidir só por "tem `Records`?" seria um bug.

## 4. Memória × CPU

**Faça:** no `template.yaml` da Parte 4, dobre `MemorySize` de 512 para 1024 e re-implante. Rode `make medir`.
**Observe:** o `Init Duration` muda? E se você medisse `Duration` de uma função com trabalho de CPU?
**Explique:** por que "menos memória" nem sempre é "mais barato" (pense em GB·s).

## 5. SnapStart sem Init pesada

**Faça:** comente o bloco `static` pesado do `Handler.java` da Parte 5, re-implante e rode `make snapstart`.
**Observe:** o `Restore Duration` agora supera o `Init Duration`?
**Explique:** por que o SnapStart só compensa quando a Init é cara.

## 6. Mitigações de cold start para Java

**Cenário:** uma API Java voltada ao usuário tem cold starts de ~2,5 s que irritam clientes.
**Liste** duas abordagens de mitigação e **diferencie** o que cada uma custa (SnapStart · Provisioned Concurrency · runtime nativo).

## 7. Adicionar um terceiro consumidor (U1-LAB02)

**Faça:** no `template.yaml` do U1-LAB02, acrescente uma fila `FilaFiscal`, sua `AWS::SNS::Subscription` e um `ConsumidorFiscal` (handler novo em `src/`). Re-implante e rode `make fanout`.
**Observe:** os três consumidores reagem ao mesmo pedido? O código do **produtor** mudou?
**Explique:** o que exatamente o desacoplamento por tópico te poupou de tocar.

## 8. Quebrar (e consertar) a autorização SNS→SQS

**Faça:** remova o recurso `PoliticaFilas` do template do U1-LAB02, re-implante e publique um pedido.
**Observe:** os consumidores param de reagir — a mensagem "some" sem erro visível. Por quê?
**Explique:** onde a entrega foi negada e por que o SNS não acusa a falha ao produtor.

## 9. Duplo envelope na mão

**Faça:** capture um registro SQS real (`aws sqs receive-message` na `u1lab02-fila-estoque`, antes do consumidor apagá-la, ou monte no pytest) e desembrulhe até o `PedidoCriado` sem usar `extrair_evento`.
**Observe:** quantos `json.loads` foram necessários?
**Explique:** por que a entrega padrão do SNS produz dois níveis — e quando `RawMessageDelivery` os reduziria a um.

## 10. Deduplicar pela chave errada (U1-LAB03)

**Faça:** troque `chave_idempotencia` para usar `context.aws_request_id` (ou o `MessageId` da SQS) em vez do `pedidoId`. Re-implante e rode `make idem`.
**Observe:** a duplicata ainda é ignorada? Por quê?
**Explique:** por que a chave precisa ser a identidade **de negócio**, e não da mensagem.

## 11. Check-then-put e a janela de corrida (U1-LAB03)

**Faça:** substitua o *conditional write* por um `get_item` seguido de `put_item` (sem `ConditionExpression`). Rode `make idem`.
**Observe:** com envios quase simultâneos, o item pode ser processado duas vezes?
**Explique:** onde está a janela de corrida e por que a atomicidade do conditional write a elimina.

## 12. TTL do armazém de deduplicação (U1-LAB03)

**Faça:** no `montar_item`, reduza `ttl_dias` para um valor curto. Consulte o item no DynamoDB antes e depois da expiração.
**Observe:** o registro some sozinho? O que acontece se a mesma mensagem voltar **depois** do TTL expirar?
**Explique:** como dimensionar a janela de TTL em função de quando as duplicatas realmente chegam.

## 13. Sem falha parcial, o lote inteiro volta (U1-LAB04)

**Faça:** remova o `FunctionResponseTypes: [ReportBatchItemFailures]` do template e troque o consumidor para `raise` na primeira falha. Envie um lote com bons + veneno e olhe os logs.
**Observe:** os pedidos bons são reprocessados junto com o veneno a cada tentativa?
**Explique:** por que a falha parcial importa mais numa fila **sem** idempotência.

## 14. Mudar o maxReceiveCount (U1-LAB04)

**Faça:** troque `maxReceiveCount` de 3 para 1 e re-implante. Rode `make dlq`.
**Observe:** em quantas tentativas o veneno chega à DLQ? E com um número alto (ex. 10)?
**Explique:** o trade-off entre dar chances de retry (falhas transitórias) e travar a fila com veneno.

## 15. Reprocessar a partir da DLQ (U1-LAB04)

**Cenário:** o veneno foi um bug de validação já corrigido; as mensagens na DLQ agora são válidas.
**Descreva** como devolvê-las à fila principal (redrive/*DLQ redrive* do console ou `aws sqs` + reenvio) e **explique** por que a DLQ separada (sem consumidor) torna esse reprocessamento seguro.

---

⬅️ [Arquitetura](03-arquitetura/arquitetura.md) · 📑 [Índice](index.md) · [Glossário ➡️](glossario.md)
