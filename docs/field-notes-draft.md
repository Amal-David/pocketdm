# PocketDM Field Notes Draft

## Working Title

PocketDM: a tiny Dungeon Master, a stricter engine, and one hovering dragon

## Thesis

The small-model trick is not asking a 2B model to be a whole game. PocketDM lets
the model do the fun part: short, vivid adventure prose and three tempting
choices. The deterministic engine owns the brittle part: state, HP, inventory,
ending pressure, grammar, retries, and validation.

## What Exists Now

- A custom `gr.Server` app with a parchment UI and a persistent Ember assistant.
- A local dragon spritesheet at `app/static/dragon-sprites.png` with CSS wing
  flapping and fire-puff states.
- A scripted checkpoint backend that proves the game loop, state display,
  assistant, voice selector, and ending behavior.
- An optional llama.cpp backend path enabled by `POCKETDM_GGUF`.
- A custom Kokoro Lore Narrator voice blend saved as
  `app/voices/lore_narrator.npy` and `app/voices/lore_narrator.pt`.
- A Modal Qwen3-32B teacher pipeline with a passing 50-adventure smoke:
  632 clean turns and all turn gates at least 99.1%.
- Train/eval scripts for fine-tuning, GGUF export, local smoke inference,
  automated metrics, judge scoring, and report generation.

## Receipts To Add Before Publishing

- Full dataset filter report with at least 5,000 clean training turns.
- `data/clean/holdout_seeds.jsonl` with 100 held-out adventures.
- Modal fine-tune cost line and final train/eval loss.
- GGUF file size and SHA256 for Q4_K_M and Q8_0.
- Base-vs-finetuned eval table, including grammar-free schema validity.
- LLM judge scores with coherence, choice meaningfulness, and ending satisfaction.
- Live Space timing: first token, sustained tok/s, TTS latency, and no-network audit.

## Story Arc

1. I started with the tempting but wrong idea: make the model own the game.
2. The first smoke run caught the failure mode before it poisoned the dataset:
   adventures wandered, endings failed, and narration filters exposed prompt drift.
3. The engine became the adult in the room. It applied state deltas, forced the
   final turn, repaired harmless missing inventory removals, and bridged unsafe
   failures.
4. Ember made the small-model constraint legible. It is not decoration; it is a
   persistent guide that explains state, risk, and why a choice is clean.
5. The final product is meant to be playable with the Wi-Fi off: a tiny DM, a
   local voice, a local dragon, and receipts instead of vibes.

## Demo Close

The video should end on the same claim the repo can prove:

> The model writes the magic. The engine keeps the rules. The dragon keeps you
> company.
