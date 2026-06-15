# PocketDM Hackathon Submission Plan

## Consumer Pitch

PocketDM is a tiny offline adventure game with a native desktop companion. You
play a short fantasy quest, but the fun twist is that Pikachu lives on top of
your Mac: it reacts, gives hints, chirps, teaches quick Spanish and Mandarin
lessons, and earns daily Bond HP when you care for it. The model writes the
adventure flavor; the deterministic engine keeps the rules clean.

For judges, lead with the product surface: a playable adventure plus an
always-on pet that makes the tiny-model constraint feel charming instead of
technical.

## Current Evidence Snapshot

- Native macOS companion is the priority surface and is already implemented as
  a transparent desktop overlay.
- Default state is pet-only Pikachu. Clicking the pet expands chat, care, and
  learning controls.
- Companion supports Pet, Learn, Nap, and Hyper behaviors, a close control, mute
  control, original chirp sounds, and visible Bond HP/Joy/Day progress.
- Language coach ships Spanish and Mandarin packs with 100 words and 100
  sentences per language. Current resource count is 200 cards per language.
- Lessons use local macOS TTS voices through AVFoundation, with replay, slow
  audio, quiz choices, pronunciation tips, and daily practice rewards.
- Custom Gradio adventure app remains the playable fallback and API backend for
  the native companion.
- Optional GGUF and llama.cpp paths exist, including the Gemma 4 E2B MTP runbook,
  but the final tiny-model quality gate is not yet green.

## Creative Director Review

| Area | Verdict | Evidence | Remaining polish |
| --- | --- | --- | --- |
| First impression | Good | Pet-only desktop Pikachu is now the first surface. | Capture a clean video showing the pet floating over normal desktop work. |
| Character affordance | Good | Clicking the pet expands the overlay. Minimize returns to pet-only mode. | Make expand/minimize feel more character-led in the demo, with a clear bounce or reaction beat. |
| Visual asset quality | Good | Cleaned 3D sprite strips are bundled as native resources. | Recheck on a white desktop during video capture to prove no dark halo remains. |
| Daily loop | Good | Bond HP, Joy, Day streak, Pet action, and language-practice rewards are visible. | In the video, pet once and practice once so the reward loop is obvious. |
| Language learning | Good first version | Spanish and Mandarin have 100 words plus 100 sentences each, TTS, slow audio, tips, and quizzes. | Frame it as a compact beginner pack, not a complete language course. |
| Sound design | Good first version | Original chirps exist for send, reply, open, minimize, close, pet, and moods. | During capture, keep sounds subtle and verify mute visibly stops them. |
| Chat utility | Good | Expanded panel has Ask Pikachu entry and visible response. | Demo one status or hint response tied to the current adventure state. |
| Submission readiness | Partial | Playable app, native companion, docs, tests, and MTP runbook exist. | Demo video, social post, model repo, dataset/traces repo, final eval table, and final earned tags remain. |

## Model And Eval Risks

Tracked model/eval work is blocked, not ignored:

- `T-0007` is blocked because the current 2B GGUF eval is below the judge gate:
  coherence is 2.52 against a 3.5 target, even though zero-bridge reached 92%
  in one corrected report.
- `T-0008` is blocked because the current local 2B Q4_K_M GGUF does not pass
  the 50/50 grammar-clean session gate. A 2-session proof completed, but only
  1/2 sessions was grammar-clean because one session used bridge fallbacks.

Submission framing should therefore be honest: the product demo is playable now,
the native companion is the delight layer, and final fine-tune/eval receipts are
the remaining competitive-risk workstream.

## Public Asset Risk

The current prototype uses user-provided Pikachu-style generated sheets because
they communicate the desktop-pet idea immediately. For a public hackathon
submission, confirm the rules around branded or fan-art assets. If owned assets
are required, reskin the companion as an original electric creature while keeping
the same pet-only overlay, Bond HP, chirps, and language-coach behavior.

## Required Submission Assets

1. Demo video: 90-120 seconds, product first.
2. Social post: one short clip or GIF of desktop Pikachu opening into the lesson
   and hint panel.
3. Field notes/blog: tell the engine/model split and the native companion pivot.
4. Model repo: publish after final WP-4 training/export or clearly label the
   smoke GGUF as a plumbing checkpoint.
5. Dataset/traces repo: publish after WP-3 full filtering and holdout split.
6. Final README links and tags: add only earned badges after verification.

## Demo Video Shot List

1. Cold open on the desktop: Pikachu is the only visible overlay.
2. Click Pikachu. The panel opens with Bond HP/Joy and the Ask Pikachu field.
3. Start or show a PocketDM adventure and make one choice that changes HP,
   inventory, or location.
4. Ask Pikachu for a hint or status response tied to that state.
5. Tap Pet and show the daily Bond HP/Joy reward.
6. Tap Learn, choose Spanish, play normal and slow TTS, answer one quiz.
7. Switch to Mandarin and show pinyin/pronunciation guidance.
8. Toggle mute, tap a sound-producing control, then unmute.
9. Minimize back to pet-only mode and close cleanly.
10. End on evidence: tests, language pack counts, backend status, and honest
    model/eval gate state.

## Acceptance Gates Before Final Submit

- `swift build --package-path macos/PocketDMCompanion`
- `node --check app/static/app.js`
- `PYTHONDONTWRITEBYTECODE=1 uv run pytest tests/test_server.py tests/test_offline.py -q`
- Count Spanish and Mandarin packs at 100 words and 100 sentences each.
- Relaunch `macos/PocketDMCompanion/scripts/launch_app.sh --attach http://127.0.0.1:7860 --launch-server`
- Live-check pet-only default, expand, close, mute, chat, Pet, Learn, Spanish
  TTS, Mandarin TTS, quiz reward, and minimized border on a white desktop.
- If using GGUF in the video, verify the app visibly reports the real backend.
  If not, keep `Scripted` visible and call it a playable checkpoint.

## Next Work Order

1. Capture the native companion demo and use it as the main submission artifact.
2. Update README submission links as assets are produced.
3. Refresh field notes from the Pikachu/native companion story, replacing stale
   Ember/dragon language.
4. Decide whether to spend remaining time on model/eval recovery or present the
   smoke GGUF as an honest runtime checkpoint.
5. Run the final verification gates and freeze the tags.
