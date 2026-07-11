// Parte 4 — Teste do runtime Go.
//
// A função é trivial (o lab mede o cold start, não a lógica), mas o teste
// garante o contrato do handler: responde OK identificando o runtime.
//
// Rodar:
//
//	go test ./...
package main

import (
	"context"
	"testing"
)

func TestHandlerRespondeOK(t *testing.T) {
	resp, err := handler(context.Background(), map[string]interface{}{})
	if err != nil {
		t.Fatalf("handler retornou erro inesperado: %v", err)
	}
	if !resp.OK {
		t.Errorf("esperava OK=true, veio %v", resp.OK)
	}
	if resp.Runtime != "go-provided.al2023" {
		t.Errorf("runtime inesperado: %q", resp.Runtime)
	}
}
