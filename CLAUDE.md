# CLAUDE.md

This is Mauro's fork of ComfyUI (`origin` = `mauroao/ComfyUI`), tracking `upstream` = `comfyanonymous/ComfyUI`. He runs it in three environments — WSL2/RTX 4060, MacBook M1, and a RunPod Docker image — each with its own setup under `mauro-files/`.

Last merged with `upstream/master` on 2026-11-10 (pulled in `MiniMaxH3AddGuide`, needed by `video/minimax_h3_ref2va_wsl.json`). The only merge conflict was `main.py`'s timing log, which kept the fork's version (see below).

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
- `mauro-files/run*.sh` launchers share one skeleton, `mauro-files/scripts/run-common.sh` (env detection via `WSL_DISTRO_NAME`/`uname`, `.venv` check, Triton pre-warm, the final per-environment `python main.py` invocation). Each `run-*.sh` is a thin wrapper: it sets an `EXTRA_ARGS` bash array (plus any extra env vars) and sources the common script — never edit the detection/pre-warm logic in more than one place again, it only lives in `run-common.sh` now.
  - `mauro-files/run.sh` — baseline, `EXTRA_ARGS=()`. Runs `python main.py --disable-pinned-memory --use-sage-attention` on WSL (see per-environment variants below).
  - `mauro-files/run-minimax.sh` — adds `--reserve-vram 2`, for `video/minimax_h3_i2v_wsl.json` on the 16GB card (renamed from `run-reserve-vram.sh`).
  - `mauro-files/run-qwen-image-edit.sh` — tuned for `image/qwen_image_edit_2509.json` and `image/qwen_image_edit_2511.json` on the 16GB card (renamed from `run-qwen-img-edit.sh` to match the `download-qwen-image-edit-*.sh` naming): adds `--reserve-vram 2`, `--lowvram`, `--disable-cuda-malloc`, and exports `PYTORCH_CUDA_ALLOC_CONF=expandable_segments:True`. Needed because the fp8 diffusion model alone (~19GB on disk) is bigger than the card's entire 16GB VRAM budget. Note: ComfyUI defaults to the `cudaMallocAsync` CUDA backend, under which `expandable_segments:True` is silently a no-op — `--disable-cuda-malloc` is required to force the native PyTorch allocator that actually honors it; without it the OOM reproduces identically regardless of the other flags. Pairs with setting the workflow's `CLIPLoader` `device` widget to `"cpu"` (already done), which keeps the ~8GB text encoder off VRAM entirely.
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
- `download-minimax.sh` — MiniMax H3 VAE/diffusion/text-encoder models for `video_minimax_h3_i2v`, plus the larryvrh v4-600 EMA Turbo LoRA (drbaph's pruned-checkpoint conversion) for `video/minimax_h3_i2v_wsl_turbo.json`. It also downloads the `ref2va` checkpoint (`minimax_h3_ref2va_pruned_int8_convrot`, ~21GB) and the official `minimax_h3_ref2v_turbo_4step_v0.1` LoRA for `video/minimax_h3_ref2va_wsl.json`.
- `download-qwen-image-edit-2509.sh` — Qwen-Image-Edit-2509 fp8 diffusion model + Lightning 4-step LoRA + Qwen2.5-VL-7B fp8 text encoder + Qwen VAE, for `image/qwen_image_edit_2509.json`.
- `download-qwen-image-edit-2511.sh` — Qwen-Image-Edit-2511 `fp8mixed` diffusion model + 2511 Lightning 4-step LoRA, plus the same text encoder and VAE as 2509 (already-present files are skipped), for `image/qwen_image_edit_2511.json`.
- `download-ace-step.sh` — ACE-Step 1.5 Turbo all-in-one checkpoint (model + text encoder + VAE in one file), for `audio/ace_step_1_5_m2m_retake.json`.

## RunPod GPU recommendations per video workflow

Model formats differ across the tracked video workflows, which changes which RunPod GPU class makes sense. General rule: fp8 needs Ada Lovelace or newer (RTX 40xx/L40S/RTX 50xx/H100/B-series all qualify — Ampere/A100 has no native fp8 tensor cores and will fall back to a slower path); NVFP4 specifically only gets native tensor-core acceleration on Blackwell (RTX 50xx, RTX PRO 6000 Blackwell, B200/B300 — compute capability sm_120). On older architectures NVFP4 still works (comfy-kitchen/`comfy/quant_ops.py` has a software stochastic-rounding fallback) but slower, with the same VRAM footprint.

- **`wan-2.1-T2V-768.json`, `wan-2.1-T2V-768-v2.json`, `wan-2.1-I2V-768.json`** — single 14B diffusion model in `fp8_e4m3fn` + UMT5-XXL fp8 text encoder. Fits comfortably on a 24GB card. Recommended: **RTX 4090 (24GB)**; RTX 5090 (32GB) if it's cheap/available for extra headroom with LoRAs stacked.
- **`wan-2.2-I2V-768-fp8.json`, `wan-2.2-FLF2V-768-fp8.json`** — WAN 2.2 MoE-style dual model (separate high-noise/low-noise 14B `fp8_scaled` checkpoints, swapped sequentially, not both resident at once) + same text encoder/VAE. Similar peak VRAM to 2.1 but more headroom is safer given the extra LoRA (lightx2v 4-step). Recommended: **RTX 4090 (24GB)** minimum, **RTX 5090 (32GB)** preferred.
- **`wan-2.2-SVI-v2.json`** — same dual-model base plus the Stable Video Infinity v2 PRO LoRAs for long-form/extended video generation, which keeps more frame context resident and raises peak VRAM meaningfully above the plain I2V workflow. Recommended: **RTX 5090 (32GB)**, or **L40S (48GB)** for longer clips/higher batch.
- **`video/minimax_h3_i2v_runpod.json`** (the WSL-local counterpart, `minimax_h3_i2v_wsl.json`, isn't a RunPod concern — see the tracked-workflows section above) — **requires a fresh Docker image.** MiniMax H3 support landed in upstream ComfyUI core on 2026-07-31/08-03 (`comfy_extras/nodes_minimax_h3.py`, `comfy/ldm/minimax/vae.py`, etc. — commits #15167/#15224/#15227), months after the `0.1.13` image (2026-04-04) was built. The current pushed image predates this node entirely and will fail to load the workflow (unrecognized node types) until rebuilt from current `master`. By far the heaviest workflow otherwise: `int8_convrot` diffusion model + a **32B-parameter Qwen3VL text encoder quantized to NVFP4** (`qwen3vl_32b_minimax_h3_nvfp4_awq.safetensors`) + separate video/audio VAEs. The 32B NVFP4 text encoder alone is ~16GB+ of weights before activations, VAEs, and the diffusion model are even loaded. This needs both a Blackwell GPU (for native NVFP4 throughput) and a large VRAM pool. Recommended: **RTX PRO 6000 Blackwell (96GB)** as the sweet spot; **B200/B300** if throughput matters more than cost. A 32GB RTX 5090 is Blackwell (fast NVFP4) but likely too tight on VRAM once the text encoder, diffusion model, and both VAEs are resident together — worth testing with `--reserve-vram`/model offload before committing to it for production runs.
- **`sdxl.json`, `sdxl_face_correction.json`** — not video, but for reference: SDXL + Impact-Pack FaceDetailer is light by comparison, any 16GB+ Ada/Ampere card is fine.

**Why this matters for the fork specifically**: all `mauro-files/run*.sh` launchers always pass `--use-sage-attention` (baked into `run-common.sh`), and SageAttention 2.2.0 (built via `mauro-files/install-sageattention.sh`) targets CUDA/Ada-class kernels — if a future workflow ever gets tested on non-Ada architectures on RunPod (e.g. an A100), confirm SageAttention still builds/runs there before assuming the same launch flags apply.

## Custom nodes

Installed via `mauro-files/install-custom-nodes.sh` (clones into `custom_nodes/`, which is gitignored — never expect these to show up in `git status`): comfyui-manager, comfyui-frame-interpolation, comfyui-videohelpersuite, comfyui-wanvideowrapper, comfyui-kjnodes, comfyui-mediamixer, ComfyUI-GGUF, ComfyUI-TeaCache, ComfyUI-Easy-Use, rgthree-comfy, comfyui-impact-pack, comfyui-impact-subpack, comfyui-sol-attn, ComfyUI-SeedVR2_VideoUpscaler, ComfyUI-MiniMax-H3-Turbo, comfyui_controlnet_aux, ComfyUI-OpenPose-Studio, ComfyUI-JoyCaption.

`ComfyUI-JoyCaption` (1038lab) runs JoyCaption Beta One, an uncensored VLM built for LoRA dataset captions, for `utils/joycaption_dataset_captions.json`. Its `requirements.txt` (adds `bitsandbytes` and `compressed-tensors`) is installed by `install-pip-requirements.sh`. Upstream `JC.py` breaks on transformers 5 in two ways. It crashes with `'SizeDict' object cannot be interpreted as an integer`. Its bare `llm_int8_skip_modules` names (`vision_tower`, …) no longer match transformers 5's full module paths, so the vision tower gets quantized too. The install script symlinks the patched copy from `mauro-files/files/ComfyUI-JoyCaption/JC.py` over it, same pattern as the TeaCache fix. Models auto-download from HF into `models/LLM/<repo name>` on first use, so there's no `download-*.sh` entry.

`comfyui_controlnet_aux` (Fannovel16) supplies `DWPreprocessor` and `ComfyUI-OpenPose-Studio` (andreszs) supplies the `OpenPoseStudio` editor/renderer node, both used by the pose workflows below. Their pip requirements are installed by `install-pip-requirements.sh` (OpenPose Studio has none of its own).

`ComfyUI-MiniMax-H3-Turbo` (Larryvrh) supplies the `MiniMaxH3TurboLoRA` and `MiniMaxH3TurboSampler` nodes used by `video/minimax_h3_i2v_wsl_turbo.json` (see below) — pure Python, no extra pip deps (`dependencies = []` in its `pyproject.toml`), so nothing beyond the git clone is needed in `.venv`.

The script also symlinks `mauro-files/files/nodes.py` over ComfyUI-TeaCache's own `nodes.py` — a fix for a [known upstream TeaCache issue](https://github.com/welltop-cn/ComfyUI-TeaCache/issues/178).

`custom_nodes/comfyui-wan-frame-length` isn't cloned from anywhere — it's a hand-written local node (a single INT primitive constrained to `step=4`, for WAN's 4n+1 frame-count rule) with no upstream repo. Its source lives in `mauro-files/files/comfyui-wan-frame-length/__init__.py` and the install script symlinks it into `custom_nodes/`, same pattern as the TeaCache fix above.

`ComfyUI-SeedVR2_VideoUpscaler` also needs its own `requirements.txt` installed — `mauro-files/install-pip-requirements.sh` has a line for it alongside the other per-node requirement installs.

## Tracked personal workflows (`user/default/workflows/`)

Tracked in git deliberately (see `.gitignore` change above), organized into subfolders by media type:

- `image/`: `sdxl.json`, `sdxl_face_correction.json`, `qwen_image_edit_2509.json`, `qwen_image_edit_2511.json`, `qwen_image_edit_2511_venera_lora.json`, `qwen_image_edit_2511_venera_lora_pose.json`, `pose_from_text.json`
- `video/`: `minimax_h3_i2v_runpod.json`, `minimax_h3_i2v_wsl.json`, `minimax_h3_i2v_wsl_turbo.json`, `minimax_h3_flf_wsl_turbo.json`, `minimax_h3_ref2va_wsl.json`, `wan-2.1-T2V-768.json`, `wan-2.1-T2V-768-v2.json`, `wan-2.1-I2V-768.json`, `wan-2.2-I2V-768-fp8.json`, `wan-2.2-FLF2V-768-fp8.json`, `wan-2.2-SVI-v2.json`, `video_upscale_1080p.json`
- `audio/`: `ace_step_1_5_m2m_retake.json`
- `utils/`: `joycaption_dataset_captions.json`

`minimax_h3_i2v_runpod.json` is the stock MiniMax H3 workflow (int8 diffusion model + NVFP4 text encoder, no acceleration nodes) for the RunPod GPU. `minimax_h3_i2v_wsl.json` is a variant tuned for the WSL2/RTX 4060 Ti's 16GB VRAM: `ComfyUI-sol-attn`'s `MiniMaxH3ChunkFeedForward` node chunks the MLP forward to cap peak activation memory (currently `chunks=4`), letting the same int8/NVFP4 model run at higher resolutions than it otherwise could on 16GB. `user/default/comfy.settings.json` is his personal UI settings, also tracked.

`minimax_h3_i2v_wsl_turbo.json` is `minimax_h3_i2v_wsl.json` plus the larryvrh v4-600 EMA Turbo LoRA (via `ComfyUI-MiniMax-H3-Turbo`'s `MiniMaxH3TurboLoRA`/`MiniMaxH3TurboSampler` nodes, inserted after the existing `MiniMaxH3ChunkFeedForward`), steps dropped 16→8. Chosen after comparing the available MiniMax H3 acceleration LoRAs (larryvrh, lightx2v/ModelTC, joyfox) against an independent quantitative benchmark ([jo-nike/h3-turbo-eval](https://jo-nike.github.io/h3-turbo-eval/)): larryvrh's EMA LoRA at 8 steps tracked the 20-step baseline closely (~0.95× normalized detail, same "take" when combined with SageAttention), while lightx2v v0.1 measurably lost fine detail and was jitterier on low-motion shots — exactly the slow/static-camera style of these prompts. Confirmed working by Mauro on 2026-08-12 — good quality, meaningfully faster than the 16-step baseline. `low_vram` is left off (bypass mode, sharper) on the LoRA node; switch it on if a shot OOMs.

`minimax_h3_flf_wsl_turbo.json` is the first+last-frame (FL2VA) counterpart of `minimax_h3_i2v_wsl_turbo.json`: same graph, plus a second `LoadImage` wired into the subgraph's `last_frame` input. No new model is needed — the checkpoint is already the `fl2va` one and `MiniMaxH3ImageToVideo` pins `last_frame` to the final frame index. The prompt's first line is the official FL2VA alignment line (from MiniMax-AI/MiniMax-H3's `h3-prompt-writing` guide) instead of the I2VA one; its `S.SS` timecode is hardcoded to `14.38` (14s duration → 345 frames snapped to the 17k+5 grid → 345/24) and must be edited by hand whenever the duration primitive changes. The first frame is stretched to the canvas but the last frame is center-cropped, so both images should share the canvas aspect ratio. Untested caveat: the larryvrh Turbo LoRA was benchmarked on I2V only; if the ending snaps or loses quality, compare against the non-turbo 16-step workflow, or try lightx2v's FL2V-specific Turbo LoRA v1.0. Good last frames can be made with `qwen_image_edit_2511.json` starting from the first frame.

`minimax_h3_ref2va_wsl.json` targets the **character drift** of `minimax_h3_i2v_wsl_turbo.json`, where a very specific face/body slowly turns generic over the clip. In i2va the identity only comes from the frame-0 keyframe. ref2va (separate `minimax_h3_ref2va_pruned_int8_convrot` checkpoint, same size as fl2va) keeps up to 9 reference images in context at every step and frame instead. The workflow is built from the official `video_minimax_h3_multiframe_reference` template (flat graph, no generation subgraph):
- The start image is `ref_image_0` (`<Picture 1>`) **and** goes through `MiniMaxH3AddGuide` at `frame_idx=0` to lock the exact first frame. The official template uses no guide at 0s and relies on the prompt alone, so bypass that node to go back to that behaviour.
- Three more `LoadImage` nodes feed `<Picture 2..4>` as identity photos (face close-up, full body, another angle). The node grows more slots, up to 9. They default to the start image as a placeholder, so swap in real photos.
- The prompt uses the official ref2va sections (`subject_definitions`, `summary`, `retention_analysis` with `fully_preserved`, `detailed_description`, `overall_soundscape`, `non_diegetic_music`) and names her `<Subject 1>`. cfg 1, no negative.
- Model chain: `UNETLoader` → `MiniMaxH3ChunkFeedForward` (sol-attn, same as the i2v WSL workflows) → official switch "Enable ref2v Turbo LoRA". Off means 20 steps, the default, best identity. On means the official 4-step ref2v LoRA, which the docs say weakens reference adherence. The larryvrh LoRA isn't used, since it was trained on fl2va.
- A bypassed `LoraLoaderModelOnly` at 0.5 lets you try the fl2va-trained Civitai LoRAs; how well they work on ref2va is unknown.
- Filename counter, raw `SaveVideo` and the bypassed Upscale group are copied from the turbo workflow. Launch with `run-minimax.sh`.
- Untested on the 4060 Ti as of 2026-11-10. If it OOMs, lower the duration first; `ref_image_size=max` is much slower.

`qwen_image_edit_2511.json` is the multi-image (v2) counterpart of `qwen_image_edit_2509.json`: same subgraph (renamed `Image Edit (Qwen 2511)`), with the Qwen-Image-Edit-2511 `fp8mixed` model + 2511 Lightning LoRA and a second `LoadImage` wired into the subgraph's `image2` input (`image3` is still free). 2511 was picked over 2509 for its better multi-input/identity consistency, and over Qwen-Image-2.1 (Sep 2026, 7B, up to 10 refs) because 2.1 needs an upstream merge newer than this fork's base plus a new text encoder. Things to know: Picture 1 alone defines the output size (it's the only one VAE-encoded into the starting latent); every input is internally rescaled to ~1MP by `TextEncodeQwenImageEditPlus`, so downscaling Picture 2 doesn't save VRAM; prompts should refer to inputs as "Picture 1"/"Picture 2", the labels that node injects. Each extra reference adds ~4k tokens (~40–50% slower), not a weight-size change, so `run-qwen-image-edit.sh` is reused as is. ComfyUI auto-detects 2511 from the checkpoint (`__index_timestep_zero__` key in `comfy/model_detection.py`), no extra reference-method node needed.

**Pose control for Qwen-Image-Edit 2511.** Text-only framing instructions ("head near top, cut at knees") are unreliable in `qwen_image_edit_2511_venera_lora.json`, because the model tends to zoom out. Qwen-Image-Edit 2509/2511 accept OpenPose keypoint maps natively as an ordinary extra input image, so no ControlNet model is needed. There is no usable text→skeleton model, so the pipeline is in two steps:
- `pose_from_text.json`: SDXL (`juggernautXL_ragnarokBy`) renders 4 generic reference photos from a natural-language pose/framing prompt (896×1152, ≈ Picture 1's aspect). `ImageFromBatch` picks one, then `DWPreprocessor` (torchscript bbox + pose models, auto-downloaded) extracts the skeleton into `OpenPoseStudio` for manual touch-up. The edited pose is exported as JSON (`OPS_ShowString`) and as a PNG in `output/pose/`. Gotcha: while DWPose is linked into OpenPose Studio's `pose_keypoint`, it overrides the edited `pose_json` widget on every queue, so delete that link after editing.
- `qwen_image_edit_2511_venera_lora_pose.json`: copy of the Venera LoRA workflow where Picture 2 (`image2`) is an `OpenPoseStudio` node (paste the JSON into it, `render_face` off by default). The prompt is prefixed with a Picture 1/Picture 2 pose-and-framing instruction, and the negative prompt has anti-skeleton/anti-wide-shot terms.

`video_upscale_1080p.json` is a standalone SeedVR2 upscale + RIFE interpolation pipeline — takes an already-rendered raw video from `output/video/` and upscales it to ~1080p independent of the generation workflow that made it. Light compared to everything else here: DiT 3B fp8 (~3.2GB) + VAE (~0.5GB), both auto-download on first use (no `download-*.sh` entry needed). Tuned for the WSL2 16GB card (`blocks_to_swap=16`, `offload_device=cpu`, VAE tiling) but small enough it should also just work on the MacBook M1 — the `SeedVR2LoadDiTModel`/`SeedVR2LoadVAEModel` nodes have `cuda:0` hardcoded as the device widget though, which would need changing to `mps` there first. Full notes (flicker/ghosting mitigation, FlashVSR as an alternative): `mauro-files/docs/video-upscale-notes.md`.

`joycaption_dataset_captions.json` captions a folder of images for character LoRA training. `ImageBatchPath` reads every `.jpg/.jpeg/.png/.webp` in `image_dir` (absolute path, no subfolders) as a list, so the following nodes run once per image. Each image goes through `JC_adv` (JoyCaption Advanced). A `StringConcatenate` ("Trigger tag prefix") then prepends the character trigger (`s3xyv3n3r4, `) in code, since that's more reliable than asking the model. Finally `CaptionSaver` writes `<image stem>.txt` into the image's own folder.
- The captioning instruction lives in `JC_adv`'s `custom_prompt`. It reuses JoyCaption's own trained extra-option phrasing ("refer to them as …", "Do NOT include information about people/characters that cannot be changed…"), which it follows better than free-form instructions. The default asks for ≤60 words and calls the subject "the woman". It covers scene, lighting, pose, clothing, hairstyle and framing, and leaves out permanent physical traits so those get learned into the trigger. Close-ups whose subject *is* a body part still leak traits like "large breasts", so review those captions by hand. If `custom_prompt` is cleared, the node falls back to `prompt_style` + `caption_length` + an optional `JC_ExtraOptions` node.
- Model `joycaption-beta-one` (`1038lab/llama-joycaption-beta-one`, bf16 weights) loaded as **`Maximum Savings (4-bit)`** (NF4, ~7–8GB VRAM). Tested on 2026-11-11 with 33 images in ~2:46.
  - **Don't use `Balanced (8-bit)`**: bitsandbytes' int8 matmul segfaults and kills the whole server whenever ComfyUI core's `comfy_kitchen` is imported. The crash reproduces outside ComfyUI with just `import comfy_kitchen`. No run flag helps (tried `--disable-dynamic-vram`, no custom nodes, no SageAttention, `cudaMallocAsync`).
  - **Don't use `joycaption-beta-one-fp8`**: under transformers 5 its compressed-tensors checkpoint loads with mismatched keys (`o_projweight` UNEXPECTED, `weight_scale` MISSING), so the weights are garbage.
- `CaptionSaver` with `overwrite=true` replaces existing captions. With false it writes `name_01.txt` instead of skipping, and there's no skip-existing option.
- Plain `run.sh` is enough.

`ace_step_1_5_m2m_retake.json` is an audio-to-audio ("retake"/variation) pipeline built on ACE-Step 1.5: `LoadAudio` → `VAEEncodeAudio` encodes an existing instrumental MP3 into the ACE-Step latent space (replacing the usual empty-latent start), then `KSampler` only partially denoises it (`denoise=0.4` by default) guided by a `TextEncodeAceStepAudio1.5` prompt, so the output stays close in structure/rhythm/key to the source while picking up the requested changes — same idea as Suno's "create variation from audio". Manually adapted from ComfyUI's official `audio_ace_step_1_5_checkpoint` template (`comfyui_workflow_templates_json` package), since the shipped ACE-Step 1.5 templates are text-to-audio only — no img2img/retake example exists upstream yet. Uses the single-file `ace_step_1.5_turbo_aio.safetensors` checkpoint (model+text encoder+VAE bundled), downloaded via `download-ace-step.sh`. The turbo checkpoint is distilled for an 8-step full schedule, so partial-denoise quality at very low `denoise` may be inconsistent — untested on Mauro's hardware as of 2026-08-16, `steps`/`denoise` are starting points to tune.

## Guardrails

- Don't revert the `main.py` execution-time-formatting change — it's intentional.
- Anything outside `mauro-files/` and the tracked `user/default/` files is upstream ComfyUI core: follow `AGENTS.md` (minimal diffs, no telemetry/internet requests, respect architecture boundaries).
- Never run `git push` (per global user rules) — only commit locally unless explicitly asked otherwise.
