#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/dataset-generator.sh"

RUNTIME="both"
KEEP_INPUT=false
KEEP_BINARIES=false
SIZES=(50000 100000 500000 1000000)
MODES=(uniform)

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime) shift || { echo "Missing value" >&2; exit 1; }; RUNTIME="$1" ;;
    --keep-input) KEEP_INPUT=true ;;
    --keep-binaries) KEEP_BINARIES=true ;;
    --modes) shift || { echo "Missing value" >&2; exit 1; }; IFS=',' read -r -a MODES <<< "$1" ;;
    -h|--help)
      cat <<'USAGE'
Usage: performance-extreme.sh [--runtime node|go|both] [--keep-input] [--keep-binaries] [--modes LIST]

Options:
  --runtime           Select runtime(s) to benchmark (default: both)
  --modes             Comma-separated dataset modes (valid,invalid,mixed,uniform)
  --keep-input        Preserve generated CSV/JSON fixtures
  --keep-binaries     Preserve Go binaries between runs
  -h, --help          Show this help message and exit
USAGE
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PERF_DIR="$ROOT/outputs/performance/extreme"
LOG_DIR="$PERF_DIR/logs-$(date -u +%Y%m%dT%H%M%SZ)"
mkdir -p "$PERF_DIR" "$LOG_DIR"

if [[ "$RUNTIME" != go && ! $(command -v node 2>/dev/null) ]]; then
  echo "[error] Node.js runtime not found." >&2
  exit 1
fi
if [[ "$RUNTIME" != node && ! $(command -v go 2>/dev/null) ]]; then
  echo "[error] Go toolchain not found." >&2
  exit 1
fi

GO_BINARY=""
if [[ "$RUNTIME" == go || "$RUNTIME" == both ]]; then
  GO_BINARY="$PERF_DIR/whatsapp-sync-extreme"
  echo "[info] Building Go binary once for the run"
  go build -C "$ROOT/solutions/go" -o "$GO_BINARY" ./cmd/whatsapp-sync
fi

for size in "${SIZES[@]}"; do
  for mode in "${MODES[@]}"; do
    csv="$PERF_DIR/${mode}-extreme-${size}.csv"
    json="$PERF_DIR/${mode}-extreme-patients-${size}.json"
    echo "[info] Generating ${mode} dataset (${size} rows)"
    generate_dataset --mode "$mode" --records "$size" --output "$csv" --patients-json "$json"

    if [[ "$RUNTIME" == node || "$RUNTIME" == both ]] && command -v node >/dev/null 2>&1; then
      summary="$LOG_DIR/node-${mode}-${size}-summary.json"
      time_log="$LOG_DIR/node-${mode}-${size}-time.log"
      echo "[info] Node.js benchmark (${mode}, ${size} rows)"
      { time -p node "$ROOT/solutions/nodejs/src/index.js" \
        --csv "$csv" --input-json "$json" --output-json "$PERF_DIR/node-${mode}-extreme-${size}.json"; } \
        > "$summary" 2> "$time_log" || true
    fi

    if [[ "$RUNTIME" == go || "$RUNTIME" == both ]] && command -v go >/dev/null 2>&1; then
      summary="$LOG_DIR/go-${mode}-${size}-summary.json"
      time_log="$LOG_DIR/go-${mode}-${size}-time.log"
      echo "[info] Go benchmark (${mode}, ${size} rows)"
      { time -p "$GO_BINARY" \
        --csv "$csv" --input-json "$json" --output-json "$PERF_DIR/go-${mode}-extreme-${size}.json"; } \
        > "$summary" 2> "$time_log" || true
    fi

    if [[ "$KEEP_INPUT" == false ]]; then
      rm -f "$csv" "$json"
    fi
  done
done

if [[ -n "$GO_BINARY" && "$KEEP_BINARIES" == false ]]; then
  rm -f "$GO_BINARY"
fi

echo "[done] Extreme benchmarks complete. Logs stored in $LOG_DIR"
