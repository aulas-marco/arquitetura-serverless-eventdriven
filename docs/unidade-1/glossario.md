# Glossário — Unidade 1

> 📌 Fonte única de termos e siglas desta unidade. Se o código e este glossário divergirem, o código vence. As âncoras (`#termo`) permitem deep-linking a partir dos demos.

---

<a id="serverless"></a>
### Serverless

Modelo em que o desenvolvedor entrega código e o provedor cuida de provisionamento, escala e disponibilidade. Não significa "sem servidor" — significa **sem gestão de servidor pelo desenvolvedor**. Você paga pela execução, não por capacidade reservada ociosa.

---

<a id="faas"></a>
### FaaS (Function as a Service)

Categoria de serverless em que a unidade de implantação é uma **função**. O provedor cuida do runtime, do isolamento e da escala. AWS Lambda é a implementação de referência. Ver [Lambda](#lambda).

---

<a id="lambda"></a>
### AWS Lambda

Serviço FaaS da AWS. A função executa em resposta a um [gatilho](#gatilho) e só é cobrada enquanto o [handler](#handler) roda. Escala horizontalmente criando novos [ambientes de execução](#ambiente-de-execucao) sob demanda.

---

<a id="ambiente-de-execucao"></a>
### Ambiente de execução (execution environment)

O microcontainer isolado onde a função roda. Na AWS, uma microVM [Firecracker](#firecracker). É criado na fase [Init](#ciclo-de-vida), reaproveitado entre invocações ([partida quente](#partida-quente)) e eventualmente reciclado (Shutdown).

---

<a id="firecracker"></a>
### Firecracker

Tecnologia de microVM que a AWS usa para isolar cada ambiente de execução do Lambda. Dá o isolamento de uma VM com o tempo de partida próximo ao de um container. É por causa dele que o [cold start](#cold-start) medido na AWS real não se reproduz em ferramentas locais.

---

<a id="ciclo-de-vida"></a>
### Ciclo de vida (Init · Invoke · Shutdown)

As três fases do ambiente de execução:

- **Init** — cria o ambiente, sobe o [runtime](#runtime) e roda o código fora do handler. É a [partida fria](#cold-start).
- **Invoke** — chama o [handler](#handler). É a fase **faturada**.
- **Shutdown** — encerra o ambiente ocioso, de forma não determinística.

Modelo mental: *Init custa latência (uma vez), Invoke custa dinheiro (toda vez), Shutdown é silencioso.*

---

<a id="cold-start"></a>
### Partida fria (cold start)

O tempo da fase [Init](#ciclo-de-vida) antes de o handler rodar. Ocorre em três situações, e só nelas: primeira invocação; ambiente reciclado por inatividade; escala horizontal (mais requisições simultâneas que ambientes quentes). Sua magnitude depende do [runtime](#runtime) — ver [Init Duration](#init-duration).

---

<a id="partida-quente"></a>
### Partida quente (warm start)

Invocação atendida por um ambiente que já existe. Pula a fase Init inteira e vai direto ao handler. É o caso comum de funções com tráfego regular. No lab, o contador `invocacoes_neste_ambiente` cresce (2, 3...) nas partidas quentes.

---

<a id="init-duration"></a>
### Init Duration

Campo da linha `REPORT` no CloudWatch que registra a duração da fase Init. **Só aparece em partida fria.** Magnitudes típicas por runtime (medição do lab, `us-east-1`, 512 MB, arm64): Go ~62 ms · Python ~83 ms · Java ~420 ms.

---

<a id="restore-duration"></a>
### Restore Duration

Campo que substitui o [Init Duration](#init-duration) quando o [SnapStart](#snapstart) está ativo: em vez de rodar a Init, a plataforma restaura um snapshot da JVM. `Billed Restore Duration` é a parcela faturada.

---

<a id="billed-duration"></a>
### Billed Duration

Duração faturada da invocação, arredondada ao milissegundo. Observação do lab: em partida fria com runtimes gerenciados, a AWS **fatura a Init** (o `Billed Duration` da 1ª invocação ≈ Init + Duration) — nuance que contraria a simplificação "Init nunca é faturada".

---

<a id="gb-segundo"></a>
### GB-segundo (GB·s)

Unidade de cobrança de computação: memória (em GB) × duração faturada (em s). Como a **CPU é proporcional à memória**, dobrar a memória pode reduzir a duração pela metade e manter o GB·s — mais rápido pelo mesmo custo. No Lambda, cortar memória nem sempre economiza.

---

<a id="runtime"></a>
### Runtime (ambiente de execução da linguagem)

O interpretador ou máquina virtual que executa o código: interpretador Python, JVM (Java), binário nativo (Go). Determina o peso da [partida fria](#cold-start) — VMs (JVM, CLR) custam mais que interpretadores leves e binários nativos.

---

<a id="snapstart"></a>
### SnapStart

Mitigação de cold start para Java: a AWS roda a Init **uma vez** no publish, tira um snapshot cifrado da JVM já inicializada e o restaura nas partidas frias seguintes ([Restore Duration](#restore-duration)). Só compensa quando a Init é cara. Cuidado: o snapshot congela estado gerado na Init (aleatoriedade, conexões, timestamps) — use runtime hooks para reinicializá-lo.

---

<a id="provisioned-concurrency"></a>
### Provisioned Concurrency

Mantém N ambientes já quentes, prontos. Dentro de N, não há partida fria. **Custa** — paga-se a capacidade mesmo ociosa. É latência trocada por dinheiro.

---

<a id="concorrencia-reservada"></a>
### Concorrência reservada (reserved concurrency)

Garante/limita quantas execuções simultâneas uma função pode ter. **Não custa** e **não elimina** cold start. Não confundir com [Provisioned Concurrency](#provisioned-concurrency). Nota operacional: contas AWS novas têm o teto de concorrência em 10 e exigem concorrência não reservada ≥ 10 — reservar sob esse piso é rejeitado no deploy.

---

<a id="evento"></a>
### Evento vs Comando

**Evento** é um fato passado e imutável (`PedidoCriado`). **Comando** é um pedido de ação (`CrieUmPedido`). Quem publica um evento não sabe quem vai reagir — é a base do desacoplamento em [EDA](#eda).

---

<a id="eda"></a>
### EDA (Event-Driven Architecture)

Arquitetura em que componentes se comunicam por [eventos](#evento) em vez de chamadas síncronas ponto-a-ponto. No Lambda, uma função é o microsserviço mínimo: ativada por evento, sem estado compartilhado.

---

<a id="gatilho"></a>
### Gatilho (trigger)

A fonte que invoca a função. Cada uma entrega o `event` com uma forma distinta: [API Gateway](#api-gateway) (HTTP), [SQS](#sqs) (fila), S3 (objeto), [EventBridge](#eventbridge) (agendado/regra). Reconhecer a assinatura de cada envelope é o que permite um handler multiuso.

---

<a id="handler"></a>
### Handler

A função designada como ponto de entrada — `lambda_handler` (Python), o método de `RequestHandler` (Java), o `handler` passado a `lambda.Start` (Go). Recebe o `event` e o `context`. Só o tempo do handler é faturado.

---

<a id="api-gateway"></a>
### API Gateway

Gatilho HTTP. No payload HTTP API v2, o `event` traz `requestContext.http` com método e rota. É a única fonte síncrona deste lab (retorna resposta ao chamador).

---

<a id="sqs"></a>
### SQS (Simple Queue Service)

Fila. Entrega mensagens em **lotes** (`event['Records']`, cada um com `eventSource == aws:sqs`). Modelo *pull*: o consumidor busca no seu ritmo. Entrega *at-least-once* — uma mensagem pode chegar duas vezes (motivo da [idempotência](#idempotencia), tratada em labs seguintes).

---

<a id="sns"></a>
### SNS (Simple Notification Service)

Barramento pub/sub por **tópico**. Modelo *push*: ao publicar, o SNS empurra uma cópia da mensagem a **cada** assinante. Quem publica não sabe quantos assinantes existem — é o ponto de desacoplamento do [fan-out](#fan-out). Assinantes comuns: filas [SQS](#sqs), funções [Lambda](#lambda), HTTP, e-mail.

---

<a id="fan-out"></a>
### Fan-out (SNS + SQS)

Padrão em que uma publicação vira N entregas independentes: [SNS](#sns) na frente espalha a mensagem; uma [SQS](#sqs) por consumidor amortece o pico e **isola falhas** (se um consumidor trava, sua fila enche sem afetar os outros). Detalhe de implementação: na entrega padrão SNS→SQS, o evento chega em **duplo envelope** — o `body` do registro SQS é o envelope do SNS, e o evento de domínio está no campo `Message` (string JSON), exigindo dois `json.loads`.

---

<a id="dlq"></a>
### DLQ (Dead-Letter Queue)

Fila para onde vão as mensagens que falharam o processamento após esgotar as tentativas (`maxReceiveCount`). Isola o "veneno" — a mensagem que sempre quebra — para inspeção posterior, sem travar a fila principal num loop de reentrega. Tema do U1-LAB04.

---

<a id="dynamodb"></a>
### DynamoDB

Banco NoSQL gerenciado da AWS, chave-valor/documento. No modo *on-demand* (`PAY_PER_REQUEST`) não há capacidade a provisionar — combina com o serverless. No U1-LAB03 é o armazém de [idempotência](#idempotencia): a gravação condicional (ver [conditional write](#conditional-write)) usa a chave de partição para deduplicar, e o [TTL](#ttl) expira os registros.

---

<a id="conditional-write"></a>
### Conditional write

Gravação no [DynamoDB](#dynamodb) que só acontece se uma condição for satisfeita — p. ex. `attribute_not_exists(pedidoId)` ("grave se ainda não existe"). Teste e gravação são **atômicos**: é o que torna a [idempotência](#idempotencia) correta sob concorrência, não só sob repetição. Quando a condição falha, o serviço levanta `ConditionalCheckFailedException`.

---

<a id="ttl"></a>
### TTL (Time to Live)

Atributo com o *epoch* em que o item deve expirar; o [DynamoDB](#dynamodb) o remove automaticamente depois disso. No U1-LAB03 impede que o armazém de deduplicação cresça para sempre — a janela é escolhida pela realidade das duplicatas (minutos/horas de retry → dias de TTL).

---

<a id="eventbridge"></a>
### EventBridge

Barramento de eventos. Como gatilho agendado, entrega o `event` com `source` + `detail-type`. Neste lab dispara a função a cada 5 minutos.

---

<a id="sam"></a>
### SAM (Serverless Application Model)

Extensão do CloudFormation para descrever recursos serverless como código (`template.yaml`). `sam build` compila; `sam deploy` implanta a topologia inteira de forma reproduzível e versionável.

---

<a id="idempotencia"></a>
### Idempotência

Propriedade de processar a mesma mensagem N vezes com o mesmo efeito de processá-la uma vez. Necessária porque filas como a [SQS](#sqs) entregam *at-least-once*. Aprofundada no U1-LAB03 (idempotência com Lambda + DynamoDB).
