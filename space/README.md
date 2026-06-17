---
title: Pocket Pikachu — A Pokémon You Talk To, 100% Local
emoji: ⚡
colorFrom: yellow
colorTo: red
sdk: gradio
sdk_version: 6.17.3
app_file: app.py
pinned: true
license: apache-2.0
short_description: On-device talking Pikachu — MiniCPM5 brain, runs on free CPU
models:
  - openbmb/MiniCPM5-1B-GGUF
  - Systran/faster-whisper-small.en
  - hexgrad/Kokoro-82M
  - openbmb/VoxCPM-0.5B
  - nvidia/nemotron-speech-streaming-en-0.6b
tags:
  - track:wood
  - sponsor:openbmb
  - achievement:offbrand
  - achievement:offgrid
  - gradio
  - hackathon
  - build-small-hackathon
  - minicpm
  - on-device
  - local-llm
---

# ⚡ Pocket Pikachu — a Pokémon you actually talk to

A clickable, talking digital pet that runs **100% on-device**. Click the mic (or
type), and your pocket Pikachu **hears you, thinks, and talks back** — no cloud
APIs, no internet required. Built for the **Build Small** hackathon: every model
is small enough to run on your own machine (all ≤ 4B params).

**Stack — all in-process, all local, no GPU:**

| Role  | Model (this Space) | Notes |
|-------|--------------------|-------|
| 🧠 Brain | `openbmb/MiniCPM5-1B-GGUF` (Q4_K_M) | OpenBMB, via `llama-cpp-python`, ~1B params |
| 👂 Ears | `Systran/faster-whisper-small.en` | CTranslate2 int8 — fast + accurate on free CPU |
| 🗣️ Voice | Kokoro (`kokoro-onnx`, voice `af_heart`) | warm female voice, ONNX/torch-free, + pitch↑/tempo↓ styling |

The **native macOS PocketDM app** uses heavier models for the same roles —
**NVIDIA Nemotron** (ears) and **OpenBMB VoxCPM-0.5B** (voice) — which need a GPU
and OOM-kill the free-CPU Space build. This Space swaps in faster-whisper +
Kokoro so it builds and runs interactively on **free** hardware. See *Why these
substitutions* below — it's an honest design note, not a claim that Nemotron or
VoxCPM run here.

## How it works

`app.py` is a single Gradio Blocks app. Models are loaded **in-process and
lazy-loaded on first request** (the Space boots fast; weights download on first
use). A turn flows:

1. **Mic / text in** — `gr.Audio(sources=["microphone"])` or a textbox.
2. **Transcribe** — **faster-whisper `small.en`** (CTranslate2, int8, with Silero
   VAD) turns speech into text in-process. It's light enough to run on free CPU.
3. **Reply** — MiniCPM5-1B generates Pikachu's response with the same system
   prompt and keyless tool-fact grounding (time / weather / web lookup) as the
   desktop companion.
4. **Speak** — Kokoro (`af_heart`) synthesizes the reply in a consistent cute
   female voice, styled with a pitch-up / tempo-down ffmpeg pass, played via
   `gr.Audio(autoplay=True)`.

The conversation renders as rounded chat bubbles, and Pikachu bobs in the center
of a soft sunny gradient — a custom (non-stock-Gradio) UI.

## Why it qualifies

- **Best MiniCPM Build (`sponsor:openbmb`)** — the brain is **OpenBMB's
  MiniCPM5-1B**, running in full on free CPU via llama.cpp. (The native app also
  uses OpenBMB's VoxCPM for the voice.)
- **Off the Grid (`achievement:offgrid`)** — no cloud APIs; every model is loaded
  and run locally inside the Space process. Runs with WiFi off.
- **Off-Brand (`achievement:offbrand`)** — fully custom UI: sunny gradient,
  bobbing sprite, chat bubbles, daily check-in — well beyond stock Gradio.
- **Thousand Token Wood (`track:wood`)** — a whimsical desktop pet that lives on
  your machine.
- **Tiny / ≤4B** — every model is well under 4B params: MiniCPM5-1B, Kokoro-82M,
  faster-whisper-small here; VoxCPM-0.5B and Nemotron-0.6B in the native app.

## Why these substitutions (honest design note)

The native macOS PocketDM app runs **NVIDIA Nemotron** (ears) + **OpenBMB
VoxCPM-0.5B** (voice). We tried to ship both on this Space, but **free
cpu-basic** (2 vCPU / 16 GB) can't take them:

- `nemo_toolkit[asr]` (Nemotron) pulls torch + the full training stack →
  **OOM-killed the build** (`exit code 137, OOMKilled`).
- `voxcpm` pulls torch + funasr + ~5 GB of CUDA wheels → **OOM-killed the build**
  again; and CPU VoxCPM inference is too slow to be interactive.

Rather than require a paid GPU, the Space substitutes two torch-free, CPU-fast
models that fill the same roles: **faster-whisper small.en** (ears) and
**Kokoro `af_heart`** (voice, RTF ≈ 0.3 — faster than real time on CPU). The
OpenBMB **MiniCPM brain runs here in full**. Nemotron + VoxCPM run for real in
the native app — this Space does not claim to run them.

## Running locally

```bash
pip install -r requirements.txt
python app.py   # serves on http://0.0.0.0:7860
```

`ffmpeg` powers the voice styling (pitch/tempo); `kokoro-v1.0.onnx` +
`voices-v1.0.bin` ship with the Space. The MiniCPM GGUF + Whisper weights
download from the HF hub on first message.

## Hardware note

Runs entirely on **HF cpu-basic** (free, 2 vCPU / 16 GB, no GPU). First message
is a little slow (CPU inference + first-run weight download for MiniCPM/Whisper);
subsequent turns are quick. Kokoro and faster-whisper are both light and fast on
CPU; MiniCPM-1B via llama.cpp is the main latency cost.
