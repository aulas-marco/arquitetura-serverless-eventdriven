"""Configuração do pytest para o lab de DLQ e resiliência.

Adiciona `src/` ao path para importar `comum` diretamente, sem empacotamento.
"""

import pathlib
import sys

SRC = pathlib.Path(__file__).resolve().parent.parent / "src"
sys.path.insert(0, str(SRC))
