# Pika Experience QA Brief

Scope: always-on native Pika pet in `/Users/amal/listenowl/experiments/build-small`.
This is a review artifact only; app code was not changed.

## Executive Bar

The next 5-6 hour stabilization loop should stop adding new pet systems until
the core realtime loop is reliable:

1. User types or speaks a normal desktop request.
2. Pika immediately shows it heard the user.
3. The local assistant path gets the right context or tool result.
4. The bubble gives a useful answer in Pika character.
5. A crisp original Pika voice cue is actually audible.
6. The pet state and animation match the response.
7. Failure states explain what is missing and how to recover.

Current live evidence shows this loop is not passing yet:

- `POST /api/assistant` with `Hello what is the time now` returned the adventure
  hint about `Study the silver acorn`.
- `POST /api/assistant` with `What is the weather and should I do a morning
  check-in?` returned the same adventure hint.
- `http://127.0.0.1:7861/health` is up in `stub` mode, and `/tts` returns a
  valid 0.83s WAV for `Pikaa Pikaa!`, but the user reported no audible playback.
- `/api/start` reported `"backend":"scripted"`, not `llama.cpp`, so the current
  running demo is not proving the local LLM orchestration promise.

## Top UX Defects

### P0 - Assistant Answers The Wrong Product

The native `ask` path sends raw text to `/api/assistant`. The server assistant
is still game-session logic: if the message contains `what`, `hint`, or `help`,
it returns an adventure recommendation. That is why basic requests like time and
weather produce silver-acorn hints.

Acceptance:

- `Hello what is the time now` returns current local time in the text bubble.
- `What is the weather?` returns the fetched morning weather and asks for a
  check-in when appropriate.
- `Can you hear me?` returns the current STT/listening state, not a generic hint.
- `Open settings`, `mute`, `close`, `minimize`, and `show journal` route to
  native action intents or clear guidance.
- The prompt sent to the local model includes a compact context envelope:
  user utterance, local time, weather summary, pet mood, current mode, STT/TTS
  health, and allowed app actions.
- Demo proof shows the backend is `llama.cpp` or clearly labels fallback as
  scripted.

### P0 - No Audibility Proof For Pika Voice

The app can request sidecar audio and the sidecar can return WAV bytes, but the
native UI marks the reply as playing before the async sound request is proven
audible. If `NSSound.play()` fails, the user gets no visible error.

Acceptance:

- Every assistant reply triggers exactly one audible Pika cue unless muted.
- The cue is a short crisp syllable line, for example `Pikaa Pikaa!`, not a
  mumbled long English narration.
- The UI distinguishes `Playing Pika voice`, `Voice played`, `Muted`, and
  `Voice unavailable; using local chirp`.
- A test command can generate and inspect a WAV:
  `curl -s -X POST http://127.0.0.1:7861/tts ...`
- A native smoke test or manual checklist verifies the user can hear output from
  the app, not only that the sidecar produced bytes.
- If the app launched without `POCKETDM_PIKA_TTS_URL`, it surfaces that in the
  settings/status panel.

### P0 - STT Is Not Realtime Enough

The current native path uses macOS Speech with partial text and manual stop/send.
It is useful, but it does not yet feel like an agentic conversation because turn
end, interruption, audio reply, and recovery are not tightly controlled.

Acceptance:

- Press `Talk now`; visible feedback appears in under 200ms.
- Partial transcript appears while speaking.
- `Send voice` sends the current transcript deterministically.
- If no transcript is captured, the bubble says exactly why: permission denied,
  recognizer unavailable, no mic input, or silence.
- User can interrupt while Pika is speaking; current Pika audio stops.
- The same utterance works by typed input and voice input.
- The flow is compatible with a future LiveKit room, but does not require
  LiveKit for the immediate demo.

### P1 - Weather Check-In Is Not Yet Product-Grade

The native model has a morning weather fetch path, but it defaults to fixed
coordinates and is not yet clearly orchestrated through the local assistant.

Acceptance:

- Weather location is explicit: env vars, app setting, or user-approved location.
- On morning open or Affirm, Pika says a weather-specific line:
  `It's beautiful weather, isn't it? Want to do a check-in with me?`
- Gloom/rain/fog/storm copy changes tone without becoming negative.
- Offline/weather failure gives a local fallback and says weather could not be
  refreshed.
- The local LLM receives the weather summary and writes the final short Pika
  line; deterministic code only supplies facts and safety rails.

### P1 - Minimize, Expand, Close, And Settings Need Reliability Proof

The code has pet-only mode, hover-only controls, settings, close, and expanded
mode. The risk is discoverability and hit testing: hidden controls must not make
the app feel trapped, and minimize must always return to pet-only.

Acceptance:

- Default launch shows only animated Pika.
- Hover over the visible pet reveals gear and close X within 150ms.
- Moving off the visible pet hides gear and close X without flicker.
- Click Pika expands the panel; minus returns to pet-only.
- Close works from hover X, expanded settings, and menu-bar fallback.
- Dragging the pet does not accidentally expand, close, or open settings.
- Mute persists and suppresses all sounds without suppressing text.

### P1 - Conversation Feels Like A Button Demo, Not A Pet

Pika currently has many loops and labels, but the live trust gap makes the
experience feel scripted. The demo needs fewer visible systems and stronger
moment-to-moment responses.

Acceptance:

- Pika reacts differently to greeting, question, success, confusion, tiredness,
  weather, and check-in.
- The spoken cue, sprite mood, and text intent match.
- Pika never answers general desktop questions with adventure-only text.
- Daily HP/Joy reward appears only after a real pet/check-in action.
- Long system copy is hidden from the small overlay; only user-relevant lines are
  visible.

## Priority Order For The Stabilization Loop

1. Build a deterministic assistant router around `/api/assistant` for desktop
   intents before the game hint logic sees the request.
2. Add a local context envelope and tool results for time, date, weather,
   app/service health, pet state, and allowed native actions.
3. Prove the launched backend is local LLM mode when claiming local LLM
   orchestration; otherwise show `scripted fallback` in the UI and docs.
4. Add TTS playback telemetry in the native model: requested, sidecar response,
   native `NSSound.play()` result, fallback used, muted.
5. Tighten STT recovery states and make voice input follow the same assistant
   router as typed input.
6. Verify minimize/expand/hover/close controls by manual desktop pass.
7. Only after these pass, resume pet lore, language packs, sprite sheets, and
   long-tail emotional loops.

## Use-Case Matrix

These are the minimum scripted scenarios for the reviewer/council loop. Each
case should record text response, audio result, mood, latency, and pass/fail.

| ID | Scenario | Must Pass |
| --- | --- | --- |
| 01 | Type `Hello` | Warm Pika greeting plus audible cue |
| 02 | Type `What time is it now?` | Current local time, no adventure hint |
| 03 | Type `What day is it?` | Current date/day |
| 04 | Type `What is the weather?` | Weather summary or explicit unavailable state |
| 05 | Click `Affirm` in morning | Weather-aware affirmation check-in |
| 06 | Type `I feel tired` | Empathy response, soft Pika cue, no forced hype |
| 07 | Type `I am stuck` | One tiny next step, question cue |
| 08 | Type `I finished a task` | Joy/Sparks reward only if appropriate |
| 09 | Type `status` | Pet + adventure status separated clearly |
| 10 | Type `hint` | Adventure hint only when user asks for hint |
| 11 | Type `mute` | Sounds off and visible muted state |
| 12 | Type `unmute` | Sounds on and audible confirmation |
| 13 | Type `close` | Safe close affordance or confirmation |
| 14 | Type `minimize` | Pet-only mode |
| 15 | Type `open settings` | Settings visible |
| 16 | Press `Talk now` | Listening feedback under 200ms |
| 17 | Speak a short greeting | Partial transcript and reply |
| 18 | Speak `what time is it` | Same result as typed time |
| 19 | Stop voice with empty transcript | Clear no-input recovery |
| 20 | Deny Speech permission | Specific permission message |
| 21 | Kill TTS sidecar | Text still appears; fallback/status visible |
| 22 | Restart TTS sidecar | Voice resumes without relaunch if feasible |
| 23 | Turn mute on, ask question | No audio, text response normal |
| 24 | Ask while backend is down | Visible recoverable backend error |
| 25 | Launch without local LLM | UI labels scripted fallback honestly |
| 26 | Launch with llama.cpp active | UI labels local model and model name |
| 27 | Click Pika in pet-only mode | Expands reliably |
| 28 | Click minus | Returns to pet-only reliably |
| 29 | Hover Pika | Gear/X appear only over visible pet |
| 30 | Move mouse away | Gear/X hide without flicker |
| 31 | Drag pet | Moves without accidental expand |
| 32 | Click close X | App exits or hides exactly as intended |
| 33 | Open Learn mode | No pet catchphrase pollution in lesson feedback |
| 34 | Spanish TTS replay | Uses language TTS, not Pika chirp |
| 35 | Mandarin TTS replay | Uses Mandarin voice/pinyin support |
| 36 | Start daily check-in | Asks one short check-in question |
| 37 | User interrupts Pika audio | Current audio stops |
| 38 | Ask same question twice | Consistent answer, no duplicate Pika prefix |
| 39 | Very long user message | Clipped safely with visible handling |
| 40 | No network weather | Falls back without blocking chat |

## Reviewer Council Rubric

Use these as internal review roles, not user-facing UI.

- Experience Director: Does the pet feel alive within 10 seconds, or like a
  control panel?
- Voice Director: Are Pika syllables crisp, audible, short, and intentional?
- Interaction Director: Are Talk, send, minimize, close, settings, mute, and
  drag reliable?
- Local-AI Director: Is the workflow actually local LLM + STT + TTS, or is it
  a scripted/backend fallback being presented as local intelligence?
- Hackathon Director: Can the demo be explained in one minute and survive the
  obvious judge questions: why local, why pet, why voice, why useful?

## Done Criteria For The Next Loop

Do not call this stabilized until all of these are true:

- `swift build --package-path /Users/amal/listenowl/experiments/build-small/macos/PocketDMCompanion` passes.
- `PYTHONDONTWRITEBYTECODE=1 uv run pytest tests/test_pika_tts_server.py tests/test_server.py tests/test_offline.py -q` passes.
- Live `/api/assistant` checks for time, weather, greeting, status, and hint pass.
- Live `/tts` returns WAV and the native app audibly plays it.
- Manual desktop pass confirms pet-only default, hover controls, minimize,
  expand, close, typed send, Talk/send voice, mute, and weather affirmation.
- The UI honestly reports whether it is using `llama.cpp`, scripted fallback,
  Pika TTS sidecar, or bundled chirps.
