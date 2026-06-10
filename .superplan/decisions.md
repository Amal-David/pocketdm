# Decisions

- Record durable workflow or architecture decisions here when they change how future work should proceed.

## 2026-06-10 — T-0004 latency benchmark (real free-tier Space, 2 vCPU quota confirmed)
llama.cpp b9587, Q4_K_M, t=2 optimal (t=4 thrashes the 2-vCPU quota):
- Qwen3.5-2B: prefill 35.6 tok/s, decode 10.77 tok/s — PASSES the >=10 decode gate, barely.
- Qwen3.5-0.8B: prefill 82.8 tok/s, decode 22.8 tok/s.
NEW RISK FOUND: prefill dominates TTFT (~500-tok prompt = ~14s on 2B). Decisions:
1. 2B stays primary; 0.8B trained IN PARALLEL (cost trivial) as a drop-in — final pick on live play-feel Day 3.
2. Hard prompt budget: <=350 tokens total, dynamic suffix <=150 (engine/prompt.py contract).
3. llama-server prompt-prefix caching ON; stable prefix = system+genre; dice animation masks TTFT.
4. llama.cpp b9587+ confirmed loading Qwen3.5 hybrid arch on CPU — no arch blocker.
