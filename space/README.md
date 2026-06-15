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
short_description: On-device talking Pikachu — MiniCPM5, VoxCPM, Nemotron
models:
  - openbmb/MiniCPM5-1B-GGUF
  - openbmb/VoxCPM-0.5B
  - nvidia/nemotron-speech-streaming-en-0.6b
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
  - nemotron
  - on-device
  - local-llm
---

# ⚡ Pocket Pikachu — a Pokémon you actually talk to

A clickable, talking digital pet that runs **100% on-device**. Click the mic (or
type), and your pocket Pikachu **hears you, thinks, and talks back** — no cloud
APIs, no internet required. Built for the **Build Small** hackathon: every model
is small enough to run on your own machine (all ≤ 4B params).

**Stack — all in-process, all local:**

| Role  | Model | Notes |
|-------|-------|-------|
| 🧠 Brain | `openbmb/MiniCPM5-1B-GGUF` (Q4_K_M) | via `llama-cpp-python`, ~1B params |
| 🗣️ Voice | `openbmb/VoxCPM-0.5B` | one cute high-pitch female voice (pitch ↑, tempo ↓) |
| 👂 Ears  | `nvidia/nemotron-speech-streaming-en-0.6b` | NVIDIA Nemotron ASR via NeMo (primary) |
| 👂 Ears (fallback) | `Systran/faster-whisper-small.en` | silent fallback so the demo never breaks |

## How it works

`app.py` is a single Gradio Blocks app. Models are loaded **in-process and
lazy-loaded on first request** (the Space boots fast; weights download on first
use). A turn flows:

1. **Mic / text in** — `gr.Audio(sources=["microphone"])` or a textbox.
2. **Transcribe** — **NVIDIA Nemotron** (`nemotron-speech-streaming-en-0.6b`)
   turns speech into text in-process via NeMo. If NeMo can't load on the host,
   it falls back silently to faster-whisper `small.en` so the demo always works.
3. **Reply** — MiniCPM5-1B generates Pikachu's response with the same system
   prompt and keyless tool-fact grounding (time / weather / web lookup) as the
   desktop companion.
4. **Speak** — VoxCPM synthesizes the reply in a consistent cute female voice,
   styled with a pitch-up / tempo-down ffmpeg pass, played via
   `gr.Audio(autoplay=True)`.

The conversation renders as rounded chat bubbles, and Pikachu bobs in the center
of a soft sunny gradient — a custom (non-stock-Gradio) UI.

## Why it qualifies

- **Off the Grid (`achievement:offgrid`)** — no cloud APIs; runs with WiFi off.
  Every model is loaded and run locally inside the Space process.
- **Best MiniCPM Build (`sponsor:openbmb`)** — the experience is built on
  **MiniCPM5-1B** (brain) and **VoxCPM-0.5B** (voice), both from OpenBMB.
- **Off-Brand (`achievement:offbrand`)** — fully custom UI: sunny gradient,
  bobbing sprite, chat bubbles, daily check-in — well beyond stock Gradio.
- **Thousand Token Wood (`track:wood`)** — a whimsical desktop pet that lives on
  your machine.
- **NVIDIA / Nemotron eligibility** — the **primary, credited speech-to-text** is
  NVIDIA's `nemotron-speech-streaming-en-0.6b` (600M streaming ASR) loaded
  in-process via NVIDIA NeMo. faster-whisper is only a silent safety net.
- **Tiny / ≤4B** — MiniCPM5-1B, VoxCPM-0.5B, Nemotron-0.6B, faster-whisper-small
  are each well under 4B params.

## Running locally

```bash
pip install -r requirements.txt
python app.py   # serves on http://0.0.0.0:7860
```

`ffmpeg` is used for the voice styling (pitch/tempo). On first message the app
downloads the model weights from the HF hub.

## Hardware note

NeMo is a heavy dependency and the Nemotron model is ~2.3 GB. On **cpu-basic**,
MiniCPM (llama.cpp) + VoxCPM run but are slow, and NeMo may be too heavy to load
— in which case STT falls back to faster-whisper while the app keeps Nemotron as
the credited primary. For real Nemotron latency, run on a **GPU / ZeroGPU**
Space.
