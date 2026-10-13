# comum.sh — funções compartilhadas pelos scripts de demonstração (use com `source`).

BROKER_CONTAINER="u3kafka-broker"
KAFKA_BIN="/opt/kafka/bin"

titulo() { printf '\n▶ %s\n' "$1"; }
nota()   { printf '  %s\n' "$1"; }
linha()  { printf '%s\n' '───────────────────────────────────────────────────────────────────'; }

# kafka_cli <ferramenta> <args...> — roda uma ferramenta do Kafka dentro do container.
kafka_cli() {
  local ferramenta="$1"
  shift
  docker exec "$BROKER_CONTAINER" "$KAFKA_BIN/$ferramenta" --bootstrap-server localhost:9092 "$@"
}

exigir_broker() {
  if ! docker exec "$BROKER_CONTAINER" true >/dev/null 2>&1; then
    echo "Broker não encontrado. Rode 'make kafka-up' antes." >&2
    exit 1
  fi
}

criar_topico() {
  kafka_cli kafka-topics.sh --create --if-not-exists --topic "$1" --partitions 4 --replication-factor 1 >/dev/null
}

apagar_topico() {
  kafka_cli kafka-topics.sh --delete --if-exists --topic "$1" >/dev/null 2>&1 || true
}

# esperar_linhas <arquivo> <padrão> <mínimo> <segundos> — espera o padrão
# aparecer ao menos <mínimo> vezes no arquivo. Devolve 1 se o tempo estourar.
esperar_linhas() {
  local arquivo="$1" padrao="$2" minimo="$3" limite="$4" i=0 n
  while [ "$i" -lt "$((limite * 2))" ]; do
    n="$(grep -c -- "$padrao" "$arquivo" 2>/dev/null || true)"
    n="${n:-0}"
    if [ "$n" -ge "$minimo" ]; then
      return 0
    fi
    sleep 0.5
    i=$((i + 1))
  done
  echo "tempo esgotado esperando '$padrao' em $arquivo" >&2
  return 1
}

# esperar_fim <pid> <segundos> — espera o processo terminar sozinho.
# Devolve 1 se o tempo estourar.
esperar_fim() {
  local pid="$1" limite="$2" i=0
  while kill -0 "$pid" 2>/dev/null; do
    if [ "$i" -ge "$((limite * 2))" ]; then
      return 1
    fi
    sleep 0.5
    i=$((i + 1))
  done
  return 0
}

# encerrar <pid>... — envia SIGTERM e espera. O consumidor trata o sinal e deixa
# o grupo antes de sair, o que dispara o rebalanceamento dos demais membros.
encerrar() {
  local pid
  for pid in "$@"; do
    kill -TERM "$pid" 2>/dev/null || true
  done
  for pid in "$@"; do
    wait "$pid" 2>/dev/null || true
  done
}
