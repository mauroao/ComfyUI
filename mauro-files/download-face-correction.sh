#!/bin/bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMFY_ROOT="$(dirname "$SCRIPT_DIR")"

"$SCRIPT_DIR/scripts/install-aria-ffmpeg.sh" || exit 1
source "$SCRIPT_DIR/scripts/common.sh"

# Face bbox detector for Impact-Pack's FaceDetailer (requires ComfyUI-Impact-Subpack)
mkdir -p "$COMFY_ROOT/models/ultralytics/bbox"
cd "$COMFY_ROOT/models/ultralytics/bbox"
download_file "face_yolov8m.pt" "https://huggingface.co/Bingsu/adetailer/resolve/main/face_yolov8m.pt?download=true"

CHECKPOINT="$COMFY_ROOT/models/checkpoints/juggernautXL_ragnarokBy.safetensors"
if [ ! -f "$CHECKPOINT" ]; then
  echo "Warning: SDXL checkpoint not found at $CHECKPOINT"
  echo "Run: bash $SCRIPT_DIR/download-sdxl.sh"
fi

echo -e "${GREEN}All downloads completed successfully.${NC}"
exit 0
