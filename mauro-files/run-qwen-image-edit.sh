#!/bin/bash
# Same as run.sh but tuned to avoid CUDA OOMs on the Qwen-Image-Edit-2509 workflow
# (image/qwen_image_edit_2509.json) on 16GB cards: the fp8 diffusion model (~19GB
# on disk) plus the fp8 text encoder (~8GB loaded) don't fit together in VRAM at
# once, and PyTorch's allocator can fragment badly when they're loaded back to back.
#
# - --disable-cuda-malloc forces ComfyUI onto PyTorch's native CUDA allocator instead
#   of its default cudaMallocAsync backend. This matters because
#   PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True (below) is a no-op under
#   cudaMallocAsync — it silently does nothing, which is why earlier attempts at this
#   flag alone didn't change the OOM at all. Only the native allocator honors it.
# - PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True avoids the fragmentation
#   (large gap between "reserved" and "allocated" CUDA memory) seen in the OOM trace.
# - --reserve-vram 2 gives the allocator extra headroom, same fix already used in
#   run-reserve-vram.sh for a prior MiniMax H3 OOM.
# - --lowvram forces per-layer weight streaming instead of trying to keep large
#   chunks of the model resident in VRAM — needed because the fp8 diffusion model
#   alone (~19GB on disk) is bigger than the card's entire 16GB VRAM budget.
# The workflow's CLIPLoader should also have its "device" widget set to "cpu" so the
# ~8GB text encoder never touches VRAM at all, leaving it free for the diffusion model.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMFY_ROOT="$(dirname "$SCRIPT_DIR")"

export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True

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
    python main.py --listen --reserve-vram 2 --lowvram --disable-cuda-malloc
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
    python main.py --disable-pinned-memory --use-sage-attention --reserve-vram 2 --lowvram --disable-cuda-malloc
elif $IS_WSL_KERNEL; then
    # Container running on a WSL2 host (Docker Desktop) — same pinned-memory
    # bug as bare-metal WSL, but still needs --listen since it's a container.
    python main.py --listen --use-sage-attention --reserve-vram 2 --disable-pinned-memory --lowvram --disable-cuda-malloc
else
    python main.py --listen --use-sage-attention --reserve-vram 2 --lowvram --disable-cuda-malloc
fi
