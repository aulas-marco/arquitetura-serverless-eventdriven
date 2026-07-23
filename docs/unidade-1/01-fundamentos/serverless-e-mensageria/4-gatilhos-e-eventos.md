# Gatilhos e formatos de evento

> **Roteiro-fonte:** U1V4 · **Lab:** U1-LAB01, Parte 2 (`fundamentos/src/gatilhos.py`) · **Glossário:** [Gatilho](../../glossario.md#gatilho) · [Handler](../../glossario.md#handler)

**Objetivo de aprendizagem:** ao final, você consegue **listar** as quatro fontes de gatilho da unidade, **descrever** a forma do `event` de cada uma e **diferenciar** SQS de S3 apesar de ambos usarem `Records`.

Uma função Lambda reage a um [gatilho](../../glossario.md#gatilho). A mesma função pode ser ligada a fontes diferentes — e cada fonte entrega o objeto `event` com uma **forma própria**. Reconhecer a assinatura de cada envelope é o que permite um *handler* multiuso, que descobre em tempo de execução quem o disparou.

---

## As quatro fontes e suas assinaturas

| Fonte | Assinatura no `event` | Síncrono? |
|-------|-----------------------|-----------|
| [API Gateway](../../glossario.md#api-gateway) (HTTP v2) | `requestContext.http` (método, rota) | Sim (retorna resposta) |
| [SQS](../../glossario.md#sqs) | `Records[]`, `eventSource == aws:sqs` | Não |
| S3 | `Records[]`, `eventSource == aws:s3`, bloco `s3` | Não |
| [EventBridge](../../glossario.md#eventbridge) | `source` + `detail-type` | Não |

No lab, uma única função é ligada às quatro no *template.yaml*:

```yaml
# fundamentos/template.yaml — GatilhosFunction
Events:
  GatilhoHttp:     { Type: HttpApi, Properties: { Path: /disparar, Method: post } }
  GatilhoSqs:      { Type: SQS,     Properties: { Queue: !GetAtt FilaGatilho.Arn, BatchSize: 5 } }
  GatilhoS3:       { Type: S3,      Properties: { Bucket: !Ref BucketGatilho, Events: s3:ObjectCreated:* } }
  GatilhoAgendado: { Type: Schedule, Properties: { Schedule: rate(5 minutes) } }
```

---

## O handler deduz a origem pela forma do event

A decisão de qual fonte disparou não está na configuração — está na forma do `event`, inspecionada em *runtime*:

```python
# fundamentos/src/gatilhos.py
def identificar_origem(event):
    if "requestContext" in event and "http" in event.get("requestContext", {}):
        return "API Gateway (HTTP)", ...
    if _tem_records_de(event, "aws:sqs"):
        return "SQS", ...
    if _tem_records_de(event, "aws:s3"):
        return "S3", ...
    if "detail-type" in event and "source" in event:
        return "EventBridge", ...
    return "desconhecida", ...
```

---

## A pegadinha: SQS e S3 chegam iguais... quase

Tanto SQS quanto S3 entregam uma lista `Records`. O que os separa **não** é a presença de `Records` — é o campo `eventSource` de cada registro (`aws:sqs` vs `aws:s3`). Um *handler* que decide só por "tem `Records`?" confunde as duas fontes.

```
event de SQS:  { "Records": [ { "eventSource": "aws:sqs", "body": "..." } ] }
event de S3:   { "Records": [ { "eventSource": "aws:s3",  "s3": {...} } ] }
                              └── mesma chave, fonte diferente ──┘
```

A função `_tem_records_de(event, "aws:sqs")` faz exatamente essa distinção, e o teste `test_sqs_e_s3_sao_diferenciados_apesar_de_ambos_usarem_records` a fixa.

---

## Por que isso importa em escala

A escala horizontal (fundamento anterior) se conecta aqui: um pico de mensagens numa fila dispara dezenas de execuções simultâneas — e dezenas de partidas frias, cada uma pagando sua Init. Entender a origem do evento e o custo da partida é o que permite raciocinar sobre o comportamento sob carga, e prepara a distinção que vem a seguir: [evento vs comando](5-evento-vs-comando.md).

> **Veja rodando:** a Parte 2 do [U1-LAB01](../../02-demos/u1-01.md) dispara as três fontes síncronas/assíncronas via `make gatilhos` e mostra a linha `[ORIGEM]` nos logs; o EventBridge dispara sozinho a cada 5 minutos.

---

⬅️ [Anterior: Runtimes e SnapStart](3-runtimes-snapstart.md) · 📑 [Índice](../../index.md) · [Próximo: Evento vs comando ➡️](5-evento-vs-comando.md)
