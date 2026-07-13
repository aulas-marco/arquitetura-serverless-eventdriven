"""Handler Lambda: verifica cache DynamoDB, chama Claude Haiku e roteia para SQS."""
import json
import os

import anthropic
import boto3

from suporte import SemClassificacao, calcular_ttl, hash_texto, montar_prompt, parsear_resposta

sqs = boto3.client("sqs")
dynamodb = boto3.resource("dynamodb")
tabela = dynamodb.Table(os.environ["TABELA_CACHE"])
FILA_ALTA = os.environ["FILA_ALTA"]
FILA_BAIXA = os.environ["FILA_BAIXA"]
FILA_SEM = os.environ["FILA_SEM"]

claude = anthropic.Anthropic()  # lê ANTHROPIC_API_KEY do ambiente


def _buscar_cache(chave):
    resp = tabela.get_item(Key={"hash_texto": chave})
    return resp.get("Item")


def _salvar_cache(chave, classificacao):
    tabela.put_item(
        Item={
            "hash_texto": chave,
            **classificacao,
            "ttl": calcular_ttl(24),
        }
    )


def _classificar_via_api(texto):
    resp = claude.messages.create(
        model="claude-haiku-4-5",
        max_tokens=64,
        messages=[{"role": "user", "content": montar_prompt(texto)}],
    )
    return parsear_resposta(resp.content[0].text)


def _rotear(ticket, classificacao):
    if classificacao is None:
        fila = FILA_SEM
    elif classificacao["prioridade"] == "alta":
        fila = FILA_ALTA
    else:
        fila = FILA_BAIXA
    body = dict(ticket)
    if classificacao:
        body["classificacao"] = classificacao
    sqs.send_message(QueueUrl=fila, MessageBody=json.dumps(body, ensure_ascii=False))


def lambda_handler(event, context):
    for record in event["Records"]:
        ticket = json.loads(record["body"])
        texto = ticket.get("texto", "")
        chave = hash_texto(texto)

        cache = _buscar_cache(chave)
        if cache:
            classificacao = {"prioridade": cache["prioridade"], "categoria": cache["categoria"]}
            origem = "cache"
        else:
            try:
                classificacao = _classificar_via_api(texto)
                _salvar_cache(chave, classificacao)
            except SemClassificacao as e:
                print(f"[SEM-CLASSIFICACAO] {e}")
                classificacao = None
            origem = "api"

        _rotear(ticket, classificacao)
        prio = classificacao["prioridade"] if classificacao else "N/A"
        cat = classificacao["categoria"] if classificacao else "N/A"
        print(f"[CLASSIFICADO] {origem} prioridade={prio} categoria={cat} texto={texto[:50]!r}")
