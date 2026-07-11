package br.puc.iec;

import com.amazonaws.services.lambda.runtime.Context;
import com.amazonaws.services.lambda.runtime.RequestHandler;

import java.security.MessageDigest;
import java.util.Map;

/**
 * Parte 5 — SnapStart.
 *
 * O SnapStart não muda o código do handler: ele muda COMO o ambiente parte.
 *
 * IMPORTANTE — por que existe o bloco `static` pesado abaixo:
 * uma função trivial quase não tem fase Init para amortizar, e aí o SnapStart
 * não compensa (o custo de restaurar o snapshot supera o pouco que havia para
 * inicializar). O SnapStart brilha quando a Init é CARA — Spring Boot
 * carregando centenas de classes, init de 2-3 s. O bloco static simula esse
 * custo com trabalho real cronometrado (~1,5 s), para que o lab demonstre o
 * ganho de fato:
 *   - SEM SnapStart: toda partida fria paga a Init inteira (segundos).
 *   - COM SnapStart: a Init roda UMA vez no publish (vira snapshot); as
 *     partidas frias seguintes apenas RESTAURAM o snapshot (bem mais rápido).
 *
 * Cuidado a reconhecer: o snapshot fotografa o estado gerado na Init
 * (aleatoriedade, conexões, timestamps). Ele fica congelado e compartilhado
 * entre ambientes restaurados — estado único por instância exige runtime hooks.
 */
public class Handler implements RequestHandler<Map<String, Object>, Map<String, Object>> {

    // -----------------------------------------------------------------------
    // BLOCO INIT PESADO — simula o startup de um framework (roda na fase Init).
    // -----------------------------------------------------------------------
    static {
        final long alvoMs = 1500; // ~1,5 s de trabalho real, representando o boot
        final long inicio = System.nanoTime();
        long iteracoes = 0;
        try {
            MessageDigest md = MessageDigest.getInstance("SHA-256");
            byte[] buf = "framework-init".getBytes();
            while ((System.nanoTime() - inicio) / 1_000_000 < alvoMs) {
                buf = md.digest(buf); // trabalho de CPU real, não sleep
                iteracoes++;
            }
        } catch (Exception e) {
            throw new RuntimeException(e);
        }
        long gastoMs = (System.nanoTime() - inicio) / 1_000_000;
        System.out.println("[INIT] Startup simulado de framework: "
                + iteracoes + " iterações em ~" + gastoMs + " ms");
    }

    @Override
    public Map<String, Object> handleRequest(Map<String, Object> event, Context context) {
        return Map.of("runtime", "java21", "snapstart", "ver alias", "ok", true);
    }
}
