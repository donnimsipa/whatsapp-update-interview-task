#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

successes=0
failures=0
NOTES=()
TASK_LOG=()
SKIP_EXTREME=false

usage() {
  cat <<'USAGE'
Usage: run-all.sh [--skip-extreme]

Options:
  --skip-extreme   Skip the extreme benchmark step for each runtime.
  -h, --help       Show this message and exit.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --skip-extreme)
      SKIP_EXTREME=true
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

START_EPOCH=$(date +%s)
START_ISO=$(date -u -d "@${START_EPOCH}" +%Y-%m-%dT%H:%M:%SZ)
RUN_ID=$(date -u -d "@${START_EPOCH}" +%Y%m%dT%H%M%SZ)

run_task() {
  local name="$1"
  shift
  local task_start_epoch=$(date +%s)
  local task_start_iso=$(date -u -d "@${task_start_epoch}" +%Y-%m-%dT%H:%M:%SZ)
  echo "[task] ${name}"
  if "$@"; then
    echo "[ok] ${name}"
    successes=$((successes + 1))
    local status="success"
    local note=""
    local exit_code=0
    local task_end_epoch=$(date +%s)
    local task_end_iso=$(date -u -d "@${task_end_epoch}" +%Y-%m-%dT%H:%M:%SZ)
    local duration=$((task_end_epoch - task_start_epoch))
    TASK_LOG+=("${name}|${status}|${note}|${task_start_iso}|${task_end_iso}|${duration}|${exit_code}")
  else
    local exit_code=$?
    echo "[fail] ${name}" >&2
    failures=$((failures + 1))
    local status="failure"
    local note="see console"
    local task_end_epoch=$(date +%s)
    local task_end_iso=$(date -u -d "@${task_end_epoch}" +%Y-%m-%dT%H:%M:%SZ)
    local duration=$((task_end_epoch - task_start_epoch))
    TASK_LOG+=("${name}|${status}|${note}|${task_start_iso}|${task_end_iso}|${duration}|${exit_code}")
  fi
}

record_skipped() {
  local name="$1"
  local reason="$2"
  local timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)
  TASK_LOG+=("${name}|skipped|${reason}|${timestamp}|${timestamp}|0|0")
}

if command -v go >/dev/null 2>&1; then
  run_task "Go validation" bash "$ROOT/scripts/validation/run-validation.sh" --runtime go
  if [[ -f "$ROOT/outputs/validation/go-summary.json" ]]; then
    cp "$ROOT/outputs/validation/go-summary.json" \
      "$ROOT/outputs/validation/go-summary-default.json"
  fi
  if [[ -f "$ROOT/outputs/validation/node-summary.json" ]]; then
    cp "$ROOT/outputs/validation/node-summary.json" \
      "$ROOT/outputs/validation/node-summary-default.json"
  fi
  run_task "Go invalid stress" bash "$ROOT/scripts/validation/run-invalid-stress.sh" --runtime go --records 20000
  run_task "Go mixed stress" bash "$ROOT/scripts/validation/run-mixed-stress.sh" --runtime go --records 20000 --valid-ratio 0.6
  run_task "Go nominal performance" bash "$ROOT/scripts/performance/performance-test.sh" --runtime go --sizes 100,1000,5000
  if [[ "$SKIP_EXTREME" == true ]]; then
    note_msg="Go extreme benchmark skipped via --skip-extreme flag."
    echo "[info] ${note_msg}" >&2
    NOTES+=("${note_msg}")
    record_skipped "Go extreme performance" "skip-extreme flag"
  else
    run_task "Go extreme performance" bash "$ROOT/scripts/performance/performance-extreme.sh" --runtime go --modes valid,invalid,mixed,uniform
  fi
else
  note_msg="Go runtime not detected; skipped Go scenarios."
  echo "[warn] ${note_msg}" >&2
  NOTES+=("${note_msg}")
  for task in \
    "Go validation" \
    "Go invalid stress" \
    "Go mixed stress" \
    "Go nominal performance" \
    "Go extreme performance"; do
    record_skipped "$task" "Go runtime not detected"
  done
fi

if command -v node >/dev/null 2>&1; then
  run_task "Node validation" bash "$ROOT/scripts/validation/run-validation.sh" --runtime node
  run_task "Node invalid stress" bash "$ROOT/scripts/validation/run-invalid-stress.sh" --runtime node --records 20000
  run_task "Node mixed stress" bash "$ROOT/scripts/validation/run-mixed-stress.sh" --runtime node --records 20000 --valid-ratio 0.6
  run_task "Node nominal performance" bash "$ROOT/scripts/performance/performance-test.sh" --runtime node --sizes 100,1000,5000
  if [[ "$SKIP_EXTREME" == true ]]; then
    note_msg="Node extreme benchmark skipped via --skip-extreme flag."
    echo "[info] ${note_msg}" >&2
    NOTES+=("${note_msg}")
    record_skipped "Node extreme performance" "skip-extreme flag"
  else
    run_task "Node extreme performance" bash "$ROOT/scripts/performance/performance-extreme.sh" --runtime node --modes valid,invalid,mixed,uniform
  fi
else
  note_msg="Node.js runtime not detected; skipped Node scenarios."
  echo "[warn] ${note_msg}" >&2
  NOTES+=("${note_msg}")
  for task in \
    "Node validation" \
    "Node invalid stress" \
    "Node mixed stress" \
    "Node nominal performance" \
    "Node extreme performance"; do
    record_skipped "$task" "Node.js runtime not detected"
  done
fi

END_EPOCH=$(date +%s)
END_ISO=$(date -u -d "@${END_EPOCH}" +%Y-%m-%dT%H:%M:%SZ)
DURATION=$((END_EPOCH - START_EPOCH))

REPORT_DIR="$ROOT/outputs/reports"
LOG_DIR="$REPORT_DIR/logs"
mkdir -p "$LOG_DIR"

TASK_LOG_FILE=$(mktemp)
NOTES_FILE=$(mktemp)
printf '%s\n' "${TASK_LOG[@]}" > "$TASK_LOG_FILE"
printf '%s\n' "${NOTES[@]}" > "$NOTES_FILE"

LOG_PATH="$LOG_DIR/run-${RUN_ID}.json"

env \
  LOG_PATH="$LOG_PATH" \
  TASK_LOG_FILE="$TASK_LOG_FILE" \
  NOTES_FILE="$NOTES_FILE" \
  RUN_ID="$RUN_ID" \
  START_ISO="$START_ISO" \
  START_EPOCH="$START_EPOCH" \
  END_ISO="$END_ISO" \
  END_EPOCH="$END_EPOCH" \
  DURATION="$DURATION" \
  SUCCESS_COUNT="$successes" \
  FAILURE_COUNT="$failures" \
python3 <<'PY'
import json
import os
from pathlib import Path

log_path = Path(os.environ['LOG_PATH'])
log_path.parent.mkdir(parents=True, exist_ok=True)


def read_lines(path: Path):
    lines = []
    with open(path, 'r', encoding='utf-8') as fh:
        for raw in fh:
            line = raw.strip()
            if line:
                lines.append(line)
    return lines


task_entries = []
for line in read_lines(Path(os.environ['TASK_LOG_FILE'])):
    parts = line.split('|')
    if len(parts) != 7:
        continue
    name, status, note, start_iso, end_iso, duration, exit_code = parts
    task_entries.append({
        'name': name,
        'status': status,
        'note': note,
        'start_iso': start_iso,
        'end_iso': end_iso,
        'duration_seconds': int(duration),
        'exit_code': int(exit_code),
    })

notes = read_lines(Path(os.environ['NOTES_FILE']))
run_data = {
    'run_id': os.environ['RUN_ID'],
    'start_iso': os.environ['START_ISO'],
    'end_iso': os.environ['END_ISO'],
    'start_epoch': int(os.environ['START_EPOCH']),
    'end_epoch': int(os.environ['END_EPOCH']),
    'duration_seconds': int(os.environ['DURATION']),
    'success_count': int(os.environ['SUCCESS_COUNT']),
    'failure_count': int(os.environ['FAILURE_COUNT']),
    'notes': notes,
    'tasks': task_entries,
}
with open(log_path, 'w', encoding='utf-8') as fh:
    json.dump(run_data, fh, indent=2)
print(f"[info] Run log written to {log_path}")
PY

rm -f "$TASK_LOG_FILE" "$NOTES_FILE"

bash "$ROOT/scripts/reports/build-run-summary.sh" --run-id "$RUN_ID"

echo "[summary] ${successes} task(s) succeeded, ${failures} task(s) failed."
if [[ $failures -gt 0 ]]; then
  exit 1
fi
