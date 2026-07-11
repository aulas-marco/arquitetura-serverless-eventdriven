# Exercícios — Unidade 1

Desafios cirúrgicos sobre o U1-LAB01. Cada um: mude algo, observe, explique.

## 1. Cold start vs warm — na prática

**Faça:** invoque `u1lab01-alo` uma vez, espere alguns minutos sem invocar, invoque de novo.
**Observe:** o `Init Duration` reaparece na segunda?
**Explique:** qual das três causas de partida fria você acionou?

## 2. Forçar reciclagem do ambiente

**Faça:** rode `make invoke-ciclo` (contador chega a 3). Depois mude `NONCE` no `template.yaml` da Parte 3 (`v1` → `v2`), `make deploy-fundamentos`, e rode `make invoke-ciclo` de novo.
**Observe:** o contador volta a 1? O `carregado_em` muda?
**Explique:** por que atualizar a configuração recicla o ambiente.

## 3. Diferenciar SQS de S3

**Faça:** monte à mão dois dicionários `event` — um de SQS e um de S3 — e passe ambos por `identificar_origem` (pode ser no pytest).
**Observe:** o que os separa, já que ambos têm `Records`?
**Explique:** por que decidir só por "tem `Records`?" seria um bug.

## 4. Memória × CPU

**Faça:** no `template.yaml` da Parte 4, dobre `MemorySize` de 512 para 1024 e re-implante. Rode `make medir`.
**Observe:** o `Init Duration` muda? E se você medisse `Duration` de uma função com trabalho de CPU?
**Explique:** por que "menos memória" nem sempre é "mais barato" (pense em GB·s).

## 5. SnapStart sem Init pesada

**Faça:** comente o bloco `static` pesado do `Handler.java` da Parte 5, re-implante e rode `make snapstart`.
**Observe:** o `Restore Duration` agora supera o `Init Duration`?
**Explique:** por que o SnapStart só compensa quando a Init é cara.

## 6. Mitigações de cold start para Java

**Cenário:** uma API Java voltada ao usuário tem cold starts de ~2,5 s que irritam clientes.
**Liste** duas abordagens de mitigação e **diferencie** o que cada uma custa (SnapStart · Provisioned Concurrency · runtime nativo).

---

⬅️ [Arquitetura](03-arquitetura/arquitetura.md) · 📑 [Índice](index.md) · [Glossário ➡️](glossario.md)
