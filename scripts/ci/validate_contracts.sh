#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$repo_root"

if [[ ! -f contracts/validate_contracts.py ]]; then
  echo "Contract package is not present on this branch; validation is deferred until the contract PR is integrated."
  exit 0
fi

python3 -m venv "${RUNNER_TEMP:-/tmp}/dos-contract-venv"
# shellcheck disable=SC1091
source "${RUNNER_TEMP:-/tmp}/dos-contract-venv/bin/activate"
python -m pip install --disable-pip-version-check -r contracts/requirements.txt
PYTHONDONTWRITEBYTECODE=1 python contracts/validate_contracts.py

