"""Configuração do pytest para as Partes 1-3.

Adiciona a pasta `src/` ao path para que os testes importem os handlers
(`alo`, `gatilhos`, `ciclo_vida`) diretamente, sem empacotamento.
"""

import pathlib
import sys

SRC = pathlib.Path(__file__).resolve().parent.parent / "src"
sys.path.insert(0, str(SRC))
