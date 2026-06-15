# Offline API Proof

## 2026-06-11

Command:

```bash
PYTHONDONTWRITEBYTECODE=1 uv run --group eval --group tts python scripts/prove_offline_api.py --model models/2b-v1-lora/gguf/merged.Q4_K_M.gguf --max-turns 15 --require-wav
```

Result:

- Backend: `llama.cpp`
- Model: `models/2b-v1-lora/gguf/merged.Q4_K_M.gguf`
- Voice: `lore`
- Session completed: `true`
- Turns generated: `14`
- Ending type: `bittersweet`
- Bridge turns: `0`
- WAV turns: `14 / 14`
- Outbound socket attempts: `0`
- Network clean: `true`
- Duration: `277.45s`
- Final state: `5/10 HP`, `Narrow Corridor`, turn `14`

Acceptance evidence:

- The API flow exercised `/api/start`, `/api/assistant`, `/api/choose`, and `/api/tts`.
- Every narration returned `audio/wav` with status `200`.
- The socket guard raised on any attempted outbound `socket.connect`; no attempts were recorded.
