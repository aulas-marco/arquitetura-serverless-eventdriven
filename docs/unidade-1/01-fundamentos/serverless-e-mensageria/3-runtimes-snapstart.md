# Runtimes e SnapStart

> **Roteiro-fonte:** U1V3 · **Lab:** U1-LAB01, Partes 4 e 5 (`runtimes/`, `snapstart/`) · **Glossário:** [Runtime](../../glossario.md#runtime) · [SnapStart](../../glossario.md#snapstart)

**Objetivo de aprendizagem:** ao final, você consegue **diferenciar** o peso de partida fria por *runtime*, **explicar** por que a JVM penaliza mais e **identificar** quando o *SnapStart* compensa.

A [página anterior](2-ciclo-de-vida-cold-start.md) mostrou *quando* a partida fria acontece. Esta mostra *o que* determina o tamanho dela — e é sobretudo o *runtime*. É o único ponto da unidade onde o mesmo código roda em três linguagens: o comparativo **é** o conteúdo.

---

## Por que o runtime domina a partida fria

O peso da partida fria é, em boa parte, o tempo de subir o [runtime](../../glossario.md#runtime) e carregar dependências. Linguagens interpretadas leves e binários nativos custam pouco; máquinas virtuais custam mais.

Medição real do lab (`us-east-1`, 512 MB, arm64, 5 amostras):

| Runtime | Init min | Init mediana | Init p90 | Por quê |
|---------|----------|--------------|----------|---------|
| Go (binário nativo) | 52 ms | 54 ms | 61 ms | Sem VM; binário estático |
| Python 3.12 | 64 ms | 81 ms | 82 ms | Interpretador leve |
| Java 21 (JVM) | 320 ms | 415 ms | 435 ms | Subir JVM + *classloading* + JIT |

Java custa cerca de **5× a 8×** mais que Go ou Python neste comparativo. Os três *handlers* fazem a mesma coisa — só devolvem `{"runtime": ..., "ok": true}`:

```java
// runtimes/java/src/main/java/br/puc/iec/Handler.java
public Map<String, Object> handleRequest(Map<String, Object> event, Context context) {
    return Map.of("runtime", "java21", "ok", true);
}
```

```go
// runtimes/go/main.go — compilado para bootstrap (provided.al2023)
func handler(ctx context.Context, event map[string]interface{}) (Resposta, error) {
    return Resposta{Runtime: "go-provided.al2023", OK: true}, nil
}
```

---

## Por que a JVM penaliza mais

Três custos somados:

1. **Subir a JVM** — instanciar a máquina virtual tem custo fixo.
2. **Classloading** — uma app Java típica (com Spring) carrega centenas a milhares de classes no arranque.
3. **JIT** — a JVM começa interpretando e só compila para nativo o que executa muitas vezes. Numa função efêmera, o código raramente "esquenta" o suficiente para colher o ganho.

É o paradoxo: o Lambda é o oposto do cenário onde a JVM brilha (processos longos e estáveis).

---

## SnapStart

O [SnapStart](../../glossario.md#snapstart) ataca isso por outro ângulo: em vez de acelerar a Init, ele a faz **uma vez** no *publish*, tira um *snapshot* cifrado da JVM já inicializada e o restaura nas partidas frias seguintes. O `Init Duration` vira [`Restore Duration`](../../glossario.md#restore-duration).

Liga-se no *template.yaml*, sobre uma versão publicada:

```yaml
# snapstart/template.yaml
JavaComSnapStart:
  Type: AWS::Serverless::Function
  Properties:
    AutoPublishAlias: live
    SnapStart:
      ApplyOn: PublishedVersions   # invoque o alias :live, não $LATEST
```

**Só compensa quando a Init é cara.** Numa função trivial, restaurar o *snapshot* custa mais do que o pouco que havia para inicializar — o *SnapStart* chega a piorar o *cold start*. O lab demonstra isso de propósito: a função Java da Parte 5 tem um bloco `static` que gasta ~1,5 s de CPU real (iterações de SHA-256), simulando o arranque de um *framework*:

```java
// snapstart/java/.../Handler.java — bloco static roda na Init
static {
    // ~1,5 s de trabalho de CPU (não sleep) — simula init de framework
    while ((System.nanoTime() - inicio) / 1_000_000 < 1500) {
        buf = md.digest(buf);
    }
}
```

Resultado real:

| Cenário | Métrica | Valor |
|---------|---------|-------|
| Sem SnapStart | `Init Duration` | ~1990 ms |
| Com SnapStart | `Restore Duration` (*wall-clock*) | ~916 ms |
| Com SnapStart | `Billed Restore Duration` | ~281 ms |
| Com SnapStart | `Duration` (quente) | ~3 ms |

---

## Cuidado: estado congelado no snapshot

O *snapshot* fotografa o estado gerado na Init. Aleatoriedade, conexões abertas e *timestamps* ficam **congelados e compartilhados** entre ambientes restaurados. Estado único por instância exige *runtime hooks* (`afterRestore`) para reinicializar — do contrário, todos os ambientes restaurados carregam a mesma semente aleatória ou a mesma conexão morta.

---

## Outras saídas (reconhecer, não aprofundar)

- **Runtime nativo** (GraalVM *Native Image* / Quarkus / Spring Native): compila Java para binário AOT, eliminando *classloading* e JIT em *runtime*.
- **Provisioned Concurrency:** mantém ambientes quentes para qualquer *runtime* — custa capacidade ociosa. É latência trocada por dinheiro.

> **Veja rodando:** as Partes 4 e 5 do [U1-LAB01](../../02-demos/u1-01.md) medem os *runtimes* (`make medir`) e comparam Java com e sem *SnapStart* (`make snapstart`). Só rodam em AWS real — o *cold start* depende do [Firecracker](../../glossario.md#firecracker), que o LocalStack não reproduz.

---

⬅️ [Anterior: Ciclo de vida e cold start](2-ciclo-de-vida-cold-start.md) · 📑 [Índice](../../index.md) · [Próximo: Gatilhos e formatos de evento ➡️](4-gatilhos-e-eventos.md)
