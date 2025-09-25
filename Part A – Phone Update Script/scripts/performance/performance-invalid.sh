#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/dataset-generator.sh"

RECORDS=100000
RUNTIME="both"
KEEP_INPUT=false
KEEP_BINARIES=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --records) shift || { echo "Missing value" >&2; exit 1; }; RECORDS="$1" ;;
    --runtime) shift || { echo "Missing value" >&2; exit 1; }; RUNTIME="$1" ;;
    --keep-input) KEEP_INPUT=true ;;
    --keep-binaries) KEEP_BINARIES=true ;;
    -h|--help)
      cat <<'USAGE'
Usage: performance-invalid.sh [--records N] [--runtime node|go|both] [--keep-input] [--keep-binaries]
USAGE
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CSV="$ROOT/outputs/performance/invalid-${RECORDS}.csv"
generate_dataset --mode invalid --records "$RECORDS" --output "$CSV"

if [[ "$RUNTIME" == node || "$RUNTIME" == both ]] && command -v node >/dev/null 2>&1; then
  { time -p node "$ROOT/solutions/nodejs/src/index.js" \
    --csv "$CSV" --input-json "$ROOT/docs/interview/patients-data.json" \
    --output-json "$ROOT/outputs/performance/node-invalid-output.json"; } \
    > "$ROOT/outputs/performance/node-invalid-summary.json" 2> "$ROOT/outputs/performance/node-invalid-time.log" || true
fi

if [[ "$RUNTIME" == go || "$RUNTIME" == both ]] && command -v go >/dev/null 2>&1; then
  go build -C "$ROOT/solutions/go" -o "$ROOT/outputs/performance/whatsapp-sync-invalid" ./cmd/whatsapp-sync
  { time -p "$ROOT/outputs/performance/whatsapp-sync-invalid" \
    --csv "$CSV" --input-json "$ROOT/docs/interview/patients-data.json" \
    --output-json "$ROOT/outputs/performance/go-invalid-output.json"; } \
    > "$ROOT/outputs/performance/go-invalid-summary.json" 2> "$ROOT/outputs/performance/go-invalid-time.log" || true
  [[ "$KEEP_BINARIES" == false ]] && rm -f "$ROOT/outputs/performance/whatsapp-sync-invalid"
fi

[[ "$KEEP_INPUT" == false ]] && rm -f "$CSV"

echo "[done] Invalid data performance benchmark complete."
