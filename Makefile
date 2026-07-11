# Makefile — Laboratórios Arquitetura Serverless e Event-Driven
#
# Interface única de linha de comando. Os testes de unidade (test*) rodam
# localmente, sem AWS. Os alvos de deploy/invoke exigem credenciais AWS.
#
#   make test         → todos os testes de unidade (py + go + java)
#   make deploy       → implanta os 3 stacks
#   make help         → lista todos os alvos

LAB        := lab-u1-01
AWS_REGION ?= us-east-1
N          ?= 5
export AWS_DEFAULT_REGION := $(AWS_REGION)

# Ferramental: JDK 21 (keg-only no brew) e binários do Homebrew no PATH.
JAVA_HOME ?= $(shell /opt/homebrew/bin/brew --prefix openjdk@21 2>/dev/null)/libexec/openjdk.jdk/Contents/Home
export JAVA_HOME
export PATH := /opt/homebrew/bin:/opt/homebrew/opt/openjdk@21/bin:$(PATH)

# venv local para o pytest (caminho absoluto: sobrevive aos `cd` das receitas).
VENV   := $(CURDIR)/.venv
PYTEST := $(VENV)/bin/pytest

# Flags padrão de deploy (não interativo).
SAM_DEPLOY := --region $(AWS_REGION) --resolve-s3 --capabilities CAPABILITY_IAM \
              --no-confirm-changeset --no-fail-on-empty-changeset

.DEFAULT_GOAL := help

.PHONY: help test test-fundamentos test-runtimes test-snapstart \
        build deploy deploy-fundamentos deploy-runtimes deploy-snapstart \
        invoke-alo invoke-ciclo gatilhos medir snapstart outputs clean up down

help:
	@echo "Laboratórios Serverless — alvos disponíveis:"
	@echo ""
	@echo "  Testes de unidade (sem AWS):"
	@echo "    test               Todos os testes (py + go + java)"
	@echo "    test-fundamentos   pytest das Partes 1-3"
	@echo "    test-runtimes      pytest + go test + mvn test (Parte 4)"
	@echo "    test-snapstart     mvn test (Parte 5)"
	@echo ""
	@echo "  Nuvem (exigem credenciais AWS):"
	@echo "    build              sam build das 3 partes"
	@echo "    deploy             Implanta os 3 stacks"
	@echo "    deploy-fundamentos | deploy-runtimes | deploy-snapstart"
	@echo "    invoke-alo         Invoca o alô mundo (Parte 1)"
	@echo "    invoke-ciclo       Invoca 3x o ciclo de vida (Parte 3)"
	@echo "    gatilhos           Dispara os 4 gatilhos (Parte 2)"
	@echo "    medir [N=5]        Comparativo de cold start (Parte 4)"
	@echo "    snapstart          Comparativo com/sem SnapStart (Parte 5)"
	@echo "    outputs            Mostra os outputs dos stacks"
	@echo "    clean              Remove os 3 stacks + artefatos locais"
	@echo ""
	@echo "  LocalStack (opcional, Partes 1-3):"
	@echo "    up | down          Sobe/derruba o LocalStack"

# ==========================================================================
# Testes de unidade — não requerem AWS
# ==========================================================================
$(PYTEST):
	python3 -m venv $(VENV)
	$(VENV)/bin/pip install -q --upgrade pip pytest

test: test-fundamentos test-runtimes test-snapstart
	@echo "✓ Todos os testes de unidade passaram"

test-fundamentos: $(PYTEST)
	@echo "▶ Partes 1-3 — pytest (identificação de origem e handlers)"
	cd $(LAB)/fundamentos && $(PYTEST) -q

test-runtimes: $(PYTEST)
	@echo "▶ Parte 4 — pytest + go test + mvn test"
	cd $(LAB)/runtimes/python && $(PYTEST) -q
	cd $(LAB)/runtimes/go && go test ./...
	cd $(LAB)/runtimes/java && mvn test --no-transfer-progress

test-snapstart:
	@echo "▶ Parte 5 — mvn test (SnapStart, Init pesada ~1,5s)"
	cd $(LAB)/snapstart/java && mvn test --no-transfer-progress

# ==========================================================================
# Nuvem — exigem credenciais AWS (aws configure)
# ==========================================================================
build:
	cd $(LAB)/fundamentos && sam build
	cd $(LAB)/runtimes && sam build
	cd $(LAB)/snapstart && sam build

deploy: deploy-fundamentos deploy-runtimes deploy-snapstart
	@echo "✓ 3 stacks implantados"

deploy-fundamentos:
	cd $(LAB)/fundamentos && sam build && sam deploy --stack-name u1lab01-partes1a3 $(SAM_DEPLOY)

deploy-runtimes:
	cd $(LAB)/runtimes && sam build && sam deploy --stack-name u1lab01-runtimes $(SAM_DEPLOY)

deploy-snapstart:
	cd $(LAB)/snapstart && sam build && sam deploy --stack-name u1lab01-snapstart $(SAM_DEPLOY)

invoke-alo:
	@aws lambda invoke --function-name u1lab01-alo --log-type Tail \
	  --query 'LogResult' --output text /dev/null | base64 --decode | grep -E 'Alô|REPORT'

invoke-ciclo:
	@for i in 1 2 3; do \
	  aws lambda invoke --function-name u1lab01-ciclo-vida --log-type Tail \
	    --query 'LogResult' --output text /dev/null | base64 --decode | grep -E 'HANDLER|invocacoes'; \
	  echo '---'; \
	done

gatilhos:
	cd $(LAB)/scripts && bash disparar-gatilhos.sh

medir:
	cd $(LAB)/runtimes && bash medir.sh $(N)

snapstart:
	cd $(LAB)/scripts && bash comparar-snapstart.sh

outputs:
	@for s in u1lab01-partes1a3 u1lab01-runtimes u1lab01-snapstart; do \
	  echo "== $$s =="; \
	  aws cloudformation describe-stacks --stack-name $$s \
	    --query 'Stacks[0].Outputs[].{Chave:OutputKey,Valor:OutputValue}' \
	    --output table 2>/dev/null || echo "  (stack não implantado)"; \
	done

clean:
	-aws cloudformation delete-stack --stack-name u1lab01-partes1a3
	-aws cloudformation delete-stack --stack-name u1lab01-runtimes
	-aws cloudformation delete-stack --stack-name u1lab01-snapstart
	-cd $(LAB)/runtimes/java && mvn -q clean --no-transfer-progress
	-cd $(LAB)/snapstart/java && mvn -q clean --no-transfer-progress
	rm -rf $(LAB)/fundamentos/.aws-sam $(LAB)/runtimes/.aws-sam $(LAB)/snapstart/.aws-sam
	@echo "Stacks marcados para remoção (assíncrono) e artefatos locais limpos."

# ==========================================================================
# LocalStack — opcional, para as Partes 1-3 sem conta AWS
# ==========================================================================
up:
	docker run -d -p 4566:4566 \
	  -e SERVICES=lambda,sns,sqs,s3,iam,apigateway,events,logs \
	  --name localstack localstack/localstack
	@echo "LocalStack em http://localhost:4566 (use awslocal/samlocal)"

down:
	-docker rm -f localstack
