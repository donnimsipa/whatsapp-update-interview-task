#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")"/../.. && pwd)"
CSV="$ROOT/docs/interview/Whatsapp Data - Sheet.csv"
INPUT="$ROOT/docs/interview/patients-data.json"

if command -v node >/dev/null 2>&1; then
  echo "[info] Node.js quick timing"
  time node "$ROOT/solutions/nodejs/src/index.js" \
    --csv "$CSV" --input-json "$INPUT" --output-json "$ROOT/outputs/patients-node-quick.json" >/tmp/node-quick.log
fi

if command -v go >/dev/null 2>&1; then
  echo "[info] Go quick timing"
  time go run "$ROOT/solutions/go/cmd/whatsapp-sync" \
    --csv "$CSV" --input-json "$INPUT" --output-json "$ROOT/outputs/patients-go-quick.json" >/tmp/go-quick.log
fi

echo "[done] Simple performance test complete."
