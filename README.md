---
title: PocketDM
emoji: 🐉
colorFrom: amber
colorTo: red
sdk: gradio
sdk_version: 6.17.3
app_file: app.py
pinned: false
tags:
  - build-small-hackathon
  - track:wood
  - sponsor:openai
  - sponsor:modal
  - achievement:offbrand
---

# PocketDM

PocketDM is a tiny-model Dungeon Master for the Build Small Hackathon's
Thousand Token Wood track. The pitch is simple: a custom Gradio adventure game
where the model writes the prose, the deterministic engine owns game state, and
Ember, a Clippy-style dragon assistant, hovers over the whole screen with a
local sprite sheet, hints, speech, and fire.

The first-cut app is a reliable playable demo while the fine-tuned student
model pipeline finishes. It uses the frozen engine contract and a scripted local
backend so judges can play a complete adventure immediately. The same server can
switch to a llama.cpp backend when `POCKETDM_GGUF` points at the trained GGUF.
The target runtime is a Qwen3.5-2B Q4_K_M llama.cpp model plus Kokoro narration,
all under the 32B rule and designed for offline play.

## Why It Fits Build Small

- Track: Thousand Token Wood.
- Delight: a short playable adventure with a persistent animated dragon aide.
- AI load-bearing path: teacher-generated adventures train the tiny model to
  produce valid turn JSON; the engine never lets the model own logic.
- Custom Gradio UI: `gradio.Server` serves a fully custom parchment frontend,
  not stock Gradio blocks.
- Offline story: runtime is designed for local llama.cpp plus local Kokoro TTS;
  no cloud inference is needed once the model artifact is baked in.
- Voice: narration uses the local Kokoro path when installed, including a
  custom-blended Lore Narrator voice artifact. Lore Narrator is a Kokoro tensor
  blend, not a TTS fine-tune. Ember's quick chatter uses browser speech
  synthesis so the assistant stays responsive.
- Evidence path: Modal data-generation costs are logged in `tasks/costs.md`,
  smoke data lives under `data/out/`, and the train/eval scripts are in place
  for the model/export/report path once the full teacher run lands.

## Local app

Run the first-cut custom frontend with:

```bash
uv run python app.py
```

The app serves a `gradio.Server` backend with a custom HTML/CSS/JS frontend. The
fixed Ember dragon assistant uses a local sprite sheet at
`app/static/dragon-sprites.png`; it talks through browser speech synthesis and
does not call an external API.

By default the app reports `Backend: Scripted` and uses deterministic turns for
the playable checkpoint. To use the local trained GGUF model:

```bash
POCKETDM_GGUF=models/2b-v1-lora/gguf/merged.Q4_K_M.gguf uv run --group eval --group tts python app.py
```

To try the experimental Gemma 4 E2B backend after downloading its GGUF:

```bash
POCKETDM_GGUF=models/gemma-4-e2b-it/gguf/gemma-4-E2B-it-Q4_K_M.gguf POCKETDM_LLAMA_THREADS=8 uv run --group eval --group tts python app.py
```

The BF16 GGUF also loads locally, but it is a quality experiment rather than a
demo runtime on CPU:

```bash
POCKETDM_GGUF=models/gemma-4-e2b-it/gguf/gemma-4-E2B-it-BF16.gguf POCKETDM_LLAMA_THREADS=8 uv run --group eval --group tts python app.py
```

Narration audio is a progressive enhancement. If Kokoro dependencies and local
model files are available, `/api/tts` returns WAV audio for each turn. If they
are missing, the text adventure and dragon assistant continue without blocking.
The Space entrypoint preloads the Kokoro ONNX assets at startup when needed;
turn-time play never downloads them.

You can also use:

```bash
./run_local.sh
```

Then open `http://127.0.0.1:7860`.

## Submission Links

- Demo video: TODO
- Social post: TODO
- Field notes/blog: TODO
- Model repo: TODO after WP-4 training/export
- Dataset/traces repo: TODO after WP-3 filtering and split

## Candidate Badges Still To Earn

- Off Grid: keep once the live Space runs without hosted inference.
- Well-Tuned: add after the student fine-tune, eval table, and model repo are live.
- Llama Champion: add after llama.cpp/GGUF runtime is active in the app.
- Sharing Is Caring: add after dataset and Codex traces are published.
- Field Notes: add after the public build write-up is linked.

Before final submission, rerun the registration app tag generator and add only
earned final tags such as `achievement:offgrid`, `achievement:welltuned`,
`achievement:llama`, `achievement:sharing`, and `achievement:fieldnotes`.
