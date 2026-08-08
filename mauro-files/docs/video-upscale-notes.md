# Video upscale notes (2026-08)

Context: standalone upscale workflow `user/default/workflows/video/video_upscale_1080p.json` takes an already-rendered raw MiniMax H3 video (from `output/video/`) and upscales it, independent of the generation pipeline.

## What's currently installed and configured: SeedVR2

- Custom node: `custom_nodes/ComfyUI-SeedVR2_VideoUpscaler` (numz)
- Model: 3B FP8 (`seedvr2_ema_3b_fp8_e4m3fn.safetensors`) + `ema_vae_fp16.safetensors` — auto-downloads on first use
- Tuned for RTX 4060 Ti 16GB: `blocks_to_swap=16`, `swap_io_components=True`, `offload_device=cpu`, VAE tiling on
- `resolution` param targets the **shortest edge**, not height directly — for our 576×736 portrait source, `resolution=846` → ≈1080 on the long edge (height), preserving true aspect (not naive 3:4)

### Known limitation: flicker / ghosting in shadows and fine detail

SeedVR2 is diffusion-based — it regenerates fine detail (shadows, texture) per batch rather than deterministically upscaling pixels, so adjacent frames/batches can reconstruct slightly differently. This is a **documented, unresolved issue** acknowledged by the maintainer (see [discussion #187](https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler/discussions/187), [issue #217](https://github.com/numz/ComfyUI-SeedVR2_VideoUpscaler/issues/217)) — not something fixable purely through settings, only mitigated.

**Mitigation applied** (worked well for us): raised `batch_size` 9→21 and `temporal_overlap` 2→4 (both must follow 4n+1 for batch_size). Community reports mitigation up to `batch_size=101-121`, but that's tuned for cards with far more VRAM (RTX 5090) than we have to spare — 21 was a middle ground, not a guaranteed fix, and it worked.

## Alternative worth trying: FlashVSR (Alibaba)

Also diffusion-based, but purpose-built around a spatio-temporal/streaming-window architecture instead of independent batches — processes each frame together with neighboring frames in a continuous window, specifically targeting the flicker problem SeedVR2 has.

- **Much lower VRAM floor than SeedVR2**: works from ~4GB VRAM (vs SeedVR2's 3B-7B param DiT model) — real headroom advantage on our 16GB card
- ComfyUI nodes (pick one, several forks exist):
  - https://github.com/1038lab/ComfyUI-FlashVSR (built on FlashVSR V1.1)
  - https://github.com/jimly1/ComfyUI-FlashVSR_Ultra_Fast (low-VRAM optimized)
  - https://github.com/smthemex/ComfyUI_FlashVSR
- Modes: `tiny` (fast), `tiny-long` (lowest VRAM), `full` (highest quality, more VRAM)
- Recommended for smoother results: enable tile overlap for blending + wavelet color transfer (`color_fix`)
- Models auto-download to `ComfyUI/models/FlashVSR/`

**Not yet tried in this project — worth a real test given the lower VRAM cost.**

## Combo project claiming to beat Topaz: SECourses Upscaler Pro

Community guide combining **FlashVSR (video) + SeedVR2 (4x image upscale)** with automatic scene detection — splits video into scenes, upscales each separately, adds resume capability. Claims to beat Topaz AI on detail (visual comparisons only, no formal benchmarks).

- Guide: https://github.com/FurkanGozukara/Stable-Diffusion/wiki/SECourses-Upscaler-Pro-Beating-Topaz-AI-by-Far-With-Specalized-FlashVSR-and-SeedVR25-Local-Windows
- Works from 8GB VRAM (GGUF/FP8 models), demoed at 4K output on 16GB
- Key settings mentioned: DiT tiling **enabled**, VAE tiling explicitly **not recommended** by the guide's author

## Why Topaz Video AI doesn't flicker (for context, not something we run)

Topaz's older/faster models (Proteus, Artemis, Gaia) are **not diffusion** — CNN + optical-flow frame alignment, deterministic by design, built temporal-first rather than bolted on. Their newest 2026 flagship ("Starlight") moved to diffusion too, chasing the same quality ceiling as SeedVR2/FlashVSR — so even Topaz faces this tension at the high end. Their real edge: years of commercial polish, proprietary temporal-smoothing training data, and an explicit temporal-smoothing **post-process pass** after per-frame prediction that open-source pipelines don't include automatically (could be approximated manually with an optical-flow blend node after SeedVR2/FlashVSR, but that's DIY work, nothing off-the-shelf here yet).

## Quick decision guide

| Priority | Pick |
|---|---|
| Already working, good results | SeedVR2 with batch_size≥21, temporal_overlap≥4 (current setup) |
| Want to try lower VRAM / purpose-built anti-flicker | FlashVSR |
| Want max detail, willing to DIY scene-splitting | SECourses combo (FlashVSR + SeedVR2) |
