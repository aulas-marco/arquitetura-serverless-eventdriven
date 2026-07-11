# 2 — Ciclo de vida e cold start

## As três fases

Todo ambiente de execução do Lambda passa por três fases:

| Fase | O que faz | Faturamento |
|------|-----------|-------------|
| **Init** | Cria o ambiente ([Firecracker](../glossario.md#firecracker)), sobe o runtime, roda o código fora do handler | Custa latência (a partida fria) |
| **Invoke** | Chama o handler com `event` e `context` | **Faturado** (início do handler até o retorno) |
| **Shutdown** | Encerra o ambiente ocioso | Silencioso, não determinístico |

Modelo mental para guardar: **Init custa latência uma vez, Invoke custa dinheiro toda vez, Shutdown é fora do seu controle.**

## Reúso de container

O ambiente **não morre** após responder — congela e espera. Se outra requisição chega enquanto ele existe, a plataforma o reaproveita: pula a Init inteira. É a [partida quente](../glossario.md#partida-quente).

Tudo que ficou em memória **fora do handler** sobrevive entre invocações no mesmo ambiente. Daí a boa prática: abrir conexões e criar clientes na fase Init, fora do handler — paga-se uma vez por ambiente, não uma vez por invocação. O reverso é um bug clássico: estado de um usuário guardado em variável global vaza para a próxima invocação do mesmo ambiente.

> A Parte 3 do lab prova isso: o contador `invocacoes_neste_ambiente` começa em 1 (partida fria) e cresce (2, 3...) nas quentes, com o mesmo `carregado_em`.

## Quando ocorre a partida fria

Em três situações, e só nelas:

1. **Primeira invocação** — nenhum ambiente existe.
2. **Inatividade** — o ambiente ocioso foi reciclado.
3. **Escala horizontal** — chegam N requisições e há M < N ambientes quentes; cada novo ambiente paga sua partida fria.

Erro comum: *"toda invocação é cold start"*. Não é. Funções com tráfego regular respondem quase sempre quentes. Medir latência só na 1ª chamada distorce a percepção.

## Custo: GB-segundo

```
GB·s = (memória MB / 1024) × (duração faturada ms / 1000)
```

A **CPU é proporcional à memória**. Dobrar a memória pode cortar a duração pela metade e manter o GB·s igual — mais rápido pelo mesmo custo. No Lambda, reduzir memória nem sempre economiza.

## Nuance observada no lab

A teoria diz que a Init "não é faturada". Mas na medição real, a 1ª invocação (cold start) veio com `Billed Duration` ≈ `Init Duration` + `Duration` — ou seja, **a Init foi faturada**. Runtimes gerenciados hoje faturam a inicialização em partida fria. Trate "Init não faturada" como simplificação, não regra.

---

⬅️ [Serverless e FaaS](1-serverless-e-faas.md) · [Eventos e gatilhos ➡️](3-eventos-e-gatilhos.md)
