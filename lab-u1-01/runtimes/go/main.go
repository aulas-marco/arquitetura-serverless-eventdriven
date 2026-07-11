// Parte 4 — Runtime Go (provided.al2023).
//
// Binário nativo, sem máquina virtual: é o piso do comparativo de cold start.
// O handler é equivalente ao Python e ao Java — trivial de propósito.
package main

import (
	"context"

	"github.com/aws/aws-lambda-go/lambda"
)

type Resposta struct {
	Runtime string `json:"runtime"`
	OK      bool   `json:"ok"`
}

func handler(ctx context.Context, event map[string]interface{}) (Resposta, error) {
	return Resposta{Runtime: "go-provided.al2023", OK: true}, nil
}

func main() {
	lambda.Start(handler)
}
