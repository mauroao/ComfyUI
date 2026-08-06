#!/bin/bash
# TEMPORARY: same as run.sh but with --reserve-vram 2, for testing OOM fixes on MiniMax H3.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMFY_ROOT="$(dirname "$SCRIPT_DIR")"

# Detect environment via WSL_DISTRO_NAME (set by WSL on every session)
if [[ -n "${WSL_DISTRO_NAME:-}" ]]; then
    IS_WSL=true
else
    IS_WSL=false
fi
IS_MACOS=false
[[ "$(uname)" == "Darwin" ]] && IS_MACOS=true

# WSL_DISTRO_NAME isn't propagated into containers, but the WSL2 kernel string is
# (containers share the host kernel) — used only to gate --disable-pinned-memory
# below, since cudaHostRegister() is unreliable under WSL2 regardless of whether
# we're running bare-metal or inside a container on top of it.
IS_WSL_KERNEL=false
case "$(uname -r)" in
    *microsoft*) IS_WSL_KERNEL=true ;;
esac

if { $IS_WSL || $IS_MACOS; } && [[ -z "${VIRTUAL_ENV:-}" ]]; then
    echo "[startup] ERROR: .venv is not activated. Run 'source .venv/bin/activate' before running this script." >&2
    exit 1
fi

if $IS_MACOS; then
    cd "$COMFY_ROOT"
    python main.py --listen --reserve-vram 2
    exit 0
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
    python main.py --disable-pinned-memory --use-sage-attention --reserve-vram 2
elif $IS_WSL_KERNEL; then
    # Container running on a WSL2 host (Docker Desktop) — same pinned-memory
    # bug as bare-metal WSL, but still needs --listen since it's a container.
    python main.py --listen --use-sage-attention --reserve-vram 2 --disable-pinned-memory
else
    python main.py --listen --use-sage-attention --reserve-vram 2
fi
