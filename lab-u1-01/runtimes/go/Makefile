# Build do runtime custom Go para o SAM (BuildMethod: makefile).
#
# O SAM chama o alvo `build-<LogicalId>` e define ARTIFACTS_DIR. Para o runtime
# `provided.al2023`, o binário PRECISA se chamar `bootstrap`.
#
# O go.mod fixa go 1.22 (compatibilidade de módulo); o toolchain instalado pode
# ser mais novo. Arquitetura alvo: arm64 (casa com Architectures: arm64 no template).

build-GoFunction:
	GOOS=linux GOARCH=arm64 CGO_ENABLED=0 go build -o bootstrap main.go
	cp bootstrap $(ARTIFACTS_DIR)/
