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

**Running total: ~$31.92**
