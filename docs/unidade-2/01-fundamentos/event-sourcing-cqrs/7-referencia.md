# Referências — Event Sourcing e CQRS

> Fontes O'Reilly Learning que sustentam os conceitos desta unidade. Os capítulos são o ponto de partida recomendado; trate versões e edições como o que estava disponível na data de captura.

## Núcleo

- **Microservices Patterns** — Chris Richardson (Manning), Cap. 6 (Event Sourcing) e Cap. 7 (CQRS). A referência central da unidade: cobre o event store, a reconstrução por replay e a separação comando/consulta.
- **Designing Event-Driven Systems** — Ben Stopford (O'Reilly), Cap. 7. Projeções, materialização de estado e o *stream* como fonte da verdade — base direta dos laboratórios.

## Apoio

- **Implementing Domain-Driven Design** — Vaughn Vernon (Pearson/AW), Cap. 8. Eventos de domínio e agregados — o vocabulário que ancora `ContaCriada`, `DepositoRealizado`, `SaqueRealizado`.
- **Designing Data-Intensive Applications** — Martin Kleppmann (O'Reilly), Cap. 11. *Streams*, logs e a relação entre estado e eventos — o pano de fundo teórico do append-only.

## Do conceito ao código

Cada padrão desta trilha aparece nos três laboratórios:

| Conceito | Onde ver no código |
|----------|--------------------|
| Append-only com concorrência otimística | `lab-u2-01/src/app.py` (`ConditionExpression`) |
| Replay e snapshots | `lab-u2-02/src/dominio.py`, `app.py` |
| Projeção via DynamoDB Streams | `lab-u2-03/src/projecao.py`, `projetar.py` |
| `TransactWriteItems` e rebuild | `lab-u2-03/src/comando.py`, `rebuild.py` |

---

⬅️ [Anterior: ES + CQRS combinados](6-es-cqrs-combinados.md) · 📑 [Índice](../../index.md) · [Próximo: Demo U2-LAB01](../../02-demos/u2-01.md) ➡️
