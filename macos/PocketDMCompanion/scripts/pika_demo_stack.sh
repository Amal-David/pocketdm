#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"

python_bin="${PYTHON:-python3}"

usage() {
  cat <<'USAGE'
Usage: macos/PocketDMCompanion/scripts/pika_demo_stack.sh start|status|stop|logs|launch

Delegates to the existing PocketDM sidecar wrappers:
  local_llm_service.py
  pika_stt_service.py
  nemotron_asr_service.py
  pika_tts_service.py

Environment overrides:
  PYTHON                         Python executable for wrapper scripts.
  POCKETDM_DEMO_SKIP_LLM_DOWNLOAD=1
  POCKETDM_LOCAL_LLM_TIMEOUT=90
  POCKETDM_PIKA_STT_BACKEND=faster-whisper
  POCKETDM_PIKA_STT_TIMEOUT=90
  POCKETDM_NEMOTRON_ASR_BACKEND=auto
  POCKETDM_NEMOTRON_ASR_FALLBACK_BACKEND=pika-stt
  POCKETDM_NEMOTRON_ASR_FALLBACK_URL=http://127.0.0.1:7862
  POCKETDM_NEMOTRON_ASR_CHUNK_MS=160
  POCKETDM_NEMOTRON_ASR_TIMEOUT=45
  POCKETDM_PIKA_TTS_BACKEND=stub
  POCKETDM_PIKA_TTS_TIMEOUT=90

The launch command starts the native companion with:
  MiniCPM5-1B brain:          http://127.0.0.1:8081
  reliable Pika STT:          http://127.0.0.1:7862
  Nemotron ASR bridge:         http://127.0.0.1:7863/ws/transcribe
  Pika TTS:                   http://127.0.0.1:7861/tts
USAGE
}

run_service() {
  local service="$1"
  shift
  "$python_bin" "$script_dir/${service}_service.py" "$@"
}

step() {
  printf '\n== %s ==\n' "$1"
}

start_stack() {
  local llm_args=(start --timeout "${POCKETDM_LOCAL_LLM_TIMEOUT:-90}")
  if [[ "${POCKETDM_DEMO_SKIP_LLM_DOWNLOAD:-0}" != "1" ]]; then
    llm_args+=(--download-minicpm5)
  fi

  step "Local LLM"
  run_service local_llm "${llm_args[@]}"

  export POCKETDM_PIKA_STT_MODEL="${POCKETDM_PIKA_STT_MODEL:-Systran/faster-whisper-small.en}"
  step "Pika STT"
  run_service pika_stt start \
    --backend "${POCKETDM_PIKA_STT_BACKEND:-faster-whisper}" \
    --timeout "${POCKETDM_PIKA_STT_TIMEOUT:-90}" \
    --warmup

  step "Nemotron streaming ASR"
  run_service nemotron_asr start \
    --backend "${POCKETDM_NEMOTRON_ASR_BACKEND:-auto}" \
    --fallback-backend "${POCKETDM_NEMOTRON_ASR_FALLBACK_BACKEND:-pika-stt}" \
    --fallback-url "${POCKETDM_NEMOTRON_ASR_FALLBACK_URL:-http://127.0.0.1:7862}" \
    --chunk-ms "${POCKETDM_NEMOTRON_ASR_CHUNK_MS:-160}" \
    --timeout "${POCKETDM_NEMOTRON_ASR_TIMEOUT:-45}"

  step "Pika TTS"
  run_service pika_tts start \
    --backend "${POCKETDM_PIKA_TTS_BACKEND:-stub}" \
    --timeout "${POCKETDM_PIKA_TTS_TIMEOUT:-90}"
}

status_stack() {
  local failed=0

  step "Local LLM"
  run_service local_llm status || failed=1

  step "Pika STT"
  run_service pika_stt status || failed=1

  step "Nemotron streaming ASR"
  run_service nemotron_asr status || failed=1

  step "Pika TTS"
  run_service pika_tts status || failed=1

  return "$failed"
}

stop_stack() {
  local failed=0

  step "Pika TTS"
  run_service pika_tts stop || failed=1

  step "Nemotron streaming ASR"
  run_service nemotron_asr stop || failed=1

  step "Pika STT"
  run_service pika_stt stop || failed=1

  step "Local LLM"
  run_service local_llm stop || failed=1

  return "$failed"
}

logs_stack() {
  local failed=0

  step "Local LLM"
  run_service local_llm log || failed=1

  step "Pika STT"
  run_service pika_stt log || failed=1

  step "Nemotron streaming ASR"
  run_service nemotron_asr log || failed=1

  step "Pika TTS"
  run_service pika_tts log || failed=1

  return "$failed"
}

launch_companion() {
  export POCKETDM_LLAMA_SERVER_URL="${POCKETDM_LLAMA_SERVER_URL:-${POCKETDM_ASSISTANT_LLAMA_URL:-http://127.0.0.1:8081}}"
  if [[ -z "${POCKETDM_LLAMA_SERVER_MODEL:-}" && -n "${POCKETDM_ASSISTANT_LLAMA_MODEL:-}" ]]; then
    export POCKETDM_LLAMA_SERVER_MODEL="$POCKETDM_ASSISTANT_LLAMA_MODEL"
  fi
  export POCKETDM_ASSISTANT_LLAMA_URL="$POCKETDM_LLAMA_SERVER_URL"
  if [[ -n "${POCKETDM_LLAMA_SERVER_MODEL:-}" ]]; then
    export POCKETDM_ASSISTANT_LLAMA_MODEL="$POCKETDM_LLAMA_SERVER_MODEL"
  fi
  local launch_args=(
    --attach "${POCKETDM_COMPANION_ATTACH_URL:-http://127.0.0.1:7860}" \
    --character pika \
    --pika-tts-url "${POCKETDM_PIKA_TTS_URL:-http://127.0.0.1:7861/tts}" \
    --pika-stt-url "${POCKETDM_PIKA_STT_URL:-http://127.0.0.1:7862}" \
    --realtime-stt-url "${POCKETDM_REALTIME_STT_URL:-http://127.0.0.1:7863/ws/transcribe}" \
    --launch-server
  )
  "$script_dir/launch_app.sh" "${launch_args[@]}" "$@"
}

command="${1:-}"
case "$command" in
  start)
    shift
    if [[ $# -ne 0 ]]; then
      usage >&2
      exit 64
    fi
    start_stack
    ;;
  status)
    shift
    if [[ $# -ne 0 ]]; then
      usage >&2
      exit 64
    fi
    status_stack
    ;;
  stop)
    shift
    if [[ $# -ne 0 ]]; then
      usage >&2
      exit 64
    fi
    stop_stack
    ;;
  logs)
    shift
    if [[ $# -ne 0 ]]; then
      usage >&2
      exit 64
    fi
    logs_stack
    ;;
  launch)
    shift
    launch_companion "$@"
    ;;
  -h|--help|help|"")
    usage
    ;;
  *)
    echo "Unknown command: $command" >&2
    usage >&2
    exit 64
    ;;
esac
