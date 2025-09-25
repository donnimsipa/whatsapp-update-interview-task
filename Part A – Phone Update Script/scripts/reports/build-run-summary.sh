#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
REPORT_DIR="$ROOT/outputs/reports"
LOG_DIR="$REPORT_DIR/logs"

usage() {
  cat <<'USAGE'
Usage: build-run-summary.sh [--run-id RUN_ID]

Generates a markdown report from the most recent run log (or the specified run ID).
USAGE
}

RUN_ID=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --run-id)
      shift || { echo "Missing value after --run-id" >&2; exit 1; }
      RUN_ID="$1"
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

if [[ ! -d "$LOG_DIR" ]]; then
  echo "[error] No run logs directory found at $LOG_DIR" >&2
  exit 1
fi

if [[ -n "$RUN_ID" ]]; then
  LOG_PATH="$LOG_DIR/run-${RUN_ID}.json"
  if [[ ! -f "$LOG_PATH" ]]; then
    echo "[error] Run log not found: $LOG_PATH" >&2
    exit 1
  fi
else
  latest=$(ls -1 "$LOG_DIR"/run-*.json 2>/dev/null | sort | tail -n 1 || true)
  if [[ -z "$latest" ]]; then
    echo "[error] No run logs found in $LOG_DIR" >&2
    exit 1
  fi
  LOG_PATH="$latest"
  RUN_ID=$(basename "$LOG_PATH")
  RUN_ID="${RUN_ID#run-}"
  RUN_ID="${RUN_ID%.json}"
fi

SUMMARY_PATH="$REPORT_DIR/run-summary-${RUN_ID}.md"
GEN_TS=$(date -u +%Y-%m-%dT%H:%M:%SZ)

rel_log_path="outputs/reports/logs/run-${RUN_ID}.json"

env \
  LOG_PATH="$LOG_PATH" \
  SUMMARY_PATH="$SUMMARY_PATH" \
  RUN_ID="$RUN_ID" \
  GENERATED_AT="$GEN_TS" \
  REL_LOG_PATH="$rel_log_path" \
python3 <<'PY'
import json
import os
from pathlib import Path
from datetime import datetime, timezone

log_path = Path(os.environ['LOG_PATH'])
summary_path = Path(os.environ['SUMMARY_PATH'])
summary_path.parent.mkdir(parents=True, exist_ok=True)

with open(log_path, 'r', encoding='utf-8') as fh:
    run = json.load(fh)

def fmt_duration(seconds: int) -> str:
    seconds = max(0, int(seconds))
    minutes, sec = divmod(seconds, 60)
    hours, minutes = divmod(minutes, 60)
    return f"{hours:02d}:{minutes:02d}:{sec:02d}"

status_icons = {
    'success': '✅',
    'failure': '❌',
    'skipped': '⏭️',
}

success_count = run.get('success_count', 0)
failure_count = run.get('failure_count', 0)
skip_count = sum(1 for task in run.get('tasks', []) if task.get('status') == 'skipped')

def format_note(value: str) -> str:
    return value if value else '-'

lines = []
lines.append(f"# Test Run Summary (Run ID {os.environ['RUN_ID']})")
lines.append('')
lines.append(f"- Generated (UTC): {os.environ['GENERATED_AT']}")
lines.append(f"- Source log: `{os.environ['REL_LOG_PATH']}`")
lines.append(f"- Started (UTC): {run['start_iso']} (epoch {run['start_epoch']})")
lines.append(f"- Finished (UTC): {run['end_iso']} (epoch {run['end_epoch']})")
lines.append(f"- Duration: {fmt_duration(run['duration_seconds'])} ({run['duration_seconds']} seconds)")
lines.append(f"- Successes: {success_count}")
lines.append(f"- Failures: {failure_count}")
lines.append(f"- Skipped: {skip_count}")
lines.append('')

if run.get('tasks'):
    lines.append('## Task Timeline')
    lines.append('| Task | Status | Start (UTC) | Finish (UTC) | Wall Time | Notes |')
    lines.append('| --- | :---: | --- | --- | --- | --- |')
    for task in run['tasks']:
        icon = status_icons.get(task.get('status'), task.get('status', '?'))
        start_iso = task.get('start_iso', '-')
        end_iso = task.get('end_iso', '-')
        wall = fmt_duration(task.get('duration_seconds', 0))
        note = format_note(task.get('note', ''))
        lines.append(f"| {task.get('name', 'Unknown')} | {icon} | {start_iso} | {end_iso} | {wall} | {note} |")
    lines.append('')

if run.get('notes'):
    lines.append('## Skipped / Warnings')
    for note in run['notes']:
        lines.append(f"- {note}")
    lines.append('')

lines.append('## Artefacts')
lines.append('- Validation outputs: `outputs/validation/`')
lines.append('- Performance outputs: `outputs/performance/`')
lines.append('')

summary_path.write_text('\n'.join(lines), encoding='utf-8')
print(f"[info] Summary written to {summary_path}")
PY
