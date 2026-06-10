# PocketDM — Build Plan (Hackathon: Build Small, deadline June 15, 2026)

## Context

The PRD (`PRD.md`, to be committed as repo root doc) defines PocketDM: a tiny fine-tuned Dungeon Master that runs a spoken interactive adventure fully offline (llama.cpp + Kokoro TTS) inside a custom-frontend Gradio Space. **The PRD's 270M student model was rejected by the user on June 10; the primary is now Qwen3.5-2B** (see model ladder below) — update `PRD.md` §5.1 accordingly when committing it. Marketing line becomes "a Dungeon Master in 1.2GB, with the Wi-Fi off"; total runtime params 2B + 82M TTS ≪ the 32B cap and inside Tiny Titan's ≤4B. Goal: stack the maximum number of Build Small hackathon awards/badges in ~5 days, solo, with all production code Codex-attributed.

Working dir `/Users/amal/listenowl/experiments/build-small` is **empty** — this is a greenfield build. Today is **June 10** = PRD Day 1.

### Research findings that shape this plan (verified June 10, 2026)

- **`gr.Server` is real** (Gradio ≥ 6.10.0, current 6.17.3): FastAPI subclass; custom routes override the default UI; JS talks to Python via `@gradio/client` over SSE. The Off-Brand badge *explicitly* rewards `gr.Server` custom frontends. Pin `sdk_version: 6.17.3` (or latest ≥6.10) in Space README.
- **Hackathon rules confirmed**: Space must live in the `build-small-hackathon` org, every model ≤32B, Gradio interface required, README needs `track-*`/`badge-*` frontmatter tags + demo video + social post link. Badges: off-grid, well-tuned, off-brand, llama-champion, sharing-is-caring, field-notes. Tiny Titan (≤4B) is an award, not a badge. Exact canonical tag strings are behind the auth-gated registration app — **verify there before submitting (Day 5 checklist item)**.
- **Student model swapped per user decision (June 10): Qwen3.5-2B replaces Gemma-3-270M.** User judged 270M unworkable; "Qwen 4" doesn't exist (newest small generation = Qwen3.5: 0.8B/2B/4B, Feb 2026, Apache 2.0, 262K context, IFEval 61.2 at 2B); Gemma 4's smallest (E2B) is 5.1B *total* params (2.3B effective) — a Tiny Titan ≤4B eligibility risk — and only ~7–12 tok/s on small CPUs, so it's demoted to rung 3. Qwen3.5 small models are **non-thinking by default** — ideal for grammar-constrained JSON (keep thinking off).
- **New model ladder**: Primary **Qwen3.5-2B** (quality, unambiguously ≤4B) → Fallback 1 **Qwen3.5-0.8B** (speed insurance, same pipeline/license, full FT trivial) → Fallback 2 **Gemma 4 E2B** (only if organizers confirm effective-param counting AND latency acceptable). Demotion to 0.8B is triggered by *latency*, promotion to E2B by *quality* — both gates measured, not vibed.
- **Teacher = Qwen3-32B** (Apache 2.0, fits 1×H100 BF16, top-tier JSON adherence, vLLM xgrammar structured output). **Avoid Llama-3.3-70B**: its license forces models trained on its *outputs* to carry "Llama" in the name. Optional 100-turn bake-off vs Qwen3.5-27B (newer gen, Apache 2.0) if smoke-batch quality disappoints.
- **llama.cpp + Qwen3.5 + GBNF**: GBNF is model-agnostic (token-level masking) so grammar guarantees hold. Gotchas to encode: **pin a fresh llama.cpp build** (Qwen3.5's hybrid Gated-DeltaNet arch support is recent; Unsloth ships working GGUFs), keep thinking mode OFF (default), grammar doesn't constrain EOS (set max-tokens + retry), avoid `\d`-style regex shorthands (hand-write the GBNF).
- **Quantization: ship Q4_K_M, not Q8_0** — research shows Q8 roughly halves CPU tok/s for marginal quality on a narrow fine-tuned task. 2B Q4 ≈ 1.2GB GGUF. **Latency is the #1 open risk**: 2B Q4 on 2 vCPU is estimated 8–15 tok/s (no published benchmark exists) → a ~150-token turn = 10–19s generated, masked by token-streaming typewriter + TTS-while-generating. **Hard gate: benchmark on a real free-tier Space Day 1–2; if <10 tok/s, drop to Qwen3.5-0.8B.**
- **Unsloth supports Qwen3.5 0.8B/2B/4B** fine-tuning with documented GGUF export; full FT of 2B on a Modal A100 stays in single-digit dollars.
- **Kokoro-82M**: Apache 2.0, `kokoro-onnx` runtime preferred on CPU (no torch), RTF ~0.5 on typical CPUs. Free Space = 2 vCPU/16GB → run TTS *sequentially* after text generation, never concurrently with decoding.
- **Space free tier**: ~300MB Q8 GGUF ≈ ballpark 15–40 tok/s on 2 vCPU (unverified — measure Day 3; this is the main latency risk). Spaces sleep after inactivity; keep warm during judging.

### Custom "game lore" narrator voice (user addition, June 10 — decisions made)

User wants a custom Kokoro woman voice that sounds like a game lore narrator (dark-fantasy intro narration style). Research findings + user decisions:

- **True Kokoro fine-tuning is off the table**: hexgrad has released no training code (official FAQ recommends voice-tensor manipulation). User chose the **voice-tensor blend** path; voice ships as a **4th selectable "Lore Narrator"** usable in any genre (the 3 per-genre voices stay).
- **How**: each Kokoro voice is a (510, 1, 256) style tensor; custom voices = weighted mix. Starting recipe: `bf_emma` (British gravitas, B-) + `af_heart`/`af_bella` (A-grade quality) + minority `af_nicole` (breathy/ASMR), ~0.45/0.35/0.20; `speed≈0.8`; "reverb" is DSP post-processing (`pedalboard` Reverb on CPU, cheap). Artifact ≈ 0.5MB `.pt`/numpy vector, loadable by `kokoro-onnx` (`create(..., voice=<ndarray>)`; rebuild `voices.bin` with the custom entry via the sherpa-onnx script).
- **Optional polish (timeboxed 2h)**: `kvoicewalk` random-walk refinement toward a *self-recorded or consented* target WAV. **Never** target ripped game audio (copyright + right-of-publicity: Lehrman v. Lovo, ELVIS Act). Market the voice as "dark-fantasy narration style," never a named actor/game.
- **Honesty rule**: this is a crafted/blended voice, not a weight fine-tune — the Well-Tuned badge claim rests solely on the 270M DM model; blog/README describe the voice accurately ("custom-blended Kokoro voice").

## Operating model: Claude orchestrates, Codex authors

Per PRD CX-1, all production code must land as Codex-attributed commits. Concretely:

- Claude Code (this session) = architect/orchestrator: writes specs & prompts, runs `codex exec` non-interactively per work package, reviews diffs, runs tests/Modal jobs, decides promote/retry.
- Every code change goes through `codex exec` against the repo with `PRD.md` + the relevant spec section in the prompt. Claude never uses Edit/Write on production source files; review feedback is fed back as a new Codex prompt.
- Commits authored/attributed to Codex (Codex CLI commits with its own attribution; verify the first commit's author metadata shows Codex before proceeding).
- Codex session logs exported to `traces/` (Sharing is Caring evidence).
- Non-code actions (running `modal run`, `hf upload`, eval commands, playtesting) are Claude-driven — running code doesn't break attribution.

## Repo layout (created Day 1)

```
build-small/                  # git init + GitHub public repo (gh repo create pocketdm)
  PRD.md                      # this PRD, referenced in every Codex prompt
  specs/                      # per-work-package specs Claude writes for Codex
  data/                       # generator + filters (Modal app)
    teacher_gen.py            # vLLM batch on Modal: Qwen3-32B, xgrammar guided JSON
    filters.py                # schema/distinctness/legality/profanity gates
  train/
    finetune.py               # Unsloth full FT on Modal T4/L4
    grpo.py                   # stretch
    export_gguf.py
  eval/
    harness.py                # automated metrics + LLM-judge batch (Modal)
    sessions.py               # 50-session grammar-clean CI check
  engine/
    schema.py                 # frozen turn schema (single source of truth)
    state.py                  # deterministic state machine, validation, story pressure
    grammar.gbnf              # hand-written GBNF pinned to schema
  app/                        # the HF Space (also pushed to Space repo)
    server.py                 # gr.Server: FastAPI routes + @app.api endpoints
    frontend/                 # parchment UI: index.html, css, js (@gradio/client over SSE)
    tts.py                    # kokoro-onnx wrapper, per-genre voices, async
    voices/                   # custom blended/finetuned narrator voice artifact
  traces/                     # codex session logs (published to HF dataset)
  tasks/todo.md, tasks/lessons.md
```

## Day-by-day plan

### Day 1 — today (June 10): foundations + data pipeline
1. **Bootstrap** (Claude): `superplan init --scope local --yes`; `git init`; `gh repo create` (public `pocketdm`); commit `PRD.md` + this plan as `specs/`. Shape the Superplan change graph (`superplan change new pocketdm`) with tasks mirroring the work packages below.
2. **WP-1 Freeze schema** (Codex): `engine/schema.py` (pydantic model of the turn object) + `engine/grammar.gbnf` hand-written to match + round-trip unit tests (sample JSON → schema → GBNF acceptance).
3. **WP-2 Engine skeleton** (Codex): `engine/state.py` — state dataclass, delta validation/clamping, story-pressure injector (act hints by turn count, force ending by 15), retry→canned-bridge fallback. CLI REPL harness that plays a session with any backend.
4. **WP-0 Latency benchmark** (Claude, parallel): push a throwaway free-tier Space running stock `unsloth/Qwen3.5-2B-GGUF` Q4_K_M under llama.cpp and measure real tok/s on 2 vCPU **before training money is spent**. <10 tok/s → primary becomes Qwen3.5-0.8B immediately (no published benchmark exists for this arch on 2 vCPU; this is the plan's #1 unknown).
5. **WP-3 Teacher pipeline** (Codex): `data/teacher_gen.py` Modal app — vLLM serving Qwen3-32B w/ xgrammar guided JSON; simulates DM + 3 player personas; emits full adventures in frozen schema. `data/filters.py` quality gates (DR-4). Claude runs a 50-adventure smoke batch, inspects quality, then launches the full ~2k-adventure run overnight.
6. **Exit criteria**: engine REPL plays a complete teacher-backed adventure; ≥5k filtered turns banked or generating overnight; tok/s number from the real Space known; first Codex-attributed commits verified on GitHub.

### Day 2 (June 11): train + eval + publish model
1. **WP-4 Training** (Codex): `train/finetune.py` Unsloth fine-tune of **Qwen3.5-2B** (full FT on Modal A100 preferred — still single-digit dollars; LoRA fallback per Unsloth's Qwen3.5 recipe; completion-only loss, packed seqs, 2–3 epochs, thinking off); `export_gguf.py` → **Q4_K_M (ship)** + Q8_0 (local/comparison).
2. **WP-5 Eval harness** (Codex): automated metrics (schema-valid w/o grammar, choice distinctness, delta legality, fallback rate, tok/turn) + LLM-judge rubric batch on 50 held-out seeds.
3. Claude: run train → eval; apply ladder rules (quality gate: coherence ≥3.5, distinctness failures ≤10%; latency gate: ≥10 tok/s measured on a free-tier Space → else retrain on Qwen3.5-0.8B; max half-day per rung).
4. **WP-6 llama.cpp integration test** (Codex): 50 automated grammar-constrained sessions vs llama-server (pinned fresh build for Qwen3.5 arch) must complete clean (CI script). Encodes the template/EOS/max-tokens gotchas.
5. Publish model repo (safetensors + GGUF, `license: apache-2.0`, before/after eval table) + dataset repo on HF.
6. **WP-V Lore Narrator voice** (Codex): `app/voices/build_lore_voice.py` — load Kokoro female voice tensors, blend (start 0.45 bf_emma / 0.35 af_heart / 0.20 af_nicole), generate a fixed audition script ("Long ago, in the Whispering Wood…") across a small grid of blend weights + speeds; Claude listens and picks the winner; apply `pedalboard` reverb in the TTS pipeline for this voice only; save the tensor artifact + rebuild kokoro-onnx `voices.bin`. Optional 2h kvoicewalk polish only if the blend disappoints.

### Day 3 (June 12): the Space — UI + voice (starts regardless of model state)
1. **WP-7 gr.Server app** (Codex): `app/server.py` with `@app.api` endpoints (`new_game`, `take_turn` streaming, `tts`), llama.cpp (llama-cpp-python or llama-server subprocess) + GBNF, kokoro-onnx sequential TTS.
2. **WP-8 Parchment frontend** (Codex, iterated with screenshots): custom HTML/CSS/JS served from `/`; typewriter streaming, wax-seal choices, HP hearts, dice animation, proof-of-tininess badge w/ live tok/s, mute toggle, "Begin adventure 🔊" click-to-start (autoplay policy), mobile responsive.
3. Deploy to `build-small-hackathon` org Space (Gradio SDK, `sdk_version` ≥6.10; bake Q4_K_M GGUF + voice artifacts into the build). Measure real tok/s on Space CPU → if a streamed turn feels broken (<~8 tok/s), execute the 0.8B fallback retrain same day (pipeline is model-agnostic by design).
4. **Exit criteria**: full 15-turn voiced session on the live Space, desktop + phone, zero visible failures.

### Day 4 (June 13): polish, video, blog
1. Playtest hard (Claude runs scripted + manual sessions; 3 human testers). Fix via Codex.
2. Stretch *only if green*: GRPO pass (~300 steps), ambient audio, page-turn transitions.
3. `run_local.sh` + airplane-mode verification for the video's Wi-Fi-off beat.
4. Shoot + edit the ≤2:00 demo video per PRD §8 storyboard. Draft Field Notes blog ("$X total training cost" with real Modal numbers — track every run).

### Day 5 (June 14–15): submit + push
1. README frontmatter: verify canonical `track-thousand-token-wood` + all `badge-*` strings against the auth-gated registration app, add video + social links.
2. Publish: blog, `traces/` dataset, social post w/ teaser clip (morning).
3. Submit with buffer; re-scan org for near-duplicates; keep Space warm; reply to comments.

## Budget tracking
Log every Modal run cost in `tasks/costs.md` (feeds the blog's "$X total" claim). Expected: teacher gen $5–10, FT $1–3, eval $2–4, GRPO $1–2, voice blending $0 (local CPU). $250 ceiling is nowhere near binding — spend on data quality if Day 3 quality is marginal.

## Verification (ship gates)
- 50 automated + 10 human sessions: 0 visible broken turns.
- Latency on the live Space CPU: first streamed token ≤2s, ≥10 tok/s sustained (typewriter keeps pace), TTS ready ≤3s after text completes. (PRD's "≤4s full turn" was written for a 270M model; with 2B the contract is *streaming* responsiveness, enforced by the 0.8B fallback gate.)
- Coherence ≥3.5/5 (LLM-judge); ≥90% sessions reach a real ending without fallback.
- `curl`-level network audit: no outbound calls during play (CI assertion).
- First commit check: `git log --format='%an %ae'` shows Codex attribution.

## Decisions log
1. Lore-narrator voice = blended Kokoro voice tensor (no public Kokoro training code exists), shipped as a 4th selectable narrator. Decided with user June 10.
2. Teacher = Qwen3-32B (Apache 2.0; avoids Llama output-naming clause). Bake-off vs Qwen3.5-27B only if smoke-batch quality disappoints.
3. **Student = Qwen3.5-2B** (user decision June 10, replacing the PRD's Gemma-3-270M which the user rejected as unworkable; "Qwen 4" doesn't exist). Ladder: Qwen3.5-0.8B (latency fallback) → Gemma 4 E2B (quality rung, blocked on organizer confirmation that its 5.1B total / 2.3B effective params pass the ≤4B Tiny Titan cap).
4. UI mechanism = `gr.Server` (Gradio ≥ 6.10) — confirmed real and explicitly named by the Off-Brand badge.
