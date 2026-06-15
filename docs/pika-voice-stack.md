# Pikachu Voice Stack

## Hackathon Demo Quickstart

Use this path when the demo needs to clearly show the three-model voice stack
without making the stable native pet depend on every experimental backend:

1. MiniCPM5-1B is the local companion brain on `127.0.0.1:8081`.
2. Nemotron ASR is the native realtime voice path on `127.0.0.1:7863`, with
   local NeMo/Nemotron as the intended primary backend.
3. faster-whisper remains the backup STT path on `127.0.0.1:7862` and is used
   automatically when local Nemotron startup is unavailable.
4. Pika TTS starts in stub mode by default; opt into VoxCPM or VoxCPM2 with
   explicit flags when model latency is acceptable.

Run the whole smoke-safe hackathon stack:

```bash
macos/PocketDMCompanion/scripts/pika_demo_stack.sh start
```

Check every sidecar:

```bash
macos/PocketDMCompanion/scripts/pika_demo_stack.sh status
```

Stop every sidecar in reverse dependency order:

```bash
macos/PocketDMCompanion/scripts/pika_demo_stack.sh stop
```

The stack script only delegates to the existing service wrappers, so their PID
files, health checks, and logs remain the source of truth. For the fastest local
plumbing check, set `POCKETDM_DEMO_SKIP_LLM_DOWNLOAD=1` when a GGUF already
exists or `POCKETDM_PIKA_STT_BACKEND=stub` when speech model startup is not the
thing under test.

Manual equivalent: start the brain:

```bash
python3 macos/PocketDMCompanion/scripts/local_llm_service.py start \
  --download-minicpm5
```

Start reliable app STT:

```bash
POCKETDM_PIKA_STT_MODEL=Systran/faster-whisper-small.en \
python3 macos/PocketDMCompanion/scripts/pika_stt_service.py start \
  --backend faster-whisper \
  --warmup
```

Start the Nemotron ASR bridge. In `auto` mode this tries local NeMo/Nemotron
first. If local model startup is unavailable, the bridge falls back to the local
faster-whisper sidecar and reports `fallback_used`. Hosted NIM is optional and
only uses `NVIDIA_API_KEY` when that route is explicitly configured:

```bash
python3 macos/PocketDMCompanion/scripts/nemotron_asr_service.py start \
  --backend auto \
  --fallback-backend pika-stt \
  --fallback-url http://127.0.0.1:7862 \
  --chunk-ms 160
```

Start TTS in safe smoke mode:

```bash
python3 macos/PocketDMCompanion/scripts/pika_tts_service.py start --backend stub
```

Opt into VoxCPM-0.5B TTS:

```bash
python3 macos/PocketDMCompanion/scripts/pika_tts_service.py start \
  --backend voxcpm \
  --model openbmb/VoxCPM-0.5B \
  --warmup \
  --timeout 180
```

Opt into VoxCPM2 TTS:

```bash
python3 macos/PocketDMCompanion/scripts/pika_tts_service.py start \
  --backend voxcpm \
  --model openbmb/VoxCPM2 \
  --warmup \
  --timeout 240
```

Status:

```bash
python3 macos/PocketDMCompanion/scripts/local_llm_service.py status
python3 macos/PocketDMCompanion/scripts/pika_stt_service.py status
python3 macos/PocketDMCompanion/scripts/nemotron_asr_service.py status
python3 macos/PocketDMCompanion/scripts/pika_tts_service.py status
```

Stop:

```bash
python3 macos/PocketDMCompanion/scripts/pika_tts_service.py stop
python3 macos/PocketDMCompanion/scripts/nemotron_asr_service.py stop
python3 macos/PocketDMCompanion/scripts/pika_stt_service.py stop
python3 macos/PocketDMCompanion/scripts/local_llm_service.py stop
```

Launch the native companion against the running stack:

```bash
POCKETDM_ASSISTANT_LLAMA_URL=http://127.0.0.1:8081 \
POCKETDM_ASSISTANT_LLAMA_MODEL=minicpm5-1b-q4 \
macos/PocketDMCompanion/scripts/launch_app.sh \
  --attach http://127.0.0.1:7860 \
  --character pika \
  --pika-tts-url http://127.0.0.1:7861/tts \
  --pika-stt-url http://127.0.0.1:7862 \
  --realtime-stt-url http://127.0.0.1:7863/ws/transcribe \
  --launch-server
```

Codex-authored commits from this checkout should use the Codex identity before
committing; human-authored commits should keep the human's identity:

```bash
git config user.name Codex
git config user.email codex@local
git config --get user.name
git config --get user.email
```

## Direction

The native companion should be voice-first for chat:

1. User presses `Talk`.
2. The native app records the utterance and sends it to the local Pika STT
   sidecar when `POCKETDM_PIKA_STT_URL` is set, falling back to macOS Speech
   only when no sidecar is configured.
3. The transcript is sent to the existing `/api/assistant` flow.
4. Pikachu replies in text and voice.

The same route must handle typed input and speech input. Desktop questions such
as current time/date, runtime status, weather check-ins, mute, and focus help
should be resolved before adventure-hint logic. Adventure hints should only fire
when the user explicitly asks for a hint, clue, choice, or quest help.

## Local Orchestration Contract

The product path is:

1. STT captures the user utterance through the local Nemotron ASR bridge today.
   The bridge loads local NeMo/Nemotron first and falls back to the
   faster-whisper sidecar when the local runtime or model cache is unavailable.
2. The native overlay sends the transcript or typed text to `/api/assistant`.
3. `/api/assistant` attaches deterministic local facts: time/date, weather
   summary, pet state, app/service health, and allowed native actions.
4. The assistant response is generated by the local llama.cpp backend when
   configured; otherwise the UI and docs must label the scripted fallback.
5. Native playback sends a short Pika line to `POCKETDM_PIKA_TTS_URL` when set,
   or falls back to bundled original chirps if the sidecar is unavailable.

Morning weather check-ins follow the same contract. Native code fetches weather
facts, then asks `/api/assistant` to compose the final short Pika line instead
of showing a hardcoded affirmation as the product response.

## Voice Safety

Do not download or clone official Pikachu audio from YouTube or other media.
Use an original, cute, high-energy voice profile that suggests the character
without copying a copyrighted performance.

## TTS Runtime

Kokoro remains a fallback for the web story voice, but the native pet can now
use an external local Pika voice endpoint by setting:

```bash
export POCKETDM_PIKA_TTS_URL=http://127.0.0.1:7861/tts
```

Expected request for the demo-safe mascot sound:

```json
{"text":"Pikaa Pikaa!","voice":"pika-signature","format":"wav"}
```

Expected response: HTTP 200 with WAV bytes.

## STT Runtime

The native companion can use local faster-whisper speech recognition by setting:

```bash
export POCKETDM_PIKA_STT_URL=http://127.0.0.1:7862
```

Start the real local STT sidecar:

```bash
POCKETDM_PIKA_STT_MODEL=Systran/faster-whisper-small.en \
  python3 macos/PocketDMCompanion/scripts/pika_stt_service.py start \
  --backend faster-whisper \
  --warmup
```

Smoke-test mode, no model load:

```bash
python3 macos/PocketDMCompanion/scripts/pika_stt_service.py start --backend stub
```

Manage the sidecar:

```bash
python3 macos/PocketDMCompanion/scripts/pika_stt_service.py status
python3 macos/PocketDMCompanion/scripts/pika_stt_service.py log
python3 macos/PocketDMCompanion/scripts/pika_stt_service.py stop
```

Useful checks:

```bash
curl -s http://127.0.0.1:7862/health
```

When the sidecar is configured, `Talk now` records a temporary WAV locally,
uploads it to `/transcribe`, sends the returned transcript to `/api/assistant`,
then plays the short original Pika voice through the TTS sidecar.

### Local Sidecar

Smoke-test mode, no model download:

```bash
python3 macos/PocketDMCompanion/scripts/pika_tts_service.py start --backend stub
```

For smoke tests, the native app sends `voice: "pika-signature"`, which renders
short original generated syllable clips such as `Pikaa Pikaa`, `Pikaa?`, and
`Pikaa! Pikaaa!`. The full assistant reply stays in the text bubble.

VoxCPM is the preferred local model voice path for the hackathon build because
`openbmb/VoxCPM-0.5B` is Apache-2.0, English/Chinese, and small enough to try
locally before graduating to VoxCPM2:

```bash
python3 macos/PocketDMCompanion/scripts/pika_tts_service.py start \
  --backend voxcpm \
  --model openbmb/VoxCPM-0.5B \
  --timeout 180
```

The first run creates `.pika-voxcpm-venv`, installs `voxcpm`, and downloads the
model through Hugging Face. With `--backend voxcpm`, the sidecar synthesizes the
exact `text` it receives — it no longer rewrites `pika-signature`/`pika-original`
requests into a canned `Pikaa! Pikaaa!` line. Deciding *what* the mascot says
(short signature chirp vs. a fuller line) is the caller's job: the native app
already shortens replies to a mascot line in `pikaVoiceLine(...)` before posting.
Only the `stub` backend stays a non-speech chirp generator for smoke tests.

VoxCPM2 is the quality showcase target. It is Apache-2.0, multilingual, and
voice-cloning/design capable, but it is heavier than the 0.5B path. Treat it as
an opt-in sidecar model until latency is consistently under the native timeout:

```bash
python3 macos/PocketDMCompanion/scripts/pika_tts_service.py start \
  --backend voxcpm \
  --model openbmb/VoxCPM2 \
  --timeout 240
```

Chatterbox remains available for optional voice experiments with generated or
consented reference audio:

```bash
POCKETDM_PIKA_TTS_REF=/path/to/consented-or-generated-reference.wav \
  macos/PocketDMCompanion/scripts/start_pika_tts.sh --backend chatterbox --warmup
```

The Chatterbox backend uses an isolated `.pika-voice-venv` on first launch
because `chatterbox-tts==0.1.7` pins `gradio==6.8.0`, while the PocketDM app
pins `gradio==6.17.3`. Keeping the voice model in a separate environment avoids
breaking the web adventure server.

For a background service that survives the shell session, use explicit backend
selection. The default is `stub` so a smoke run never downloads a model by
surprise:

```bash
python3 macos/PocketDMCompanion/scripts/pika_tts_service.py start --backend stub
python3 macos/PocketDMCompanion/scripts/pika_tts_service.py status
python3 macos/PocketDMCompanion/scripts/pika_tts_service.py stop
```

The first Chatterbox run downloads and caches these Hugging Face files from
`ResembleAI/chatterbox`: `ve.safetensors`, `t3_cfg.safetensors`,
`s3gen.safetensors`, `tokenizer.json`, and `conds.pt`. The start script sets
`HF_HUB_DISABLE_XET=1` by default because that path gave clearer progress on
this machine than the silent Xet download path.

Useful checks:

```bash
curl -s http://127.0.0.1:7861/health
curl -s -X POST http://127.0.0.1:7861/warmup
```

Then launch the native pet with the sidecar URL:

```bash
macos/PocketDMCompanion/scripts/launch_app.sh \
  --attach http://127.0.0.1:7860 \
  --character pika \
  --pika-tts-url http://127.0.0.1:7861/tts \
  --pika-stt-url http://127.0.0.1:7862 \
  --launch-server
```

If Chatterbox is not installed or cannot load, the sidecar returns HTTP 503 and
the native app falls back to bundled original Pika chirps instead of generic
macOS speech.

### Local Companion LLM

The preferred Tiny Titan conversational ladder is:

1. `openbmb/MiniCPM5-1B-GGUF` Q4_K_M for the fastest current open-source tiny
   chat baseline.
2. `unsloth/Qwen3.5-2B-GGUF` Q4_K_M when the roleplay/adventure quality needs
   a stronger 2B-class model and still stays unambiguously under 4B.
3. `unsloth/Phi-4-mini-instruct-GGUF` Q4_K_M only when the demo can afford the
   larger near-4B runtime.
4. The existing PocketDM fine-tuned 2B Q4_K_M model in `models/` as the
   no-download fallback.

Download and run MiniCPM5-1B:

```bash
python3 macos/PocketDMCompanion/scripts/local_llm_service.py start --download-minicpm5
python3 macos/PocketDMCompanion/scripts/local_llm_service.py status
```

Download and run Qwen3.5-2B:

```bash
python3 macos/PocketDMCompanion/scripts/local_llm_service.py start --download-qwen35-2b
python3 macos/PocketDMCompanion/scripts/local_llm_service.py status
```

Download and run Phi-4-mini:

```bash
python3 macos/PocketDMCompanion/scripts/local_llm_service.py start --download-phi4-mini
python3 macos/PocketDMCompanion/scripts/local_llm_service.py status
```

Run the local default immediately. On this machine, the no-arg launcher resolves
to the downloaded MiniCPM5-1B Q4 file first, then Qwen3.5-2B, Phi-4-mini, and
finally the existing PocketDM 2B fallback:

```bash
python3 macos/PocketDMCompanion/scripts/local_llm_service.py start
python3 macos/PocketDMCompanion/scripts/local_llm_service.py status
```

Then point the assistant composition path at the local server before launching
the app/server:

```bash
export POCKETDM_ASSISTANT_LLAMA_URL=http://127.0.0.1:8081
export POCKETDM_ASSISTANT_LLAMA_MODEL=minicpm5-1b-q4
macos/PocketDMCompanion/scripts/launch_app.sh \
  --attach http://127.0.0.1:7860 \
  --character pika \
  --pika-tts-url http://127.0.0.1:7861/tts \
  --pika-stt-url http://127.0.0.1:7862 \
  --realtime-stt-url http://127.0.0.1:7863/ws/transcribe \
  --launch-server
```

This keeps typed chat, speech transcripts, weather check-ins, and morning
affirmations on the same `/api/assistant` route. The deterministic routes still
own facts such as time, date, weather, and app status before the LLM composes
freeform phrasing.

### Nemotron Streaming ASR

`nvidia/nemotron-speech-streaming-en-0.6b` is a 600M streaming ASR model with a
NeMo/FastConformer RNNT stack. It supports 80ms, 160ms, 560ms, and 1120ms chunk
settings; use 160ms for the demo latency target before dropping to the 80ms
extreme.

Demo path:

- keep faster-whisper on `127.0.0.1:7862` as the reliable backup STT sidecar;
- run the Nemotron ASR bridge on a separate `127.0.0.1:7863` sidecar;
- expose websocket `start` / binary chunk / `end` frames plus partial/final text
  frames for the model path;
- launch native with both `--realtime-stt-url http://127.0.0.1:7863/ws/transcribe`
  and `--pika-stt-url http://127.0.0.1:7862`; the websocket path is attempted
  first and the batch STT path remains the fallback when both are configured.

One-command local demo launch after the stack is running:

```bash
macos/PocketDMCompanion/scripts/pika_demo_stack.sh launch
```

The native UI has two voice modes:

- `Talk now`: one push-to-talk turn.
- `Hands-free`: opt-in short-turn looping. The app listens for speech, sends after
  a short pause using recorder metering, falls back to a max turn timeout, routes
  the final transcript through `/api/assistant`, plays Pika TTS, then opens the
  mic for the next short turn.

This is not yet barge-in or always-listening interruption. The current loop is a
safe hands-free turn cycle over the same local STT -> local LLM -> local TTS
pipeline. The Nemotron sidecar now speaks a chunked websocket contract, while the
native app still chunks a completed short turn rather than streaming live mic
buffers during capture.

Before claiming realtime, run:

```bash
python3 macos/PocketDMCompanion/scripts/benchmark_nemotron_asr.py \
  --url http://127.0.0.1:7863/transcribe-file \
  --repeat 5 \
  --audio /path/to/short-speech.wav
```

Use `audio_ms`, `server_asr_ms`, `wall_ms`, `rtfx`, `backend`, and
`fallback_used` from the output as the speed receipt.

The expanded native settings include a `Stack details` toggle with a compact
`Live local stack` chip row so the demo can show the runtime truth without
another paragraph:

- Brain: `MiniCPM5` when the configured llama.cpp server advertises
  `minicpm5-1b-q4` from `/v1/models`.
- STT: `Whisper` when the faster-whisper sidecar health endpoint is reachable.
- Frames: `Nemotron` when the bridge is running, with fallback status visible in
  response metadata and benchmark output.
- Voice: `VoxCPM` when the Pika TTS sidecar is running with `--backend voxcpm`.

This lets the demo honestly show three models without risking the core pet:

1. Nemotron streaming ASR for speech-to-text.
2. MiniCPM5-1B GGUF for the local companion brain.
3. VoxCPM2 or VoxCPM for Pika-like local text-to-speech.

## Candidate Models

- VoxCPM-0.5B: preferred current Pika voice runtime because it is Apache-2.0,
  English/Chinese, and much lighter than VoxCPM2.
- VoxCPM2: best next quality target, but heavier at 2B and not necessary for
  the first local voice milestone.
- Chatterbox: preferred next runtime because it has an MIT license, multilingual
  tags, voice-cloning support, and current Hugging Face activity. Its Python
  API is `ChatterboxTTS.from_pretrained(...)` followed by `model.generate(...)`.
- F5-TTS: strong quality and very popular, but the main model is
  `cc-by-nc-4.0`, so keep it for non-commercial demos unless licensing changes.

Use only consented or generated reference audio for any voice conditioning.
