#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$SCRIPT_DIR"
OUTPUT_DIR="$ROOT/outputs"
CSV_PATH="$ROOT/docs/interview/Whatsapp Data - Sheet.csv"
JSON_PATH="$ROOT/docs/interview/patients-data.json"
RUNTIME="go"
CSV_OVERRIDE=""
CSV_URL=""
TMP_CSV=""

usage() {
  cat <<'USAGE'
Usage: process-offline.sh [--runtime go|node|both] [--csv PATH] [--csv-url URL]

Processes the interview dataset and writes timestamped outputs under outputs/.
  --runtime     Select runtime to execute (default: go).
  --csv PATH    Override CSV path (defaults to docs/interview/...)
  --csv-url URL Download CSV from URL before processing (e.g. public Google Sheet export)
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --runtime)
      shift || { echo "Missing value after --runtime" >&2; exit 1; }
      RUNTIME="$1"
      ;;
    --csv)
      shift || { echo "Missing value after --csv" >&2; exit 1; }
      CSV_OVERRIDE="$1"
      ;;
    --csv-url)
      shift || { echo "Missing value after --csv-url" >&2; exit 1; }
      CSV_URL="$1"
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
  shift
done

mkdir -p "$OUTPUT_DIR"

if [[ -n "$CSV_OVERRIDE" ]]; then
  CSV_PATH="$CSV_OVERRIDE"
fi

if [[ -n "$CSV_URL" ]]; then
  TMP_CSV=$(mktemp)
  trap 'status=$?; [[ -n "$TMP_CSV" && -f "$TMP_CSV" ]] && rm -f "$TMP_CSV"; exit $status' EXIT
  echo "[info] Downloading CSV from $CSV_URL"
  if ! curl -fsSL "$CSV_URL" -o "$TMP_CSV"; then
    echo "[error] Failed to download CSV from $CSV_URL" >&2
    exit 1
  fi
  CSV_PATH="$TMP_CSV"
fi

if [[ ! -f "$CSV_PATH" ]]; then
  echo "[error] CSV not found at $CSV_PATH" >&2
  exit 1
fi

if [[ ! -f "$JSON_PATH" ]]; then
  echo "[error] Patients JSON not found at $JSON_PATH" >&2
  exit 1
fi

TS=$(date -u +%Y%m%dT%H%M%SZ)
BASE_OUTPUT="$OUTPUT_DIR/${TS}-patients-data.json"

do_go() {
  if ! command -v go >/dev/null 2>&1; then
    echo "[warn] Go runtime not available; skipping Go processing." >&2
    return 1
  fi
  go run -C "$ROOT/solutions/go" ./cmd/whatsapp-sync \
    --csv "$CSV_PATH" --input-json "$JSON_PATH" --output-json "$BASE_OUTPUT"
  echo "[info] Go output: $BASE_OUTPUT"
}

do_node() {
  if ! command -v node >/dev/null 2>&1; then
    echo "[warn] Node.js runtime not available; skipping Node processing." >&2
    return 1
  fi
  local node_output="${BASE_OUTPUT%.json}-nodejs.json"
  node "$ROOT/solutions/nodejs/src/index.js" \
    --csv "$CSV_PATH" --input-json "$JSON_PATH" --output-json "$node_output"
  echo "[info] Node output: $node_output"
}

case "$RUNTIME" in
  go)
    do_go
    ;;
  node)
    # For node-only runs, change the base name to match expectation
    if do_node; then
      # rename primary output to match the node run format (no -nodejs suffix)
      node_output="${BASE_OUTPUT%.json}-nodejs.json"
      if [[ -f "$node_output" ]]; then
        mv "$node_output" "$BASE_OUTPUT"
        echo "[info] Renamed Node output to $BASE_OUTPUT"
      fi
    fi
    ;;
  both)
    go_success=false
    node_success=false
    if do_go; then
      go_success=true
    fi
  if do_node; then
      node_success=true
    fi
    if ! $go_success && ! $node_success; then
      echo "[error] Neither Go nor Node run succeeded." >&2
      exit 1
    fi
    ;;
  *)
    echo "[error] Unknown runtime "$RUNTIME"" >&2
    usage
    exit 1
    ;;
 esac
