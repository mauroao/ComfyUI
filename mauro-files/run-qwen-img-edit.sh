#!/bin/bash
# Tuned for image/qwen_image_edit_2509.json on 16GB cards: the fp8 diffusion model
# (~19GB on disk) plus the fp8 text encoder (~8GB loaded) don't fit together in VRAM
# at once, and PyTorch's allocator can fragment badly when they're loaded back to back.
#
# - --disable-cuda-malloc forces ComfyUI onto PyTorch's native CUDA allocator instead
#   of its default cudaMallocAsync backend. This matters because
#   PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True (below) is a no-op under
#   cudaMallocAsync — it silently does nothing, which is why earlier attempts at this
#   flag alone didn't change the OOM at all. Only the native allocator honors it.
# - PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True avoids the fragmentation
#   (large gap between "reserved" and "allocated" CUDA memory) seen in the OOM trace.
# - --reserve-vram 2 gives the allocator extra headroom.
# - --lowvram forces per-layer weight streaming instead of trying to keep large
#   chunks of the model resident in VRAM — needed because the fp8 diffusion model
#   alone (~19GB on disk) is bigger than the card's entire 16GB VRAM budget.
# The workflow's CLIPLoader should also have its "device" widget set to "cpu" so the
# ~8GB text encoder never touches VRAM at all, leaving it free for the diffusion model.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"

export PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True
EXTRA_ARGS=(--reserve-vram 2 --lowvram --disable-cuda-malloc)

source "$SCRIPT_DIR/scripts/run-common.sh"
