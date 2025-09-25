# Part A – Phone Update Script

Offline tooling for applying WhatsApp updates to the interview bundle. The runtime-agnostic scripts live in this directory; Part B (system design) is tracked separately.

## What's Inside

| Path | Purpose |
| --- | --- |
| `docs/interview/` | Offline copies of the Google Sheet export and patient bundle used across the exercises. |
| `process-offline.sh` | Convenience script to run the Go and/or Node CLI against the offline dataset. |
| `solutions/` | Canonical Go and Node implementations of the phone update CLI (Go binary built via `go build`). |
| `scripts/` | Shared dataset generators, validation harnesses, performance benchmarks, and report builders. |
| `test/` | Orchestration wrapper (`run-all.sh`) plus documentation of the validation/performance matrix. |
| `outputs/` | Generated artefacts (validation summaries, performance logs, timestamped bundles). Populated on demand. |

## Quick Start

```bash
cd "Part A – Phone Update Script"
./process-offline.sh                 # default Go run, writes outputs/<ts>-patients-data.json
./process-offline.sh --runtime node  # Node-only run (same filename convention)
./process-offline.sh --runtime both  # Go + Node; second file ends with -nodejs.json
./process-offline.sh --csv-url "<public csv url>" --runtime both  # download + process in one go
```

The script validates that the offline CSV/JSON fixtures exist and skips runtimes that are not available on the current machine.

### Direct CLI usage

- **Go build/run**
  ```bash
  cd solutions/go
  go build ./cmd/whatsapp-sync    # binary written to ./whatsapp-sync
  ./whatsapp-sync --csv "../../docs/interview/Whatsapp Data - Sheet.csv" \
    --input-json "../../docs/interview/patients-data.json" \
    --output-json "../../outputs/$(date -u +%Y%m%dT%H%M%SZ)-patients-data.json"
  ```
- **Node run**
  ```bash
  cd solutions/nodejs
  node src/index.js --csv "../../docs/interview/Whatsapp Data - Sheet.csv" \
    --input-json "../../docs/interview/patients-data.json" \
    --output-json "../../outputs/$(date -u +%Y%m%dT%H%M%SZ)-patients-data-nodejs.json"
  ```

Both CLIs emit clear error messages on invalid input, e.g. missing files or malformed phone numbers, and exit with status code `1` so they are easy to integrate into scripts.

### Using the live Google Sheet (public access)

If the interview sheet remains publicly viewable, you can download it as CSV without authentication:

```bash
curl -L \
  'https://docs.google.com/spreadsheets/d/1Uh6788unaWaAE1VlnbhGbWzANcf-hN3DrGQzJcxJ3Fc/export?format=csv&gid=0' \
  -o /tmp/whatsapp-data.csv

# then run the CLI against the freshly downloaded CSV
./process-offline.sh --runtime both --csv /tmp/whatsapp-data.csv

# or do it in one step
./process-offline.sh --runtime both --csv-url \
  'https://docs.google.com/spreadsheets/d/1Uh6788unaWaAE1VlnbhGbWzANcf-hN3DrGQzJcxJ3Fc/export?format=csv&gid=0'
```

- Replace `gid=0` with the tab ID you want to export (each sheet tab has a different gid).
- If the share settings are not “Anyone with the link can view”, Google returns an HTML login page instead of CSV; in that case configure a service account and use the Sheets API.

**Converting the sheet URL:**

Starting from the viewer URL:

```
https://docs.google.com/spreadsheets/d/1Uh6788unaWaAE1VlnbhGbWzANcf-hN3DrGQzJcxJ3Fc/edit?usp=sharing
```

Swap `/edit?usp=sharing` with `/export?format=csv&gid=<TAB_ID>`:

```
https://docs.google.com/spreadsheets/d/1Uh6788unaWaAE1VlnbhGbWzANcf-hN3DrGQzJcxJ3Fc/export?format=csv&gid=0
```

- `gid=0` targets the first tab; open the sheet in a browser and look at the `gid` query parameter to target other tabs (e.g. `gid=123456789`).
- Use this converted URL with `--csv-url` or any HTTP client to pull the raw CSV.

## Validation & Benchmarks

High-level orchestration (validation checks, stress runs, benchmarks, report rebuild):

```bash
cd "Part A – Phone Update Script"
bash test/run-all.sh                       # Full Go/Node matrix (skips missing runtimes)
bash scripts/reports/build-run-summary.sh   # Regenerate Markdown summary from latest JSON log
```

The harness logs each task (start/end timestamps, wall time, exit code) to `outputs/reports/logs/run-*.json`; the report builder rewrites `outputs/reports/run-summary-*.md` from those logs.

## Individual Scripts

- Validation: `bash scripts/validation/run-validation.sh --runtime go|node|both`
- Stress datasets: `bash scripts/validation/run-invalid-stress.sh --records 20000`
- Mixed datasets: `bash scripts/validation/run-mixed-stress.sh --records 20000 --valid-ratio 0.6`
- Performance: `bash scripts/performance/performance-test.sh --runtime go --sizes 100,1000,5000`
- Extreme benchmarks: `bash scripts/performance/performance-extreme.sh --runtime both --modes valid,invalid,mixed,uniform`

Dataset generation automatically prefers the Python generator (falls back to Node) so 1 M-row fixtures can be produced without exhausting Node’s JSON serializer.

## Outputs & Artefacts

- `outputs/<timestamp>-patients-data*.json` – results from `process-offline.sh`
- `outputs/validation/` – URS/UAT validation summaries and stress-run snapshots
- `outputs/performance/` – Benchmark logs, summaries, and generated datasets
- `outputs/reports/` – JSON run logs and Markdown summaries for `run-all.sh`

Clean the directory with `rm -rf outputs/*` before a fresh run if you want to avoid mixing artefacts.

## Notes

- Both implementations accept the same CLI flags (`--csv`, `--input-json`, `--output-json`, optional `--last-updated-date`).
- Go 1.22+ and Node 18+ have been exercised; the scripts autodetect runtimes but do not install them.
- Extreme benchmarks rely on ~30 minutes of wall time; interrupt the run if you do not need 1 M-row datasets.
