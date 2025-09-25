#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/dataset-generator.sh"

print_usage() {
  cat <<'USAGE'
Usage: performance-test.sh [options]

Options:
  --runtime {node|go|both}    Select runtime(s) to benchmark (default: both)
  --sizes LIST                Comma-separated record counts (default: 100,1000,5000)
  --keep-input                Preserve generated fixtures
  --keep-binaries             Preserve Go binaries
  -h, --help                  Show this help message
USAGE
}

RUNTIME="both"
SIZES=(100 1000 5000)
KEEP_INPUT=false
KEEP_BINARIES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime) shift || { echo "Missing value" >&2; exit 1; }; RUNTIME="$1" ;;
    --sizes) shift || { echo "Missing value" >&2; exit 1; }; IFS=',' read -r -a SIZES <<< "$1" ;;
    --keep-input) KEEP_INPUT=true ;;
    --keep-binaries) KEEP_BINARIES=true ;;
    -h|--help) print_usage; exit 0 ;;
    *) echo "Unknown option: $1" >&2; print_usage; exit 1 ;;
  esac
  shift
done

ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PERF_DIR="$ROOT/outputs/performance"
mkdir -p "$PERF_DIR"

if [[ "$RUNTIME" != go && ! $(command -v node 2>/dev/null) ]]; then
  echo "[error] Node.js runtime not found." >&2
  exit 1
fi
if [[ "$RUNTIME" != node && ! $(command -v go 2>/dev/null) ]]; then
  echo "[error] Go toolchain not found." >&2
  exit 1
fi

for size in "${SIZES[@]}"; do
  csv="$PERF_DIR/whatsapp-${size}.csv"
  json="$PERF_DIR/patients-${size}.json"
  echo "[info] Generating dataset size=${size}"
  generate_dataset --mode uniform --records "$size" --output "$csv" --patients-json "$json"

  if [[ "$RUNTIME" == node || "$RUNTIME" == both ]]; then
    echo "[info] Node.js benchmark (size=${size})"
    { time -p node "$ROOT/solutions/nodejs/src/index.js" \
      --csv "$csv" --input-json "$json" --output-json "$PERF_DIR/node-output-${size}.json"; } \
      > "$PERF_DIR/node-summary-${size}.json" 2> "$PERF_DIR/node-time-${size}.log" || true
  fi

  if [[ "$RUNTIME" == go || "$RUNTIME" == both ]]; then
    go_binary="$PERF_DIR/whatsapp-sync-${size}"
    echo "[info] Building Go binary (size=${size})"
    go build -C "$ROOT/solutions/go" -o "$go_binary" ./cmd/whatsapp-sync
    echo "[info] Go benchmark (size=${size})"
    { time -p "$go_binary" \
      --csv "$csv" --input-json "$json" --output-json "$PERF_DIR/go-output-${size}.json"; } \
      > "$PERF_DIR/go-summary-${size}.json" 2> "$PERF_DIR/go-time-${size}.log" || true
    [[ "$KEEP_BINARIES" == false ]] && rm -f "$go_binary"
  fi

  if [[ "$KEEP_INPUT" == false ]]; then
    rm -f "$csv" "$json"
  fi

done

echo "[done] Performance benchmark complete. See outputs/performance for results."
