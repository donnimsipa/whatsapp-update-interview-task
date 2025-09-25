# Testing & Performance Scripts

## Structure
| Path | Purpose |
| --- | --- |
| `samples/` | Utilities for generating WhatsApp CSV/JSON fixtures. |
| `validation/` | CLI validation and stress test harnesses. |
| `performance/` | Benchmarks for nominal, invalid-heavy, and extreme workloads. |
| `reports/` | Helpers for rebuilding Markdown summaries from run logs. |
| _(root)_ `process-offline.sh` | Wrapper that calls either runtime against the offline CSV/JSON (lives at repo root, documented here for discoverability). |

## Sample Generators (`scripts/samples/`)
- `generate-whatsapp-dataset.js` / `.py` – core generator (modes: `valid`, `invalid`, `mixed`, `uniform`; flags for record count, valid ratio, patients JSON). The Python variant is invoked automatically when Node.js is unavailable.
- `generate-sample-data.js` – wrapper for a 100-row valid dataset.
- `generate-sample-invalid.js` – wrapper for invalid dataset creation.
- `generate-sample-mixed.js` – wrapper for mixed datasets (50% valid by default).
- `generate-sample-correct.js` – wrapper emitting a tiny valid fixture for smoke tests.
- `generate-large-dataset.js` – wrapper producing the standard 100/1k/5k uniform datasets under `outputs/performance/`.

## Validation Suite (`scripts/validation/`)
- `run-validation.sh` – core validator with `--runtime node|go|both`, `--csv`, and `--input-json` overrides.
- `run-node.sh`, `run-go.sh`, `run-both.sh` – convenience wrappers.
- `run-invalid-stress.sh` – generate/validate large invalid datasets.
- `run-mixed-stress.sh` – generate/validate mixed datasets with configurable ratios.

## Performance Benchmarks (`scripts/performance/`)
- `simple-performance-test.sh` – quick timing smoke test on the default dataset.
- `performance-test.sh` – averaged timings with configurable dataset sizes (default 100/1k/5k).
- `comprehensive-benchmark.sh` – throughput study for datasets 10→20k, exporting CSV summary.
- `performance-invalid.sh` – benchmark behaviour on predominantly invalid rows.
- `performance-extreme.sh` – extreme-scale benchmark for 50k/100k/500k/1M rows using the sample generator.

## Run Reporting (`scripts/reports/`)
- `build-run-summary.sh` – regenerates the Markdown summary for the latest (or specified) run using the JSON log under `outputs/reports/logs/`.

All scripts should be invoked from the repository root so relative paths resolve correctly. Outputs are stored under `outputs/` (e.g. `outputs/validation/`, `outputs/performance/`).
