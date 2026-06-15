# LiveKit Pika Voice Agent Plan

## Purpose

Make the native Pika companion feel like a real-time desktop character, not a
button-triggered TTS demo. LiveKit should become the realtime session layer for
voice, turn-taking, interruptions, room events, and agent tools, while the
existing PocketDM app remains the product brain and native overlay.

This document is a plan only. It does not require app code changes by itself.

## Current Repo Surface

- Native macOS overlay:
  `/Users/amal/listenowl/experiments/build-small/macos/PocketDMCompanion/Sources/PocketDMCompanion/main.swift`
- Native launch script:
  `/Users/amal/listenowl/experiments/build-small/macos/PocketDMCompanion/scripts/launch_app.sh`
- Existing chat backend:
  `/Users/amal/listenowl/experiments/build-small/app/server.py`
- Existing chat endpoint:
  `POST /api/assistant`
- Existing web fallback TTS endpoint:
  `POST /api/tts`
- Pika TTS sidecar:
  `/Users/amal/listenowl/experiments/build-small/app/pika_tts_server.py`
- Pika TTS service script:
  `/Users/amal/listenowl/experiments/build-small/macos/PocketDMCompanion/scripts/start_pika_tts.sh`
- Current voice notes:
  `/Users/amal/listenowl/experiments/build-small/docs/pika-voice-stack.md`

The current native app already has a product-relevant shape: desktop overlay,
pet state, chat through `/api/assistant`, macOS speech capture, and an optional
Pika sidecar at `POCKETDM_PIKA_TTS_URL`. LiveKit should replace the fragile
local turn loop, not replace the companion UI.

## LiveKit Patterns To Use

LiveKit Agents now centers voice apps around these pieces:

- A LiveKit room is the realtime session boundary. The user/native client and
  the AI agent join as participants.
- An `AgentServer` registers one or more RTC sessions.
- An `AgentSession` runs the conversational loop.
- A voice pipeline can be assembled from STT, LLM, and TTS components.
- VAD, commonly Silero in the examples, handles speech activity.
- Turn detection, including a multilingual turn detector, decides when the user
  has finished speaking.
- Function tools let the LLM call app actions. Tools can also call frontend RPC,
  store session data, or generate speech.
- Open-source examples cover `listen_and_respond`, `tool_calling`,
  `update_tools`, `rpc_agent`, `transcriber`, `playing_audio`,
  `tts_comparison`, `tts_node_modifications`, `metrics_stt`, `metrics_vad`,
  `metrics_tts`, `agent_transfer`, and `warm_handoff`.

The important product translation: LiveKit owns realtime media and turn state;
PocketDM owns pet state, lore, rewards, and hackathon demo behavior.

## Target Architecture

### Participants

- `pika-native-client`
  - The macOS overlay from
    `/Users/amal/listenowl/experiments/build-small/macos/PocketDMCompanion/Sources/PocketDMCompanion/main.swift`.
  - Publishes microphone audio when the user presses Talk or enables live mode.
  - Subscribes to agent audio and data messages.
  - Shows partial transcript, final transcript, assistant response, mood state,
    and tool-driven animations.

- `pika-agent`
  - A Python LiveKit Agents worker, proposed future file:
    `/Users/amal/listenowl/experiments/build-small/app/livekit_pika_agent.py`.
  - Joins the same room as a participant.
  - Runs `AgentSession` with STT, VAD, turn detection, assistant reply routing,
    and TTS.

- `pocketdm-backend`
  - Existing FastAPI/Gradio server in
    `/Users/amal/listenowl/experiments/build-small/app/server.py`.
  - Continues to provide `/api/assistant`.
  - Future addition: token endpoint for LiveKit room access.

- `pika-tts-sidecar`
  - Existing sidecar in
    `/Users/amal/listenowl/experiments/build-small/app/pika_tts_server.py`.
  - Produces crisp original Pika syllable audio.
  - Should not attempt to speak long English replies in Pika mode. The bubble
    can show English; the voice should say clear intent-mapped lines like
    `Pikaa Pikaa`, `Pikaa?`, `Pikaa! Pikaaa!`, and slower sleepy variants.

### Realtime Flow

1. The native overlay asks the backend for a LiveKit access token.
2. The overlay joins a room such as `pocketdm-pika-<session_id>`.
3. The LiveKit worker dispatches or joins as `pika-agent`.
4. User presses Talk or live mode starts; the native overlay publishes mic
   audio.
5. `AgentSession` receives audio, uses VAD and turn detection, and produces a
   final transcript.
6. The agent posts the transcript to the existing `/api/assistant` endpoint.
7. The backend returns the text reply and any future state hints.
8. The agent maps the reply intent to a crisp Pika voice line and asks the Pika
   TTS sidecar for WAV audio.
9. The agent speaks into the room and sends a data message to the native overlay
   with the full text reply, transcript, mood, and animation cue.
10. The overlay updates the bubble, plays the agent audio, and triggers the pet
    animation.

## Voice Direction

The product should split meaning from character sound:

- Text bubble: full helpful answer from `/api/assistant`.
- Voice: short, clean, original Pika syllables.
- State label: user-visible status such as `Listening`, `Thinking`,
  `Pika replied`, or `Tap to answer`.

This avoids the current failure mode where a small voice model mumbles long
assistant text. For the hackathon demo, a crisp `Pikaa Pikaa` with precise
timing is better than a low-quality full spoken answer.

Recommended voice-intent map:

| Intent | Spoken line | Notes |
| --- | --- | --- |
| greeting | `Pikaa Pikaa!` | bright, two clean syllable groups |
| success | `Pikaa! Pikaaa!` | second phrase elongated |
| question | `Pikaa? Pikaa.` | first phrase rising pitch |
| empathy | `Pikaa... Pikaa.` | slower, softer |
| hyper | `Pikaa pika pika!` | faster, but not clipped |
| sleep | `Pikaa... pikaa...` | low volume, long tail |

Future TTS work should tune phoneme spelling, pitch, gap length, and gain before
adding more model complexity.

## Function Tools

Use LiveKit function tools as the bridge between voice intent and native pet
behavior. Initial tools should be minimal and map directly to existing app
concepts:

- `show_bubble(text: str, mood: str)`
  - Sends frontend RPC or a data message to the native overlay.
- `set_pet_mood(mood: "happy" | "nap" | "hyper" | "listening" | "thinking")`
  - Drives visible animation state.
- `play_pet_sound(intent: str)`
  - Selects a Pika syllable line and plays it through the room.
- `award_bond_hp(reason: str, amount: int)`
  - Updates future pet progression state.
- `start_learning(language: "spanish" | "mandarin")`
  - Opens the language coach without leaving the overlay.
- `record_daily_checkin(feeling: str)`
  - Converts daily check-in speech into the existing pet-care loop.
- `next_pet_loop()`
  - Triggers the next rich loop: errand, wish, toy, trick, home room, or story
    beat.

For implementation, prefer frontend RPC or LiveKit data messages for native UI
commands. Avoid making the LiveKit worker mutate native state directly without a
visible client acknowledgement.

## Council Loop

The requested "elder council" should not be runtime clutter in the user-facing
pet. It should be an evaluation loop around the experience:

- Experience Director: checks timing, delight, confusion, and whether the pet
  feels alive.
- Voice Director: checks crispness, vowel elongation, silence gaps, gain, and
  whether Pika syllables are intelligible.
- Interaction Director: checks minimize, expand, close, Talk, mute, response,
  interruption, and daily-return flows.
- Hackathon Director: checks the demo story, open-source framing, privacy/local
  claims, and whether the build can be explained in one minute.

LiveKit recipe inspiration for this loop:

- Use `metrics_stt`, `metrics_vad`, and `metrics_tts` style examples for
  measurable latency and audio quality checks.
- Use `agent_transfer` or `warm_handoff` concepts only for internal evaluator
  roles, not as visible product characters in v1.
- Use `tool_calling` and `update_tools` patterns to let reviewers request
  experience checks without hardcoding every check into the base agent.

## Environment Variables

Existing variables to preserve:

```bash
POCKETDM_PIKA_TTS_URL=http://127.0.0.1:7861/tts
POCKETDM_PIKA_TTS_HOST=127.0.0.1
POCKETDM_PIKA_TTS_PORT=7861
POCKETDM_PIKA_TTS_BACKEND=chatterbox
POCKETDM_PIKA_TTS_REF=/absolute/path/to/consented-or-generated-reference.wav
POCKETDM_PIKA_TTS_DEVICE=auto
POCKETDM_REPO=/Users/amal/listenowl/experiments/build-small
```

Proposed LiveKit variables:

```bash
LIVEKIT_URL=wss://<project>.livekit.cloud
LIVEKIT_API_KEY=<key>
LIVEKIT_API_SECRET=<secret>
POCKETDM_LIVEKIT_AGENT_NAME=pika-agent
POCKETDM_LIVEKIT_ROOM_PREFIX=pocketdm-pika
POCKETDM_LIVEKIT_TOKEN_TTL_SECONDS=3600
POCKETDM_LIVEKIT_STT=livekit-inference
POCKETDM_LIVEKIT_LLM=assistant-api
POCKETDM_LIVEKIT_TTS=pika-sidecar
POCKETDM_ASSISTANT_BASE_URL=http://127.0.0.1:7860
POCKETDM_PIKA_VOICE_MODE=semantic-pika
```

For a fully open-source/local run, use a self-hosted LiveKit server and local
model providers where possible. The first hackathon path can still use LiveKit
Cloud for the room transport if the demo clearly states which pieces are local
and which are hosted.

## Phased Implementation Plan

### Phase 0: Documented Contract

- Keep this document as the integration contract.
- Confirm the current app launches with:
  `/Users/amal/listenowl/experiments/build-small/macos/PocketDMCompanion/scripts/launch_app.sh`.
- Confirm the Pika sidecar starts with:
  `/Users/amal/listenowl/experiments/build-small/macos/PocketDMCompanion/scripts/start_pika_tts.sh`.

### Phase 1: Token And Room Skeleton

- Add a token endpoint to
  `/Users/amal/listenowl/experiments/build-small/app/server.py`.
- Token payload should include room name, participant name, and expiry.
- Do not wire native audio yet.
- Acceptance: a local script can request a token and join a room.

### Phase 2: Agent Worker

- Add future worker:
  `/Users/amal/listenowl/experiments/build-small/app/livekit_pika_agent.py`.
- Start an `AgentServer` with `agent_name=POCKETDM_LIVEKIT_AGENT_NAME`.
- Create `AgentSession` with:
  - STT: LiveKit inference STT for first pass, local Whisper later.
  - LLM: custom assistant adapter that calls `/api/assistant`.
  - TTS: custom Pika sidecar adapter that calls `POCKETDM_PIKA_TTS_URL`.
  - VAD: Silero.
  - Turn detection: multilingual turn detector.
- Acceptance: Agent Console or a small test client can speak and hear a Pika
  reply while `/api/assistant` provides the text.

### Phase 3: Native Overlay Joins Room

- Add LiveKit Swift SDK integration to
  `/Users/amal/listenowl/experiments/build-small/macos/PocketDMCompanion/Sources/PocketDMCompanion/main.swift`.
- Keep existing buttons and pet-only mode.
- Replace the current one-shot Talk loop with room audio publishing.
- Subscribe to agent data messages for bubble text and animation cues.
- Acceptance: press Talk in the overlay, say a sentence, see transcript,
  receive text response, hear crisp Pika audio, and see the matching animation.

### Phase 4: Experience Polish

- Tune Pika syllable prompts and sidecar gain.
- Add interruption behavior: user speech should stop agent speech cleanly.
- Add startup, minimize, maximize, send, reply, mute, close, success, and error
  sound cues.
- Add latency indicators only when useful; do not expose developer metrics in
  the main pet view.
- Acceptance: the full loop feels realtime: listen, partial status, final
  transcript, answer bubble, crisp Pika sound, animation, and recovery on error.

### Phase 5: Council Evaluation Loop

- Add an offline evaluator harness that replays scripted voice/text scenarios.
- Score:
  - time to first visible feedback,
  - time to first audio,
  - interruption correctness,
  - Pika syllable clarity,
  - response helpfulness,
  - animation/state match,
  - minimize/expand/close reliability.
- Use the council roles as named rubric sections, not as extra visible UI.
- Acceptance: each demo-critical flow has a pass/fail note and a captured
  artifact or log.

## Acceptance Tests

### Backend And Sidecar

- `POST /api/assistant` returns text containing `Pika pika!` for a simple user
  message.
- `GET http://127.0.0.1:7861/health` returns `status: ok`.
- `POST http://127.0.0.1:7861/tts` with `{"text":"Pika pika!","voice":"pika-original","format":"wav"}` returns WAV bytes.
- The sidecar voice mode produces short syllable audio, not mumbled long English
  speech.

### LiveKit Room

- A client can join a room with a backend-issued token.
- The agent appears as `pika-agent`.
- User audio reaches the agent.
- VAD marks speech start and speech end.
- Turn detection finalizes a transcript without requiring manual send.
- Agent audio returns to the client.
- Data messages carry transcript, reply text, mood, and animation cue.

### Native Overlay

- Pressing Talk shows immediate listening feedback.
- Partial transcript or listening state appears before the final reply.
- Assistant text appears in the compact/expanded bubble.
- Pika voice says a crisp intent-mapped line.
- Mute suppresses audio but not text.
- Minimize, maximize, and close remain reliable.
- Network or sidecar failure leaves the pet visible and shows a recoverable
  status instead of failing silently.

### Experience Bar

- First visible feedback after Talk: under 200 ms.
- Final transcript after user stops speaking: under 1.5 s in a local demo.
- First reply audio after backend reply: under 700 ms with warmed sidecar.
- Pika syllables are manually audible as `Pikaa Pikaa`, not garbled speech.
- The demo can be explained as: "A realtime desktop pet that listens, answers,
  cheers, teaches, and grows through daily care."

## References

- LiveKit Voice AI quickstart:
  https://docs.livekit.io/agents/start/voice-ai/
- LiveKit tool definition and use:
  https://docs.livekit.io/agents/logic/tools/
- LiveKit Python agent examples:
  https://github.com/livekit-examples/python-agents-examples/tree/main/docs/examples
- LiveKit Python starter project:
  https://github.com/livekit-examples/agent-starter-python
