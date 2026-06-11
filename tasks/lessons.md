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

## 2026-06-10 — codex exec inherits the shell's cwd as its sandbox root
A `cd` into a subdirectory in a prior command silently scoped a later `codex exec`
workspace-write sandbox to that subdir (it reported the whole repo as read-only).
**Rule:** always pass `-C <repo-root>` explicitly to `codex exec`; verify the
`workdir:` line in its output header before trusting a run.

## 2026-06-11 — When the user says "speed" on Gemma 4, check MTP first
The "not too quantized" path improved quality knobs but missed the user's screenshot:
Gemma 4 MTP/speculative decoding is the speed lever. The working local path needs
native recent llama.cpp `llama-server`/`llama-cli` support with `--spec-type draft-mtp`;
`llama-cpp-python` alone cannot load the Gemma4Assistant drafter because it needs
`ctx_other` shared with the target context.
**Rule:** for Gemma 4 latency work, prioritize MTP server/CLI proof, tune
`--spec-draft-n-max` on the actual hardware, and keep the Python binding as the
fallback quality/smoke path.
