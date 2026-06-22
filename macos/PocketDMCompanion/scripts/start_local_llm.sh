#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
repo_root="$(cd -- "$script_dir/../../.." >/dev/null 2>&1 && pwd -P)"

host="${POCKETDM_LLAMA_SERVER_HOST:-127.0.0.1}"
port="${POCKETDM_LLAMA_SERVER_PORT:-8081}"
model_path="${POCKETDM_GGUF:-}"
model_alias="${POCKETDM_LLAMA_SERVER_MODEL:-pocketdm-local}"
n_ctx="${POCKETDM_LLAMA_CTX:-4096}"
n_gpu_layers="${POCKETDM_LLAMA_GPU_LAYERS:--1}"
n_threads="${POCKETDM_LLAMA_THREADS:--1}"
chat_template_kwargs="${POCKETDM_LLAMA_CHAT_TEMPLATE_KWARGS:-{\"enable_thinking\":false}}"
download_minicpm5=0
download_qwen35_2b=0
download_qwen35_08b=0
download_phi4=0

usage() {
  cat <<'USAGE'
Usage: scripts/start_local_llm.sh [--model PATH] [--model-alias NAME] [--host 127.0.0.1] [--port 8081] [--download-minicpm5] [--download-qwen35-2b] [--download-qwen35-0.8b] [--download-phi4-mini]

Starts a local OpenAI-compatible llama.cpp Python server for PocketDM companion
chat. It exports no cloud dependency; the native app and `/api/assistant` can
then use:

  export POCKETDM_ASSISTANT_LLAMA_URL=http://127.0.0.1:8081
  export POCKETDM_ASSISTANT_LLAMA_MODEL=pocketdm-local

Default model selection prefers a downloaded MiniCPM5-1B Q4_K_M GGUF, then
Qwen3.5-2B Q4_K_M, then Qwen3.5-0.8B Q4_K_M, then the existing PocketDM 2B
Q4_K_M GGUF. Phi-4-mini is opt-in only because it is close to the Tiny Titan
ceiling and heavier than the default companion-brain story.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --model)
      if [[ $# -lt 2 ]]; then
        echo "--model requires a path" >&2
        exit 64
      fi
      model_path="$2"
      shift 2
      ;;
    --model-alias)
      if [[ $# -lt 2 ]]; then
        echo "--model-alias requires a value" >&2
        exit 64
      fi
      model_alias="$2"
      shift 2
      ;;
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
    --download-phi4-mini)
      download_phi4=1
      shift
      ;;
    --download-minicpm5)
      download_minicpm5=1
      shift
      ;;
    --download-qwen35-2b)
      download_qwen35_2b=1
      shift
      ;;
    --download-qwen35-0.8b)
      download_qwen35_08b=1
      shift
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 64
      ;;
  esac
done

cd "$repo_root"

minicpm_dir="$repo_root/models/minicpm5-1b"
minicpm_model="$minicpm_dir/MiniCPM5-1B-Q4_K_M.gguf"
qwen35_dir="$repo_root/models/qwen3.5-2b"
qwen35_model="$qwen35_dir/Qwen3.5-2B-Q4_K_M.gguf"
qwen35_08b_dir="$repo_root/models/qwen3.5-0.8b"
qwen35_08b_model="$qwen35_08b_dir/Qwen3.5-0.8B-Q4_K_M.gguf"
phi_dir="$repo_root/models/phi-4-mini-instruct"
phi_model="$phi_dir/Phi-4-mini-instruct-Q4_K_M.gguf"
fallback_model="$repo_root/models/2b-v1-lora/gguf/merged.Q4_K_M.gguf"

if [[ "$download_minicpm5" -eq 1 ]]; then
  mkdir -p "$minicpm_dir"
  uv run --with huggingface-hub hf download openbmb/MiniCPM5-1B-GGUF \
    MiniCPM5-1B-Q4_K_M.gguf \
    --local-dir "$minicpm_dir"
fi

if [[ "$download_qwen35_2b" -eq 1 ]]; then
  mkdir -p "$qwen35_dir"
  uv run --with huggingface-hub hf download unsloth/Qwen3.5-2B-GGUF \
    Qwen3.5-2B-Q4_K_M.gguf \
    --local-dir "$qwen35_dir"
fi

if [[ "$download_qwen35_08b" -eq 1 ]]; then
  mkdir -p "$qwen35_08b_dir"
  uv run --with huggingface-hub hf download unsloth/Qwen3.5-0.8B-GGUF \
    Qwen3.5-0.8B-Q4_K_M.gguf \
    --local-dir "$qwen35_08b_dir"
fi

if [[ "$download_phi4" -eq 1 ]]; then
  mkdir -p "$phi_dir"
  uv run --with huggingface-hub hf download unsloth/Phi-4-mini-instruct-GGUF \
    Phi-4-mini-instruct-Q4_K_M.gguf \
    --local-dir "$phi_dir"
fi

if [[ -z "$model_path" ]]; then
  if [[ -f "$minicpm_model" ]]; then
    model_path="$minicpm_model"
    model_alias="minicpm5-1b-q4"
  elif [[ -f "$qwen35_model" ]]; then
    model_path="$qwen35_model"
    model_alias="qwen35-2b-q4"
  elif [[ -f "$qwen35_08b_model" ]]; then
    model_path="$qwen35_08b_model"
    model_alias="qwen35-0.8b-q4"
  else
    model_path="$fallback_model"
    model_alias="pocketdm-2b-q4"
  fi
fi

if [[ ! -f "$model_path" ]]; then
  echo "GGUF model not found: $model_path" >&2
  echo "For the hackathon demo, run with --download-minicpm5 or pass --model /path/to/model.gguf" >&2
  exit 66
fi

# Distributed app path: run the OpenAI-compatible server from a pre-built venv that has
# llama-cpp-python installed from the prebuilt Apple-Silicon Metal wheel (no compiler).
# The first-run bootstrap creates this venv and sets POCKETDM_LLAMA_VENV.
llama_venv="${POCKETDM_LLAMA_VENV:-}"
if [[ -n "$llama_venv" && -x "$llama_venv/bin/python" ]]; then
  # NOTE: the pinned prebuilt Metal wheel (llama-cpp-python 0.3.2) does not accept
  # --chat_template_kwargs (newer source builds do). Omit it here; the companion
  # server strips any <think> output, and the system prompt already forbids it.
  exec "$llama_venv/bin/python" -m llama_cpp.server \
    --model "$model_path" \
    --model_alias "$model_alias" \
    --host "$host" \
    --port "$port" \
    --n_ctx "$n_ctx" \
    --n_gpu_layers "$n_gpu_layers" \
    --n_threads "$n_threads" \
    --flash_attn true \
    --verbose false
fi

exec uv run \
  --with sse-starlette \
  --with starlette-context \
  --with pydantic-settings \
  python -m llama_cpp.server \
    --model "$model_path" \
    --model_alias "$model_alias" \
    --host "$host" \
    --port "$port" \
    --n_ctx "$n_ctx" \
    --n_gpu_layers "$n_gpu_layers" \
    --n_threads "$n_threads" \
    --chat_template_kwargs "$chat_template_kwargs" \
    --flash_attn true \
    --verbose false
