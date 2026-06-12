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

## 2026-06-12 — Browser TTS must have a single audio owner
User reported overlapping sound after clicking answer choices. The frontend was
starting async narration audio while Ember's browser speech could also speak, and
old `/api/tts` responses could still start after the next turn began.
**Rule:** when a new turn/action starts, abort pending TTS, stop any current
narration, cancel browser speech, and make turn-result assistant text silent
unless the user explicitly asks Ember to speak.

## 2026-06-12 — The dragon visual must be cinematic, not cute mascot art
User rejected the green cute sprite and clarified the target is a How to Train
Your Dragon-like 3D companion feel: sleek, dark, expressive, pet-like, and
always-on above the screen.
**Rule:** keep Ember original, but steer the artifact toward glossy black
cinematic dragon traits, expressive eyes, wing silhouette, and desktop-pet
behavior; do not ship a generic cartoon dragon or a chat widget with a mascot.

## 2026-06-12 — Use anime-mascot energy without shipping protected characters
User suggested a top anime pet direction such as Pikachu because the shape reads
faster than the custom dragon attempts.
**Rule:** do not use official character sprites, names, or catchphrases in the
public hackathon artifact. Build an original electric familiar with yellow
mascot readability, cheek sparks, and short custom chirps like "zip-zip" instead.

## 2026-06-12 — Sprite sheets should become pet states, not decoration
User provided 3D mood sheets and wanted the whole app to pick up that livelier
desktop-pet feeling.
**Rule:** when good reference sheets arrive, extract a consistent frame format
and wire the app around visible states like happy, nap, hyper, and alert; don't
leave the asset as a static mascot beside a normal chat UI.

## 2026-06-12 — Native pet polish beats branded action names
User cared about the macOS overlay itself, not the browser, and called out the
sprite extraction border plus marketing-heavy labels like Spark.
**Rule:** verify the actual desktop overlay, regenerate masks when source-sheet
halos appear, and prefer literal state labels such as Happy, Nap, and Hyper.

## 2026-06-12 — Minimized native pets still need core utility
User wanted the minimized macOS companion to remain a real chat surface, not a
tiny decorative pill.
**Rule:** collapsed native overlays should keep the animated pet, response
preview, direct input, send control, mute toggle, and expand control; avoid
marketing-heavy visible labels and remove source-sheet halo pixels before
shipping screenshots.

## 2026-06-12 — Default desktop-pet mode must be pet-first, not chat-first
User corrected the minimized state again: the default surface should show only
the animated pet, and clicking the pet should expand the chat/care interface.
**Rule:** for the native companion, make the character the primary affordance:
pet-only default, click-to-expand chat, visible close in expanded mode, and a
small daily care loop with Bond HP/Joy rather than a generic compact chat strip.

## 2026-06-12 — Low-alpha dark pixels still read as a border
User pointed at a black contour around the minimized 3D pet even after the
SwiftUI border was gone. The line came from semi-transparent dark pixels baked
into the extracted sprite edge.
**Rule:** when extracting 3D mascot sheets, pixel-check the alpha fringe on a
white background, remove dark/gray low-alpha halo pixels, and regenerate native
plus web strips from the original sheets instead of trying to hide the issue in
layout code.

## 2026-06-12 — Language packs must be real packs, not demo cards
User corrected the language coach scope after the first Spanish/Mandarin demo
used only a few cards.
**Rule:** language-learning packs should ship as explicit word and sentence
sections with at least 100 entries each per language, and the native lesson
store should count the whole pack rather than hard-code the first three cards.
