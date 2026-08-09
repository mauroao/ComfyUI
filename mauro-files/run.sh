#!/bin/bash
# Default launcher: no extra flags beyond the per-environment baseline in run-common.sh.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

EXTRA_ARGS=()

source "$SCRIPT_DIR/scripts/run-common.sh"
