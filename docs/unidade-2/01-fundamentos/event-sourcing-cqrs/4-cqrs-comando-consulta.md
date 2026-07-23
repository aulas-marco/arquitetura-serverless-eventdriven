# CQRS — separando comando de consulta

> **Pré-requisito:** [Replay e snapshots](3-replay-e-snapshots.md) · **Demo:** U2-LAB03 · **Script:** `cqrs-projecao.sh`

Toda aplicação tem dois problemas que parecem iguais, mas têm naturezas opostas. **Escrever** exige validação rica de domínio, consistência forte e o log imutável de eventos. **Ler** exige formato otimizado para a tela, valor pré-calculado e zero validação. Tentar servir ambos com o mesmo modelo é uma aposta perdida: o resultado é um código que serve mal a cada um.

---

## O problema: um modelo que tenta servir a dois donos

Nos labs anteriores, consultar o saldo custava um replay (ou snapshot + delta). Para uma tela que mostra o saldo de milhares de contas por segundo, refazer contas a cada leitura é caro — mesmo com snapshot. Escrita e leitura têm necessidades opostas: a escrita quer o log de eventos; a leitura quer o valor pronto, agora. Otimizar um degrada o outro.

## O princípio: responsabilidade única por lado

**CQRS — Command Query Responsibility Segregation** — eleva ao nível arquitetural o princípio de Bertrand Meyer (CQS): um método deve ou modificar estado, ou retornar um valor, nunca os dois. No CQRS, modelos inteiros são separados por responsabilidade:

| Lado         | Responsabilidade                            | Modelo de dados                          | Regra de ouro                              |
| ------------ | ------------------------------------------- | ---------------------------------------- | ------------------------------------------ |
| **Comando**  | Validar, proteger o domínio, gravar eventos | Event store append-only `(contaId, seq)` | Nunca lê a projeção                        |
| **Consulta** | Responder requisições de leitura            | Projeção desnormalizada `saldos`         | Nunca valida, nunca escreve no event store |

O lado de consulta não sabe que o event store existe. O lado de comando não sabe que a projeção existe. O único elo entre eles é o fluxo de eventos, operado de forma assíncrona pelo DynamoDB Streams.

## Como funciona no lab (U2-LAB03)

No U2-LAB03, os dois lados são **Lambdas separadas** — separação física, não só lógica.

### Lado de comando — só grava eventos

O `comando.py` grava o evento no event store e nunca lê a projeção. Ele reconstrói o estado por replay do event store para validar cada comando:

```python
# comando.py — fiel ao que está em lab-u2-03
def _comando(contaId, decidir):
    eventos = _eventos(contaId)
    if not eventos:
        return _resp(404, {"erro": "conta não encontrada"})
    conta = reconstruir(contaId, eventos)
    evento = decidir(conta)
    _append(evento, len(eventos) + 1)
    return _resp(200, {"contaId": contaId, "saldo": _num(conta.aplicar(evento).saldo)})
```

O carregamento usa `ConsistentRead=True` — o lado de comando **precisa** ver os eventos recém-gravados para calcular a próxima sequência; uma leitura eventualmente consistente colidiria na gravação.

### Lado de consulta — só lê a projeção

O `consulta.py` lê diretamente a tabela `saldos` via `get_item`. Nenhum replay, nenhuma lógica de domínio, nenhum acesso ao event store:

```python
# consulta.py — fiel ao que está em lab-u2-03
def lambda_handler(event, context):
    contaId = (event.get("pathParameters") or {}).get("contaId")
    linha = saldos.get_item(Key={"contaId": contaId}).get("Item")

    if not linha:
        return _resp(404, {"erro": "conta ainda não projetada (consistência eventual)"})

    return _resp(200, {
        "contaId": linha["contaId"],
        "titular": linha["titular"],
        "saldo": _num(linha["saldo"]),
        "ultimaSequencia": int(linha["ultimaSequencia"]),
        "fonte": "projecao",
    })
```

A consulta é uma única operação por chave primária — O(1), sem cálculos.

## Por que isso importa

A separação torna cada lado simples por design. A Lambda de consulta pode escalar independentemente da Lambda de comando. Uma falha no projetor congela as leituras no último estado bom, mas não afeta a escrita — os comandos continuam aceitando eventos. A assimetria entre os dois lados é uma característica, não um defeito.

> **Ponto de atenção:** o lado de comando nunca consulta `saldos` para validar. A projeção pode estar defasada — um saque gravado há um instante ainda pode não ter propagado. O comando sempre reconstrói o estado pelo replay do event store.

---

⬅️ [Anterior: Replay e snapshots](3-replay-e-snapshots.md) · 📑 [Índice](../../index.md) · [Próximo: Projeções e consistência eventual](5-projecoes-consistencia-eventual.md) ➡️
