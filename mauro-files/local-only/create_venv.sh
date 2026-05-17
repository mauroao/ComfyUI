#!/bin/bash
set -euo pipefail

trap 'echo "ERROR: Command failed at line $LINENO with exit code $?" >&2; exit 1' ERR

GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMFY_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# NOTE: To keep the venv active in your current shell after this script,
# run it with: source create_venv.sh

# 1. Deactivate any active venv
if type deactivate &>/dev/null; then
    deactivate
fi

# 2. Remove existing venv if present, then create and activate
if [ -d "$COMFY_ROOT/.venv" ]; then
    rm -rf "$COMFY_ROOT/.venv"
fi
python3 -m venv "$COMFY_ROOT/.venv"
source "$COMFY_ROOT/.venv/bin/activate"

# 3. Upgrade pip
python -m pip install --upgrade pip

echo -e "${GREEN}All commands executed successfully.${NC}"
echo "venv location: $COMFY_ROOT/.venv"
exit 0
