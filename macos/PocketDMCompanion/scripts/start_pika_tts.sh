#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
repo_root="$(cd -- "$script_dir/../../.." >/dev/null 2>&1 && pwd -P)"

host="${POCKETDM_PIKA_TTS_HOST:-127.0.0.1}"
port="${POCKETDM_PIKA_TTS_PORT:-7861}"
backend="${POCKETDM_PIKA_TTS_BACKEND:-stub}"
model="${POCKETDM_PIKA_TTS_MODEL:-}"
voice_env="${POCKETDM_PIKA_TTS_VENV:-}"
voice_python="${POCKETDM_PIKA_TTS_PYTHON:-}"
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
        echo "--backend requires chatterbox, voxcpm, or stub" >&2
        exit 64
      fi
      backend="$2"
      shift 2
      ;;
    --model)
      if [[ $# -lt 2 ]]; then
        echo "--model requires a Hugging Face model id" >&2
        exit 64
      fi
      model="$2"
      shift 2
      ;;
    --python)
      if [[ $# -lt 2 ]]; then
        echo "--python requires a Python executable" >&2
        exit 64
      fi
      voice_python="$2"
      shift 2
      ;;
    --warmup)
      warmup=1
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: scripts/start_pika_tts.sh [--host 127.0.0.1] [--port 7861] [--backend stub|voxcpm|chatterbox] [--model MODEL_ID] [--python PATH] [--warmup]

Starts the local Pika voice sidecar. The default backend is stub, which plays
original chirps and is safe for smoke tests. Use --backend voxcpm to opt into
model TTS. VoxCPM-0.5B is the default model; pass --model openbmb/VoxCPM2 for
the heavier quality showcase. Model backends run from isolated environments so
voice dependencies do not disturb the PocketDM web server. Use --warmup to load
the model before the endpoint starts accepting requests.
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
  chatterbox|voxcpm|stub) ;;
  *)
    echo "--backend must be chatterbox, voxcpm, or stub" >&2
    exit 64
    ;;
esac

cd "$repo_root"
export POCKETDM_PIKA_TTS_BACKEND="$backend"
export HF_HUB_DISABLE_XET="${HF_HUB_DISABLE_XET:-1}"
if [[ "$backend" == "voxcpm" && -z "$model" ]]; then
  model="openbmb/VoxCPM-0.5B"
fi
if [[ -n "$model" ]]; then
  export POCKETDM_PIKA_TTS_MODEL="$model"
fi

args=(--host "$host" --port "$port" --backend "$backend")
if [[ "$warmup" -eq 1 ]]; then
  args+=(--warmup)
fi

if [[ "$backend" == "chatterbox" || "$backend" == "voxcpm" ]]; then
  if [[ -z "$voice_env" ]]; then
    if [[ "$backend" == "voxcpm" ]]; then
      voice_env="$repo_root/.pika-voxcpm-venv"
    else
      voice_env="$repo_root/.pika-voice-venv"
    fi
  fi
  if [[ -z "$voice_python" ]]; then
    voice_python="$voice_env/bin/python"
  fi
  if [[ ! -x "$voice_python" ]]; then
    echo "Creating isolated Pika voice environment at $voice_env" >&2
    uv venv "$voice_env"
    if [[ "$backend" == "voxcpm" ]]; then
      uv pip install --python "$voice_python" -r "$script_dir/pika_voxcpm_requirements.txt"
    else
      uv pip install --python "$voice_python" -r "$script_dir/pika_voice_requirements.txt"
    fi
  fi
  exec "$voice_python" -m app.pika_tts_server "${args[@]}"
fi

exec uv run python -m app.pika_tts_server "${args[@]}"
