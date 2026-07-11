package br.puc.iec;

import static org.assertj.core.api.Assertions.assertThat;

import java.util.Map;

import org.junit.jupiter.api.DisplayName;
import org.junit.jupiter.api.Test;

/**
 * U1-LAB01 Parte 4 — Testes do runtime Java.
 *
 * A função é trivial (o lab mede o cold start, não a lógica), mas o teste
 * garante o contrato do handler sem precisar de AWS: recebe um evento e
 * responde identificando o runtime.
 */
@DisplayName("U1-LAB01 Parte 4 — Handler do runtime Java")
class HandlerTest {

    final Handler handler = new Handler();

    @Test
    @DisplayName("responde ok=true identificando o runtime java21")
    void responde_ok_identificando_o_runtime() {
        Map<String, Object> resposta = handler.handleRequest(Map.of(), null);

        assertThat(resposta)
                .as("o handler deve responder ok=true e o nome do runtime")
                .containsEntry("ok", true)
                .containsEntry("runtime", "java21");
    }
}
