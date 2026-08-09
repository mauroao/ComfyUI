#!/bin/bash
set -euo pipefail

trap 'echo "ERROR: Command failed at line $LINENO with exit code $?" >&2; exit 1' ERR

GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMFY_ROOT="$(dirname "$SCRIPT_DIR")"

clone_node() {
  local url="$1"
  local dir="${2:-$(basename "$url" .git)}"
  rm -rf "$dir"
  git clone --depth 1 "$url" "$dir"
}

cd "$COMFY_ROOT/custom_nodes"
clone_node https://github.com/ltdrdata/ComfyUI-Manager comfyui-manager
clone_node https://github.com/Fannovel16/ComfyUI-Frame-Interpolation.git comfyui-frame-interpolation
clone_node https://github.com/Kosinkadink/ComfyUI-VideoHelperSuite.git comfyui-videohelpersuite
clone_node https://github.com/kijai/ComfyUI-WanVideoWrapper.git comfyui-wanvideowrapper
clone_node https://github.com/kijai/ComfyUI-KJNodes.git comfyui-kjnodes
clone_node https://github.com/DoctorDiffusion/ComfyUI-MediaMixer.git comfyui-mediamixer
clone_node https://github.com/city96/ComfyUI-GGUF ComfyUI-GGUF
clone_node https://github.com/welltop-cn/ComfyUI-TeaCache
clone_node https://github.com/yolain/ComfyUI-Easy-Use
clone_node https://github.com/rgthree/rgthree-comfy.git
clone_node https://github.com/ltdrdata/ComfyUI-Impact-Pack comfyui-impact-pack
clone_node https://github.com/ltdrdata/ComfyUI-Impact-Subpack.git comfyui-impact-subpack
clone_node https://github.com/Saganaki22/ComfyUI-sol-attn.git comfyui-sol-attn
clone_node https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler.git ComfyUI-SeedVR2_VideoUpscaler

# temporary fix from https://github.com/welltop-cn/ComfyUI-TeaCache/issues/178
ln -sf "$SCRIPT_DIR/files/nodes.py" "$COMFY_ROOT/custom_nodes/ComfyUI-TeaCache/nodes.py"

# comfyui-wan-frame-length isn't a clonable repo — it's a hand-written local node
# (a single INT primitive constrained to step=4 for WAN's 4n+1 frame-count rule),
# kept in mauro-files/files/ and symlinked into place like the TeaCache fix above.
mkdir -p "$COMFY_ROOT/custom_nodes/comfyui-wan-frame-length"
ln -sf "$SCRIPT_DIR/files/comfyui-wan-frame-length/__init__.py" "$COMFY_ROOT/custom_nodes/comfyui-wan-frame-length/__init__.py"

mkdir -p "$COMFY_ROOT/custom_nodes/comfyui-frame-interpolation/ckpts/rife"
FILE="$COMFY_ROOT/custom_nodes/comfyui-frame-interpolation/ckpts/rife/rife47.pth"
if [ ! -f "$FILE" ]; then
  wget -O "$FILE" https://huggingface.co/jasonot/mycomfyui/resolve/main/rife47.pth
fi

echo -e "${GREEN}All commands executed successfully.${NC}"
exit 0
