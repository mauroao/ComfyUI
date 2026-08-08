# CLAUDE.md

This is Mauro's fork of ComfyUI (`origin` = `mauroao/ComfyUI`), tracking `upstream` = `comfyanonymous/ComfyUI`. He runs it in three environments — WSL2/RTX 4060, MacBook M1, and a RunPod Docker image — each with its own setup under `mauro-files/`.

To re-check what's custom vs. stock at any time:
```
git diff $(git merge-base HEAD upstream/master) HEAD --stat
```

## What's custom (Mauro's) vs. stock ComfyUI

Everything is stock ComfyUI **except**:

- **`mauro-files/`** — entirely custom (see below).
- **`.dockerignore`** — new, for the RunPod image build.
- **`.gitignore`** — changed to track `user/default/workflows/` and `user/default/comfy.settings.json` instead of ignoring all of `/user/`.
- **`user/default/comfy.settings.json`** and **`user/default/workflows/{image,video}/*.json`** — his personal UI settings and saved workflows, organized into `image/`/`video/` subfolders.
- **`main.py`** — one intentional simplification: execution time is always logged as `HH:MM:SS`, not switched to seconds under 10 minutes like upstream. This is deliberate — don't "fix" it back to match upstream.
- **`input/example.png`** removed, **`output/_output_images_will_be_put_here`** added (empty placeholder).
- **`custom_nodes/*`** — installed locally via `mauro-files/install-custom-nodes.sh`, but **not git-tracked** (gitignored). Don't expect `git diff`/`git status` to show anything there.

Everything else (`comfy/`, `comfy_api/`, `comfy_execution/`, `comfy_extras/`, `api_server/`, `app/`, `server.py`, `execution.py`, `nodes.py`, `folder_paths.py`, `README.md`, etc.) is unmodified upstream ComfyUI.

**`AGENTS.md`** (repo root) is 100% upstream and already defines the engineering rules for touching core ComfyUI code (small diffs, no telemetry/internet requests, architecture-boundary rules). Follow it whenever changing anything outside `mauro-files/` — it isn't repeated here.

## The three execution environments

### 1. WSL2 + RTX 4060 (main dev / heaviest local generation)
- `.venv`-based: create it with `mauro-files/local-only/create_venv.sh` (run via `source` to keep it active). CUDA 12.8 toolkit via `mauro-files/local-only/install-cuda-toolkit.sh`, PyTorch cu128 wheels via `mauro-files/local-only/install-pytorch`, SageAttention 2.2.0 built from source via `mauro-files/install-sageattention.sh`.
- Launch with `mauro-files/run.sh` — detects `WSL_DISTRO_NAME`, pre-warms Triton, runs `python main.py --disable-pinned-memory --use-sage-attention`.
- `mauro-files/run-reserve-vram.sh` is the same launcher with `--reserve-vram 2` added — **marked TEMPORARY** in the script itself, used for debugging a MiniMax H3 OOM issue. Don't treat it as a permanent second entry point.
- `mauro-files/check.sh` is the dependency doctor: checks Python/torch/triton/sageattention/CUDA versions and prints a pass/fail table.

### 2. MacBook M1 (image-generation focus)
- `.venv`-based (same `create_venv.sh` as above). PyTorch nightly wheels via `mauro-files/local-only/install-pytorch-mac` (the `nightly/cpu` index is the correct way to get MPS-enabled torch on Apple Silicon — there's no separate "mps" wheel variant).
- Launch with the same `mauro-files/run.sh` — Darwin branch runs `python main.py --listen` (no SageAttention, it's CUDA-only).

### 3. RunPod Docker image (heavy video generation, higher resolutions)
- Built/pushed via `mauro-files/Makefile` (`make -C mauro-files docker-build` / `docker-push`, image tag `mauroao/runpod-comfy:0.1.14`) and `mauro-files/Dockerfile` (base `runpod/pytorch:1.1.0-cu1281-torch280-ubuntu2404`).
- No venv — system Python inside the container. Image build runs `install-custom-nodes.sh` + `install-pip-requirements.sh`.
- Same `run.sh` "else" branch: sets `AIOHTTP_NO_SENDFILE=1`, runs `python main.py --listen --use-sage-attention`.
- Models are pulled at container runtime via the `download-*.sh` scripts, not baked into the image.
- **Previous image pushed: `0.1.13` on 2026-04-04** (confirmed via Docker Hub), ~4 months and 700+ upstream commits stale by 2026-08-05 — that's why the base image was bumped to `1.1.0` and the tag to `0.1.14` (same CUDA 12.8.1 / torch 2.8.0 pins, deliberately not moving to CUDA 13 yet).
  - Upstream ComfyUI added a new hard pip dependency, `comfy-kitchen` (currently pinned `==0.2.26` in `requirements.txt`), which provides the fp8/int8/NVFP4 quantized tensor-core kernels used by newer model releases (incl. MiniMax H3, see below). `install-pip-requirements.sh` already installs it automatically via `pip install -r requirements.txt` — no script change needed.
  - Remember to bump `mauro-files/Makefile`'s `TAG` again on the *next* rebuild after this one, so `docker-push` doesn't silently overwrite `0.1.14`.

## Model download scripts (`mauro-files/download-*.sh`)

All share helpers from `mauro-files/scripts/common.sh`: `download_file` (aria2c), `download_file_v2` (wget, for Civitai), `download_file_hf_private` (wget + Bearer token, for private HF repos) — all skip downloads that already exist on disk. They also run `scripts/install-aria-ffmpeg.sh` first to make sure `aria2c`/`ffmpeg` are present.

Env vars required: `RP_TOKEN` (Civitai API token) for anything from civitai.com/civitai.red; `HF_TOKEN` (HuggingFace token) only for the private-HF calls.

- `download-sdxl.sh` — SDXL checkpoint + LoRAs for the `sdxl*` workflows.
- `download-face-correction.sh` — face bbox detector for Impact-Pack's FaceDetailer, used by `sdxl_face_correction` workflow; depends on the SDXL checkpoint above.
- `download-wan21.sh` — WAN 2.1 base models + LoRAs for the `wan-2.1-*` workflows.
- `download-wan22.sh` — WAN 2.2 base models + LoRAs (incl. SVI v2 PRO) for the `wan-2.2-*` workflows.
- `download-minimax.sh` — MiniMax H3 VAE/diffusion/text-encoder models for `video_minimax_h3_i2v`.

## RunPod GPU recommendations per video workflow

Model formats differ across the tracked video workflows, which changes which RunPod GPU class makes sense. General rule: fp8 needs Ada Lovelace or newer (RTX 40xx/L40S/RTX 50xx/H100/B-series all qualify — Ampere/A100 has no native fp8 tensor cores and will fall back to a slower path); NVFP4 specifically only gets native tensor-core acceleration on Blackwell (RTX 50xx, RTX PRO 6000 Blackwell, B200/B300 — compute capability sm_120). On older architectures NVFP4 still works (comfy-kitchen/`comfy/quant_ops.py` has a software stochastic-rounding fallback) but slower, with the same VRAM footprint.

- **`wan-2.1-T2V-768.json`, `wan-2.1-T2V-768-v2.json`, `wan-2.1-I2V-768.json`** — single 14B diffusion model in `fp8_e4m3fn` + UMT5-XXL fp8 text encoder. Fits comfortably on a 24GB card. Recommended: **RTX 4090 (24GB)**; RTX 5090 (32GB) if it's cheap/available for extra headroom with LoRAs stacked.
- **`wan-2.2-I2V-768-fp8.json`, `wan-2.2-FLF2V-768-fp8.json`** — WAN 2.2 MoE-style dual model (separate high-noise/low-noise 14B `fp8_scaled` checkpoints, swapped sequentially, not both resident at once) + same text encoder/VAE. Similar peak VRAM to 2.1 but more headroom is safer given the extra LoRA (lightx2v 4-step). Recommended: **RTX 4090 (24GB)** minimum, **RTX 5090 (32GB)** preferred.
- **`wan-2.2-SVI-v2.json`** — same dual-model base plus the Stable Video Infinity v2 PRO LoRAs for long-form/extended video generation, which keeps more frame context resident and raises peak VRAM meaningfully above the plain I2V workflow. Recommended: **RTX 5090 (32GB)**, or **L40S (48GB)** for longer clips/higher batch.
- **`video/minimax_h3_i2v_runpod.json`** (the WSL-local counterpart, `minimax_h3_i2v_wsl.json`, isn't a RunPod concern — see the tracked-workflows section above) — **requires a fresh Docker image.** MiniMax H3 support landed in upstream ComfyUI core on 2026-07-31/08-03 (`comfy_extras/nodes_minimax_h3.py`, `comfy/ldm/minimax/vae.py`, etc. — commits #15167/#15224/#15227), months after the `0.1.13` image (2026-04-04) was built. The current pushed image predates this node entirely and will fail to load the workflow (unrecognized node types) until rebuilt from current `master`. By far the heaviest workflow otherwise: `int8_convrot` diffusion model + a **32B-parameter Qwen3VL text encoder quantized to NVFP4** (`qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors`) + separate video/audio VAEs. The 32B NVFP4 text encoder alone is ~16GB+ of weights before activations, VAEs, and the diffusion model are even loaded. This needs both a Blackwell GPU (for native NVFP4 throughput) and a large VRAM pool. Recommended: **RTX PRO 6000 Blackwell (96GB)** as the sweet spot; **B200/B300** if throughput matters more than cost. A 32GB RTX 5090 is Blackwell (fast NVFP4) but likely too tight on VRAM once the text encoder, diffusion model, and both VAEs are resident together — worth testing with `--reserve-vram`/model offload before committing to it for production runs.
- **`sdxl.json`, `sdxl_face_correction.json`** — not video, but for reference: SDXL + Impact-Pack FaceDetailer is light by comparison, any 16GB+ Ada/Ampere card is fine.

**Why this matters for the fork specifically**: `mauro-files/run.sh` and `run-reserve-vram.sh` always pass `--use-sage-attention`, and SageAttention 2.2.0 (built via `mauro-files/install-sageattention.sh`) targets CUDA/Ada-class kernels — if a future workflow ever gets tested on non-Ada architectures on RunPod (e.g. an A100), confirm SageAttention still builds/runs there before assuming the same launch flags apply.

## Custom nodes

Installed via `mauro-files/install-custom-nodes.sh` (clones into `custom_nodes/`, which is gitignored — never expect these to show up in `git status`): comfyui-manager, comfyui-frame-interpolation, comfyui-videohelpersuite, comfyui-wanvideowrapper, comfyui-kjnodes, comfyui-mediamixer, ComfyUI-GGUF, ComfyUI-TeaCache, ComfyUI-Easy-Use, rgthree-comfy, comfyui-impact-pack, comfyui-impact-subpack.

The script also symlinks `mauro-files/files/nodes.py` over ComfyUI-TeaCache's own `nodes.py` — a fix for a [known upstream TeaCache issue](https://github.com/welltop-cn/ComfyUI-TeaCache/issues/178).

**Pending sync item**: `custom_nodes/comfyui-wan-frame-length` is installed locally but is *not yet* in `install-custom-nodes.sh` — remember to add it there once its setup is finalized.

## Tracked personal workflows (`user/default/workflows/`)

Tracked in git deliberately (see `.gitignore` change above), organized into subfolders by media type:

- `image/`: `sdxl.json`, `sdxl_face_correction.json`
- `video/`: `minimax_h3_i2v_runpod.json`, `minimax_h3_i2v_wsl.json`, `wan-2.1-T2V-768.json`, `wan-2.1-T2V-768-v2.json`, `wan-2.1-I2V-768.json`, `wan-2.2-I2V-768-fp8.json`, `wan-2.2-FLF2V-768-fp8.json`, `wan-2.2-SVI-v2.json`

`minimax_h3_i2v_runpod.json` is the stock MiniMax H3 workflow (int8 diffusion model + NVFP4 text encoder, no acceleration nodes) for the RunPod GPU. `minimax_h3_i2v_wsl.json` is a variant tuned for the WSL2/RTX 4060 Ti's 16GB VRAM: `ComfyUI-sol-attn`'s `MiniMaxH3ChunkFeedForward` node chunks the MLP forward to cap peak activation memory (currently `chunks=4`), letting the same int8/NVFP4 model run at higher resolutions than it otherwise could on 16GB. `user/default/comfy.settings.json` is his personal UI settings, also tracked.

## Guardrails

- Don't revert the `main.py` execution-time-formatting change — it's intentional.
- Anything outside `mauro-files/` and the tracked `user/default/` files is upstream ComfyUI core: follow `AGENTS.md` (minimal diffs, no telemetry/internet requests, respect architecture boundaries).
- Never run `git push` (per global user rules) — only commit locally unless explicitly asked otherwise.
