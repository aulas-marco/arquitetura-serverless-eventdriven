"""Parte 2 — Testes da identificação de origem de evento.

O coração testável deste lab é `identificar_origem`: uma função pura que recebe
o dicionário `event` e deduz de qual fonte da AWS ele veio, pela assinatura do
envelope. Cada teste monta o envelope MÍNIMO de uma fonte e verifica que a
função a reconhece — é assim que um handler multiuso decide o que fazer.

Rodar só este arquivo:
    python3 -m pytest tests/test_gatilhos.py -v
"""

from gatilhos import identificar_origem


def test_api_gateway_http_e_reconhecido_pelo_requestContext_http():
    """API Gateway (HTTP API v2) traz requestContext.http com método e rota."""
    event = {"requestContext": {"http": {"method": "POST", "path": "/disparar"}}}
    origem, detalhe = identificar_origem(event)
    assert origem == "API Gateway (HTTP)"
    assert detalhe == "POST /disparar"


def test_sqs_e_reconhecido_pelo_eventSource_dos_records():
    """SQS entrega uma lista Records; cada registro tem eventSource == aws:sqs."""
    event = {"Records": [{"eventSource": "aws:sqs", "body": "{}"}]}
    origem, detalhe = identificar_origem(event)
    assert origem == "SQS"
    assert detalhe == "lote com 1 mensagem(ns)"


def test_sqs_conta_o_tamanho_do_lote():
    """A SQS entrega em lotes; o detalhe reflete quantas mensagens vieram."""
    event = {"Records": [{"eventSource": "aws:sqs"}, {"eventSource": "aws:sqs"}]}
    _, detalhe = identificar_origem(event)
    assert detalhe == "lote com 2 mensagem(ns)"


def test_s3_e_reconhecido_e_extrai_bucket_e_chave():
    """S3 também usa Records, mas com eventSource aws:s3 e o bloco s3."""
    event = {
        "Records": [
            {
                "eventSource": "aws:s3",
                "s3": {"bucket": {"name": "meu-bucket"}, "object": {"key": "arquivo.txt"}},
            }
        ]
    }
    origem, detalhe = identificar_origem(event)
    assert origem == "S3"
    assert detalhe == "s3://meu-bucket/arquivo.txt"


def test_eventbridge_e_reconhecido_por_source_e_detail_type():
    """EventBridge traz source + detail-type — nada de Records."""
    event = {"source": "aws.events", "detail-type": "Scheduled Event"}
    origem, detalhe = identificar_origem(event)
    assert origem == "EventBridge"
    assert detalhe == "aws.events / Scheduled Event"


def test_sqs_e_s3_sao_diferenciados_apesar_de_ambos_usarem_records():
    """A pegadinha do lab: SQS e S3 chegam ambos em Records. O que os separa
    é o eventSource — não a presença de Records."""
    sqs = {"Records": [{"eventSource": "aws:sqs"}]}
    s3 = {"Records": [{"eventSource": "aws:s3", "s3": {"bucket": {"name": "b"}, "object": {"key": "k"}}}]}
    assert identificar_origem(sqs)[0] == "SQS"
    assert identificar_origem(s3)[0] == "S3"


def test_evento_vazio_cai_em_desconhecida():
    """Sem nenhuma assinatura conhecida, a função não inventa uma origem."""
    origem, _ = identificar_origem({})
    assert origem == "desconhecida"


def test_evento_que_nao_e_dicionario_cai_em_desconhecida():
    """Robustez: um event que não seja dict não pode quebrar a função."""
    origem, detalhe = identificar_origem("string qualquer")
    assert origem == "desconhecida"
    assert "não é um dicionário" in detalhe
