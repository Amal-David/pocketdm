# WP-5 — Eval harness (automated metrics + LLM judge)

Read PRD §5.5 (ER-1..ER-3). Outputs feed the model card (base-vs-finetuned table), the ship gate, and the Field Notes blog.

## Deliverables

1. `eval/harness.py` — local CLI: `uv run python eval/harness.py --model models/pocketdm-2b-Q4_K_M.gguf --seeds data/clean/holdout_seeds.jsonl --sessions 50 --out eval/results/<name>.json`:
   - Plays full sessions via `engine/` against llama.cpp (llama-cpp-python with `engine/grammar.gbnf`), seeded player persona (reuse WP-3 personas).
   - **Automated metrics (ER-1):** % turns schema-valid WITHOUT grammar (run each prompt twice: once grammar-free for this metric, once grammar-on for the session), choice-distinctness rate, delta-legality rate, % sessions completing ≤15 turns with zero bridge turns, mean tokens/turn, mean wall-clock/turn.
   - Must also run against the BASE (un-fine-tuned) GGUF for the before/after table.
2. `eval/judge.py` — Modal batch: LLM judge (reuse the Qwen3-32B teacher image) scores 50 held-out-seeded session transcripts on coherence / choice meaningfulness / ending satisfaction, 1–5 each, with a fixed rubric prompt and JSON-schema-constrained verdicts; outputs mean±sd per dimension.
   - Judge prompt must include 2 few-shot anchor examples (a clearly-bad transcript scored low, a good one scored high) so scores are calibrated, not vibes.
3. `eval/report.py` — merges results into `eval/results/REPORT.md`: metrics table (base vs 2B-FT vs 0.8B-FT), judge table, and an explicit SHIP GATE line: pass iff coherence ≥3.5 AND zero-bridge sessions ≥90%.
4. `tests/test_eval.py` — unit tests for metric computation on canned transcripts (no model needed).

## Constraints
- Deterministic: all sampling seeded; session seeds derived from adventure_id.
- The grammar-free schema-validity metric is THE before/after headline — make sure base-model failures are counted fairly (same max_tokens, same prompt).
- Judge cost target ≤$4; batch all 50 transcripts in one Modal run.
