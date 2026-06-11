# PocketDM MTP Runtime Runbook

Purpose: make the native llama.cpp + Gemma 4 MTP demo path easy to run,
verify, and explain to judges.

## What Runs

- Native server binary:
  `/Users/amal/.cache/pocketdm-mtp/llama.cpp/build/bin/llama-server`
- Native CLI benchmark binary:
  `/Users/amal/.cache/pocketdm-mtp/llama.cpp/build/bin/llama-cli`
- Target model:
  `/Users/amal/listenowl/experiments/build-small/models/gemma-4-e2b-it/gguf/gemma-4-E2B-it-Q4_K_M.gguf`
- MTP drafter:
  `/Users/amal/listenowl/experiments/build-small/models/gemma-4-e2b-it/gguf/mtp-gemma-4-E2B-it.gguf`
- Local server URL: `http://127.0.0.1:8081`
- PocketDM app URL: `http://127.0.0.1:7860`

## Preferred Demo Command

Let PocketDM manage the native llama.cpp server process:

```bash
cd /Users/amal/listenowl/experiments/build-small
POCKETDM_LLAMA_SERVER_BIN=/Users/amal/.cache/pocketdm-mtp/llama.cpp/build/bin/llama-server \
POCKETDM_GGUF=/Users/amal/listenowl/experiments/build-small/models/gemma-4-e2b-it/gguf/gemma-4-E2B-it-Q4_K_M.gguf \
POCKETDM_LLAMA_DRAFT_GGUF=/Users/amal/listenowl/experiments/build-small/models/gemma-4-e2b-it/gguf/mtp-gemma-4-E2B-it.gguf \
POCKETDM_LLAMA_SPEC_DRAFT_N=1 \
POCKETDM_LLAMA_SERVER_LABEL="Gemma 4 E2B Q4_K_M MTP managed llama.cpp server" \
POCKETDM_LLAMA_SERVER_LOG=/tmp/pocketdm-llama-server-managed-auto.log \
uv run --group eval --group tts python app.py
```

Notes:

- The app starts `llama-server`, waits for `/health`, and shuts down the child
  process when the app exits.
- If something is already serving `http://127.0.0.1:8081`, managed mode first
  checks `/v1/models`; for MTP it also looks for a local `llama-server` process
  command containing `--model-draft` and `draft-mtp`. Stop stale servers before
  demoing. Set `POCKETDM_LLAMA_SERVER_ALLOW_EXISTING=1` only after manually
  verifying the existing server command.
- `POCKETDM_LLAMA_REASONING` is optional. The fastest verified local path omits
  it; forcing reasoning off was slower in the managed app proof.
- MTP is enabled by `POCKETDM_LLAMA_DRAFT_GGUF` plus
  `POCKETDM_LLAMA_SPEC_DRAFT_N=1`.

## Manual Server Fallback

If you want two terminals, start the native server first:

```bash
/Users/amal/.cache/pocketdm-mtp/llama.cpp/build/bin/llama-server \
  --model /Users/amal/listenowl/experiments/build-small/models/gemma-4-e2b-it/gguf/gemma-4-E2B-it-Q4_K_M.gguf \
  --model-draft /Users/amal/listenowl/experiments/build-small/models/gemma-4-e2b-it/gguf/mtp-gemma-4-E2B-it.gguf \
  --spec-type draft-mtp --spec-draft-n-max 1 --spec-draft-ngl 999 \
  --ctx-size 2048 --threads 8 -ngl 999 -fa on \
  --host 127.0.0.1 --port 8081 --no-ui
```

Then start the app:

```bash
cd /Users/amal/listenowl/experiments/build-small
POCKETDM_LLAMA_SERVER_URL=http://127.0.0.1:8081 \
POCKETDM_LLAMA_SERVER_LABEL="Gemma 4 E2B Q4_K_M MTP llama.cpp server" \
uv run --group eval --group tts python app.py
```

## Proof Checks

Server health:

```bash
curl -sS http://127.0.0.1:8081/health
# {"status":"ok"}

curl -sS http://127.0.0.1:8081/v1/models | python3 -m json.tool
# includes: "id": "gemma-4-E2B-it-Q4_K_M.gguf"
```

Server log receipts:

```bash
rg -n "draft-mtp|speculative decoding|draft acceptance" /tmp/pocketdm-llama-server-managed-auto.log
```

Expected lines include `adding speculative implementation 'draft-mtp'`,
`speculative decoding context initialized`, and `draft acceptance`.

## Two-Turn API Timing Probe

Run this against the live app:

```bash
python3 - <<'PY'
import json, time, urllib.request

base = "http://127.0.0.1:7860"

def post(path, payload):
    data = json.dumps(payload).encode()
    req = urllib.request.Request(
        base + path,
        data=data,
        headers={"content-type": "application/json"},
    )
    started = time.perf_counter()
    with urllib.request.urlopen(req, timeout=180) as response:
        body = json.loads(response.read().decode())
    return time.perf_counter() - started, body

t1, first = post(
    "/api/start",
    {"genre": "whispering_wood", "premise": "A judge asks for proof.", "voice": "lore"},
)
choice = first["turn"]["choices"][0]
t2, second = post("/api/choose", {"session_id": first["session_id"], "action": choice})

print(json.dumps({
    "http_wall_seconds": [round(t1, 2), round(t2, 2)],
    "reported_last_turn_seconds": [
        first["state"]["last_turn_seconds"],
        second["state"]["last_turn_seconds"],
    ],
    "backend": [first["state"]["backend"], second["state"]["backend"]],
    "model": [first["state"]["model"], second["state"]["model"]],
    "tokens_per_second": [
        first["state"]["last_turn_tokens_per_second"],
        second["state"]["last_turn_tokens_per_second"],
    ],
    "used_bridge": [first["turn"]["used_bridge"], second["turn"]["used_bridge"]],
    "turn_count": [first["state"]["turn_count"], second["state"]["turn_count"]],
}, indent=2))
PY
```

Current verified managed MTP timing on 2026-06-11:

```json
{
  "http_wall_seconds": [4.1, 1.69],
  "reported_last_turn_seconds": [2.04, 1.69],
  "backend": ["llama.cpp", "llama.cpp"],
  "model": [
    "Gemma 4 E2B Q4_K_M MTP managed llama.cpp server",
    "Gemma 4 E2B Q4_K_M MTP managed llama.cpp server"
  ],
  "tokens_per_second": [22.5, 26.1],
  "used_bridge": [false, false],
  "turn_count": [1, 2]
}
```

Current no-MTP managed baseline on the same probe:

```json
{
  "http_wall_seconds": [3.08, 1.75],
  "reported_last_turn_seconds": [2.03, 1.74],
  "tokens_per_second": [21.2, 21.2],
  "used_bridge": [false, false]
}
```

The current app-level proof is therefore: native MTP is working, it keeps wall
time comparable, and it improved second-turn reported throughput from
`21.2 tok/s` to `26.1 tok/s` on this local probe. Treat bigger speedup claims
as benchmark-dependent.

## Native CLI Benchmark

Use the helper to compare target-only generation against MTP draft lengths:

```bash
cd /Users/amal/listenowl/experiments/build-small
PYTHONDONTWRITEBYTECODE=1 uv run python scripts/bench_llama_mtp.py \
  --format both --n-predict 64 --threads 8 --draft-values 1,2,4 --timeout 180 \
  -- --gpu-layers 999 --flash-attn on
```

Verified local result on 2026-06-11:

```text
case       prompt_tps  gen_tps  wall_s  llama_total_s  speedup
no_mtp        526.900   40.800   3.301              -  1.000x
mtp_n1        572.300   80.600   4.641              -  1.975x
mtp_n2        490.100   58.200   4.579              -  1.426x
mtp_n4        520.500   43.800   4.274              -  1.074x
```

A longer `--n-predict 160 --ctx-size 2048` run on the same prompt favored the
no-MTP CLI baseline (`81.8 tok/s`) over `mtp_n1` (`48.6 tok/s`). Use
`--spec-draft-n-max 1` for the demo path because it is the best MTP setting seen
so far, but rerun this helper before claiming a universal speedup.

## Caveat

Do not swap this demo path to direct `llama-cpp-python` loading for
`Gemma4Assistant`. The Gemma 4 MTP/drafter path needs native llama.cpp runtime
support for the drafter context. The direct Python binding path can load
ordinary GGUFs, but this MTP setup should run through `llama-server` or
`llama-cli`.
