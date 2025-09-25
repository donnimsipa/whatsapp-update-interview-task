#!/usr/bin/env bash
set -euo pipefail

print_usage() {
  cat <<'USAGE'
Usage: run-validation.sh [options]

Options:
  --runtime {node|go|both}    Select runtime(s) to validate (default: both)
  --csv PATH                  Override WhatsApp CSV path
  --input-json PATH           Override patients JSON path
  -h, --help                  Show this help message

The script runs the selected CLI(s), stores outputs in `outputs/validation/`, and verifies results against the URS/UAT checklist.
USAGE
}

RUNTIME="both"
CSV_OVERRIDE=""
INPUT_OVERRIDE=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime)
      shift || { echo "Missing value after --runtime" >&2; exit 1; }
      case "$1" in
        node|go|both) RUNTIME="$1" ;;
        *) echo "Unknown runtime '$1'" >&2; exit 1 ;;
      esac
      ;;
    --csv)
      shift || { echo "Missing value after --csv" >&2; exit 1; }
      CSV_OVERRIDE="$1"
      ;;
    --input-json)
      shift || { echo "Missing value after --input-json" >&2; exit 1; }
      INPUT_OVERRIDE="$1"
      ;;
    -h|--help)
      print_usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      print_usage
      exit 1
      ;;
  esac
  shift
done

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
DEFAULT_CSV="$ROOT/docs/interview/Whatsapp Data - Sheet.csv"
DEFAULT_INPUT="$ROOT/docs/interview/patients-data.json"
CSV_PATH=${CSV_OVERRIDE:-$DEFAULT_CSV}
INPUT_JSON=${INPUT_OVERRIDE:-$DEFAULT_INPUT}
OUT_DIR="$ROOT/outputs/validation"
OUT_ROOT_DIR="$ROOT/outputs/validation"
mkdir -p "$OUT_DIR"

run_node() {
  if ! command -v node >/dev/null 2>&1; then
    echo "[warn] Skipping Node.js validation (node not found)."
    return 1
  fi
  echo "[info] Running Node.js validation"
  local summary="$OUT_DIR/node-summary.json"
  node "$ROOT/solutions/nodejs/src/index.js" \
    --csv "$CSV_PATH" \
    --input-json "$INPUT_JSON" \
    --output-json "$OUT_DIR/patients-node.json" \
    > "$summary"
  echo "[ok] Node.js summary stored at $summary"
  return 0
}

run_go() {
  if ! command -v go >/dev/null 2>&1; then
    echo "[warn] Skipping Go validation (go not found)."
    return 1
  fi
  echo "[info] Running Go validation"
  local summary="$OUT_DIR/go-summary.json"
  go run -C "$ROOT/solutions/go" ./cmd/whatsapp-sync \
    --csv "$CSV_PATH" \
    --input-json "$INPUT_JSON" \
    --output-json "$OUT_DIR/patients-go.json" \
    > "$summary"
  echo "[ok] Go summary stored at $summary"
  return 0
}

successes=0
failures=0

if [[ "$RUNTIME" == node || "$RUNTIME" == both ]]; then
  run_node || failures=$((failures+1))
  [[ $? -eq 0 ]] && successes=$((successes+1))
fi

if [[ "$RUNTIME" == go || "$RUNTIME" == both ]]; then
  run_go || failures=$((failures+1))
  [[ $? -eq 0 ]] && successes=$((successes+1))
fi

if [[ $successes -eq 0 ]]; then
  echo "[error] No validations completed successfully." >&2
  exit 1
fi

echo "[done] Validation complete: ${successes} success(es), ${failures} failure(s)."
