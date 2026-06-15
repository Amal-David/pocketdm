# Small LLM Selection

## Decision

Use `MiniCPM5-1B-Q4_K_M.gguf` as the active companion/chat model for the
hackathon demo when the story is "tiny local brain under 4B."

Keep `Qwen3.5-2B-Q4_K_M.gguf` as the quality-favored fallback when the roleplay
line matters more than the lowest RAM footprint.

Keep `Qwen3.5-0.8B-Q4_K_M.gguf` as the speed fallback when MiniCPM5 is too bland
or unavailable but the demo still needs a sub-1B-ish footprint.

## Why

The current open-source small-model signal points to MiniCPM5-1B as a strong
tiny general model in the roughly 1B class, with a clean Apache-2.0 GGUF path.
It is already downloaded locally and is the best fit for a Tiny Titan story
where RAM and latency matter.

The local roleplay smoke was better on Qwen3.5-2B. MiniCPM5 answered quickly,
while Qwen3.5-2B gave a more vivid pet/roleplay line at interactive latency and
still stays safely under the 4B Tiny Titan ceiling.

## Local Smoke Results

| Model | GGUF | Local result |
| --- | --- | --- |
| MiniCPM5-1B | `models/minicpm5-1b/MiniCPM5-1B-Q4_K_M.gguf` | Active on `127.0.0.1:8081` as `minicpm5-1b-q4`; 5 warm chat calls returned in 0.16-0.38s with roughly 150-220 estimated output tok/s on short companion prompts. Tone is generic without strict prompt shaping. |
| Qwen3.5-2B | `models/qwen3.5-2b/Qwen3.5-2B-Q4_K_M.gguf` | Loaded locally, about 1.2 GB, better roleplay/pet phrasing. |
| PocketDM 2B fine-tune | `models/2b-v1-lora/gguf/merged.Q4_K_M.gguf` | Good adventure-specialized fallback, but weaker for general desktop chat. |
| Qwen3.5-0.8B | `models/qwen3.5-0.8b/Qwen3.5-0.8B-Q4_K_M.gguf` | Speed fallback in the Qwen3.5 family, useful if the demo needs a smaller model than 2B. |
| Phi-4-mini | `models/phi-4-mini-instruct/Phi-4-mini-instruct-Q4_K_M.gguf` | Opt-in only; close to the 4B ceiling and not part of the automatic companion ladder. |

## Current Ranking

| Rank | Model | Use | Risk |
| --- | --- | --- | --- |
| 1 | MiniCPM5-1B | Default companion brain | Needs tight prompt shaping for charm. |
| 2 | Qwen3.5-2B | Quality fallback | Heavier and may need newer llama.cpp support. |
| 3 | Qwen3.5-0.8B | Speed fallback | Less roleplay headroom than 2B. |
| 4 | Gemma 4 E2B | Optional llama.cpp/GGUF runbook tech | Stronger multimodal/wellness story, but runtime RAM is much heavier and eligibility should be checked against total parameters. |
| 5 | LFM2-2.6B | Speed experiment | Interesting llama.cpp edge model, but the license story is weaker for the hackathon default. |
| 6 | Qwen3-1.7B | Conservative older fallback | Stable GGUF fallback, less current than Qwen3.5. |

## Current GGUF Shortlist

| Role | Hugging Face repo | Files to try |
| --- | --- | --- |
| Default brain | `openbmb/MiniCPM5-1B-GGUF` | `MiniCPM5-1B-Q4_K_M.gguf`; `MiniCPM5-1B-Q8_0.gguf` if quality needs a small bump. |
| Quality challenger | `unsloth/Qwen3.5-2B-GGUF` | `Qwen3.5-2B-Q4_K_M.gguf`; try `Qwen3.5-2B-Q5_K_M.gguf` only if RAM is fine. |
| Tiny fallback | `unsloth/Qwen3.5-0.8B-GGUF` | `Qwen3.5-0.8B-Q4_K_M.gguf`. |
| Gemma/MTP demo | `unsloth/gemma-4-E2B-it-GGUF` | `gemma-4-E2B-it-Q4_K_M.gguf`; `MTP/gemma-4-E2B-it-Q8_0-MTP.gguf` for the native llama.cpp MTP path. |
| Edge-speed experiment | `LiquidAI/LFM2-2.6B-GGUF` | `LFM2-2.6B-Q4_K_M.gguf` if we want a non-Qwen speed comparison. |
| Older conservative fallback | `ggml-org/Qwen3-1.7B-GGUF` | `Qwen3-1.7B-Q4_K_M.gguf`. |

## Run Commands

MiniCPM5 active tiny companion model:

```bash
python3 macos/PocketDMCompanion/scripts/local_llm_service.py stop
python3 macos/PocketDMCompanion/scripts/local_llm_service.py start \
  --model models/minicpm5-1b/MiniCPM5-1B-Q4_K_M.gguf \
  --model-alias minicpm5-1b-q4
python3 macos/PocketDMCompanion/scripts/local_llm_service.py status
```

Qwen3.5-2B quality fallback:

```bash
python3 macos/PocketDMCompanion/scripts/local_llm_service.py start \
  --model models/qwen3.5-2b/Qwen3.5-2B-Q4_K_M.gguf \
  --model-alias qwen35-2b-q4
python3 macos/PocketDMCompanion/scripts/local_llm_service.py status
```

Qwen3.5-0.8B speed fallback:

```bash
python3 macos/PocketDMCompanion/scripts/local_llm_service.py start \
  --download-qwen35-0.8b \
  --model-alias qwen35-0.8b-q4
python3 macos/PocketDMCompanion/scripts/local_llm_service.py status
```

Stop whichever local model is active:

```bash
python3 macos/PocketDMCompanion/scripts/local_llm_service.py stop
```

Launch the native companion against the active local model:

```bash
POCKETDM_ASSISTANT_LLAMA_URL=http://127.0.0.1:8081 \
POCKETDM_ASSISTANT_LLAMA_MODEL=minicpm5-1b-q4 \
macos/PocketDMCompanion/scripts/launch_app.sh \
  --attach http://127.0.0.1:7860 \
  --character pika \
  --pika-tts-url http://127.0.0.1:7861/tts \
  --launch-server
```

## Sources Checked

- Hugging Face model metadata for `openbmb/MiniCPM5-1B-GGUF`: https://hf.co/openbmb/MiniCPM5-1B-GGUF
- Hugging Face model metadata for `unsloth/Qwen3.5-2B-GGUF`: https://hf.co/unsloth/Qwen3.5-2B-GGUF
- Hugging Face model metadata for `unsloth/Qwen3.5-0.8B-GGUF`: https://hf.co/unsloth/Qwen3.5-0.8B-GGUF
- Hugging Face model metadata for `unsloth/gemma-4-E2B-it-GGUF`: https://hf.co/unsloth/gemma-4-E2B-it-GGUF
- Hugging Face model metadata for `LiquidAI/LFM2-2.6B-GGUF`: https://hf.co/LiquidAI/LFM2-2.6B-GGUF
- Hugging Face model metadata for `ggml-org/Qwen3-1.7B-GGUF`: https://hf.co/ggml-org/Qwen3-1.7B-GGUF
