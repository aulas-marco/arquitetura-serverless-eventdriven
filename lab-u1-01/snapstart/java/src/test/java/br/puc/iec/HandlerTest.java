package br.puc.iec;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * U1-LAB01 Parte 5 — Testes da função SnapStart.
 *
 * Ao carregar a classe Handler, o bloco `static` pesado (que simula o startup
 * de um framework) roda uma vez — é justamente esse custo de Init que o
 * SnapStart amortiza na nuvem. Aqui o teste garante o contrato do handler.
 */
@DisplayName("U1-LAB01 Parte 5 — Handler SnapStart")
class HandlerTest {

    final Handler handler = new Handler();

    @Test
    @DisplayName("responde ok=true após a Init pesada")
    void responde_ok_apos_init_pesada() {
        Map<String, Object> resposta = handler.handleRequest(Map.of(), null);

        assertThat(resposta)
                .as("o handler deve responder ok=true identificando o runtime")
                .containsEntry("ok", true)
                .containsEntry("runtime", "java21");
    }
}
