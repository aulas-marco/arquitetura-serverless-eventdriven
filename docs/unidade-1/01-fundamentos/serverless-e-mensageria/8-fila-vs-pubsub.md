# Fila (SQS) vs pub/sub (SNS)

> **Roteiro-fonte:** U1V6 · **Lab:** U1-LAB02 · **Glossário:** [SQS](../../glossario.md#sqs) · [SNS](../../glossario.md#sns)

**Objetivo de aprendizagem:** ao final, você consegue **diferenciar** o modelo de fila (SQS) do modelo *pub/sub* (SNS), **descrever** as entregas *push* e *pull* e **explicar** por que cada serviço resolve metade do problema.

O [event mesh](7-microsservicos-event-mesh.md) mostrou a camada de roteamento por cima. Desça ao nível dos dois serviços concretos que a AWS oferece para mensageria — SQS e SNS. São complementares, não intercambiáveis, e entender por quê é o que prepara o [fan-out](9-fan-out.md) da próxima página.

---

## Dois modelos, duas entregas

| Serviço | Modelo | Entrega | Uma mensagem é lida por |
|---------|--------|---------|-------------------------|
| [SQS](../../glossario.md#sqs) | fila | *pull* — o consumidor busca no seu ritmo | **um** consumidor |
| [SNS](../../glossario.md#sns) | *pub/sub* (tópico) | *push* — empurra a **cada** assinante | **todos** os assinantes |

```
SQS (fila):                          SNS (pub/sub, tópico):
                                                  ┌──► assinante A
produtor ──► [ m m m ] ──► consumidor  produtor ──┼──► assinante B
             (um lê cada mensagem)                └──► assinante C
                                                  (cada um recebe uma cópia)
```

- **SQS** desacopla no tempo e amortece picos: as mensagens esperam na fila até o consumidor buscá-las. Uma mensagem some quando um consumidor a processa e apaga — não há cópia para outro.
- **SNS** espalha: ao publicar, empurra uma cópia a cada assinante. Mas não guarda nada — se o assinante estiver fora do ar quando o *push* chega, a mensagem se perde (sem uma fila absorvendo).

---

## Por que cada um resolve só metade

Pegue o requisito "quando um pedido é criado, baixe o estoque **e** avise o cliente":

- **Só SQS não faz fan-out.** Uma mensagem numa fila é lida por um consumidor. Para dois consumidores independentes reagirem ao mesmo fato, uma fila só não basta.
- **Só SNS é frágil.** O *push* direto para cada Lambda funciona até um pico derrubar um consumidor — sem fila, a mensagem daquele *push* se perde.

A conclusão que a próxima página desenvolve: combine os dois. **SNS na frente** (espalha), **uma SQS por consumidor** (amortece e isola). Cada serviço faz o que faz bem.

---

## Entrega at-least-once (a conta que fica para depois)

A SQS entrega *at-least-once* — a mesma mensagem pode chegar duas vezes. É contrato do serviço, não falha rara. Publicar um fato e reagir a ele exige, portanto, que a reação seja segura sob repetição. Esse é o tema de [idempotência](10-idempotencia.md), duas páginas à frente.

---

⬅️ [Anterior: Microsserviços e event mesh](7-microsservicos-event-mesh.md) · 📑 [Índice](../../index.md) · [Próximo: Fan-out SNS→SQS ➡️](9-fan-out.md)
