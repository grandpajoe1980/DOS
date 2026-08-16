#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

if [[ ! -f contracts/validate_contracts.py ]]; then
  if [[ "${CONTRACTS_REQUIRED:-false}" == "true" ]]; then
    echo "Contract validation is required, but contracts/validate_contracts.py is missing." >&2
    exit 1
  fi
  echo "::warning::Contract validation is deferred until PR #12 integrates and CONTRACTS_REQUIRED=true is configured; see issue #22."
  exit 0
fi

python3 -m venv "${RUNNER_TEMP:-/tmp}/dos-contract-venv"
# shellcheck disable=SC1091
source "${RUNNER_TEMP:-/tmp}/dos-contract-venv/bin/activate"
python -m pip install --disable-pip-version-check -r contracts/requirements.txt
PYTHONDONTWRITEBYTECODE=1 python contracts/validate_contracts.py
