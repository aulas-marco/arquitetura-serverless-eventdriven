"""Lógica pura do classificador: hash, prompt e parsing — sem dependências AWS ou Anthropic."""
import hashlib
import json
import time


class SemClassificacao(ValueError):
    """Levantada quando o LLM retorna algo que não pode ser interpretado como classificação."""


def hash_texto(texto):
    """SHA-256 hex do texto — chave de cache no DynamoDB."""
    return hashlib.sha256(texto.encode("utf-8")).hexdigest()


def montar_prompt(texto):
    """Prompt estruturado para o Claude Haiku classificar o ticket em JSON."""
    return (
        "Classifique este ticket de suporte. Responda APENAS com JSON válido, "
        "sem texto adicional, sem markdown:\n\n"
        f'"{texto}"\n\n'
        "Formato obrigatório: "
        '{"prioridade": "alta" ou "baixa", "categoria": "tecnico" ou "comercial"}'
    )


def parsear_resposta(texto_llm):
    """Valida e retorna o dict de classificação; lança SemClassificacao em caso de erro."""
    try:
        dados = json.loads(texto_llm.strip())
    except json.JSONDecodeError as e:
        raise SemClassificacao(f"JSON inválido: {e}") from e
    if dados.get("prioridade") not in ("alta", "baixa"):
        raise SemClassificacao(f"prioridade inválida: {dados.get('prioridade')!r}")
    if dados.get("categoria") not in ("tecnico", "comercial"):
        raise SemClassificacao(f"categoria inválida: {dados.get('categoria')!r}")
    return {"prioridade": dados["prioridade"], "categoria": dados["categoria"]}


def calcular_ttl(horas=24):
    """Unix timestamp de expiração para o campo TTL do DynamoDB."""
    return int(time.time()) + horas * 3600
