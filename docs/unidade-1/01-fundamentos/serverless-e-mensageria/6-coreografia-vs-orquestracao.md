# Coreografia vs orquestração

> **Roteiro-fonte:** U1V4 · **Glossário:** [Evento vs Comando](../../glossario.md#evento) · [EDA](../../glossario.md#eda)

**Objetivo de aprendizagem:** ao final, você consegue **diferenciar** coreografia de orquestração, **descrever** onde mora a lógica do fluxo em cada estilo e **identificar** o risco típico de cada um.

Um fato como `PedidoCriado` raramente termina em si mesmo: dispara pagamento, que dispara reserva de estoque, que dispara notificação. Como se coordena essa sequência de passos entre serviços? Há dois estilos — e a escolha decorre diretamente da distinção [evento vs comando](5-evento-vs-comando.md) da página anterior.

---

## Coreografia

Não há coordenador central. Cada serviço **reage ao evento anterior** e, ao terminar, **publica o próprio evento**, que desencadeia o próximo. Ninguém rege o fluxo — ele *emerge* da reação em cadeia.

```
PedidoCriado ──► Pagamento reage ──► PagamentoAprovado ──► Estoque reage ──► EstoqueReservado ──► ...
   (cada serviço só conhece o evento que escuta e o que publica)
```

A metáfora: dançarinos que conhecem só o próprio passo e a deixa — não há partitura central.

---

## Orquestração

Existe um **coordenador central** — um orquestrador, *workflow* ou **saga** — que conhece o fluxo inteiro e **emite comandos** para cada serviço na ordem certa, aguardando a resposta antes de seguir. O fluxo está **explícito** num lugar só.

```
              ┌──► comando: ReserveEstoque ──► Estoque
Orquestrador ─┼──► comando: CobrePagamento ──► Pagamento
              └──► comando: Notifique       ──► Notificação
   (o orquestrador sabe a partitura inteira)
```

A metáfora: a orquestra com maestro, que dá a entrada de cada instrumento.

---

## A comparação

| Critério | Coreografia | Orquestração |
|----------|-------------|--------------|
| Mecanismo | Cada serviço reage a **eventos** | Coordenador emite **comandos** |
| Acoplamento | Mais baixo entre serviços | Serviços acoplados ao orquestrador |
| Onde está a lógica do fluxo | Espalhada — não há um lugar único | Concentrada no orquestrador |
| Evolução | Adicionar consumidor é barato | Mudar o fluxo = mexer no orquestrador |
| Risco | Fluxo vira "espaguete de eventos" | Orquestrador vira ponto único / gargalo |

Note a simetria com a página anterior: **coreografia anda com eventos; orquestração anda com comandos.** As duas distinções centrais se conectam — não por acaso.

---

## Qual escolher

Nenhum é universalmente melhor. Coreografia favorece autonomia e evolução independente, ao custo de visibilidade — quando algo falha no meio, não há um lugar que saiba o estado do fluxo inteiro. Orquestração dá visibilidade e controle explícito, ao custo de concentrar acoplamento e criar um ponto que precisa mudar toda vez que o fluxo muda. Sistemas reais misturam os dois: coreografia entre domínios, orquestração dentro de um fluxo transacional crítico (a *saga* da Unidade 2).

---

⬅️ [Anterior: Evento vs comando](5-evento-vs-comando.md) · 📑 [Índice](../../index.md) · [Próximo: Microsserviços e event mesh ➡️](7-microsservicos-event-mesh.md)
