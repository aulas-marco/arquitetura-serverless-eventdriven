# 4 — Runtimes e SnapStart

## Por que o runtime domina a partida fria

O peso da [partida fria](../glossario.md#cold-start) é, sobretudo, o tempo de subir o [runtime](../glossario.md#runtime) e carregar dependências. Linguagens interpretadas leves e binários nativos custam pouco; máquinas virtuais custam mais.

Medição real do lab (`us-east-1`, 512 MB, arm64, 5 amostras, mediana):

| Runtime | Init Duration (mediana) | Por quê |
|---------|-------------------------|---------|
| Go (binário nativo) | ~62 ms | Sem VM; binário estático |
| Python 3.12 | ~83 ms | Interpretador leve |
| Java 21 (JVM) | ~420 ms | Subir JVM + classloading + JIT |

Java custa cerca de **5× mais** que Go ou Python neste comparativo.

## Por que a JVM penaliza mais

Três custos somados:

1. **Subir a JVM** — instanciar a máquina virtual tem custo fixo.
2. **Classloading** — uma app Java típica (com Spring) carrega centenas a milhares de classes no arranque.
3. **JIT** — a JVM começa interpretando e só compila para nativo o que executa muitas vezes. Numa função efêmera, o código raramente "esquenta" o suficiente para colher o ganho.

É o paradoxo: o Lambda é o oposto do cenário onde a JVM brilha (processos longos e estáveis).

## SnapStart

O [SnapStart](../glossario.md#snapstart) ataca isso de forma diferente: em vez de acelerar a Init, ele a faz **uma vez** no publish, tira um snapshot cifrado da JVM já inicializada e o restaura nas partidas frias seguintes. `Init Duration` vira [`Restore Duration`](../glossario.md#restore-duration).

**Só compensa quando a Init é cara.** Numa função trivial, restaurar o snapshot custa mais do que o pouco que havia para inicializar — o SnapStart chega a piorar o cold start. O lab demonstra isso deliberadamente: a função Java da Parte 5 tem um bloco Init pesado (~1,5 s, simulando um framework). Resultado real:

| Cenário | Métrica | Valor |
|---------|---------|-------|
| Sem SnapStart | `Init Duration` | ~1990 ms |
| Com SnapStart | `Restore Duration` (wall-clock) | ~916 ms |
| Com SnapStart | `Billed Restore Duration` | ~281 ms |
| Com SnapStart | `Duration` (quente) | ~3 ms |

## Cuidado: estado congelado no snapshot

O snapshot fotografa o estado gerado na Init. Aleatoriedade, conexões abertas e timestamps ficam **congelados e compartilhados** entre ambientes restaurados. Estado único por instância exige runtime hooks (`afterRestore`) para reinicializar.

## Outras saídas (reconhecer, não aprofundar)

- **Runtime nativo** (GraalVM Native Image / Quarkus / Spring Native): compila Java para binário AOT, eliminando classloading e JIT em runtime.
- **Provisioned Concurrency**: mantém ambientes quentes para qualquer runtime — custa capacidade ociosa.

---

⬅️ [Eventos e gatilhos](3-eventos-e-gatilhos.md) · [Mensageria e fan-out ➡️](5-mensageria-e-fanout.md)
