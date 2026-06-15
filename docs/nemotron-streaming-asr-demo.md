# Nemotron Streaming ASR Demo

## Positioning

Use `nvidia/nemotron-speech-streaming-en-0.6b` as the native realtime ASR
bridge for the hackathon demo. The intended path is local NeMo/Nemotron first,
with faster-whisper kept as the fail-safe backup. Hosted NVIDIA NIM is optional
and only needs `NVIDIA_API_KEY` when we deliberately choose the hosted route.

The stable app path remains:

- app server: `127.0.0.1:7860`
- Pika TTS: `127.0.0.1:7861`
- faster-whisper backup STT: `127.0.0.1:7862`
- Nemotron ASR bridge: `127.0.0.1:7863`
- local MiniCPM/Qwen llama.cpp chat server: `127.0.0.1:8081`

The bridge loads a local `.nemo` checkpoint when `POCKETDM_NEMOTRON_ASR_MODEL_PATH`
is set, or loads `nvidia/nemotron-speech-streaming-en-0.6b` through NeMo when it
is already cached. If local NeMo/model startup is unavailable, the bridge
returns explicit `fallback_used` metadata and sends the same audio to the local
faster-whisper Pika STT sidecar.

## Proposed Contract

Expose:

- `GET /health`
- `POST /warmup`
- `WS /ws/transcribe`
- optional `POST /transcribe-file` for smoke tests

Websocket messages should be explicit:

```json
{"type":"partial","text":"Nemotron ASR listening...","chunk_ms":160,"backend":"local-nemotron"}
{"type":"final","text":"hello pika","chunk_ms":160,"backend":"local-nemotron","fallback_used":false,"rtfx":3.42}
{"type":"error","message":"NeMo ASR is not installed"}
```

## Demo Commands

Stable STT:

```bash
POCKETDM_PIKA_STT_MODEL=Systran/faster-whisper-small.en \
python3 macos/PocketDMCompanion/scripts/pika_stt_service.py start \
  --backend faster-whisper \
  --warmup
```

Nemotron bridge, local model first, faster-whisper fallback otherwise:

```bash
python3 macos/PocketDMCompanion/scripts/nemotron_asr_service.py start \
  --backend auto \
  --fallback-backend pika-stt \
  --fallback-url http://127.0.0.1:7862 \
  --chunk-ms 160
python3 macos/PocketDMCompanion/scripts/nemotron_asr_service.py status
```

Local Nemotron only, with fallback disabled for debugging:

```bash
uv pip install -r macos/PocketDMCompanion/scripts/nemotron_asr_requirements.txt
huggingface-cli download nvidia/nemotron-speech-streaming-en-0.6b \
  nemotron-speech-streaming-en-0.6b.nemo \
  --local-dir models/nemotron-speech-streaming-en-0.6b
export POCKETDM_NEMOTRON_ASR_MODEL_PATH=/path/to/nemotron-speech-streaming-en-0.6b.nemo
python3 macos/PocketDMCompanion/scripts/nemotron_asr_service.py start \
  --backend local-nemotron \
  --fallback-backend none \
  --chunk-ms 160 \
  --warmup
```

Hosted Nemotron/Riva/NIM only, with fallback disabled for debugging:

```bash
export NVIDIA_API_KEY=nvapi-...
python3 macos/PocketDMCompanion/scripts/nemotron_asr_service.py start \
  --backend riva-nim \
  --fallback-backend none \
  --port 7863 \
  --chunk-ms 560 \
  --warmup
```

The hosted path uses:

- server: `grpc.nvcf.nvidia.com:443`
- function id: `bb0837de-8c7b-481f-9ec8-ef5663e9c1fa`
- client package: `nvidia-riva-client`

## Latency Check

Measure the actual bridge speed before claiming realtime:

```bash
python3 macos/PocketDMCompanion/scripts/benchmark_nemotron_asr.py \
  --url http://127.0.0.1:7863/transcribe-file \
  --repeat 5 \
  --audio /path/to/short-speech.wav
```

The output includes `audio_ms`, `server_asr_ms`, `wall_ms`, `rtfx`, `backend`,
`fallback_used`, and `streaming_mode`. For an interactive pet, we want
`server_asr_ms` below the spoken audio duration (`rtfx > 1`) and low enough wall
time that the STT -> LLM -> TTS turn still feels conversational. The current
local websocket facade is still `buffered-offline` at the end of a short turn;
true sub-turn streaming should use NeMo cache-aware streaming or NVIDIA
Realtime ASR directly.

Current local Mac receipt from June 15, 2026:

- audio fixture: 2.423s, generated with macOS `say`
- backend: `local-nemotron`
- fallback: `false`
- chunk config: `160ms`
- first cold local call: 10.5s including model load
- warm calls: 0.93-0.97s wall time, `rtfx` 2.52-2.62

That is fast enough for short push-to-talk turns after warmup. It is not yet
barge-in streaming because the native app records a short turn, then sends the
WAV chunks to the bridge.

Stop the showcase sidecar:

```bash
python3 macos/PocketDMCompanion/scripts/nemotron_asr_service.py stop
```

## Guardrails

- Do not call the fallback a Nemotron success; show `backend` and
  `fallback_used` in debug output.
- Keep faster-whisper available so the pet demo still works when NVIDIA
  credentials or hosted latency are the thing under test.
- Start with `560ms` chunks; lower chunk sizes can feel faster but may reduce
  accuracy.
- Keep license notes visible because the Hugging Face model is `license:other`.
