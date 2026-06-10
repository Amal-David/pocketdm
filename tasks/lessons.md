# Lessons

## 2026-06-10 — Don't trust a PRD's model pick; verify against the current landscape
The PRD specified Gemma-3-270M as the student model. User rejected it as unworkable.
Also: "Qwen 4" doesn't exist (newest small gen = Qwen3.5), and Gemma 4's smallest model
is 5.1B *total* params — naming generations from memory is hazardous.
**Rule:** before any training spend, (1) re-verify the model landscape with fresh research,
(2) confirm the size/quality tradeoff with the user, (3) check prize/size caps against
*total* params, not marketing "effective" params.

## 2026-06-10 — Licenses propagate through outputs, not just weights
Llama-3.3's license forces models trained on its *outputs* to carry "Llama" in the name.
**Rule:** check the teacher's license before generating synthetic data, not after.
