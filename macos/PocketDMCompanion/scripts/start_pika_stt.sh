#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
repo_root="$(cd -- "$script_dir/../../.." >/dev/null 2>&1 && pwd -P)"

host="${POCKETDM_PIKA_STT_HOST:-127.0.0.1}"
port="${POCKETDM_PIKA_STT_PORT:-7862}"
backend="${POCKETDM_PIKA_STT_BACKEND:-faster-whisper}"
stt_env="${POCKETDM_PIKA_STT_VENV:-$repo_root/.pika-stt-venv}"
stt_python="${POCKETDM_PIKA_STT_PYTHON:-}"
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
        echo "--backend requires faster-whisper or stub" >&2
        exit 64
      fi
      backend="$2"
      shift 2
      ;;
    --python)
      if [[ $# -lt 2 ]]; then
        echo "--python requires a Python executable" >&2
        exit 64
      fi
      stt_python="$2"
      shift 2
      ;;
    --warmup)
      warmup=1
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: scripts/start_pika_stt.sh [--host 127.0.0.1] [--port 7862] [--backend faster-whisper|stub] [--python PATH] [--warmup]

Starts the local Pika speech-to-text sidecar. The default backend is
faster-whisper with Systran/faster-whisper-small.en for local push-to-talk.
Use --backend stub only for tests and UI plumbing.
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
  faster-whisper|stub) ;;
  *)
    echo "--backend must be faster-whisper or stub" >&2
    exit 64
    ;;
esac

cd "$repo_root"
export POCKETDM_PIKA_STT_BACKEND="$backend"
export HF_HUB_DISABLE_XET="${HF_HUB_DISABLE_XET:-1}"

args=(--host "$host" --port "$port" --backend "$backend")
if [[ "$warmup" -eq 1 ]]; then
  args+=(--warmup)
fi

if [[ "$backend" == "faster-whisper" ]]; then
  if [[ -z "$stt_python" ]]; then
    stt_python="$stt_env/bin/python"
  fi
  if [[ ! -x "$stt_python" ]]; then
    echo "Creating isolated Pika STT environment at $stt_env" >&2
    uv venv "$stt_env"
  fi
  uv pip install --python "$stt_python" -r "$script_dir/pika_stt_requirements.txt"
  exec "$stt_python" -m app.pika_stt_server "${args[@]}"
fi

exec uv run --with python-multipart python -m app.pika_stt_server "${args[@]}"
