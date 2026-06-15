# Modal / compute cost log

Every run gets a line. This table feeds the Field Notes blog's "total cost" claim.

| Date | Run | Hardware | Duration | Cost ($) | Notes |
|---|---|---|---|---|---|
| 2026-06-10 | WP-0 CPU bench (throwaway Space) | HF free CPU | ~20 min | 0.00 | 2B: 10.8 tok/s decode / 35.6 prefill; 0.8B: 22.8 / 82.8 (t=2) |
| 2026-06-10 | WP-3 smoke v1 (50 adv, defects found) | Modal H100 | 105.5 min | 6.95 | 462 turns; 5/50 real endings; rep-penalty suspected for 30 tok/s aggregate |
| 2026-06-10 | WP-3 smoke v2 (12 adv, post-fix) | Modal H100 | 46.4 min | 3.05 | 157 turns; 8/12 real endings; schema_failures=2; validation_failures=12; retried=10; 0.26 adventures/min |
| 2026-06-10 | WP-3 smoke v3 (interrupted timing probe) | Modal H100 | ~13 min | ~0.85 | Stopped after 4 waves / 48 turns because wave time stayed ~170-185s; no output JSONL |
| 2026-06-10 | WP-3 smoke v4 (6 adv, bridge fallback probe) | Modal H100 | 26.7 min | 1.76 | 84 turns; 5/6 real endings; 4/6 clean adventures; 9 bridge fallbacks; filter turn gates 72/75 narration pass |
| 2026-06-10 | WP-3 smoke v5 (6 adv, retry-feedback probe) | Modal H100 | 27.5 min | 1.81 | 85 turns; 5/6 real endings after filter update; 3/6 clean adventures; 5 bridge fallbacks; narration gate 77/80 |
| 2026-06-10 | WP-3 smoke v6 (3 adv, two-sentence prompt probe) | Modal H100 | 7.1 min | 0.46 | 42 turns; 3/3 clean adventures; 0 bridge fallbacks; narration gate 41/42; terrible cold start but 0.43 adventures/min |
| 2026-06-10 | WP-3 smoke v7 (50 adv, acceptance attempt) | Modal H100 | 118.6 min | 7.81 | 669 turns; 38/50 clean adventures; 622 clean turns; 41 bridge fallbacks; reached_real_ending 46/50; failed acceptance |
| 2026-06-11 | WP-3 smoke v8 (6 adv, multi-retry probe) | Modal H100 | 16.6 min | 1.09 | 76 turns; 4/6 clean adventures; 4 bridge fallbacks, all missing remove_items; reached_real_ending 6/6 |
| 2026-06-11 | WP-3 smoke v9 (6 adv, deterministic remove repair) | Modal H100 | 13.6 min | 0.90 | 78 turns; 6/6 clean adventures; 0 bridge fallbacks; 4 auto-repaired missing remove_items; all filter gates 100% |
| 2026-06-11 | WP-3 smoke v10 (50 adv, acceptance smoke) | Modal H100 | 109.9 min | 7.24 | 644 turns; 45/50 clean adventures; 632 clean turns; 2 bridge fallbacks; 16 auto-repaired turns; turn gates all >=99.1% |
| 2026-06-11 | WP-3 full chunk fanout attempt (6x75 adv) | Modal H100 | canceled around wave 2 | pending dashboard | Local Modal heartbeats failed; all six remote inputs were canceled before JSONL was written; rerun requires `--remote-out` volume persistence |
| 2026-06-11 | WP-3 full chunk 000 (25 adv) | Modal H100 | 66.3 min | 4.37 | 345 turns; schema_failures=42; validation_failures=32; retried=74; bridged=0; repaired=9; 0.38 adventures/min |
| 2026-06-11 | WP-3 full chunk 025 (25 adv) | Modal H100 | 62.4 min | 4.10 | 327 turns; schema_failures=35; validation_failures=29; retried=61; bridged=3; repaired=7; 0.40 adventures/min |
| 2026-06-11 | WP-3 full chunk 050 (25 adv) | Modal H100 | 51.7 min | 3.41 | 320 turns; schema_failures=38; validation_failures=25; retried=62; bridged=1; repaired=13; 0.48 adventures/min |
| 2026-06-11 | WP-3 full chunk 075 (25 adv) | Modal H100 | 59.6 min | 3.93 | 327 turns; schema_failures=35; validation_failures=28; retried=63; bridged=0; repaired=6; 0.42 adventures/min |
| 2026-06-11 | WP-3 full chunk 100 (25 adv) | Modal H100 | 57.6 min | 3.79 | 337 turns; schema_failures=36; validation_failures=26; retried=61; bridged=1; repaired=6; 0.43 adventures/min |
| 2026-06-11 | WP-3 full chunk 125 (25 adv) | Modal H100 | 49.6 min | 3.27 | 311 turns; schema_failures=33; validation_failures=23; retried=54; bridged=2; repaired=6; 0.50 adventures/min |
| 2026-06-11 | WP-3 full chunk 150 (25 adv) | Modal H100 | 63.8 min | 4.20 | 337 turns; schema_failures=35; validation_failures=24; retried=56; bridged=3; repaired=12; 0.39 adventures/min |
| 2026-06-11 | WP-3 full chunk 175 (25 adv) | Modal H100 | 52.0 min | 3.43 | 318 turns; schema_failures=38; validation_failures=23; retried=60; bridged=1; repaired=7; 0.48 adventures/min |
| 2026-06-11 | WP-3 full chunk 200 (25 adv) | Modal H100 | 58.4 min | 3.85 | 325 turns; schema_failures=39; validation_failures=25; retried=64; bridged=0; repaired=10; 0.43 adventures/min |
| 2026-06-11 | WP-3 full chunk 225 (25 adv) | Modal H100 | 61.8 min | 4.07 | 327 turns; schema_failures=32; validation_failures=29; retried=59; bridged=2; repaired=7; 0.40 adventures/min |
| 2026-06-11 | WP-3 full chunk 250 (25 adv) | Modal H100 | 49.7 min | 3.27 | 313 turns; schema_failures=30; validation_failures=18; retried=48; bridged=0; repaired=8; 0.50 adventures/min |
| 2026-06-11 | WP-3 full chunk 275 (25 adv) | Modal H100 | 63.5 min | 4.18 | 327 turns; schema_failures=29; validation_failures=26; retried=52; bridged=3; repaired=9; 0.39 adventures/min |
| 2026-06-11 | WP-4 0.8B LoRA smoke attempt (dependency conflict) | Modal image build | n/a | 0.00 | Failed before GPU training: Unsloth requires trl<=0.24.0 |
| 2026-06-11 | WP-4 fine-tune (0p8b-smoke-lora-20) | Modal A100-40GB | 4.8 min | 0.17 | 20-step LoRA smoke; 978 train rows; 20 eval rows; train_loss=1.555; eval_loss=1.284; merged model saved to pocketdm-models volume |
| 2026-06-11 | WP-4 GGUF export probe (pre-MTP patch) | Modal A10 | 3.3 min | 0.06 | Q4_K_M export completed but local llama.cpp rejected metadata expecting missing blk.24 tensors |
| 2026-06-11 | WP-4 GGUF export (0p8b-smoke-lora-20 Q4_K_M) | Modal A10 | 3.3 min | 0.06 | SHA256 02f57aca6929095f80b359d63760cbcd7e4d16ad4ce8d83b4af2d2c5c0355dc8; mtp_num_hidden_layers 1->0; local 3-turn llama.cpp smoke passed |
| 2026-06-11 | WP-4 fine-tune (2b-v1-lora) | Modal A100-40GB | 56.0 min | 1.96 | 3513 train rows; 72 eval rows; base=principled-intelligence/Qwen3.5-2B-text-only; lora=True; train_loss=0.854 |
| 2026-06-11 | WP-4 GGUF export (2b-v1-lora Q4_K_M + Q8_0) | Modal A10 | 4.7 min | ~0.09 | Q4_K_M SHA256 16fe19e2d786d6cca7db000807844fba39bd687480ebf7b6282258a984c651ff; Q8_0 SHA256 5065375f759954f82224b804d3d6da3f9d4412c645e3066fbb9c4ef6cacc44ca; mtp_num_hidden_layers 1->0 |
| 2026-06-11 | WP-5 judge API compatibility failure | Modal H100 | ~2.5 min | ~0.16 | vLLM 0.11 rejected deprecated `guided_json`; no verdicts written |
| 2026-06-11 | WP-5 judge parse-failure probe | Modal H100 | ~9.0 min | ~0.59 | 50 prompts generated but one whitespace-heavy partial JSON crashed parsing before local write |
| 2026-06-11 | WP-5 judge corrected parser, truncated transcript prompt | Modal H100 | ~10.5 min | ~0.69 | 50 verdicts written with 1 parse fallback, but prompt truncation hid endings and report was not used as final evidence |
| 2026-06-11 | WP-5 judge compact all-turn transcript prompt | Modal H100 | ~11.5 min | ~0.76 | 50 verdicts written with 1 parse fallback; corrected report: coherence 2.52, choice meaningfulness 2.46, ending satisfaction 2.98 |

**Running total: at least ~$82.33**, plus the failed full-chunk fanout once Modal dashboard billing settles.
