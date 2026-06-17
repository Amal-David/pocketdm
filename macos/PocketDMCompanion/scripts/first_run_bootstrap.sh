#!/usr/bin/env bash
# First-run bootstrap for the distributed Pocket Pikachu macOS app.
#
# Turns a clean Mac into a working talking pet by setting up the torch-free local
# stack in a writable working dir and downloading the public model weights:
#   * Brain : MiniCPM5-1B GGUF via llama-cpp-python (prebuilt Apple-Silicon Metal wheel — no compiler)
#   * Voice : Kokoro (kokoro-onnx; weights ship inside the app, copied in here)
#   * Ears  : faster-whisper (CTranslate2; lazy ~140 MB on first transcription)
#
# Emits machine-readable "PROGRESS: <done>/<total> <label>" lines on stdout for the
# in-app progress screen, then "DONE" on success or "ERROR: <msg>" on failure.
#
# Env:
#   POCKETDM_BUNDLE_RUNTIME  path to the bundled runtime tree (the app passes its
#                            Contents/Resources/pocketdm-runtime dir)
#   POCKETDM_WORKDIR         writable working dir (default: Application Support)
set -uo pipefail

TOTAL=7
step() { echo "PROGRESS: $1/$TOTAL $2"; }
fail() { echo "ERROR: $1"; exit 1; }

WORK="${POCKETDM_WORKDIR:-$HOME/Library/Application Support/PocketDM/runtime}"
SRC_RUNTIME="${POCKETDM_BUNDLE_RUNTIME:-}"
LLAMA_WHL_INDEX="https://abetlen.github.io/llama-cpp-python/whl/metal"
PYVER="3.12"
REQ_DIR_REL="macos/PocketDMCompanion/scripts"

step 1 "Preparing workspace"
mkdir -p "$WORK" || fail "cannot create working dir $WORK"
if [[ -n "$SRC_RUNTIME" && -d "$SRC_RUNTIME" ]]; then
  # Copy the bundled runtime (app source, scripts, bundled Kokoro weights) into the
  # writable working dir. Keep any already-built venvs + downloaded models.
  rsync -a --exclude '.pika-*-venv' --exclude 'models' "$SRC_RUNTIME"/ "$WORK"/ \
    || fail "cannot stage runtime into $WORK"
fi
cd "$WORK" || fail "working dir vanished"

step 2 "Installing the package manager (uv)"
export PATH="$HOME/.local/bin:$PATH"
if ! command -v uv >/dev/null 2>&1; then
  curl -LsSf https://astral.sh/uv/install.sh | sh >/dev/null 2>&1 || fail "uv install failed (need internet on first run)"
  export PATH="$HOME/.local/bin:$PATH"
fi
command -v uv >/dev/null 2>&1 || fail "uv not on PATH after install"
UV="$(command -v uv)"
# Best-effort system deps for the Kokoro voice (espeak-ng = phonemes, ffmpeg = styling).
# If unavailable the pet still talks via the bundled chirp fallback.
if command -v brew >/dev/null 2>&1; then
  command -v espeak-ng >/dev/null 2>&1 || brew install espeak-ng >/dev/null 2>&1 || true
  command -v ffmpeg    >/dev/null 2>&1 || brew install ffmpeg    >/dev/null 2>&1 || true
fi

step 3 "Setting up the brain (MiniCPM5-1B, Metal-accelerated)"
LLAMA_VENV="$WORK/.pika-llama-venv"
if [[ ! -x "$LLAMA_VENV/bin/python" ]]; then
  "$UV" venv "$LLAMA_VENV" --python "$PYVER" || fail "brain venv create failed"
  "$UV" pip install --python "$LLAMA_VENV/bin/python" \
    --extra-index-url "$LLAMA_WHL_INDEX" --index-strategy unsafe-best-match \
    "llama-cpp-python[server]==0.3.2" || fail "brain install failed (Metal wheel)"
fi

step 4 "Setting up the voice (Kokoro)"
KOKORO_VENV="$WORK/.pika-kokoro-venv"
if [[ ! -x "$KOKORO_VENV/bin/python" ]]; then
  "$UV" venv "$KOKORO_VENV" --python "$PYVER" || fail "voice venv create failed"
  "$UV" pip install --python "$KOKORO_VENV/bin/python" \
    -r "$WORK/$REQ_DIR_REL/pika_kokoro_requirements.txt" || fail "voice install failed"
fi

step 5 "Setting up the ears (faster-whisper)"
STT_VENV="$WORK/.pika-stt-venv"
if [[ ! -x "$STT_VENV/bin/python" ]]; then
  "$UV" venv "$STT_VENV" --python "$PYVER" || fail "ears venv create failed"
  "$UV" pip install --python "$STT_VENV/bin/python" \
    -r "$WORK/$REQ_DIR_REL/pika_stt_requirements.txt" || fail "ears install failed"
fi

step 6 "Setting up the companion server"
WEB_VENV="$WORK/.pika-web-venv"
if [[ ! -x "$WEB_VENV/bin/python" ]]; then
  "$UV" venv "$WEB_VENV" --python "$PYVER" || fail "server venv create failed"
  # The companion server (app/server.py) is torch-free: FastAPI + Gradio's Server.
  "$UV" pip install --python "$WEB_VENV/bin/python" \
    "fastapi>=0.115" "gradio==6.17.3" "pydantic>=2" "python-multipart>=0.0.9" "httpx" \
    || fail "server deps failed"
fi

step 7 "Downloading the brain weights (~700 MB, one time)"
BRAIN="$WORK/models/minicpm5-1b/MiniCPM5-1B-Q4_K_M.gguf"
if [[ ! -f "$BRAIN" ]]; then
  "$UV" run --with huggingface-hub hf download openbmb/MiniCPM5-1B-GGUF MiniCPM5-1B-Q4_K_M.gguf \
    --local-dir "$WORK/models/minicpm5-1b" >/dev/null 2>&1 || fail "brain weights download failed"
fi
[[ -f "$BRAIN" ]] || fail "brain weights missing after download"

echo "DONE"
