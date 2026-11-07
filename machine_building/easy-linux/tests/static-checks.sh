#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

bash -n "${ROOT_DIR}/provision/install.sh"
bash -n "${ROOT_DIR}/provision/ledger-backup"
bash -n "${ROOT_DIR}/provision/ledger-scrub"
bash -n "${ROOT_DIR}/provision/remove-build-user"
bash -n "${ROOT_DIR}/tests/verify-vm.sh"
grep -Eq '^[A-Fa-f0-9]{32}$' < <(sed -n 's/^USER_FLAG="\(.*\)"/\1/p' "${ROOT_DIR}/provision/install.sh")
grep -Eq '^[A-Fa-f0-9]{32}$' < <(sed -n 's/^ROOT_FLAG="\(.*\)"/\1/p' "${ROOT_DIR}/provision/install.sh")
python3 -m py_compile "${ROOT_DIR}/app/app.py"
python3 -m py_compile "${ROOT_DIR}/app/init_db.py"

echo "Static checks passed."

