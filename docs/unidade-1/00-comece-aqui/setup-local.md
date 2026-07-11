# Setup local (LocalStack) — Unidade 1

As Partes 1–3 do U1-LAB01 rodam sem conta AWS, num LocalStack local. As Partes 4 e 5 **não** — cold start e SnapStart dependem do [Firecracker](../glossario.md#firecracker) e do mecanismo de snapshot da JVM, que o LocalStack não reproduz.

## Subir o LocalStack

```bash
make up
# LocalStack em http://localhost:4566
```

Ou manualmente:

```bash
docker run -d -p 4566:4566 \
  -e SERVICES=lambda,sns,sqs,s3,iam,apigateway,events,logs \
  --name localstack localstack/localstack
```

## Alternar o terminal para o modo local

O código e o `template.yaml` são idênticos entre AWS real e LocalStack. A alternância é por variável de ambiente — o `boto3` e o SAM leem `AWS_ENDPOINT_URL` automaticamente.

| Dimensão | LocalStack | AWS Real |
|----------|-----------|----------|
| `AWS_ENDPOINT_URL` | `http://localhost:4566` | (não definida) |
| `AWS_ACCESS_KEY_ID` | `test` | credenciais reais |
| CLI | `awslocal` | `aws` |
| SAM | `samlocal` | `sam` |

```bash
pip install awscli-local aws-sam-cli-local
export AWS_ACCESS_KEY_ID=test AWS_SECRET_ACCESS_KEY=test
export AWS_DEFAULT_REGION=us-east-1
export AWS_ENDPOINT_URL=http://localhost:4566
awslocal sts get-caller-identity
```

## Limitação a conhecer

No LocalStack Community, o runtime Python de Lambda tem suporte parcial. Para validar a lógica sem depender disso, rode os **testes de unidade** (`make test`) — eles não precisam de LocalStack nem de AWS.

## Derrubar

```bash
make down
```

---

⬅️ [Pré-requisitos](pre-requisitos.md) · [Índice da unidade ➡️](../index.md)
