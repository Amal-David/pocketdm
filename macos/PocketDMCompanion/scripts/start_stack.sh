#!/usr/bin/env bash
# Start the torch-free local Pocket Pikachu stack from a working dir.
#
# Used by the distributed macOS app right after first_run_bootstrap.sh AND on every
# subsequent launch. Starts ONLY the four services the distributable ships:
#   * Brain : MiniCPM5-1B  (llama.cpp OpenAI server)  -> http://127.0.0.1:8081
#   * Voice : Kokoro       (kokoro-onnx, torch-free)  -> http://127.0.0.1:7861/tts
#   * Ears  : faster-whisper (batch STT, torch-free)  -> http://127.0.0.1:7862
#   * Web   : companion FastAPI/Gradio server         -> http://127.0.0.1:7860
#
# It DELIBERATELY does NOT start the Nemotron streaming-ASR sidecar (port 7863).
# Nemotron's `auto` backend pulls NeMo + torch (multi-GB, OOM-prone) the first time
# it runs, which the distributable cannot afford on a clean Mac. The native app's
# realtime path already falls back to the batch faster-whisper STT on 7862, so the
# pet still hears the user without the heavyweight streaming sidecar.
#
# Idempotent: a service whose health endpoint is already live is left untouched, so
# a second launch (or a dev stack already running on these ports) is a no-op.
#
# Emits a final "STACK_STARTED" line on success.
#
# Env:
#   POCKETDM_WORKDIR  override the working dir (default: this script's repo_root,
#                     i.e. the WORK copy under Application Support when the app runs it)
set -uo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
repo_root="$(cd -- "$script_dir/../../.." >/dev/null 2>&1 && pwd -P)"
WORK="${POCKETDM_WORKDIR:-$repo_root}"

cd "$WORK" || { echo "ERROR: working dir not found: $WORK" >&2; exit 1; }

# uv (and the prebuilt venvs' tools) live under ~/.local/bin on a fresh Mac.
export PATH="$HOME/.local/bin:$PATH"
# Every wrapper resolves repo_root from its own location, but be explicit so the
# native app and /api/assistant point at the writable working dir.
export POCKETDM_REPO="$WORK"
export HF_HUB_DISABLE_XET="${HF_HUB_DISABLE_XET:-1}"

python_bin="${PYTHON:-python3}"
svc() { "$python_bin" "$script_dir/$1_service.py" "${@:2}"; }

# Is a local TCP port already accepting connections? (idempotency guard)
port_live() {
  "$python_bin" - "$1" <<'PY'
import socket, sys
port = int(sys.argv[1])
s = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
s.settimeout(0.4)
try:
    s.connect(("127.0.0.1", port))
    sys.exit(0)
except OSError:
    sys.exit(1)
finally:
    s.close()
PY
}

# ---- Brain: MiniCPM5-1B via the prebuilt llama.cpp Metal venv (no compiler) ----
if port_live 8081; then
  echo "Brain already live on 8081; skipping" >&2
else
  echo "== Local LLM (MiniCPM5-1B) ==" >&2
  brain_gguf="$WORK/models/minicpm5-1b/MiniCPM5-1B-Q4_K_M.gguf"
  llama_env_overrides=(
    "POCKETDM_LLAMA_VENV=$WORK/.pika-llama-venv"
    "POCKETDM_LLAMA_SERVER_MODEL=minicpm5-1b-q4"
  )
  [[ -f "$brain_gguf" ]] && llama_env_overrides+=("POCKETDM_GGUF=$brain_gguf")
  # No --download-minicpm5: weights are already present (bootstrap fetched them);
  # this mirrors POCKETDM_DEMO_SKIP_LLM_DOWNLOAD=1 in pika_demo_stack.sh.
  env "${llama_env_overrides[@]}" \
    "$python_bin" "$script_dir/local_llm_service.py" start \
      --timeout "${POCKETDM_LOCAL_LLM_TIMEOUT:-120}" \
    || echo "WARN: brain did not report healthy" >&2
fi

# ---- Voice: Kokoro (torch-free) from the bundled onnx weights ----
if port_live 7861; then
  echo "Voice already live on 7861; skipping" >&2
else
  echo "== Pika TTS (Kokoro) ==" >&2
  # pika_tts_service.py restricts --backend to chatterbox/voxcpm/stub, but its
  # default is read from POCKETDM_PIKA_TTS_BACKEND and argparse does NOT validate
  # defaults against choices. So set the env var and DON'T pass --backend: the
  # wrapper forwards "kokoro" to start_pika_tts.sh, which knows the kokoro path.
  env \
    "POCKETDM_PIKA_TTS_BACKEND=kokoro" \
    "POCKETDM_KOKORO_ONNX=${POCKETDM_KOKORO_ONNX:-$WORK/space/kokoro-v1.0.onnx}" \
    "POCKETDM_KOKORO_VOICES=${POCKETDM_KOKORO_VOICES:-$WORK/space/voices-v1.0.bin}" \
    "POCKETDM_PIKA_TTS_VENV=${POCKETDM_PIKA_TTS_VENV:-$WORK/.pika-kokoro-venv}" \
    "$python_bin" "$script_dir/pika_tts_service.py" start \
      --timeout "${POCKETDM_PIKA_TTS_TIMEOUT:-120}" \
    || echo "WARN: voice did not report healthy" >&2
fi

# ---- Ears: faster-whisper batch STT (lazy ~140 MB model on first transcribe) ----
if port_live 7862; then
  echo "Ears already live on 7862; skipping" >&2
else
  echo "== Pika STT (faster-whisper) ==" >&2
  export POCKETDM_PIKA_STT_MODEL="${POCKETDM_PIKA_STT_MODEL:-Systran/faster-whisper-small.en}"
  env \
    "POCKETDM_PIKA_STT_VENV=${POCKETDM_PIKA_STT_VENV:-$WORK/.pika-stt-venv}" \
    "$python_bin" "$script_dir/pika_stt_service.py" start \
      --backend faster-whisper \
      --timeout "${POCKETDM_PIKA_STT_TIMEOUT:-120}" \
      --warmup \
    || echo "WARN: ears did not report healthy" >&2
fi

# ---- Web: the companion FastAPI/Gradio server, from the torch-free web venv ----
if port_live 7860; then
  echo "Web already live on 7860; skipping" >&2
else
  echo "== Companion web server ==" >&2
  web_python="${POCKETDM_WEB_VENV:-$WORK/.pika-web-venv}/bin/python"
  web_log="${POCKETDM_WEB_LOG:-/tmp/pocketdm-web.log}"
  if [[ ! -x "$web_python" ]]; then
    echo "ERROR: companion web venv python missing: $web_python" >&2
    exit 1
  fi
  # app.py binds 0.0.0.0:7860 and blocks, so background it and detach.
  (
    cd "$WORK" || exit 1
    exec "$web_python" app.py
  ) >>"$web_log" 2>&1 &
  web_pid=$!
  echo "$web_pid" > "${POCKETDM_WEB_PID:-/tmp/pocketdm-web.pid}"
  echo "Started companion web server pid $web_pid; log $web_log" >&2
  # Best-effort readiness wait so STACK_STARTED means the pet can attach.
  for _ in $(seq 1 "${POCKETDM_WEB_WAIT_TRIES:-60}"); do
    port_live 7860 && break
    if ! kill -0 "$web_pid" 2>/dev/null; then
      echo "ERROR: companion web server exited early; see $web_log" >&2
      exit 1
    fi
    sleep 1
  done
fi

echo "STACK_STARTED"
