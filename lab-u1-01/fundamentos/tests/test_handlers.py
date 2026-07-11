"""Partes 1 e 3 — Testes dos handlers alô mundo e ciclo de vida.

Handlers de Lambda são difíceis de testar de forma pura porque dependem do
objeto `context` da AWS. Aqui usamos um `context` falso mínimo — o suficiente
para exercitar a lógica sem subir nada na nuvem.

Rodar só este arquivo:
    python3 -m pytest tests/test_handlers.py -v
"""

from dataclasses import dataclass


@dataclass
class FakeContext:
    """Imita os campos do context da AWS que os handlers usam."""

    function_name: str = "funcao-de-teste"
    memory_limit_in_mb: int = 256
    aws_request_id: str = "req-teste-123"

    def get_remaining_time_in_millis(self) -> int:
        return 30000


# --- Parte 1 — alô mundo -----------------------------------------------------

def test_alo_retorna_metadados_do_context():
    """O handler alô mundo devolve os metadados que leu do context."""
    import alo

    resultado = alo.lambda_handler({}, FakeContext())

    assert resultado["mensagem"] == "Alô, serverless!"
    assert resultado["funcao"] == "funcao-de-teste"
    assert resultado["memoria_mb"] == 256
    assert resultado["request_id"] == "req-teste-123"


# --- Parte 3 — ciclo de vida -------------------------------------------------

def test_ciclo_vida_conta_reuso_de_container_entre_invocacoes():
    """Prova do reúso de container: o contador global sobrevive entre chamadas
    no mesmo 'ambiente' (o módulo importado). Primeira chamada é partida fria
    (contador 1); as seguintes são quentes (2, 3...)."""
    import ciclo_vida

    ctx = FakeContext(function_name="u1lab01-ciclo-vida")

    primeira = ciclo_vida.lambda_handler({}, ctx)
    segunda = ciclo_vida.lambda_handler({}, ctx)
    terceira = ciclo_vida.lambda_handler({}, ctx)

    assert primeira["invocacoes_neste_ambiente"] == 1
    assert segunda["invocacoes_neste_ambiente"] == 2
    assert terceira["invocacoes_neste_ambiente"] == 3


def test_ciclo_vida_preserva_o_mesmo_carregado_em():
    """O `carregado_em` é gravado uma vez na fase Init (fora do handler) e não
    muda entre invocações do mesmo ambiente."""
    import ciclo_vida

    ctx = FakeContext()
    a = ciclo_vida.lambda_handler({}, ctx)
    b = ciclo_vida.lambda_handler({}, ctx)

    assert a["carregado_em"] == b["carregado_em"]
