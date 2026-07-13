"""Configuração do pytest: adiciona src/ ao path para importar suporte.py."""
import pathlib
import sys

SRC = pathlib.Path(__file__).resolve().parent.parent / "src"
sys.path.insert(0, str(SRC))
