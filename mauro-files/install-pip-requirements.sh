#!/bin/bash
set -euo pipefail

trap 'echo "ERROR: Command failed at line $LINENO with exit code $?" >&2; exit 1' ERR

GREEN='\033[0;32m'
NC='\033[0m'

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMFY_ROOT="$(dirname "$SCRIPT_DIR")"

cd "$COMFY_ROOT"

pip install -r requirements.txt
pip install opencv-python

pip install -r "$COMFY_ROOT/custom_nodes/comfyui-manager/requirements.txt"
pip install -r "$COMFY_ROOT/custom_nodes/comfyui-frame-interpolation/requirements-no-cupy.txt"
pip install -r "$COMFY_ROOT/custom_nodes/comfyui-wanvideowrapper/requirements.txt"
pip install -r "$COMFY_ROOT/custom_nodes/comfyui-videohelpersuite/requirements.txt"
pip install -r "$COMFY_ROOT/custom_nodes/comfyui-kjnodes/requirements.txt"
pip install -r "$COMFY_ROOT/custom_nodes/comfyui-mediamixer/requirements.txt"
pip install -r "$COMFY_ROOT/custom_nodes/ComfyUI-GGUF/requirements.txt"
pip install -r "$COMFY_ROOT/custom_nodes/ComfyUI-TeaCache/requirements.txt"
pip install -r "$COMFY_ROOT/custom_nodes/ComfyUI-Easy-Use/requirements.txt"
pip install -r "$COMFY_ROOT/custom_nodes/rgthree-comfy/requirements.txt"
pip install -r "$COMFY_ROOT/custom_nodes/comfyui-impact-pack"

pip install --upgrade requests

if [[ "$(uname -s)" != "Darwin" ]]; then
  pip install triton
  pip install ninja packaging
fi
# pip install sageattention==1.0.6
# pip install "https://huggingface.co/Kijai/PrecompiledWheels/resolve/main/sageattention-2.2.0-cp312-cp312-linux_x86_64.whl"

echo -e "${GREEN}All commands executed successfully.${NC}"
exit 0
