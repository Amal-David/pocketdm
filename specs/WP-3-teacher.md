# WP-3 — Synthetic adventure generation on Modal (teacher = Qwen3-32B)

Read `PRD.md` §5.2 (DR-1..DR-6) and reuse `engine/` (schema, prompt, pressure, state) — the teacher must see EXACTLY the prompts the student will be trained on.

## Deliverables

1. `data/teacher_gen.py` — a Modal app (`modal run data/teacher_gen.py --adventures 50 --out data/out/smoke.jsonl`):
   - One H100 (or A100-80GB fallback) container running **offline vLLM** (`vllm.LLM`, not a server) with `Qwen/Qwen3-32B`, structured output via vLLM's xgrammar backend using `engine.schema.Turn.model_json_schema()` (`/no_think` — keep reasoning off).
   - Simulates complete adventures: engine `GameState` + `build_messages` from `engine/prompt.py` → teacher emits turn JSON → engine validates + applies delta → a **player persona** picks the next action → repeat until `is_ending` or turn 15.
   - Player personas (rotate per adventure): `greedy` (picks the choice mentioning items/reward), `curious` (picks the most novel choice vs. history), `chaotic` (random choice, 20% of the time a freeform action sampled from a template list like "I befriend the {noun}"). Seeded RNG per adventure id.
   - Premise variety: ~30% of adventures get a one-line premise sampled from a 40+ entry template list (genre-appropriate, whimsical).
   - Batching: drive N adventures concurrently (vLLM continuous batching does the work — submit per-adventure next-turn requests in waves; target ≥64 concurrent sequences).
   - Output JSONL, one line per adventure: `{"adventure_id", "genre", "premise", "persona", "seed", "turns": [{"state_summary", "messages", "turn_json", "action_taken"}]}` — `messages` is the exact training input, `turn_json` the exact target.
   - Logs: adventures/min, schema-failure count, $ estimate (GPU-seconds × rate) printed at end. Append the run line to `tasks/costs.md` format (print it; do not edit the file).
2. `data/filters.py` + `data/filter_run.py` (CLI: `uv run python data/filter_run.py data/out/*.jsonl --out data/clean/`):
   - Turn-level gates per DR-4: schema-valid (re-parse), narration 2–4 sentences (split on `.!?`), choices pairwise distinct (embedding cosine < 0.85 via `sentence-transformers` `all-MiniLM-L6-v2`, CPU), no choice repeated from the previous turn, delta legal for the tracked state, profanity wordlist (use `better-profanity`), narration length ≤ 600 chars.
   - Adventure-level gates: reached a real ending (`is_ending` true before forced cap counts as real; pure cap-forced = drop), ≥6 turns, ≤1 bridge/invalid turn dropped.
   - Report: pass rates per gate (the ≥95% target is measured here), written to `data/clean/REPORT.md`.
3. `data/build_dataset.py` — flatten clean adventures into training pairs JSONL `{"messages": [...], "completion": "<turn json>"}`; split: hold out 100 complete adventures (stratified by genre) into `data/clean/holdout_seeds.jsonl`; the rest → `data/clean/train.jsonl`. Print counts.

## Constraints
- Modal idioms: `modal.App`, `modal.Image.from_registry` with vLLM pinned, `@app.function(gpu="H100", timeout=...)`, model weights cached in a `modal.Volume`.
- The teacher sees the SAME system prompt/pressure text as inference will — import from `engine/`, never duplicate strings. The ≤350-token prompt budget in `engine/prompt.py` therefore applies to training data automatically; do not pad prompts in the generator.
- Deps go in the Modal image, not the local pyproject (local only needs: `sentence-transformers`, `better-profanity` in a `data` dependency group).
- Smoke mode first-class: `--adventures 50` must run end-to-end in <15 min.
