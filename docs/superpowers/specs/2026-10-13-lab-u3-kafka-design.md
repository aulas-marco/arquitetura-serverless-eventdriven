# Spec — lab-u3-kafka (trilha Kafka local da Unidade 3)

Data: 2026-10-13
Estado: aguardando revisão

## 1. Objetivo

Oferecer ao aluno uma trilha de Kafka real, executada em Docker local, que complementa os laboratórios Kinesis da Unidade 3. A trilha dispensa conta AWS, LocalStack e token do LocalStack, e demonstra os conceitos que os vídeos conceituais da unidade ensinam em Kafka: chave de partição, consumer groups, rebalanceamento e entrega at-least-once.

Critério de sucesso: um aluno com Docker e o `.venv` do repositório executa `make kafka-up` e as três demonstrações, e obtém em cada uma a saída descrita na seção 5.

## 2. Escopo

Dentro do escopo:

- Diretório novo `lab-u3-kafka/`, autocontido.
- Alvos novos no Makefile.
- Uma página de demonstração em `docs/unidade-3/02-demos/` e links nas páginas existentes (seção 6).

Fora do escopo:

- Lambda, Event Source Mapping, MSK e interface web de Kafka.
- Qualquer alteração em `lab-u3-01`, `lab-u3-02` e `lab-u3-03`, ou nos alvos `LOCALSTACK=1`.
- Vídeos e teleprompters.

## 3. Decisões adotadas

| Decisão | Escolha | Origem |
| --- | --- | --- |
| Cenário | Complemento ao Kinesis | Marco |
| Abordagem | Cliente Kafka direto, com o `lambda_handler` fora do escopo | Marco |
| Local | Diretório novo `lab-u3-kafka/` | Marco |
| Lógica pura compartilhada | Cópia de `montar_evento` dentro do lab novo, que fica independente de `lab-u3-01` | Marco |
| Scripts | Três scripts separados, um por demonstração | Marco |
| Cliente Python | `confluent-kafka` 2.16.0 | Suposição (seção 8) |
| Imagem | `apache/kafka:4.2.2`, modo KRaft, um nó | Suposição (seção 8) |

## 4. Componentes

```
lab-u3-kafka/
├── compose.yaml
├── src/
│   ├── suporte.py
│   ├── produtor.py
│   └── consumidor.py
├── scripts/
│   ├── rotear-por-chave.sh
│   ├── grupos-e-rebalanceamento.sh
│   └── reentrega.sh
└── tests/
    ├── conftest.py
    └── test_suporte.py
```

**compose.yaml.** O arquivo define um serviço Kafka em modo KRaft com listener anunciado como `localhost:9092` para os clientes executados no host, e um serviço auxiliar de uso único que cria o tópico `u3kafka-eventos-suporte` com 4 partições e fator de replicação 1. O estado do broker fica em um volume nomeado, que o alvo `kafka-down` remove junto com o container.

**src/suporte.py.** Lógica pura, sem I/O e sem importar `confluent_kafka`:

- `montar_evento(bruto)`: cópia da função homônima de [lab-u3-01/src/suporte.py](../../../lab-u3-01/src/suporte.py), com a mesma validação (`clienteId` e `mensagem` obrigatórios) e a mesma classe `EventoInvalido`.
- `deve_falhar(cliente_id, falhar_em)`: devolve verdadeiro quando `falhar_em` não é vazio e coincide com o `clienteId`. Isola a regra de falha intencional para ser testável.

**src/produtor.py.** O programa lê eventos em JSON (objeto ou lista) da linha de comando ou da entrada padrão, valida cada um com `montar_evento` e publica com `key=clienteId`, e o callback de entrega imprime o `clienteId`, a partição e o offset de cada registro publicado.

**src/consumidor.py.** O programa lê as variáveis de ambiente `GRUPO` (obrigatória), `CONSUMIDOR` (rótulo, padrão `consumidor`) e `FALHAR_EM` (padrão vazio), usa `enable.auto.commit=false` e confirma o offset depois de processar cada registro, o que mantém a semântica at-least-once. Os callbacks `on_assign` e `on_revoke` imprimem as partições atribuídas e revogadas, e cada registro processado imprime rótulo, partição, offset e `clienteId` na saída padrão. Quando `deve_falhar` é verdadeiro, o processo encerra com código de saída diferente de zero antes de confirmar o offset, e o registro volta a ser entregue na próxima execução do mesmo grupo.

## 5. Demonstrações

Cada script segue o padrão didático dos scripts existentes (funções `titulo`, `nota` e `linha`, introdução e fecho explicativos) e exige o broker ativo (`make kafka-up`).

1. **rotear-por-chave.sh** (espelha o U3-LAB01). Publica 7 eventos de 3 clientes intercalados, com o mesmo lote de [publicar-e-rotear.sh](../../../lab-u3-01/scripts/publicar-e-rotear.sh). Saída esperada: cada `clienteId` aparece sempre na mesma partição, com offsets crescentes dentro dela, e o resumo informa quantas partições distintas foram usadas.
2. **grupos-e-rebalanceamento.sh** (espelha a Parte 1 do U3-LAB02 e acrescenta o rebalanceamento). Parte A: dois consumidores em grupos diferentes recebem o mesmo conjunto de eventos. Parte B: com um único grupo, sobe 1 consumidor (recebe as 4 partições), depois um segundo e um terceiro, e as atribuições impressas mostram a divisão das 4 partições a cada mudança.
3. **reentrega.sh** (análogo local do retry do ESM). Publica eventos com `FALHAR_EM` definido, o consumidor falha antes do commit, é reiniciado sem `FALHAR_EM`, e o mesmo registro é entregue de novo. Saída esperada: o par partição/offset do registro que falhou aparece duas vezes. O script explica que não há equivalente ao `BisectBatchOnFunctionError` nessa trilha.

## 6. Integração com o repositório

Makefile:

| Alvo | Ação |
| --- | --- |
| `kafka-up` | Sobe o Compose e aguarda o broker aceitar conexões e o tópico existir. |
| `kafka-down` | Derruba o Compose e remove o volume. |
| `kafka-rotear`, `kafka-grupos`, `kafka-reentrega` | Executam os três scripts. |
| `test-kafka` | Executa o pytest de `lab-u3-kafka`, sem broker. |

O alvo `test` agregado passa a incluir `test-kafka`. O alvo `help` lista os alvos novos.

Documentação:

- Página nova `docs/unidade-3/02-demos/u3-kafka.md`, no formato de [u3-01.md](../../unidade-3/02-demos/u3-01.md) (objetivos, motivação, estrutura, código anotado, rodar e observar, pontos de atenção, checklist, limpeza, referências).
- Links para a página nova em `docs/unidade-3/index.md`, `docs/unidade-3/00-comece-aqui/setup-local.md` e `docs/unidade-3/01-fundamentos/kinesis-e-ia/3-ponte-kafka-kinesis.md`.
- Uma linha no `README.md`.
- Instrução de instalação do `confluent-kafka` no `.venv`, em `setup-local.md`.

## 7. Testes

- `test_suporte.py` cobre `montar_evento` (evento válido, `clienteId` ausente, `mensagem` ausente, entrada que não é objeto) e `deve_falhar` (coincidência, não coincidência, `falhar_em` vazio).
- O comportamento com broker real é validado pela execução das três demonstrações da seção 5, e o pytest cobre apenas a lógica pura.

## 8. Suposições e riscos

- **Cliente.** O `confluent-kafka` 2.16.0 tem wheel para macOS arm64 com Python 3.14, a versão do `.venv` (verificado no PyPI). Wheels para Linux e Windows não foram verificadas.
- **Imagem.** A tag `apache/kafka:4.2.2` existe no Docker Hub (verificado). Não foi verificado que a imagem inicia em Apple Silicon e em Colima com a configuração de listeners prevista. É o risco principal, e a validação ocorre no início da implementação.
- **Duplicação.** `montar_evento` fica duplicada entre `lab-u3-01` e `lab-u3-kafka`. Alterações futuras na validação precisam ser aplicadas nos dois.
- **Estimativa.** O esforço previsto para este escopo é de 10 a 17 horas, calculado a partir da quantidade de arquivos e de demonstrações das seções 4 e 5, e ainda sem medição.

## 9. Refinamentos definidos no plano de implementação

Estes pontos detalham o spec sem alterar o escopo, e foram definidos ao escrever o plano em `docs/superpowers/plans/2026-10-13-lab-u3-kafka.md`.

- **Tópico por execução.** Cada script de demonstração cria um tópico próprio (`u3kafka-<demo>-<pid>`) com 4 partições e o apaga ao terminar, de modo que execuções repetidas não herdam eventos nem offsets confirmados de execuções anteriores. O tópico `u3kafka-eventos-suporte` criado pelo `kafka-up` permanece para uso manual do produtor e do consumidor.
- **Serviço auxiliar.** O serviço que cria o tópico compartilha a rede do broker (`network_mode: "service:kafka"`), o que permite usar o endereço `localhost:9092` anunciado pelo broker sem um segundo listener.
- **`suporte.py`.** Além de `montar_evento` e `deve_falhar`, o módulo ganha `montar_lote`, que normaliza objeto ou lista e rejeita lote vazio. `montar_evento` passa a exigir `clienteId` em texto, porque a chave de uma mensagem Kafka precisa ser texto ou bytes.
- **Variáveis de ambiente.** O produtor e o consumidor aceitam também `KAFKA_BOOTSTRAP` (padrão `localhost:9092`) e `TOPICO` (padrão `u3kafka-eventos-suporte`).
- **Arquivos adicionais.** `requirements.txt` com `confluent-kafka==2.16.0`, instalado no `.venv` por uma regra do Makefile, e `scripts/comum.sh`, com as funções compartilhadas pelos três scripts.
- **Glossário.** `docs/unidade-3/glossario.md` ganha as entradas Offset e Rebalanceamento.
