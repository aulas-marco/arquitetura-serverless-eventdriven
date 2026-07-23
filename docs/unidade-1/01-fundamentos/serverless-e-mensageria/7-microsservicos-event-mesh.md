# Microsserviços e event mesh

> **Roteiro-fonte:** U1V5 · **Glossário:** [EDA](../../glossario.md#eda) · [SNS](../../glossario.md#sns) · [EventBridge](../../glossario.md#eventbridge)

**Objetivo de aprendizagem:** ao final, você consegue **descrever** por que a integração ponto-a-ponto cresce de forma quadrática, **diferenciar** *broker*, *bus* e *mesh* e **identificar** quando o *mesh* é exagero.

A [coreografia](6-coreografia-vs-orquestracao.md) mostrou eventos coordenando um fluxo. Suba um nível: quando os eventos deixam de ser detalhe de uma função e viram o **tecido conectivo** entre microsserviços inteiros, aparece a pergunta de infraestrutura — por onde esses eventos trafegam?

---

## EDA como cola de microsserviços

Microsserviços dividem um sistema grande em serviços pequenos, cada um dono de uma capacidade de negócio, deployável de forma independente. Dividir cria um novo problema: *como os pedaços conversam*. A resposta ingênua é a chamada síncrona ponto-a-ponto — A chama a API de B, espera, segue. Funciona com poucos serviços; vira armadilha com muitos.

EDA oferece outra cola: em vez de A *pedir* algo a B, A **publica um fato do seu domínio** e segue sem saber quem ouve. A frase-síntese: **cada serviço publica os fatos do seu domínio e consome os fatos dos outros.**

Isso muda a natureza do acoplamento. Na chamada síncrona, A depende de B estar *no ar, respondendo, na versão certa*. Na EDA, A depende apenas de que o evento seja publicado.

---

## O problema N×N do ponto-a-ponto

Quando a integração é feita por conexões diretas, o número de ligações cresce com o quadrado do número de sistemas:

```
      ponto-a-ponto (N×(N−1)/2 ligações)        via barramento (N ligações)
        A───B                                       A   B
        │╳╳╳│                                        \ /
        C───D    5 serviços → 10 ligações         ──[ bus ]──   5 serviços → 5 ligações
        (cada uma com seu formato e erro)             / \
                                                     C   D
```

Sair de 5 para 10 serviços mais que quadruplica os caminhos possíveis. Cada conexão tem seu formato de dados, seu tratamento de erro, seu "quem chama quem" — o *spaghetti* de integração. O ponto-a-ponto também acopla fisicamente: A precisa do endereço, da credencial e da disponibilidade de B.

---

## Broker vs bus vs mesh

Três termos que circulam como sinônimos e não são, em escala crescente de abrangência:

| Termo | O que é | Escopo típico |
|-------|---------|---------------|
| **Event broker** | O *componente* de infraestrutura que recebe eventos e os entrega, com fila/tópico no meio | Um cluster/instância |
| **Event bus** | O *canal lógico* compartilhado por onde os eventos trafegam, servido por um *broker* | Uma aplicação / um ambiente |
| **Event mesh** | A *camada* que interliga vários *brokers*/*bus* entre aplicações, domínios e clouds, roteando eventos de ponta a ponta | Múltiplas aplicações, domínios, clouds |

A progressão mental: o *broker* é a peça; o *bus* é o canal que aquela peça oferece dentro de um espaço; o *mesh* é a rede de *brokers* interconectados. *Mesh* está para *bus* assim como a internet (rede de redes) está para uma rede local.

Em serverless (Python/AWS), o *broker*/*bus* gerenciado típico é o **EventBridge** (barramento por regras) e o par **SNS/SQS** (tópico + filas de assinatura) — que a unidade exercita a partir da [próxima página](8-fila-vs-pubsub.md).

O princípio clássico por trás disso é **"smart endpoints, dumb pipes"**: a inteligência mora nos serviços (as pontas); o transporte é deliberadamente burro — só roteia, não embute lógica de negócio. É o oposto do velho ESB "*smart pipe*", que concentrava lógica e virava gargalo.

---

## Quando o mesh é exagero

Identificar o papel do *mesh* inclui identificar quando ele **não** é necessário. *Event mesh* resolve larga escala: muitos domínios, múltiplos ambientes/clouds, dezenas de produtores e consumidores heterogêneos. Para um sistema pequeno — poucos serviços, um único ambiente — um tópico de notificação com filas de assinatura já entrega *pub/sub* desacoplado sem o custo de uma malha.

A regra: **mesh é resposta a escala e heterogeneidade.** Sem elas, é peso morto. Introduzir *mesh* "porque é moderno" num sistema de cinco serviços adiciona infraestrutura, custo e superfície de falha sem ganho proporcional.

---

⬅️ [Anterior: Coreografia vs orquestração](6-coreografia-vs-orquestracao.md) · 📑 [Índice](../../index.md) · [Próximo: Fila (SQS) vs pub/sub (SNS) ➡️](8-fila-vs-pubsub.md)
