#!/usr/bin/env bash
#
# medir.sh — Comparativo de cold start entre runtimes (Parte 4).
#
# Para cada função, força N partidas frias e coleta o Init Duration real:
#   1. atualiza uma env var (NONCE) -> recicla o ambiente de execução
#   2. espera a atualização terminar
#   3. invoca com --log-type Tail e extrai "Init Duration" da linha REPORT
#
# No fim, agrega min / mediana / p90 por runtime e imprime uma tabela markdown
# (também salva em resultado-AAAA-MM-DD.md).
#
# Requer: AWS CLI v2, python3, deploy da Parte 4 já feito (sam deploy).
# Uso:    ./medir.sh [N_amostras]     (padrão: 5)

set -euo pipefail

N="${1:-5}"
REGION="${AWS_DEFAULT_REGION:-us-east-1}"
FUNCOES=(u1lab01-runtime-python u1lab01-runtime-java u1lab01-runtime-go)

DATA="$(date +%Y-%m-%d)"
SAIDA="resultado-${DATA}.md"

titulo() { printf '\n▶ %s\n' "$1"; }
linha()  { printf '%s\n' '───────────────────────────────────────────────────────────────────'; }

linha
echo " U1-LAB01 · Parte 4 — Cold start: Python vs. Java vs. Go"
linha
echo "Cada runtime paga um custo de inicialização diferente na partida fria."
echo "Para cada função, forçamos ${N} partidas frias (mudando uma env var, o"
echo "que recicla o ambiente) e medimos o Init Duration real da linha REPORT."
echo "Região: ${REGION}."

# Extrai o valor de "Init Duration: X ms" de um bloco de log já decodificado.
extrai_init() {
  grep -Eo 'Init Duration: [0-9.]+ ms' | grep -Eo '[0-9.]+' | head -1
}

# Estatísticas (min, mediana, p90) de uma lista de números via python3.
estatisticas() {
  python3 - "$@" <<'PY'
import sys
def num(x):
    try:
        return float(x)
    except ValueError:
        return None
vals = sorted(v for v in (num(x) for x in sys.argv[1:]) if v is not None)
if not vals:
    print("- - -"); sys.exit()
def pct(p):
    i = min(len(vals) - 1, int(round((p/100) * (len(vals) - 1))))
    return vals[i]
mediana = vals[len(vals)//2] if len(vals) % 2 else (vals[len(vals)//2 - 1] + vals[len(vals)//2]) / 2
print(f"{vals[0]:.0f} {mediana:.0f} {pct(90):.0f}")
PY
}

linhas_tabela=()

for FN in "${FUNCOES[@]}"; do
  titulo "${FN}"
  amostras=()

  for i in $(seq 1 "$N"); do
    # (1) Força cold start reciclando o ambiente via mudança de configuração.
    aws lambda update-function-configuration \
      --function-name "$FN" \
      --region "$REGION" \
      --environment "Variables={NONCE=amostra-${i}-${RANDOM}}" \
      >/dev/null

    # (2) Espera a atualização propagar (senão o invoke falha com conflito).
    aws lambda wait function-updated --function-name "$FN" --region "$REGION"

    # (3) Invoca capturando o tail do log (contém a linha REPORT com Init Duration).
    log_b64="$(aws lambda invoke \
      --function-name "$FN" \
      --region "$REGION" \
      --log-type Tail \
      --query 'LogResult' --output text \
      /dev/null)"

    init_ms="$(printf '%s' "$log_b64" | python3 -c 'import sys,base64; sys.stdout.write(base64.b64decode(sys.stdin.read()).decode())' | extrai_init || true)"

    if [[ -n "${init_ms:-}" ]]; then
      amostras+=("$init_ms")
      echo "   amostra ${i}: ${init_ms} ms"
    else
      echo "   amostra ${i}: Init Duration não encontrado (invocação quente?) — descartada"
    fi
  done

  read -r vmin vmed vp90 <<<"$(estatisticas "${amostras[@]:-}")"
  runtime_label="${FN#u1lab01-runtime-}"
  linhas_tabela+=("| ${runtime_label} | ${#amostras[@]} | ${vmin} | ${vmed} | ${vp90} |")
done

titulo "Tabela comparativa"
# Monta a tabela markdown.
{
  echo "# Comparativo de cold start — U1-LAB01 Parte 4"
  echo
  echo "- **Data:** ${DATA}"
  echo "- **Região:** ${REGION}"
  echo "- **Memória:** 512 MB · **Arquitetura:** arm64 · **Amostras/função:** ${N}"
  echo
  echo "| Runtime | Amostras | Init min (ms) | Init mediana (ms) | Init p90 (ms) |"
  echo "| ------- | -------- | ------------- | ----------------- | ------------- |"
  printf '%s\n' "${linhas_tabela[@]}"
  echo
  echo "> Números são desta captura específica. Reproduza no seu ambiente para valores atuais."
} | tee "$SAIDA"

linha
echo " Tabela salva em ${SAIDA}. Compare a coluna 'Init mediana': é o custo"
echo " de inicialização que cada runtime paga antes de processar o 1º evento."
linha
