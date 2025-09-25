#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/dataset-generator.sh"

SIZES=(10 100 1000 5000 10000 20000)
RUNTIME="both"
KEEP_INPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime) shift || { echo "Missing value" >&2; exit 1; }; RUNTIME="$1" ;;
    --keep-input) KEEP_INPUT=true ;;
    -h|--help)
      cat <<'USAGE'
Usage: comprehensive-benchmark.sh [--runtime node|go|both] [--keep-input]
USAGE
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PERF_DIR="$ROOT/outputs/performance/comprehensive"
mkdir -p "$PERF_DIR"
RESULTS="$PERF_DIR/results.csv"
echo "records,node_time_ms,go_time_ms" > "$RESULTS"

for size in "${SIZES[@]}"; do
  csv="$PERF_DIR/dataset-${size}.csv"
  json="$PERF_DIR/patients-${size}.json"
  generate_dataset --mode uniform --records "$size" --output "$csv" --patients-json "$json"

  node_time=""
  go_time=""

  if [[ "$RUNTIME" == node || "$RUNTIME" == both ]] && command -v node >/dev/null 2>&1; then
    start=$(date +%s%3N)
    node "$ROOT/solutions/nodejs/src/index.js" \
      --csv "$csv" --input-json "$json" --output-json "$PERF_DIR/node-output-${size}.json" > /dev/null
    end=$(date +%s%3N)
    node_time=$((end - start))
  fi

  if [[ "$RUNTIME" == go || "$RUNTIME" == both ]] && command -v go >/dev/null 2>&1; then
    go build -C "$ROOT/solutions/go" -o "$PERF_DIR/whatsapp-sync" ./cmd/whatsapp-sync
    start=$(date +%s%3N)
    "$PERF_DIR/whatsapp-sync" --csv "$csv" --input-json "$json" --output-json "$PERF_DIR/go-output-${size}.json" > /dev/null
    end=$(date +%s%3N)
    go_time=$((end - start))
    rm -f "$PERF_DIR/whatsapp-sync"
  fi

  echo "$size,${node_time:-},${go_time:-}" >> "$RESULTS"
  [[ "$KEEP_INPUT" == false ]] && rm -f "$csv" "$json"

done

echo "[done] Comprehensive benchmark complete. Results: $RESULTS"
