# WP-4 — Fine-tune Qwen3.5-2B AND 0.8B on Modal (Unsloth), export GGUF

Read PRD §5.3 (TR-1..TR-4) and the bench decision in `.superplan/decisions.md` (2026-06-10): **both sizes are trained**; 2B is primary, 0.8B is the latency drop-in. Final pick happens on live Space play-feel.

## Deliverables

1. `train/finetune.py` — Modal app, parameterized by size:
   - `modal run train/finetune.py --base unsloth/Qwen3.5-2B --data data/clean/train.jsonl --out-volume pocketdm-models --run-name 2b-v1` (and `--base unsloth/Qwen3.5-0.8B`).
   - GPU: A100-40GB (2B full FT fits; fall back to `--lora` flag if OOM — log which path ran).
   - Unsloth `FastModel.from_pretrained(..., full_finetuning=True)`; chat-template formatting must reproduce EXACTLY the inference-side message rendering (Qwen3.5 chat template, thinking disabled); **completion-only loss** (train on the turn-JSON target only, mask the prompt); packed sequences; 2–3 epochs (`--epochs`), cosine schedule, lr 2e-5 full FT / 2e-4 LoRA defaults; seed fixed.
   - Eval split: 2% of train pairs for eval loss each epoch; print final train/eval loss.
   - Save merged model (safetensors) to a `modal.Volume`; print GPU-seconds and $ estimate line for `tasks/costs.md`.
2. `train/export_gguf.py` — Modal function (CPU or small GPU): convert merged model → GGUF via llama.cpp's `convert_hf_to_gguf.py` + `llama-quantize` → **Q4_K_M (ship)** and Q8_0 (comparison); download artifacts to `models/` locally (gitignored); print SHA256 + sizes.
3. `train/smoke_infer.py` — local: load the Q4_K_M with llama-cpp-python (or pinned llama.cpp `llama-cli`), run 3 turns with `engine/grammar.gbnf` + `engine/prompt.py` against a fixed state, print the JSON turns. This is the "did the fine-tune actually learn the task" eyeball check before the full WP-5 eval.
4. Update `pyproject.toml` dependency group `train` only if local code needs anything (Modal image deps live in the Modal app).

## Constraints
- Unsloth pinned to a version with documented Qwen3.5 support (see https://unsloth.ai/docs/models/qwen3.5/fine-tune); pin llama.cpp release b9587+ for conversion (Qwen3.5 hybrid arch).
- Idempotent + cheap re-runs: dataset cached in a Volume, model weights cached, `--max-steps` flag for a 20-step smoke run.
- Never bake tokens/secrets into code; HF token via Modal secret `huggingface`.
