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

---

# VAD-gated turn-taking voice pipeline (isolated worktree)

Replace the buggy energy-meter turn detector with a Pipecat/LiveKit-style
streaming Silero-VAD turn loop. Demo sidecars (7861/7862/7863) untouched.

## Part A — Server (`app/nemotron_streaming_asr_server.py`)
- [ ] Env knobs: `POCKETDM_WS_VAD` (on), `POCKETDM_VAD_THRESHOLD` (0.5),
      `POCKETDM_VAD_SILENCE_MS` (700), `POCKETDM_VAD_PAD_MS` (300),
      `POCKETDM_VAD_MIN_SPEECH_MS` (120 — drop clicks).
- [ ] Per-connection `VADIterator` via cached `_silero_vad_model()`.
- [ ] On `{"type":"start", ..., "vad": true}` enter VAD path; reply `ready`.
- [ ] Buffer int16 PCM bytes -> 512-sample float32 @16k frames; feed VADIterator.
- [ ] Emit `speech_started`/`speech_ended`; on end, transcribe that turn's
      buffered segment, send `partial`+`final`, reset turn buffer, keep socket open.
- [ ] Drop start spans shorter than min-speech.
- [ ] BACKWARD COMPAT: `vad` absent/false keeps today's end-triggers-transcribe.
- [ ] faster-whisper fallback path untouched.

## Part B — Client (`macos/.../main.swift`)
- [ ] DELETE `scheduleVoiceAutoSendIfNeeded()` + `currentMeterPower()` + meter calls.
- [ ] Live mic stream via AVAudioEngine tap -> AVAudioConverter (16k mono int16)
      -> push PCM frames into open WS. Send `{"type":"start","sample_rate":16000,"vad":true}`.
- [ ] Finalize turn on server `final`; `partial` updates live UI. Hands-free re-arms.
- [ ] Preserve NON-realtime fallback (faster-whisper batch / system speech).
- [ ] (Optional) barge-in flag stub only; default OFF.

## Verify
- [ ] `swift build -c release --package-path macos/PocketDMCompanion`.
- [ ] `uv run --group dev pytest -q` green; update native snapshot tests to VAD.
- [ ] Focused server test for VADIterator turn loop (monkeypatched, importorskip).
- [ ] Commit in worktree branch; report branch + SHA + honest caveats.

## Review (VAD pipeline)

### Done + verified
- **Part A (server)** — new `StreamingVADTurnDetector` wraps Silero `VADIterator`
  (512-sample @16k frames), per-connection via cached `_silero_vad_model()`. WS
  `start` with `vad:true` enters a multi-turn loop: emits `speech_started`/`speech_ended`,
  transcribes each confirmed utterance, sends `partial`+`final` (`streaming_mode:"vad-turn"`),
  resets the turn buffer, keeps the socket open. Sub-min-speech blips dropped.
  Env knobs: `POCKETDM_WS_VAD`, `POCKETDM_VAD_THRESHOLD`, `POCKETDM_VAD_SILENCE_MS`,
  `POCKETDM_VAD_PAD_MS`, `POCKETDM_VAD_MIN_SPEECH_MS`. Backward compat preserved
  (no `vad` flag → legacy `end`-triggers-transcribe). Graceful degrade if silero missing.
- **Part B (client)** — energy meter deleted (`scheduleVoiceAutoSendIfNeeded`,
  `currentMeterPower`, -38 dB / 1.25 s / 10 s rules, recorder metering). New
  `RealtimeVADStreamingSession` taps the live mic → AVAudioConverter (16k mono Int16)
  → pushes PCM into the open VAD WebSocket. Turn finalizes on server `final` →
  `finishVoiceConversation`. Non-realtime faster-whisper batch fallback intact.
  Barge-in present as an OFF-by-default flag stub only.
- **Verify** — `swift build -c release` OK (clean, 0 warnings). `pytest -q` = 180 passed,
  7 skipped (dep-gated), 1 xfailed. Native snapshot tests updated to VAD intent.
  New server VAD tests pass with real silero installed (throwaway venv), skip cleanly
  without it. Demo sidecars 7861/7862/7863 untouched (in-process TestClient only).

### Needs the user's live-mic test (cannot verify here — no real mic)
- Speak a sentence hands-free → pet replies once per pause; multi-turn keeps working
  on the same WS without re-tapping the mic.
- Confirm AVAudioConverter resampling on the real input device (48k→16k) yields clean
  STT (the conversion path is the riskiest unverified spot).
- Confirm no double-finalize / dropped first word at turn boundaries.

---

# Workstream 3 — Native first-run flow + stack orchestration

## Part A — start_stack.sh (new)
- [ ] Write `macos/PocketDMCompanion/scripts/start_stack.sh`
- [ ] Start ONLY brain(8081) + Kokoro TTS(7861) + faster-whisper STT(7862) + web(7860)
- [ ] Skip Nemotron ASR sidecar (avoids multi-GB NeMo install)
- [ ] Idempotent (skip if port already live), emit `STACK_STARTED`

## Part B — native first-run flow (main.swift)
- [ ] Distributed-build detection (Bundle.main.resourceURL has pocketdm-runtime)
- [ ] Gate applicationDidFinishLaunching: dev path unchanged; distributed bootstrap
- [ ] BootstrapModel: ObservableObject (Process + Pipe + PROGRESS parsing)
- [ ] BootstrapView (SwiftUI, design system) + BootstrapWindow (NSWindow)
- [ ] State machine: bootstrap -> start_stack -> poll 7860 health -> pet
- [ ] PocketDMServerProcess honors POCKETDM_WEB_VENV (or distributed path owns web)

## Part C — verification
- [x] swift build -c release green between parts (clean, 0 warnings)
- [x] uv run --group dev pytest -q green (182 passed, 5 skipped, 1 xfailed)
- [x] Commit each part w/ Co-Authored-By trailer; push branch
- [x] Do NOT relaunch user's running app / sidecars (verified by build+read only)

## Review (Workstream 3)
- start_stack.sh: brain 8081 / Kokoro 7861 / faster-whisper 7862 / web 7860;
  Nemotron 7863 intentionally skipped (auto backend pulls multi-GB NeMo+torch;
  realtime path falls back to batch STT). Idempotent per-port; emits STACK_STARTED.
- Distributed gate: payload present AND POCKETDM_REPO absent. Dev (launch_app.sh
  always exports POCKETDM_REPO) keeps the existing attach-and-show path verbatim,
  so test_native_lifecycle_flow still passes (overlayController?.show() present,
  showExpanded() absent in applicationDidFinishLaunching).
- State machine: detect -> [first run] BootstrapWindow + first_run_bootstrap.sh
  (PROGRESS streamed) -> start_stack.sh -> poll 7860 /health -> didBootstrap=true
  -> pet; [later] start_stack.sh -> health -> pet. ERROR/health-timeout -> Retry.
- PocketDMServerProcess honors POCKETDM_WEB_VENV; distributed path lets
  start_stack.sh own the web server (no --launch-server).

### Caveats (need a real fresh-Mac launch test — not possible here)
- End-to-end first run (uv install, Metal wheel, MiniCPM download, all 4 venvs,
  espeak-ng for Kokoro) is unverified on a clean machine.
- BootstrapWindow visuals (hero, gold progress, scrolling log) unverified live.
- Web venv import of app.server confirmed torch-free by reading imports only.
