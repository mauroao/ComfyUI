#!/bin/bash
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
COMFY_ROOT="$(dirname "$SCRIPT_DIR")"

"$SCRIPT_DIR/scripts/install-aria-ffmpeg.sh" || exit 1
source "$SCRIPT_DIR/scripts/common.sh"

# VAE
cd "$COMFY_ROOT/models/vae/"
download_file "minimax_h3_video_vae_fp16.safetensors" "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_video_vae_fp16.safetensors"
download_file "minimax_h3_audio_vae_fp32.safetensors" "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/vae/minimax_h3_audio_vae_fp32.safetensors"

# Diffusion Models
cd "$COMFY_ROOT/models/diffusion_models/"
download_file "minimax_h3_fl2va_pruned_int8_convrot.safetensors" "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/diffusion_models/minimax_h3_fl2va_pruned_int8_convrot.safetensors"

# Text Encoders
cd "$COMFY_ROOT/models/text_encoders/"
download_file "qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors" "https://huggingface.co/Comfy-Org/MiniMax-H3/resolve/main/text_encoders/qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors"

# Upscale Model
cd "$COMFY_ROOT/models/upscale_models/"
download_file "RealESRGAN_x2.pth" "https://huggingface.co/ai-forever/Real-ESRGAN/resolve/a86fc6182b4650b4459cb1ddcb0a0d1ec86bf3b0/RealESRGAN_x2.pth?download=true"

echo -e "${GREEN}All downloads completed successfully.${NC}"
exit 0
