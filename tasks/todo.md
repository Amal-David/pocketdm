# Hackathon demo push — build-small "digital pet you talk to"

Time box: ~2-3 hours → record demo. Branch: codex/pika-clean-demo-stack

## Product north star (for the demo)
- A **digital pet you can talk to anytime** (primary demo point).
- Talk via **text**, **voice-to-voice**, and **speech-to-text** (two mic/voice icons).
- **Daily morning affirmation / check-in** in a cheerful voice: "Hey, how are you doing? I hope you have a wonderful day!"
- Proactive care: **"How are you doing?"**, **drink-water reminders**.
- **A little intelligent** — learns the user's patterns.
- **Language learning is a side feature**, kept minimal/on the side.
- All replies come from the local MiniCPM brain; voice via VoxCPM; STT via Nemotron/Whisper. Fully local / "build small".

## Workstreams
- [ ] A. (agent) Read HF hackathon field-guide → alignment brief (rules, judging, token wallet, positioning)
- [ ] B. (agent) Codebase architecture map + safe cleanup checklist + exact restart command
- [ ] C. (agent) Designer: pinpoint exact SwiftUI fixes for the 2 UI bugs (read-only → edit instructions)
- [ ] D. (me) Relax `pikaVoiceLine` so the pet speaks full cheerful sentences (not canned "Pika pika!")
- [ ] E. (me) UI fixes: panel too transparent (hard to read) + clipped "Realtime listening" pill + audio indicator animating continuously when idle
- [ ] F. (me) Restart the full local demo stack (sidecars + app) with VoxCPM voice
- [ ] G. (me) Verify: build passes, app launches, talk → full-sentence voice reply, UI readable
- [ ] H. Cleanup pass per agent B (safe items only), keep repo green

## Review

### Done + verified (with receipts)
- **D. Voice speaks full sentences** — `pikaVoiceLine` (main.swift) relaxed to speak the actual reply (cap 300 chars on a sentence boundary); server `_synthesis_text` passthrough fix loaded. VERIFIED: short "Hi."=1.12s vs long sentence=6.4s → duration tracks real text.
- **E. UI fixes (code applied, compiles)** — panel card opacity 0.58→0.92; chat/journal/coach transcript 0.72→0.95 (readable); pet-only status footer now wraps 2 lines (no clip); `AudioWaveView` only animates during `.listening`/`.speaking` (static when idle/thinking/transcribing). ⚠️ NOT visually confirmed — screencapture blocked (no Screen Recording perm).
- **F. Restart** — VoxCPM TTS sidecar bounced (pid 1057, steps=16) to load the fix; app rebuilt (swift build OK, 128s) + relaunched (pid 3912) attached to live stack; MiniCPM env label corrected.
- **G. End-to-end** — all 5 services healthy (web/voxcpm/whisper/nemotron/minicpm5). Full loop: session → MiniCPM reply → VoxCPM full-sentence voice. ✅
- **Stack = OpenBMB**: LLM=MiniCPM5-1B-Q4 (≤4B → Tiny Titan), TTS=VoxCPM-0.5B. ✅

### Strategic flags (need owner decision)
- ⚠️ Hackathon deadline appears past (Jun 15 23:59 UTC). Confirm late/community eligibility in Discord.
- ⚠️ Submission must be a **Gradio Space** (REQ-02). Gradio app exists (`app/server.py` :7860); macOS pet is the demo, not the entry. Needs a Space wrapper.

### Remaining
- [ ] Owner: eyeball the app UI (transparency/pill/indicator) — only unverified item.
- [ ] Optional cleanup (CodeMapper): drop `models/gemma-4-e2b-it` (20GB) + `2b-v1-lora` (3GB); commit untracked demo files so a stray `git checkout` can't wipe them.
