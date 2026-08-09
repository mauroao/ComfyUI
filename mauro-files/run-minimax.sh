#!/bin/bash
# Adds --reserve-vram 2 on top of the baseline in run-common.sh — needed to avoid
# a CUDA OOM seen on the MiniMax H3 WSL2 workflow (video/minimax_h3_i2v_wsl.json)
# on the 16GB card.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

EXTRA_ARGS=(--reserve-vram 2)

source "$SCRIPT_DIR/scripts/run-common.sh"
