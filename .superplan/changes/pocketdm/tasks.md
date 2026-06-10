# Task Graph

## Graph Metadata
- Change ID: `pocketdm`
- Title: PocketDM — offline voiced tiny-model Dungeon Master (Build Small hackathon)

## Graph Layout

- `T-0001` Repo + Codex bootstrap (git, GitHub repo, PRD.md updated to Qwen3.5-2B, specs/, first Codex-attributed commit)
  - depends_on_all: []
- `T-0002` WP-1 Freeze turn schema: engine/schema.py + engine/grammar.gbnf + round-trip tests
  - depends_on_all: [T-0001]
- `T-0003` WP-2 Engine skeleton: state machine, delta validation, story pressure, fallback, CLI REPL
  - depends_on_all: [T-0002]
- `T-0004` WP-0 Latency benchmark: stock Qwen3.5-2B Q4_K_M on free-tier Space, measure tok/s, decide 2B vs 0.8B
  - depends_on_all: [T-0001]
- `T-0005` WP-3 Teacher pipeline: Modal vLLM Qwen3-32B generator + quality filters; smoke batch then full overnight run
  - depends_on_all: [T-0002]
- `T-0006` WP-4 Training: Unsloth fine-tune Qwen3.5-2B on Modal + GGUF export (Q4_K_M ship)
  - depends_on_all: [T-0004, T-0005]
- `T-0007` WP-5 Eval harness: automated metrics + LLM-judge rubric on held-out seeds
  - depends_on_all: [T-0002]
- `T-0008` WP-6 llama.cpp integration test: 50 grammar-clean automated sessions CI script
  - depends_on_all: [T-0003, T-0006]
- `T-0009` Publish model + dataset repos on HF with eval table
  - depends_on_all: [T-0006, T-0007]
- `T-0010` WP-V Lore Narrator voice: Kokoro tensor blend + audition grid + reverb DSP + voices.bin artifact
  - depends_on_all: [T-0001]
- `T-0011` WP-7 gr.Server backend: endpoints, llama.cpp + GBNF, kokoro-onnx sequential TTS
  - depends_on_all: [T-0003]
- `T-0012` WP-8 Parchment frontend: custom HTML/CSS/JS, typewriter streaming, badge, dice, mobile
  - depends_on_all: [T-0011]
- `T-0013` Deploy Space to hackathon org, measure live tok/s, 15-turn voiced session clean
  - depends_on_all: [T-0008, T-0010, T-0012]
- `T-0014` Polish + playtests + run_local.sh airplane-mode proof
  - depends_on_all: [T-0013]
- `T-0015` Demo video (≤2:00) + Field Notes blog draft
  - depends_on_all: [T-0014]
- `T-0016` Submission: README frontmatter tags verified, traces dataset, social post, submit
  - depends_on_all: [T-0009, T-0015]

## Notes
- Plan of record: /Users/amal/.claude/plans/prd-pocketdm-cryptic-jellyfish.md (also committed as specs/PLAN.md).
- All production code authored via `codex exec` (Codex-attributed commits); Claude orchestrates, reviews, runs Modal/HF commands.
- Ladder gates: <10 tok/s on Space → retrain on Qwen3.5-0.8B; coherence <3.5 → data iteration before any rung change.
