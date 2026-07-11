"""Configuração do pytest para o lab de event store.

Adiciona `src/` ao path para importar `dominio` e `comandos` diretamente. Os
testes cobrem só a lógica pura — não importam `app` (que depende de boto3/AWS).
"""

import pathlib
import sys

SRC = pathlib.Path(__file__).resolve().parent.parent / "src"
sys.path.insert(0, str(SRC))
