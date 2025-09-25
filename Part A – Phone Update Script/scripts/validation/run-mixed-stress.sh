#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../lib/dataset-generator.sh"

RECORDS=10000
VALID_RATIO=0.5
RUNTIME="both"
KEEP_INPUT=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --records) shift || { echo "Missing value" >&2; exit 1; }; RECORDS="$1" ;;
    --valid-ratio) shift || { echo "Missing value" >&2; exit 1; }; VALID_RATIO="$1" ;;
    --runtime) shift || { echo "Missing value" >&2; exit 1; }; RUNTIME="$1" ;;
    --keep-input) KEEP_INPUT=true ;;
    -h|--help)
      cat <<'USAGE'
Usage: run-mixed-stress.sh [--records N] [--valid-ratio R] [--runtime node|go|both] [--keep-input]
USAGE
      exit 0
      ;;
    *) echo "Unknown option: $1" >&2; exit 1 ;;
  esac
  shift
done

ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
CSV="$ROOT/outputs/validation/mixed-${RECORDS}.csv"
generate_dataset --mode mixed --records "$RECORDS" --valid-ratio "$VALID_RATIO" --output "$CSV"
trap 'rm -f "$CSV"' EXIT
[[ "$KEEP_INPUT" == true ]] && trap - EXIT
bash "$ROOT/scripts/validation/run-validation.sh" --runtime "$RUNTIME" --csv "$CSV"

if [[ -f "$ROOT/outputs/validation/go-summary.json" ]]; then
  cp "$ROOT/outputs/validation/go-summary.json" \
    "$ROOT/outputs/validation/go-summary-mixed-${RECORDS}.json"
fi

if [[ -f "$ROOT/outputs/validation/node-summary.json" ]]; then
  cp "$ROOT/outputs/validation/node-summary.json" \
    "$ROOT/outputs/validation/node-summary-mixed-${RECORDS}.json"
fi
