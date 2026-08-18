#!/bin/bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMFY_ROOT="$(dirname "$SCRIPT_DIR")"

"$SCRIPT_DIR/scripts/install-aria-ffmpeg.sh" || exit 1
source "$SCRIPT_DIR/scripts/common.sh"

# Checkpoint (all-in-one: model + text encoder + VAE)
cd "$COMFY_ROOT/models/checkpoints/"
download_file "ace_step_1.5_turbo_aio.safetensors" "https://huggingface.co/Comfy-Org/ace_step_1.5_ComfyUI_files/resolve/main/checkpoints/ace_step_1.5_turbo_aio.safetensors"

echo -e "${GREEN}All downloads completed successfully.${NC}"
exit 0
