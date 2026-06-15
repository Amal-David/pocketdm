# Build Small Hackathon — Submission Guide

Single source of truth for shipping our fully-local "digital pet you talk to" (Pikachu)
to the **Build Small** hackathon as a Gradio Space under the official `build-small-hackathon`
Hugging Face org.

**Project recap (for accurate copy):**

- **Brain:** `openbmb/MiniCPM5-1B-GGUF` (~1B params, Apache-2.0), via llama.cpp. Quality fallback `Qwen3.5-2B`, all ≤4B.
- **TTS:** `openbmb/VoxCPM-0.5B` (Apache-2.0, on-device).
- **STT:** `nvidia/nemotron-speech-streaming-en-0.6b` (600M streaming ASR) with `Systran/faster-whisper-small.en` as the auto-fallback.
- **Everything ≤4B, on-device, no cloud APIs.** Custom UI (not stock Gradio).
- This makes us eligible for: **Thousand Token Wood** (whimsical track, "a desktop pet that lives on your machine"), **OpenBMB / Best MiniCPM Build**, **Tiny Titan** (≤4B), **Off-Brand** (custom UI), and as bonuses **Off the Grid** (local-first, no cloud) and **Field Notes** (we have `docs/field-notes-draft.md`).

**Sources read (verbatim, June 2026):**

- Field guide: <https://build-small-hackathon-field-guide.hf.space/> (and the `/submit` validator page)
- OpenBMB partner page: <https://build-small-hackathon-field-guide.hf.space/partners/openbmb>
- Org page: <https://huggingface.co/build-small-hackathon>
- Org README Space: <https://huggingface.co/spaces/build-small-hackathon/README>
- **HF public API tag audit of 500 real submitted Spaces:** `https://huggingface.co/api/spaces?author=build-small-hackathon&limit=500&full=true` — used to derive the exact tag strings below.
- **Field guide validator SOURCE CODE (ground truth):**
  - `src/lib/readme.ts` (the tag generator): <https://huggingface.co/spaces/build-small-hackathon/field-guide/raw/main/src/lib/readme.ts>
  - `src/lib/data/content.ts` (canonical track/sponsor/badge `id`s): <https://huggingface.co/spaces/build-small-hackathon/field-guide/raw/main/src/lib/data/content.ts>
  - `src/routes/submit/+page.svelte` (the submit/validator UI): <https://huggingface.co/spaces/build-small-hackathon/field-guide/raw/main/src/routes/submit/+page.svelte>
- Real example README front-matter: <https://huggingface.co/spaces/build-small-hackathon/aether-garden/raw/main/README.md>

---

## 1. Hugging Face Space README front-matter (copy this exactly)

> **How the tag strings were verified.** Two independent sources: (1) I read the
> field guide's **validator source code** — `readme.ts`/`content.ts`/`submit/+page.svelte`
> — which is the ground truth for what the official tag generator emits; (2) I audited
> the `tags` field of 500 real submitted Spaces via the HF API. The validator uses a
> **namespaced** scheme assembled from three lists:
>
> ```ts
> export const trackTag       = (id) => `track:${id}`;
> export const sponsorTag     = (id) => `sponsor:${id}`;
> export const achievementTag = (id) => `achievement:${id}`;
> ```
>
> The namespaced tag is the **authoritative** one (it's what the validator generates).
> Many submitters *also* add free-form human-readable duplicates (e.g. both `track:wood`
> and `thousand-token-wood`); those are harmless aliases, not what the validator emits.
> Below: authoritative namespaced tag first, optional free-form alias second.

| Track / Badge we want | Authoritative tag | Verification |
| --- | --- | --- |
| Thousand Token Wood (whimsical track) | `track:wood` | **VERIFIED (source + 120 Spaces)** — source `id: 'wood'`. It is `track:wood`, **not** `thousand-token-wood` and **not** `track:whimsical`. The free-form `thousand-token-wood` is a non-canonical alias. |
| OpenBMB / Best MiniCPM Build | `sponsor:openbmb` | **VERIFIED (source + 89 Spaces)** — source `id: 'openbmb'`, prize title "Best MiniCPM Build". Free-form aliases `minicpm` / `best-minicpm-build` are non-canonical. |
| Off-Brand (custom UI) | `achievement:offbrand` | **VERIFIED (source + 218 Spaces)** — source `id: 'offbrand'` (one word, no hyphen). The single most common tag in the org. Free-form alias `off-brand`. |
| Tiny Titan (≤4B model) | `tiny-titan` **+** `achievement:tinytitan` | **UNVERIFIED — no validator tag exists.** See warning below. Tiny Titan is a **prize badge** in a separate `BONUS_BADGES` list (`id: 'tiny'`) that the submit tool never references, so the validator emits **no** tag for it. Free-form `tiny-titan` (57 Spaces) is the most common way people self-tag; the pattern-consistent namespaced form would be `achievement:tinytitan`. Include **both** as best-effort. |

> **Tiny Titan caveat (important).** Per the validator source, the five prize badges
> — **Tiny Titan, Best Demo, Best Agent, Bonus Quest Champion, Judges' Wildcard** — live
> in a `BONUS_BADGES` list that the official submit/tag tool imports **nowhere**. These are
> judged holistically and **auto-considered**; there is no validator-emitted tag for them.
> So any Tiny Titan tag you add is a best-guess, not a validator key. Still worth adding
> `tiny-titan` for discoverability, but eligibility for the ≤4B prize rests on your model
> list (all ≤4B), not on a tag.

Bonus badges we also qualify for and should claim (these **are** validator-emitted achievements): **Off the Grid** (`achievement:offgrid`,
VERIFIED via source `id: 'offgrid'` + 163 Spaces — we are 100% local) and **Field Notes** (`achievement:fieldnotes`,
VERIFIED via source `id: 'fieldnotes'` + 190 Spaces — we have a field-notes draft).

```yaml
---
title: Pika — A Pokémon You Talk To, 100% Local
emoji: ⚡
colorFrom: yellow
colorTo: red
sdk: gradio
sdk_version: 6.17.3
app_file: app.py
pinned: true
license: apache-2.0
short_description: A fully on-device digital pet you talk to. MiniCPM5-1B brain, VoxCPM TTS, Nemotron/Whisper STT — all ≤4B, no cloud.
models:
  - openbmb/MiniCPM5-1B-GGUF
  - openbmb/VoxCPM-0.5B
  - nvidia/nemotron-speech-streaming-en-0.6b
  - Systran/faster-whisper-small.en
tags:
  # --- Track (whimsical: "a desktop pet that lives on your machine") ---
  - track:wood
  - thousand-token-wood
  # --- Sponsor prize: OpenBMB / Best MiniCPM Build ---
  - sponsor:openbmb
  - minicpm
  - best-minicpm-build
  # --- Prize badge: Tiny Titan (every model <= 4B). NOTE: validator emits no
  #     official tag for this; these are best-effort for discoverability only.
  #     Eligibility comes from the <=4B model list above, not from a tag. ---
  - tiny-titan
  - achievement:tinytitan
  # --- Badge: Off-Brand (custom UI beyond stock Gradio) ---
  - achievement:offbrand
  - off-brand
  # --- Bonus badge: Off the Grid (local-first, no cloud APIs) ---
  - achievement:offgrid
  - off-the-grid
  # --- Bonus badge: Field Notes (write-up / blog) ---
  - achievement:fieldnotes
  - field-notes
  # --- Standard discovery tags ---
  - gradio
  - hackathon
  - build-small-hackathon
  - voxcpm
  - on-device
  - local-llm
---
```

**Field notes on the front-matter:**

- `sdk_version: 6.17.3` matches our pinned `gradio==6.17.3` in `pyproject.toml`. Keep these in sync; if HF rejects 6.17.3 as too new, drop to the latest version HF supports and re-pin `pyproject.toml`.
- `app_file: app.py` is correct — the repo's `app.py` imports `app.server:app` and is the Gradio entry. (If you rename the canonical entry to `app/web_pet.py`, change this to `app_file: app/web_pet.py`.)
- `pinned: true` so judges see us on the org grid.
- The `models:` block is optional metadata but strengthens the Tiny Titan / Best MiniCPM story and links our model cards on the Space page.
- **Unverified items, clearly labeled:** the *exact* Tiny Titan namespaced string is not standardized in the org (variants seen: `achievement:tinytitan`, `achievement:tiny-titan`, `badge-tiny-titan`, `badge:tiny-titan`). The free-form `tiny-titan` is the safest single bet; we include the namespaced `achievement:tinytitan` alongside it. Likewise `best-minicpm-build` is a free-form alias — the authoritative sponsor tag is `sponsor:openbmb`.

---

## 2. Deploy checklist — create & push the Space

You (`amal-david`) are logged in via `huggingface-cli`. The Space must live **under the
`build-small-hackathon` org** (you need to be a member — join via the org page / hackathon
Discord if not already).

```bash
# 0. Confirm you are logged in and a member of the org
huggingface-cli whoami
#   -> should list `build-small-hackathon` under "orgs"

# 1. Create the Space in the org (Gradio SDK). Pick a slug, e.g. pika-local-pet.
huggingface-cli repo create pika-local-pet \
  --repo-type space \
  --space_sdk gradio \
  --organization build-small-hackathon
#   -> creates https://huggingface.co/spaces/build-small-hackathon/pika-local-pet
```

Then push the code. Two options — Option A (git) is the most reliable.

```bash
# --- Option A: git (recommended) ---
# 2a. Clone the empty Space repo somewhere outside the working tree
git clone https://huggingface.co/spaces/build-small-hackathon/pika-local-pet /tmp/pika-space
cd /tmp/pika-space

# 2b. Copy in the app. Make sure README.md has the YAML front-matter from section 1,
#     and that requirements.txt / pyproject pins gradio==6.17.3 + the model deps.
#     (rsync, excluding local model weights / venvs / caches that are too big or local-only)
rsync -av --exclude '.git' --exclude 'models/' --exclude '.venv' \
  --exclude '.pika-voxcpm-venv' --exclude '__pycache__' \
  /Users/amal/listenowl/experiments/build-small/ /tmp/pika-space/

# 2c. Large binaries (sprites, audio) must go through Git LFS
cd /tmp/pika-space
git lfs install
git lfs track "*.png" "*.wav" "*.mp3" "*.gguf"
git add .gitattributes

# 2d. Commit and push
git add .
git commit -m "Ship Pika: fully-local talking pet (MiniCPM5-1B + VoxCPM + Nemotron/Whisper)"
git push
```

```bash
# --- Option B: huggingface_hub upload (no local git clone) ---
hf upload build-small-hackathon/pika-local-pet \
  /Users/amal/listenowl/experiments/build-small \
  --repo-type space \
  --exclude "models/*" --exclude ".venv/*" --exclude "**/__pycache__/*"
#   (older CLI: `huggingface-cli upload ...` with the same args)
```

```bash
# 3. Verify the build
#    - Open https://huggingface.co/spaces/build-small-hackathon/pika-local-pet
#    - Watch the "Logs" tab until status = Running
#    - If models are downloaded at runtime, confirm they fetch on first boot
#      (or bake a smaller default so the Space boots within HF resource limits).
```

**Deploy gotchas to check before recording:**

- **Hardware / weights:** the full local model ladder is large. For the hosted Space, default to the smallest viable path (MiniCPM5-1B Q4 + VoxCPM-0.5B + faster-whisper-small) and let heavier models be opt-in, so the Space boots within free/Zero-GPU limits. Rule reminder: **≤ 10 Zero GPU apps per user.**
- **Docker is allowed** "as long as the interface is a Gradio Space" — if startup/model-loading is too complex for the plain Gradio SDK, switch the Space to `sdk: docker` and keep Gradio as the served interface.
- **Do not commit** `models/` weights, `.venv`, `.pika-voxcpm-venv`, or caches; fetch models at runtime from HF or use HF model repos.

---

## 3. Required deliverables — status checklist

The five hackathon entry requirements (from the `/submit` validator) plus the README write-up:

| # | Requirement | Status | Notes / TODO |
| --- | --- | --- | --- |
| 1 | **Every model < 32B** (≤4B for Tiny Titan) | DONE (tech) | MiniCPM5-1B, VoxCPM-0.5B, Nemotron-0.6B, faster-whisper-small — all ≤4B. Each individually under the cap. |
| 2 | **Deployed Gradio Space** in `build-small-hackathon` org | TODO | Follow section 2. Must reach status = Running. |
| 3 | **Demo video** showing the app working | TODO | Record per section 4 script. Embed/link in README. |
| 4 | **One social-media post**, linked from the Space README | TODO | Post draft in section 4. Add the live post URL to README body. |
| 5 | **README write-up** (idea + tech) with track/badge tags in YAML | PARTIAL | YAML ready (section 1). Write the body: idea, architecture, model list, local-first claim, plus links to video + social post + field notes. |
| 6 | **Mind the GPU limit** (≤10 Zero GPU apps/user) | OK | We deploy one Space. |

Bonus-badge evidence to surface in the README body so judges can award them:

- **Off the Grid:** state explicitly "no cloud APIs; runs with WiFi off" + show the WiFi-off moment in the video.
- **Field Notes:** link `docs/field-notes-draft.md` (publish it as a blog/report).
- **Best MiniCPM Build:** call out `openbmb/MiniCPM5-1B` + `openbmb/VoxCPM-0.5B` as the core of the experience.

---

## 4. Demo video script + social post

### 75-second demo video (shot-by-shot)

Target: 75s. Open with the WiFi-off "100% local" proof, then show the talking-pet loop.

| Time | Shot | Action | On-screen / VO |
| --- | --- | --- | --- |
| 0:00–0:07 | **Cold open — kill the network.** Tight shot of the macOS menu bar; click WiFi → **Turn Wi-Fi Off**. The menu-bar icon visibly goes empty. | Toggle WiFi off on camera. | VO: *"No cloud. No internet. Watch."* Caption: **100% LOCAL** |
| 0:07–0:15 | Pull back: Pikachu pet floating on the desktop / in the Gradio Space, network still off. | Show the pet idling, breathing animation. | VO: *"This is Pika — a Pokémon you actually talk to, running entirely on this machine."* |
| 0:15–0:30 | **Talk to it (STT).** Hold the mic button, say out loud: *"Hey Pika, how are you feeling today?"* Live transcript appears. | Speak; show transcript populate. | Caption: **STT · Nemotron-0.6B / faster-whisper — on-device** |
| 0:30–0:45 | **It thinks (LLM).** Pika reacts, mood sprite changes, a reply streams in. | Show the reply text streaming + sprite swap to "happy". | Caption: **Brain · MiniCPM5-1B (≤1B) via llama.cpp** |
| 0:45–0:57 | **It talks back (TTS).** Pika speaks the reply aloud in its voice; show the waveform/audio playing — WiFi still off. | Play the synthesized voice. | Caption: **Voice · VoxCPM-0.5B — synthesized locally** |
| 0:57–1:06 | **The hook:** pet it / daily check-in; Bond + mood update; a chirp plays. Quick custom-UI flourish to sell Off-Brand. | One care interaction; show the non-stock UI. | VO: *"It remembers you, reacts, and grows — no server, no API key."* |
| 1:06–1:15 | **Close on the receipt.** Split-card: `MiniCPM5-1B · VoxCPM · all ≤4B, on-device`, WiFi-off icon still in frame. End card with Space URL. | Hold the summary card. | VO: *"MiniCPM5-1B, VoxCPM, all four-billion-params-or-under, on-device. Built Small."* End card: Space + social + field-notes URLs. |

Proof beats to make sure land on camera: (1) WiFi visibly off the entire time, (2) one full
talk→think→speak loop, (3) the model-name card, (4) the custom (non-stock-Gradio) UI.

### Social post draft (ready to post; then paste the URL into the README)

> ⚡ Meet Pika — a Pokémon you actually *talk to*, running 100% on my laptop with the
> WiFi switched OFF. MiniCPM5-1B does the thinking, VoxCPM-0.5B gives it a voice, and
> Nemotron/Whisper hears me — every model ≤4B, zero cloud. Tiny models, big personality.
> Built for #BuildSmall 🌳
>
> #BuildSmall #MiniCPM #OpenBMB #VoxCPM #LocalAI #OnDevice #SmallLLM #ThousandTokenWood

After posting (X/Twitter, LinkedIn, or Bluesky), add a line to the README body:
`**Social post:** <paste-url-here>` so the validator's "link to it from your README" check passes.

---

## 5. Open items I could not fully verify

- **Tiny Titan has NO validator-emitted tag.** Confirmed from the validator source: it lives in a `BONUS_BADGES` list (`id: 'tiny'`) the submit tool never imports. The five prize badges (Tiny Titan, Best Demo, Best Agent, Bonus Quest Champion, Judges' Wildcard) are auto-considered/judged holistically. I include `tiny-titan` + `achievement:tinytitan` as best-effort discoverability tags only; ≤4B eligibility is established by our model list, not a tag. *Labeled unverified.*
- **Best MiniCPM Build:** the authoritative tag is `sponsor:openbmb` (VERIFIED from source `id: 'openbmb'`). `best-minicpm-build` / `minicpm` are free-form aliases; harmless but not canonical.
- **`sdk_version`:** confirm HF accepts `6.17.3` (matches our pin). Real example Spaces used `5.50.0`, `6.16.0`, `6.17.3`, `6.18.0`. If the build fails on version, lower it and re-pin `pyproject.toml`.
- The `/rules` and `/faq` sub-paths returned HTTP 404 at fetch time; rule details come from the field-guide home page, the `/submit` validator page (and its source), the `/partners/openbmb` page, and the live org Spaces.
- WebFetch's *summaries* of the field guide hallucinated some details (e.g. invented prize-money tag annotations). All tag strings in this doc are grounded in the validator **source code** and real Space `tags` arrays, which supersede any WebFetch paraphrase.
