package br.puc.iec;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;

import java.util.Map;

/**
 * Parte 4 — Runtime Java 21.
 *
 * Equivalente ao Python e ao Go: recebe qualquer evento, responde de imediato.
 * O handler é trivial de propósito — o que interessa é o Init Duration da
 * partida fria, dominado por subir a JVM, carregar classes e o JIT.
 *
 * Este mesmo handler é reaproveitado na Parte 5 (SnapStart).
 */
public class Handler implements RequestHandler<Map<String, Object>, Map<String, Object>> {

    @Override
    public Map<String, Object> handleRequest(Map<String, Object> event, Context context) {
        return Map.of("runtime", "java21", "ok", true);
    }
}
