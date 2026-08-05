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
- **`user/default/comfy.settings.json`** and **`user/default/workflows/*.json`** — his personal UI settings and saved workflows.
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
- Built/pushed via `mauro-files/Makefile` (`make -C mauro-files docker-build` / `docker-push`, image tag `mauroao/runpod-comfy`) and `mauro-files/Dockerfile` (base `runpod/pytorch:1.0.2-cu1281-torch280-ubuntu2404`).
- No venv — system Python inside the container. Image build runs `install-custom-nodes.sh` + `install-pip-requirements.sh`.
- Same `run.sh` "else" branch: sets `AIOHTTP_NO_SENDFILE=1`, runs `python main.py --listen --use-sage-attention`.
- Models are pulled at container runtime via the `download-*.sh` scripts, not baked into the image.

## Model download scripts (`mauro-files/download-*.sh`)

All share helpers from `mauro-files/scripts/common.sh`: `download_file` (aria2c), `download_file_v2` (wget, for Civitai), `download_file_hf_private` (wget + Bearer token, for private HF repos) — all skip downloads that already exist on disk. They also run `scripts/install-aria-ffmpeg.sh` first to make sure `aria2c`/`ffmpeg` are present.

Env vars required: `RP_TOKEN` (Civitai API token) for anything from civitai.com/civitai.red; `HF_TOKEN` (HuggingFace token) only for the private-HF calls.

- `download-sdxl.sh` — SDXL checkpoint + LoRAs for the `sdxl*` workflows.
- `download-face-correction.sh` — face bbox detector for Impact-Pack's FaceDetailer, used by `sdxl_face_correction` workflow; depends on the SDXL checkpoint above.
- `download-wan21.sh` — WAN 2.1 base models + LoRAs for the `wan-2.1-*` workflows.
- `download-wan22.sh` — WAN 2.2 base models + LoRAs (incl. SVI v2 PRO) for the `wan-2.2-*` workflows.
- `download-minimax.sh` — MiniMax H3 VAE/diffusion/text-encoder models for `video_minimax_h3_i2v`.

## Custom nodes

Installed via `mauro-files/install-custom-nodes.sh` (clones into `custom_nodes/`, which is gitignored — never expect these to show up in `git status`): comfyui-manager, comfyui-frame-interpolation, comfyui-videohelpersuite, comfyui-wanvideowrapper, comfyui-kjnodes, comfyui-mediamixer, ComfyUI-GGUF, ComfyUI-TeaCache, ComfyUI-Easy-Use, rgthree-comfy, comfyui-impact-pack, comfyui-impact-subpack.

The script also symlinks `mauro-files/files/nodes.py` over ComfyUI-TeaCache's own `nodes.py` — a fix for a [known upstream TeaCache issue](https://github.com/welltop-cn/ComfyUI-TeaCache/issues/178).

**Pending sync item**: `custom_nodes/comfyui-wan-frame-length` is installed locally but is *not yet* in `install-custom-nodes.sh` — remember to add it there once its setup is finalized.

## Tracked personal workflows (`user/default/workflows/`)

Tracked in git deliberately (see `.gitignore` change above): `sdxl.json`, `sdxl_face_correction.json`, `video_minimax_h3_i2v.json`, `wan-2.1-T2V-768.json`, `wan-2.1-T2V-768-v2.json`, `wan-2.1-I2V-768.json`, `wan-2.2-I2V-768-fp8.json`, `wan-2.2-FLF2V-768-fp8.json`, `wan-2.2-SVI-v2.json`. `user/default/comfy.settings.json` is his personal UI settings, also tracked.

## Guardrails

- Don't revert the `main.py` execution-time-formatting change — it's intentional.
- Anything outside `mauro-files/` and the tracked `user/default/` files is upstream ComfyUI core: follow `AGENTS.md` (minimal diffs, no telemetry/internet requests, respect architecture boundaries).
- Never run `git push` (per global user rules) — only commit locally unless explicitly asked otherwise.
