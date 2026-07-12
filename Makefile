# Makefile — Laboratórios Arquitetura Serverless e Event-Driven
#
# Interface única de linha de comando. Os testes de unidade (test*) rodam
# localmente, sem AWS. Os alvos de deploy/invoke exigem credenciais AWS.
#
#   make test         → todos os testes de unidade (py + go + java)
#   make deploy       → implanta os 3 stacks
#   make help         → lista todos os alvos

LAB        := lab-u1-01
LAB02      := lab-u1-02
LAB03      := lab-u1-03
LAB04      := lab-u1-04
LABU201    := lab-u2-01
LABU202    := lab-u2-02
LABU203    := lab-u2-03
LABU301    := lab-u3-01
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

.PHONY: help test test-fundamentos test-runtimes test-snapstart test-fanout \
        test-idempotencia test-dlq test-eventstore test-snapshots test-cqrs \
        test-produtor \
        build deploy deploy-fundamentos deploy-runtimes deploy-snapstart \
        deploy-fanout fanout deploy-idem idem deploy-dlq dlq \
        deploy-eventstore eventstore deploy-snapshots snapshots \
        deploy-cqrs cqrs deploy-produtor produtor \
        invoke-alo invoke-ciclo gatilhos medir snapstart outputs clean up down

help:
	@echo "Laboratórios Serverless — alvos disponíveis:"
	@echo ""
	@echo "  Testes de unidade (sem AWS):"
	@echo "    test               Todos os testes (lab-01 + lab-02)"
	@echo "    test-fundamentos   pytest das Partes 1-3 (U1-LAB01)"
	@echo "    test-runtimes      pytest + go test + mvn test (U1-LAB01 P4)"
	@echo "    test-snapstart     mvn test (U1-LAB01 P5)"
	@echo "    test-fanout        pytest do fan-out SNS+SQS (U1-LAB02)"
	@echo "    test-idempotencia  pytest da idempotência DynamoDB (U1-LAB03)"
	@echo "    test-dlq           pytest da resiliência e DLQ (U1-LAB04)"
	@echo "    test-eventstore    pytest do event store (U2-LAB01)"
	@echo "    test-snapshots     pytest de replay e snapshots (U2-LAB02)"
	@echo "    test-cqrs          pytest da projeção CQRS (U2-LAB03)"
	@echo "    test-produtor      pytest do produtor Kinesis (U3-LAB01)"
	@echo ""
	@echo "  Nuvem (exigem credenciais AWS):"
	@echo "    build              sam build das partes do U1-LAB01"
	@echo "    deploy             Implanta os 3 stacks do U1-LAB01"
	@echo "    deploy-fundamentos | deploy-runtimes | deploy-snapstart"
	@echo "    invoke-alo         Invoca o alô mundo (U1-LAB01 P1)"
	@echo "    invoke-ciclo       Invoca 3x o ciclo de vida (U1-LAB01 P3)"
	@echo "    gatilhos           Dispara os 4 gatilhos (U1-LAB01 P2)"
	@echo "    medir [N=5]        Comparativo de cold start (U1-LAB01 P4)"
	@echo "    snapstart          Comparativo com/sem SnapStart (U1-LAB01 P5)"
	@echo "    deploy-fanout      Implanta o fan-out SNS+SQS (U1-LAB02)"
	@echo "    fanout             Publica 1 pedido e observa os 2 consumidores"
	@echo "    deploy-idem        Implanta a idempotência SQS+DynamoDB (U1-LAB03)"
	@echo "    idem               Envia o mesmo pedido 2x e prova a idempotência"
	@echo "    deploy-dlq         Implanta a DLQ e resiliência (U1-LAB04)"
	@echo "    dlq                Envia lote com veneno e observa a DLQ"
	@echo "    deploy-eventstore  Implanta o event store DynamoDB (U2-LAB01)"
	@echo "    eventstore         Cria conta, deposita, saca e faz replay"
	@echo "    deploy-snapshots   Implanta o replay com snapshots (U2-LAB02)"
	@echo "    snapshots          Acumula eventos, tira snapshot e reprocessa só o delta"
	@echo "    deploy-cqrs        Implanta o CQRS + projeção via Streams (U2-LAB03)"
	@echo "    cqrs               Escreve, projeta, transfere e faz rebuild"
	@echo "    deploy-produtor    Implanta o produtor Kinesis (U3-LAB01)"
	@echo "    produtor           Publica eventos e mostra o roteamento por shard"
	@echo "    outputs            Mostra os outputs dos stacks"
	@echo "    clean              Remove todos os stacks + artefatos locais"
	@echo ""
	@echo "  LocalStack (opcional, Partes 1-3):"
	@echo "    up | down          Sobe/derruba o LocalStack"

# ==========================================================================
# Testes de unidade — não requerem AWS
# ==========================================================================
$(PYTEST):
	python3 -m venv $(VENV)
	$(VENV)/bin/pip install -q --upgrade pip pytest

test: test-fundamentos test-runtimes test-snapstart test-fanout test-idempotencia test-dlq \
      test-eventstore test-snapshots test-cqrs test-produtor
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

test-fanout: $(PYTEST)
	@echo "▶ U1-LAB02 — pytest (duplo envelope SNS→SQS e montagem de evento)"
	cd $(LAB02) && $(PYTEST) -q

test-idempotencia: $(PYTEST)
	@echo "▶ U1-LAB03 — pytest (chave de idempotência, item com TTL, duplicata)"
	cd $(LAB03) && $(PYTEST) -q

test-dlq: $(PYTEST)
	@echo "▶ U1-LAB04 — pytest (validação do veneno e falha parcial de lote)"
	cd $(LAB04) && $(PYTEST) -q

test-eventstore: $(PYTEST)
	@echo "▶ U2-LAB01 — pytest (domínio da conta, replay e invariantes)"
	cd $(LABU201) && $(PYTEST) -q

test-snapshots: $(PYTEST)
	@echo "▶ U2-LAB02 — pytest (replay a partir de base, snapshot = replay completo)"
	cd $(LABU202) && $(PYTEST) -q

test-cqrs: $(PYTEST)
	@echo "▶ U2-LAB03 — pytest (projeção incremental e idempotência)"
	cd $(LABU203) && $(PYTEST) -q

test-produtor: $(PYTEST)
	@echo "▶ U3-LAB01 — pytest (montagem/validação de evento e registro Kinesis)"
	cd $(LABU301) && $(PYTEST) -q

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

deploy-fanout:
	cd $(LAB02) && sam build && sam deploy --stack-name u1lab02-fanout $(SAM_DEPLOY)

fanout:
	cd $(LAB02)/scripts && bash publicar-e-observar.sh

deploy-idem:
	cd $(LAB03) && sam build && sam deploy --stack-name u1lab03-idempotencia $(SAM_DEPLOY)

idem:
	cd $(LAB03)/scripts && bash enviar-duplicado-e-observar.sh

deploy-dlq:
	cd $(LAB04) && sam build && sam deploy --stack-name u1lab04-dlq $(SAM_DEPLOY)

dlq:
	cd $(LAB04)/scripts && bash veneno-e-dlq.sh

deploy-eventstore:
	cd $(LABU201) && sam build && sam deploy --stack-name u2lab01-eventstore $(SAM_DEPLOY)

eventstore:
	cd $(LABU201)/scripts && bash conta-e-replay.sh

deploy-snapshots:
	cd $(LABU202) && sam build && sam deploy --stack-name u2lab02-snapshots $(SAM_DEPLOY)

snapshots:
	cd $(LABU202)/scripts && bash snapshot-e-delta.sh

deploy-cqrs:
	cd $(LABU203) && sam build && sam deploy --stack-name u2lab03-cqrs $(SAM_DEPLOY)

cqrs:
	cd $(LABU203)/scripts && bash cqrs-projecao.sh

deploy-produtor:
	cd $(LABU301) && sam build && sam deploy --stack-name u3lab01-produtor $(SAM_DEPLOY)

produtor:
	cd $(LABU301)/scripts && bash publicar-e-rotear.sh

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
	@for s in u1lab01-partes1a3 u1lab01-runtimes u1lab01-snapstart u1lab02-fanout u1lab03-idempotencia u1lab04-dlq u2lab01-eventstore u2lab02-snapshots u2lab03-cqrs u3lab01-produtor; do \
	  echo "== $$s =="; \
	  aws cloudformation describe-stacks --stack-name $$s \
	    --query 'Stacks[0].Outputs[].{Chave:OutputKey,Valor:OutputValue}' \
	    --output table 2>/dev/null || echo "  (stack não implantado)"; \
	done

clean:
	-aws cloudformation delete-stack --stack-name u1lab01-partes1a3
	-aws cloudformation delete-stack --stack-name u1lab01-runtimes
	-aws cloudformation delete-stack --stack-name u1lab01-snapstart
	-aws cloudformation delete-stack --stack-name u1lab02-fanout
	-aws cloudformation delete-stack --stack-name u1lab03-idempotencia
	-aws cloudformation delete-stack --stack-name u1lab04-dlq
	-aws cloudformation delete-stack --stack-name u2lab01-eventstore
	-aws cloudformation delete-stack --stack-name u2lab02-snapshots
	-aws cloudformation delete-stack --stack-name u2lab03-cqrs
	-aws cloudformation delete-stack --stack-name u3lab01-produtor
	-cd $(LAB)/runtimes/java && mvn -q clean --no-transfer-progress
	-cd $(LAB)/snapstart/java && mvn -q clean --no-transfer-progress
	rm -rf $(LAB)/fundamentos/.aws-sam $(LAB)/runtimes/.aws-sam $(LAB)/snapstart/.aws-sam
	rm -rf $(LAB02)/.aws-sam $(LAB03)/.aws-sam $(LAB04)/.aws-sam $(LABU201)/.aws-sam $(LABU202)/.aws-sam $(LABU203)/.aws-sam $(LABU301)/.aws-sam
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
