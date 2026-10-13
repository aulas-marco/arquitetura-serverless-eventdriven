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
LABU302    := lab-u3-02
LABU303    := lab-u3-03
LABU3K     := lab-u3-kafka
AWS_REGION ?= us-east-1
N          ?= 5
export AWS_DEFAULT_REGION := $(AWS_REGION)

# Modo de execução: LOCALSTACK=1 usa samlocal/awslocal apontando para o
# LocalStack (http://localhost:4566); o padrão usa a AWS real.
#   LOCALSTACK=1 make deploy-fanout      # implanta no LocalStack
#   LOCALSTACK=1 make fanout             # roda a demo contra o LocalStack
ifeq ($(LOCALSTACK),1)
  SAM := samlocal
  AWS := awslocal
  export AWS_ENDPOINT_URL := http://localhost:4566
  export LOCALSTACK := 1
else
  SAM := sam
  AWS := aws
endif

# Ferramental: JDK 21 (keg-only no brew) e binários do Homebrew no PATH.
JAVA_HOME ?= $(shell /opt/homebrew/bin/brew --prefix openjdk@21 2>/dev/null)/libexec/openjdk.jdk/Contents/Home
export JAVA_HOME
export PATH := $(CURDIR)/.venv/bin:/opt/homebrew/bin:/opt/homebrew/opt/openjdk@21/bin:$(PATH)

# venv local para o pytest (caminho absoluto: sobrevive aos `cd` das receitas).
VENV   := $(CURDIR)/.venv
PYTEST := $(VENV)/bin/pytest

# Flags padrão de deploy (não interativo).
SAM_DEPLOY := --region $(AWS_REGION) --resolve-s3 --capabilities CAPABILITY_IAM \
              --no-confirm-changeset --no-fail-on-empty-changeset

.DEFAULT_GOAL := help

.PHONY: help test test-fundamentos test-runtimes test-snapstart test-fanout \
        test-idempotencia test-dlq test-eventstore test-snapshots test-cqrs \
        test-produtor test-consumidor test-classificador test-kafka \
        kafka-up kafka-down kafka-clean kafka-rotear kafka-grupos kafka-reentrega \
        build deploy deploy-fundamentos deploy-runtimes deploy-snapstart \
        deploy-fanout fanout deploy-idem idem deploy-dlq dlq \
        deploy-eventstore eventstore deploy-snapshots snapshots \
        deploy-cqrs cqrs deploy-produtor produtor pegadinha \
        deploy-consumidor consumidor deploy-classificador classificador \
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
	@echo "    test-consumidor    pytest dos consumidores Kinesis (U3-LAB02)"
	@echo "    test-classificador pytest do classificador IA+cache (U3-LAB03)"
	@echo "    test-kafka         pytest do lab Kafka local (U3, trilha Docker)"
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
	@echo "    pegadinha          Pegadinha ao vivo: put_item sem ConditionExpression corrompe o event store (U2V8)"
	@echo "    deploy-cqrs        Implanta o CQRS + projeção via Streams (U2-LAB03)"
	@echo "    cqrs               Escreve, projeta, transfere e faz rebuild"
	@echo "    deploy-produtor    Implanta o produtor Kinesis (U3-LAB01)"
	@echo "    produtor           Publica eventos e mostra o roteamento por shard"
	@echo "    deploy-consumidor  Implanta os consumidores Kinesis (U3-LAB02)"
	@echo "    consumidor         Demonstra dois consumidores e at-least-once"
	@echo "    deploy-classificador Implanta o classificador IA+cache (U3-LAB03)"
	@echo "    classificador      Classifica tickets e demonstra o cache DynamoDB"
	@echo "    outputs            Mostra os outputs dos stacks"
	@echo "    clean              Remove todos os stacks + artefatos locais"
	@echo ""
	@echo "  Kafka local (Docker, sem AWS):"
	@echo "    kafka-up           Sobe o broker Kafka e cria o tópico (4 partições)"
	@echo "    kafka-rotear       Roteamento por chave de partição (mesma chave, mesma partição)"
	@echo "    kafka-grupos       Consumer groups e rebalanceamento (1, 2 e 3 consumidores)"
	@echo "    kafka-reentrega    At-least-once: falha antes do commit e reentrega"
	@echo "    kafka-down         Derruba o broker e apaga os dados"
	@echo "    kafka-clean        kafka-down + remove o cliente instalado e caches do lab"
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
      test-eventstore test-snapshots test-cqrs test-produtor test-consumidor test-classificador test-kafka
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

test-consumidor: $(PYTEST)
	@echo "▶ U3-LAB02 — pytest (decodificação de registros Kinesis)"
	cd $(LABU302) && $(PYTEST) -q

test-classificador: $(PYTEST)
	@echo "▶ U3-LAB03 — pytest (hash, prompt e parsing da resposta IA)"
	cd $(LABU303) && $(PYTEST) -q

test-kafka: $(PYTEST)
	@echo "▶ U3-KAFKA — pytest (validação de evento, lote e regra de falha)"
	cd $(LABU3K) && $(PYTEST) -q

# ==========================================================================
# Nuvem — exigem credenciais AWS (aws configure)
# ==========================================================================
build:
	cd $(LAB)/fundamentos && $(SAM) build
	cd $(LAB)/runtimes && $(SAM) build
	cd $(LAB)/snapstart && $(SAM) build

deploy: deploy-fundamentos deploy-runtimes deploy-snapstart
	@echo "✓ 3 stacks implantados"

# Banner didático padrão dos alvos deploy-*: título, recursos criados e o
# lembrete de onde ver os outputs depois. $(1)=título $(2)=recursos $(3)=stack
define BANNER_DEPLOY
	@printf '\n───────────────────────────────────────────────────────────────────\n'
	@printf ' ▶ Implantando: %s\n' "$(1)"
	@printf '   Recursos AWS criados: %s\n' "$(2)"
	@printf '───────────────────────────────────────────────────────────────────\n'
endef
define BANNER_DEPLOY_FIM
	@printf '───────────────────────────────────────────────────────────────────\n'
	@printf ' ✓ %s implantado (stack %s).\n' "$(1)" "$(2)"
	@printf '   Outputs (URLs/nomes) acima ↑ — ou rode: make outputs\n'
	@printf '───────────────────────────────────────────────────────────────────\n'
endef

deploy-fundamentos:
	$(call BANNER_DEPLOY,U1-LAB01 Partes 1-3 (Alô mundo · gatilhos · ciclo de vida),3 Lambdas + HTTP API + fila SQS + bucket S3 + regra agendada EventBridge)
	cd $(LAB)/fundamentos && $(SAM) build && $(SAM) deploy --stack-name u1lab01-partes1a3 $(SAM_DEPLOY)
	$(call BANNER_DEPLOY_FIM,U1-LAB01 Partes 1-3,u1lab01-partes1a3)

deploy-runtimes:
	$(call BANNER_DEPLOY,U1-LAB01 Parte 4 (comparativo de runtimes),3 Lambdas — Python · Java · Go)
	cd $(LAB)/runtimes && $(SAM) build && $(SAM) deploy --stack-name u1lab01-runtimes $(SAM_DEPLOY)
	$(call BANNER_DEPLOY_FIM,U1-LAB01 Parte 4,u1lab01-runtimes)

deploy-snapstart:
	$(call BANNER_DEPLOY,U1-LAB01 Parte 5 (SnapStart),2 Lambdas Java — sem SnapStart e com SnapStart (alias :live))
	cd $(LAB)/snapstart && $(SAM) build && $(SAM) deploy --stack-name u1lab01-snapstart $(SAM_DEPLOY)
	$(call BANNER_DEPLOY_FIM,U1-LAB01 Parte 5,u1lab01-snapstart)

deploy-fanout:
	$(call BANNER_DEPLOY,U1-LAB02 (fan-out SNS+SQS),1 tópico SNS + 2 filas SQS + 2 Lambdas consumidoras)
	cd $(LAB02) && $(SAM) build && $(SAM) deploy --stack-name u1lab02-fanout $(SAM_DEPLOY)
	$(call BANNER_DEPLOY_FIM,U1-LAB02,u1lab02-fanout)

fanout:
	cd $(LAB02)/scripts && bash publicar-e-observar.sh

deploy-idem:
	$(call BANNER_DEPLOY,U1-LAB03 (idempotência SQS+DynamoDB),1 fila SQS + 1 tabela DynamoDB + Lambdas produtor/consumidor)
	cd $(LAB03) && $(SAM) build && $(SAM) deploy --stack-name u1lab03-idempotencia $(SAM_DEPLOY)
	$(call BANNER_DEPLOY_FIM,U1-LAB03,u1lab03-idempotencia)

idem:
	cd $(LAB03)/scripts && bash enviar-duplicado-e-observar.sh

deploy-dlq:
	$(call BANNER_DEPLOY,U1-LAB04 (DLQ e resiliência),fila principal + DLQ + Lambdas produtor/consumidor)
	cd $(LAB04) && $(SAM) build && $(SAM) deploy --stack-name u1lab04-dlq $(SAM_DEPLOY)
	$(call BANNER_DEPLOY_FIM,U1-LAB04,u1lab04-dlq)

dlq:
	cd $(LAB04)/scripts && bash veneno-e-dlq.sh

deploy-eventstore:
	$(call BANNER_DEPLOY,U2-LAB01 (event store DynamoDB),1 tabela de eventos (append-only) + Lambda de comando/consulta)
	cd $(LABU201) && $(SAM) build && $(SAM) deploy --stack-name u2lab01-eventstore $(SAM_DEPLOY)
	$(call BANNER_DEPLOY_FIM,U2-LAB01,u2lab01-eventstore)

eventstore:
	cd $(LABU201)/scripts && bash conta-e-replay.sh

deploy-snapshots:
	$(call BANNER_DEPLOY,U2-LAB02 (replay com snapshots),tabela de eventos + Lambda com snapshot materializado)
	cd $(LABU202) && $(SAM) build && $(SAM) deploy --stack-name u2lab02-snapshots $(SAM_DEPLOY)
	$(call BANNER_DEPLOY_FIM,U2-LAB02,u2lab02-snapshots)

snapshots:
	cd $(LABU202)/scripts && bash snapshot-e-delta.sh

pegadinha:
	cd $(LABU202)/scripts && bash pegadinha-append-only.sh

deploy-cqrs:
	$(call BANNER_DEPLOY,U2-LAB03 (CQRS + projeção via Streams),tabela eventos + tabela de projeção (saldos) + 3 Lambdas (comando/consulta/rebuild) + DynamoDB Streams)
	cd $(LABU203) && $(SAM) build && $(SAM) deploy --stack-name u2lab03-cqrs $(SAM_DEPLOY)
	$(call BANNER_DEPLOY_FIM,U2-LAB03,u2lab03-cqrs)

cqrs:
	cd $(LABU203)/scripts && bash cqrs-projecao.sh

deploy-produtor:
	$(call BANNER_DEPLOY,U3-LAB01 (produtor Kinesis),1 stream Kinesis + Lambda produtora + HTTP API)
	cd $(LABU301) && $(SAM) build && $(SAM) deploy --stack-name u3lab01-produtor $(SAM_DEPLOY)
	$(call BANNER_DEPLOY_FIM,U3-LAB01,u3lab01-produtor)

produtor:
	cd $(LABU301)/scripts && bash publicar-e-rotear.sh

deploy-consumidor:
	$(call BANNER_DEPLOY,U3-LAB02 (consumidores Kinesis),2 Lambdas consumidoras (A e B) lendo o mesmo stream)
	cd $(LABU302) && $(SAM) build && $(SAM) deploy --stack-name u3lab02-consumidores $(SAM_DEPLOY)
	$(call BANNER_DEPLOY_FIM,U3-LAB02,u3lab02-consumidores)

consumidor:
	cd $(LABU302)/scripts && bash consumir-e-observar.sh

deploy-classificador:
	@test -n "$(ANTHROPIC_API_KEY)" || \
	  { echo "Erro: exporte ANTHROPIC_API_KEY antes de 'make deploy-classificador'."; exit 1; }
	$(call BANNER_DEPLOY,U3-LAB03 (classificador IA + cache),fila de tickets + 3 filas de saída + Lambda classificadora + tabela de cache DynamoDB)
	cd $(LABU303) && $(SAM) build && $(SAM) deploy --stack-name u3lab03-classificador \
	  --parameter-overrides AnthropicApiKey=$(ANTHROPIC_API_KEY) $(SAM_DEPLOY)
	$(call BANNER_DEPLOY_FIM,U3-LAB03,u3lab03-classificador)

classificador:
	cd $(LABU303)/scripts && bash classificar-e-rotear.sh

invoke-alo:
	@$(AWS) lambda invoke --function-name u1lab01-alo --log-type Tail \
	  --query 'LogResult' --output text /dev/null | base64 --decode | grep -E 'Alô|REPORT'

invoke-ciclo:
	@for i in 1 2 3; do \
	  $(AWS) lambda invoke --function-name u1lab01-ciclo-vida --log-type Tail \
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
	@for s in u1lab01-partes1a3 u1lab01-runtimes u1lab01-snapstart u1lab02-fanout u1lab03-idempotencia u1lab04-dlq u2lab01-eventstore u2lab02-snapshots u2lab03-cqrs u3lab01-produtor u3lab02-consumidores u3lab03-classificador; do \
	  echo "== $$s =="; \
	  $(AWS) cloudformation describe-stacks --stack-name $$s \
	    --query 'Stacks[0].Outputs[].{Chave:OutputKey,Valor:OutputValue}' \
	    --output table 2>/dev/null || echo "  (stack não implantado)"; \
	done

clean:
	-$(AWS) cloudformation delete-stack --stack-name u1lab01-partes1a3
	-$(AWS) cloudformation delete-stack --stack-name u1lab01-runtimes
	-$(AWS) cloudformation delete-stack --stack-name u1lab01-snapstart
	-$(AWS) cloudformation delete-stack --stack-name u1lab02-fanout
	-$(AWS) cloudformation delete-stack --stack-name u1lab03-idempotencia
	-$(AWS) cloudformation delete-stack --stack-name u1lab04-dlq
	-$(AWS) cloudformation delete-stack --stack-name u2lab01-eventstore
	-$(AWS) cloudformation delete-stack --stack-name u2lab02-snapshots
	-$(AWS) cloudformation delete-stack --stack-name u2lab03-cqrs
	-$(AWS) cloudformation delete-stack --stack-name u3lab01-produtor
	-$(AWS) cloudformation delete-stack --stack-name u3lab02-consumidores
	-$(AWS) cloudformation delete-stack --stack-name u3lab03-classificador
	-cd $(LAB)/runtimes/java && mvn -q clean --no-transfer-progress
	-cd $(LAB)/snapstart/java && mvn -q clean --no-transfer-progress
	rm -rf $(LAB)/fundamentos/.aws-sam $(LAB)/runtimes/.aws-sam $(LAB)/snapstart/.aws-sam
	rm -rf $(LAB02)/.aws-sam $(LAB03)/.aws-sam $(LAB04)/.aws-sam $(LABU201)/.aws-sam $(LABU202)/.aws-sam $(LABU203)/.aws-sam $(LABU301)/.aws-sam $(LABU302)/.aws-sam $(LABU303)/.aws-sam
	@echo "Stacks marcados para remoção (assíncrono) e artefatos locais limpos."

# ==========================================================================
# Kafka local (Docker) — trilha complementar da Unidade 3, sem AWS
# ==========================================================================
KAFKA_COMPOSE := docker compose -f $(LABU3K)/compose.yaml

# Instala o cliente Kafka no .venv só quando o requirements.txt muda.
KAFKA_DEPS := $(VENV)/.kafka-deps

$(KAFKA_DEPS): $(LABU3K)/requirements.txt | $(PYTEST)
	$(VENV)/bin/pip install -q -r $(LABU3K)/requirements.txt
	touch $@

kafka-up:
	$(KAFKA_COMPOSE) up -d --wait kafka
	$(KAFKA_COMPOSE) run --rm criar-topico
	@echo "Kafka em localhost:9092, tópico u3kafka-eventos-suporte (4 partições)."
	@echo "Demos: make kafka-rotear | make kafka-grupos | make kafka-reentrega"

kafka-down:
	$(KAFKA_COMPOSE) down -v

# Limpeza completa da trilha: o prefixo `-` deixa a limpeza dos arquivos seguir
# mesmo com o Docker parado. O marcador .kafka-deps some, então o próximo
# `make kafka-*` reinstala o confluent-kafka no .venv.
kafka-clean:
	-$(KAFKA_COMPOSE) down -v
	rm -f $(KAFKA_DEPS)
	rm -rf $(LABU3K)/src/__pycache__ $(LABU3K)/tests/__pycache__ $(LABU3K)/.pytest_cache
	@echo "Kafka local derrubado e artefatos do lab-u3-kafka limpos."

kafka-rotear: $(KAFKA_DEPS)
	cd $(LABU3K)/scripts && bash rotear-por-chave.sh

kafka-grupos: $(KAFKA_DEPS)
	cd $(LABU3K)/scripts && bash grupos-e-rebalanceamento.sh

kafka-reentrega: $(KAFKA_DEPS)
	cd $(LABU3K)/scripts && bash reentrega.sh

# ==========================================================================
# LocalStack — opcional, para as Partes 1-3 sem conta AWS
# ==========================================================================
# Socket do Docker que o LocalStack usa para rodar as Lambdas. Docker Desktop:
# /var/run/docker.sock (padrão). Colima: $HOME/.colima/default/docker.sock —
# passe DOCKER_SOCK=... ou exporte a variável.
DOCKER_SOCK ?= /var/run/docker.sock

up:
	docker run -d -p 4566:4566 \
	  -v $(DOCKER_SOCK):/var/run/docker.sock \
	  --name localstack localstack/localstack:3
	@echo "LocalStack em http://localhost:4566 — deploy com 'LOCALSTACK=1 make deploy-*'"
	@echo "(serviços carregam sob demanda; requer awslocal + aws-sam-cli-local)"

down:
	-docker rm -f localstack
