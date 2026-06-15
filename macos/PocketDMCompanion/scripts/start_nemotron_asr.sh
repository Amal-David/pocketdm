#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
repo_root="$(cd -- "$script_dir/../../.." >/dev/null 2>&1 && pwd -P)"

host="${POCKETDM_NEMOTRON_ASR_HOST:-127.0.0.1}"
port="${POCKETDM_NEMOTRON_ASR_PORT:-7863}"
backend="${POCKETDM_NEMOTRON_ASR_BACKEND:-auto}"
fallback_backend="${POCKETDM_NEMOTRON_ASR_FALLBACK_BACKEND:-pika-stt}"
fallback_url="${POCKETDM_NEMOTRON_ASR_FALLBACK_URL:-${POCKETDM_PIKA_STT_URL:-http://127.0.0.1:7862}}"
model="${POCKETDM_NEMOTRON_ASR_MODEL:-nvidia/nemotron-speech-streaming-en-0.6b}"
chunk_ms="${POCKETDM_NEMOTRON_ASR_CHUNK_MS:-560}"
asr_env="${POCKETDM_NEMOTRON_ASR_VENV:-$repo_root/.pika-nemotron-asr-venv}"
asr_python="${POCKETDM_NEMOTRON_ASR_PYTHON:-}"
warmup=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --host)
      if [[ $# -lt 2 ]]; then
        echo "--host requires a value" >&2
        exit 64
      fi
      host="$2"
      shift 2
      ;;
    --port)
      if [[ $# -lt 2 ]]; then
        echo "--port requires a value" >&2
        exit 64
      fi
      port="$2"
      shift 2
      ;;
    --backend)
      if [[ $# -lt 2 ]]; then
        echo "--backend requires auto, local-nemotron, stub, riva-nim, pika-stt, or nemo-local" >&2
        exit 64
      fi
      backend="$2"
      shift 2
      ;;
    --fallback-backend)
      if [[ $# -lt 2 ]]; then
        echo "--fallback-backend requires pika-stt, stub, or none" >&2
        exit 64
      fi
      fallback_backend="$2"
      shift 2
      ;;
    --fallback-url)
      if [[ $# -lt 2 ]]; then
        echo "--fallback-url requires a URL" >&2
        exit 64
      fi
      fallback_url="$2"
      shift 2
      ;;
    --model)
      if [[ $# -lt 2 ]]; then
        echo "--model requires a model id" >&2
        exit 64
      fi
      model="$2"
      shift 2
      ;;
    --chunk-ms)
      if [[ $# -lt 2 ]]; then
        echo "--chunk-ms requires an integer millisecond value" >&2
        exit 64
      fi
      chunk_ms="$2"
      shift 2
      ;;
    --python)
      if [[ $# -lt 2 ]]; then
        echo "--python requires a Python executable" >&2
        exit 64
      fi
      asr_python="$2"
      shift 2
      ;;
    --warmup)
      warmup=1
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: scripts/start_nemotron_asr.sh [--host 127.0.0.1] [--port 7863] [--backend auto|local-nemotron|stub|riva-nim|pika-stt|nemo-local] [--fallback-backend pika-stt|stub|none] [--fallback-url URL] [--model MODEL_ID] [--chunk-ms 560] [--python PATH] [--warmup]

Starts the Nemotron ASR bridge. The default backend is auto: local NeMo
Nemotron first, optional hosted NVIDIA/Riva NIM only when configured, with the
local faster-whisper Pika STT sidecar on 7862 as the fallback.
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 64
      ;;
  esac
done

case "$backend" in
  auto|local-nemotron|stub|riva-nim|pika-stt|nemo-local) ;;
  *)
    echo "--backend must be auto, local-nemotron, stub, riva-nim, pika-stt, or nemo-local" >&2
    exit 64
    ;;
esac
case "$fallback_backend" in
  pika-stt|stub|none) ;;
  *)
    echo "--fallback-backend must be pika-stt, stub, or none" >&2
    exit 64
    ;;
esac
if ! [[ "$chunk_ms" =~ ^[0-9]+$ ]]; then
  echo "--chunk-ms must be an integer millisecond value" >&2
  exit 64
fi

cd "$repo_root"
export POCKETDM_NEMOTRON_ASR_BACKEND="$backend"
export POCKETDM_NEMOTRON_ASR_FALLBACK_BACKEND="$fallback_backend"
export POCKETDM_NEMOTRON_ASR_FALLBACK_URL="$fallback_url"
export POCKETDM_NEMOTRON_ASR_MODEL="$model"
export POCKETDM_NEMOTRON_ASR_CHUNK_MS="$chunk_ms"
export HF_HUB_DISABLE_XET="${HF_HUB_DISABLE_XET:-1}"

args=(--host "$host" --port "$port" --backend "$backend" --fallback-backend "$fallback_backend" --fallback-url "$fallback_url")
if [[ "$warmup" -eq 1 ]]; then
  args+=(--warmup)
fi

if [[ "$backend" == "auto" || "$backend" == "local-nemotron" || "$backend" == "riva-nim" || "$backend" == "nemo-local" || "$backend" == "pika-stt" ]]; then
  if [[ -z "$asr_python" ]]; then
    asr_python="$asr_env/bin/python"
  fi
  if [[ ! -x "$asr_python" ]]; then
    echo "Creating isolated Nemotron ASR environment at $asr_env" >&2
    uv venv "$asr_env"
    uv pip install --python "$asr_python" -r "$script_dir/nemotron_asr_requirements.txt"
  fi
  exec "$asr_python" -m app.nemotron_streaming_asr_server "${args[@]}"
fi

exec uv run --with python-multipart --with websockets python -m app.nemotron_streaming_asr_server "${args[@]}"
