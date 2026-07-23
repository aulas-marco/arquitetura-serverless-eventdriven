# Ciclo de vida e cold start

> **Roteiro-fonte:** U1V3 · **Lab:** U1-LAB01, Parte 3 (`fundamentos/src/ciclo_vida.py`) · **Glossário:** [Ciclo de vida](../../glossario.md#ciclo-de-vida) · [Partida fria](../../glossario.md#cold-start)

**Objetivo de aprendizagem:** ao final, você consegue **descrever** as três fases do ambiente de execução, **identificar** o reúso de container e **reconhecer** as três situações em que a partida fria ocorre.

Uma função Lambda não roda "no vácuo": ela vive dentro de um [ambiente de execução](../../glossario.md#ambiente-de-execucao) — uma microVM isolada que a plataforma cria, reaproveita e eventualmente descarta. Entender esse ciclo é o que separa quem mede *cold start* corretamente de quem tira conclusões erradas da primeira invocação.

---

## As três fases

```
   [Init]  ───►  [Invoke]  ───►  ... (congela e espera) ...  ───►  [Shutdown]
   cria o        chama o                                            encerra o
   ambiente      handler                                            ambiente ocioso
```

| Fase | O que faz | Faturamento |
|------|-----------|-------------|
| **Init** | Cria o ambiente ([Firecracker](../../glossario.md#firecracker)), sobe o *runtime*, roda o código fora do *handler* | Custa latência (a partida fria) |
| **Invoke** | Chama o *handler* com `event` e `context` | **Faturado** (início do *handler* até o retorno) |
| **Shutdown** | Encerra o ambiente ocioso | Silencioso, não determinístico |

Modelo mental para guardar: **Init custa latência uma vez, Invoke custa dinheiro toda vez, Shutdown é fora do seu controle.**

---

## Reúso de container

O ambiente **não morre** após responder — congela e espera. Se outra requisição chega enquanto ele existe, a plataforma o reaproveita e pula a Init inteira: é a [partida quente](../../glossario.md#partida-quente).

Tudo que ficou em memória **fora do handler** sobrevive entre invocações no mesmo ambiente. É o que o lab prova, contando invocações num estado de módulo:

```python
# fundamentos/src/ciclo_vida.py
carregado_em = time.time()          # roda 1x por ambiente, na fase Init
invocacoes_neste_ambiente = 0

def lambda_handler(event, context):
    global invocacoes_neste_ambiente
    invocacoes_neste_ambiente += 1  # 1 na partida fria; 2, 3... nas quentes
    ...
```

Daí a boa prática: abrir conexões e criar clientes na fase Init, fora do *handler* — paga-se uma vez por ambiente, não uma vez por invocação. O reverso é um bug clássico: estado de um usuário guardado em variável global vaza para a próxima invocação do mesmo ambiente.

```
partida fria:   [INIT] carregado_em=... → invocacoes=1
partida quente: (pula Init)             → invocacoes=2   (mesmo carregado_em)
partida quente: (pula Init)             → invocacoes=3   (mesmo carregado_em)
```

---

## Quando ocorre a partida fria

Em três situações, e só nelas:

1. **Primeira invocação** — nenhum ambiente existe ainda.
2. **Inatividade** — o ambiente ocioso foi reciclado pela plataforma.
3. **Escala horizontal** — chegam N requisições e há M < N ambientes quentes; cada novo ambiente paga sua própria partida fria.

> Erro comum: *"toda invocação é cold start"*. Não é. Funções com tráfego regular respondem quase sempre quentes. Medir latência só na 1ª chamada distorce a percepção — invoque em sequência para ver a diferença.

---

## Custo: GB-segundo

```
GB·s = (memória MB / 1024) × (duração faturada ms / 1000)
```

A **CPU é proporcional à memória** no Lambda. Dobrar a memória pode cortar a duração pela metade e manter o GB·s igual — mais rápido pelo mesmo custo. Reduzir memória nem sempre economiza.

> **Nuance observada no lab:** a teoria diz que a Init "não é faturada". Na medição real, a 1ª invocação (partida fria) veio com `Billed Duration` ≈ `Init Duration` + `Duration` — ou seja, a Init **foi** faturada. *Runtimes* gerenciados hoje faturam a inicialização em partida fria. Trate "Init não faturada" como simplificação, não regra.

---

⬅️ [Anterior: O modelo FaaS](1-modelo-faas.md) · 📑 [Índice](../../index.md) · [Próximo: Runtimes e SnapStart ➡️](3-runtimes-snapstart.md)
