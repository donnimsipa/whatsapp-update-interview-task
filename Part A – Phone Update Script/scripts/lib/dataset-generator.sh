# shellcheck shell=bash

LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${LIB_DIR}/../.." && pwd)"
GENERATOR_JS="${REPO_ROOT}/scripts/samples/generate-whatsapp-dataset.js"
GENERATOR_PY="${REPO_ROOT}/scripts/samples/generate-whatsapp-dataset.py"

# generate_dataset forwards arguments to the available generator implementation.
# Preference order: Python (better for gigantic JSON), then Node.js as fallback.
generate_dataset() {
  if command -v python3 >/dev/null 2>&1; then
    if python3 "$GENERATOR_PY" "$@"; then
      return
    else
      echo "[warn] Python dataset generator failed, attempting Node.js fallback" >&2
    fi
  fi

  if command -v node >/dev/null 2>&1; then
    node "$GENERATOR_JS" "$@"
    return
  fi

  echo "[error] Neither Node.js nor Python 3 is available to run the dataset generator" >&2
  exit 1
}
