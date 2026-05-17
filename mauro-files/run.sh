#!/bin/bash

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMFY_ROOT="$(dirname "$SCRIPT_DIR")"

if [[ "$(uname)" == "Darwin" ]]; then
    cd "$COMFY_ROOT"
    python main.py --listen
    exit 0
fi

# Detect environment via WSL_DISTRO_NAME (set by WSL on every session)
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    IS_WSL=true
else
    IS_WSL=false
fi

if $IS_WSL; then
    # Fix for WSL2: ensures Triton finds libcuda directly,
    # without depending on ldconfig (which can have timing issues on WSL2 boot)
    export TRITON_LIBCUDA_PATH=/usr/lib/wsl/lib
    PYTHON="$COMFY_ROOT/.venv/bin/python"
else
    export AIOHTTP_NO_SENDFILE=1
    PYTHON=python3
fi

# Pre-warm Triton: forces compilation of cuda_utils.c BEFORE ComfyUI
# starts. This way any failure appears at boot, not in the middle of a workflow.
echo "[startup] Pre-warming Triton CUDA utils..."
$PYTHON -c "
from triton.backends.nvidia.driver import CudaUtils
CudaUtils()
print('[startup] Triton pre-warm OK')
" || echo "[startup] WARNING: Triton pre-warm failed. SageAttention may not work."

cd "$COMFY_ROOT"

if $IS_WSL; then
    python main.py --disable-pinned-memory --use-sage-attention
else
    python main.py --listen --use-sage-attention
fi
