# 3 — Eventos e gatilhos

## Evento vs comando

- **Evento** é um fato passado e imutável: `PedidoCriado`.
- **Comando** é um pedido de ação: `CrieUmPedido`.

Quem publica um evento **não sabe quem vai reagir**. Esse é o ponto central do desacoplamento em [EDA](../glossario.md#eda): o produtor anuncia um fato; consumidores interessados reagem no seu ritmo, sem que o produtor os conheça.

## A função como reação a um gatilho

No Lambda, a função é ativada por um [gatilho](../glossario.md#gatilho). A mesma função pode ser ligada a fontes diferentes — e cada fonte entrega o objeto `event` com uma **forma própria**. Reconhecer a assinatura de cada envelope é o que permite um handler multiuso.

| Fonte | Assinatura no `event` | Síncrono? |
|-------|-----------------------|-----------|
| [API Gateway](../glossario.md#api-gateway) (HTTP v2) | `requestContext.http` (método, rota) | Sim (retorna resposta) |
| [SQS](../glossario.md#sqs) | `Records[]`, `eventSource == aws:sqs` | Não |
| S3 | `Records[]`, `eventSource == aws:s3`, bloco `s3` | Não |
| [EventBridge](../glossario.md#eventbridge) | `source` + `detail-type` | Não |

## A pegadinha: SQS e S3 chegam iguais... quase

Tanto SQS quanto S3 entregam uma lista `Records`. O que os separa **não** é a presença de `Records` — é o campo `eventSource` de cada registro (`aws:sqs` vs `aws:s3`). Um handler que decide só por "tem Records?" confunde as duas fontes.

> A função `identificar_origem` da Parte 2 do lab implementa exatamente essa distinção, e o teste `test_sqs_e_s3_sao_diferenciados_apesar_de_ambos_usarem_records` a fixa.

## Por que isso importa em escala

A escala horizontal (fundamento anterior) se conecta aqui: um pico de mensagens numa fila dispara dezenas de execuções simultâneas — e dezenas de partidas frias. Entender a origem do evento e o custo da partida é o que permite raciocinar sobre o comportamento sob carga.

---

⬅️ [Ciclo de vida e cold start](2-ciclo-de-vida-e-cold-start.md) · [Runtimes e SnapStart ➡️](4-runtimes-e-snapstart.md)
