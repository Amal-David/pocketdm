---
title: Pocket Pikachu — A Pokémon You Talk To, On-Device
emoji: ⚡
colorFrom: yellow
colorTo: red
sdk: gradio
sdk_version: 6.17.3
app_file: app.py
pinned: true
license: apache-2.0
short_description: On-device talking Pikachu — MiniCPM5 + VoxCPM voice on GPU
models:
  - openbmb/MiniCPM5-1B-GGUF
  - openbmb/VoxCPM-0.5B
  - Systran/faster-whisper-small.en
tags:
  - track:wood
  - sponsor:openbmb
  - achievement:offbrand
  - achievement:offgrid
  - gradio
  - hackathon
  - build-small-hackathon
  - minicpm
  - voxcpm
  - on-device
  - local-llm
---

# ⚡ Pocket Pikachu — a Pokémon you actually talk to (VoxCPM on ZeroGPU)

A clickable, talking digital pet that runs in-process on a single GPU. Click the
mic (or type), and your pocket Pikachu **hears you, thinks, and talks back** — no
cloud APIs. Built for the **Build Small** hackathon: every model is ≤ 4B params.

**Stack — in-process on ZeroGPU:**

| Role  | Model | Where it runs |
|-------|-------|---------------|
| 🧠 Brain | `openbmb/MiniCPM5-1B-GGUF` (Q4_K_M) | OpenBMB, via `llama-cpp-python` — CPU |
| 🗣️ Voice | `openbmb/VoxCPM-0.5B` | OpenBMB, cute female ref + pitch↑/tempo↓ styling — **GPU** |
| 👂 Ears | `Systran/faster-whisper-small.en` | CTranslate2 int8 — CPU |

> **Why no NeMo/Nemotron here:** `nemo_toolkit[asr]` cannot build on a ZeroGPU
> Gradio Space — its multi-GB dependency tree plus a CUDA `torch` OOM-kill the
> CPU build container (`exit 137`), and the streaming model has no `transformers`
> path. Nemotron runs in the **native macOS PocketDM app** instead. This Space's
> upgrade over its free-CPU sibling is **VoxCPM** (OpenBMB's neural voice) on GPU.

## How it works

`app.py` is a single Gradio Blocks app. Per-turn inference runs inside one
**`@spaces.GPU`-decorated** function (`run_turn_gpu`) so the GPU is attached for
the turn; models lazy-load on first use. A turn flows:

1. **Mic / text in** — `gr.Audio(sources=["microphone"])` or a textbox.
2. **Transcribe** — **faster-whisper `small.en`** turns speech into text (CPU).
3. **Reply** — **MiniCPM5-1B** generates Pikachu's response with the same system
   prompt + keyless tool-fact grounding (time / weather / web lookup) as the
   desktop companion (CPU via llama.cpp).
4. **Speak** — **VoxCPM-0.5B** synthesizes the reply on the **GPU** in a
   consistent cute female voice (bundled reference clip + pitch-up/tempo-down
   ffmpeg styling), played via `gr.Audio(autoplay=True)`.

Custom (non-stock-Gradio) UI: sunny gradient, bobbing sprite, chat bubbles,
daily check-in, hero + "what can it do" sections.

## Why it qualifies

- **Best MiniCPM Build (`sponsor:openbmb`)** — built on **OpenBMB's MiniCPM5-1B**
  (brain) and **VoxCPM-0.5B** (voice).
- **Off the Grid (`achievement:offgrid`)** — no cloud APIs; every model runs
  locally in the Space process.
- **Off-Brand (`achievement:offbrand`)** — fully custom UI beyond stock Gradio.
- **Thousand Token Wood (`track:wood`)** — a whimsical talking desktop pet.
- **Tiny / ≤4B** — MiniCPM5-1B, VoxCPM-0.5B, faster-whisper-small all well under
  4B. (The native app adds NVIDIA Nemotron-0.6B for streaming ASR.)

## Hardware

Runs on **ZeroGPU** (`zero-a10g`) — the free, quota-based GPU available to
members of the `build-small-hackathon` Team-plan org (org-billed, no personal
cost). The voice (VoxCPM) runs on the GPU; the brain (llama.cpp) and ears
(faster-whisper) run on CPU. A free-CPU sibling (MiniCPM + faster-whisper +
Kokoro) runs at <https://huggingface.co/spaces/amal-david/pocket-pikachu>.
