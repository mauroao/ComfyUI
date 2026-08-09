#!/bin/bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMFY_ROOT="$(dirname "$SCRIPT_DIR")"

"$SCRIPT_DIR/scripts/install-aria-ffmpeg.sh" || exit 1
source "$SCRIPT_DIR/scripts/common.sh"

# Diffusion Model
cd "$COMFY_ROOT/models/diffusion_models/"
download_file "qwen_image_edit_2509_fp8_e4m3fn.safetensors" "https://huggingface.co/Comfy-Org/Qwen-Image-Edit_ComfyUI/resolve/main/split_files/diffusion_models/qwen_image_edit_2509_fp8_e4m3fn.safetensors"

# LoRA
cd "$COMFY_ROOT/models/loras/"
download_file "Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors" "https://huggingface.co/lightx2v/Qwen-Image-Lightning/resolve/main/Qwen-Image-Edit-2509/Qwen-Image-Edit-2509-Lightning-4steps-V1.0-bf16.safetensors"

# Text Encoder
cd "$COMFY_ROOT/models/text_encoders/"
download_file "qwen_2.5_vl_7b_fp8_scaled.safetensors" "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/text_encoders/qwen_2.5_vl_7b_fp8_scaled.safetensors"

# VAE
cd "$COMFY_ROOT/models/vae/"
download_file "qwen_image_vae.safetensors" "https://huggingface.co/Comfy-Org/Qwen-Image_ComfyUI/resolve/main/split_files/vae/qwen_image_vae.safetensors"

echo -e "${GREEN}All downloads completed successfully.${NC}"
exit 0
