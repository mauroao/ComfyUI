#!/bin/bash
set -euo pipefail

trap 'echo "ERROR: Command failed at line $LINENO with exit code $?" >&2; exit 1' ERR

GREEN='\033[0;32m'
NC='\033[0m'

# Check if the RP_TOKEN variable is set and not empty
if [ -z "${RP_TOKEN:-}" ]; then
    echo "Error: RP_TOKEN is not set. Aborting."
    exit 1
fi

download_file() {
    local target_path=$1
    local url=$2

    if [ -f "$target_path" ]; then
        echo "Skipping: $target_path already exists."
        return 0
    fi

    echo "Downloading: $target_path"
    aria2c -x 16 -s 16 -o "$target_path" "$url"
}

download_file_v2() {
    local target_path=$1
    local url=$2

    if [ -f "$target_path" ]; then
        echo "Skipping: $target_path already exists."
        return 0
    fi

    echo "Downloading: $target_path"
    wget -O "$target_path" "$url"
}

download_file_hf_private() {
    local target_path=$1
    local url=$2

    if [ -f "$target_path" ]; then
        echo "Skipping: $target_path already exists."
        return 0
    fi

    if [ -z "${HF_TOKEN:-}" ]; then
        echo "Error: HF_TOKEN is not set. Cannot download private HuggingFace file: $target_path"
        exit 1
    fi

    echo "Downloading (private HF): $target_path"
    wget --header "Authorization: Bearer ${HF_TOKEN}" -O "$target_path" "$url"
}

download_base_models() {
    # Text Encoders
    cd "$COMFY_ROOT/models/text_encoders/"
    download_file "umt5_xxl_fp8_e4m3fn_scaled.safetensors" "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/text_encoders/umt5_xxl_fp8_e4m3fn_scaled.safetensors?download=true"

    # CLIP Vision
    cd "$COMFY_ROOT/models/clip_vision/"
    download_file "clip_vision_h.safetensors" "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/clip_vision/clip_vision_h.safetensors?download=true"

    # VAE
    cd "$COMFY_ROOT/models/vae/"
    download_file "wan_2.1_vae.safetensors" "https://huggingface.co/Comfy-Org/Wan_2.1_ComfyUI_repackaged/resolve/main/split_files/vae/wan_2.1_vae.safetensors?download=true"

    # Upscale Models
    cd "$COMFY_ROOT/models/upscale_models/"
    download_file "RealESRGAN_x2.pth" "https://huggingface.co/ai-forever/Real-ESRGAN/resolve/a86fc6182b4650b4459cb1ddcb0a0d1ec86bf3b0/RealESRGAN_x2.pth?download=true"
}
