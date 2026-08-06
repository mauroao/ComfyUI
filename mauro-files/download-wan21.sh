#!/bin/bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMFY_ROOT="$(dirname "$SCRIPT_DIR")"

"$SCRIPT_DIR/scripts/install-aria-ffmpeg.sh" || exit 1
source "$SCRIPT_DIR/scripts/common.sh"

download_base_models

# Diffusion Model
cd "$COMFY_ROOT/models/diffusion_models/"
download_file "Wan2_1-I2V-14B-720P_fp8_e4m3fn.safetensors" "https://huggingface.co/Kijai/WanVideo_comfy/resolve/main/Wan2_1-I2V-14B-720P_fp8_e4m3fn.safetensors?download=true"
download_file "wan2.1_t2v_14B_fp8_e4m3fn.safetensors" "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/diffusion_models/wan2.1_t2v_14B_fp8_e4m3fn.safetensors?download=true"

# LoRAs
cd "$COMFY_ROOT/models/loras/"

# from https://civitai.com/user/ai_build_art:
download_file_v2 "wan_bounceV_01-i2v.safetensors" "https://civitai.com/api/download/models/1517164?type=Model&format=SafeTensor&token=${RP_TOKEN}"
download_file_v2 "wan_bounceV_01-t2v.safetensors" "https://civitai.com/api/download/models/1836649?type=Model&format=SafeTensor&token=${RP_TOKEN}"
download_file_v2 "wan_BouncyWalkV01.safetensors" "https://civitai.com/api/download/models/1537915?type=Model&format=SafeTensor&token=${RP_TOKEN}"

# from others:
download_file_v2 "wan_cumshot_i2v.safetensors" "https://civitai.com/api/download/models/1602715?type=Model&format=SafeTensor&token=${RP_TOKEN}"
download_file_v2 "wan_cumshot-I2V-22epo-k3nk-f4c3spl4sh.safetensors" "https://civitai.com/api/download/models/1952633?type=Model&format=SafeTensor&token=${RP_TOKEN}"
download_file_v2 "wan_Anime-CumShot-Emotion.safetensors" "https://civitai.com/api/download/models/1934867?type=Model&format=SafeTensor&token=${RP_TOKEN}"

# Private HuggingFace LoRAs (require HF_TOKEN):
download_file_hf_private "wan_s3xyv3n3r4-000022.safetensors" "https://huggingface.co/mauroao/lora_wan_2.1_t2v_s3xyv3n3r4/resolve/main/s3xyv3n3r4-000022.safetensors"

echo -e "${GREEN}All downloads completed successfully.${NC}"
exit 0
