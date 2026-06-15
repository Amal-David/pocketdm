from __future__ import annotations

import importlib.util
import sys
from pathlib import Path


SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "bench_llama_mtp.py"
SPEC = importlib.util.spec_from_file_location("bench_llama_mtp", SCRIPT)
assert SPEC is not None
bench_llama_mtp = importlib.util.module_from_spec(SPEC)
assert SPEC.loader is not None
sys.modules[SPEC.name] = bench_llama_mtp
SPEC.loader.exec_module(bench_llama_mtp)


def test_parse_llama_timings_extracts_prompt_generation_and_total_rates() -> None:
    output = """
llama_perf_context_print: prompt eval time =    68.12 ms /    16 tokens (    4.26 ms per token,   234.88 tokens per second)
llama_perf_context_print:        eval time =  2031.50 ms /   128 runs   (   15.87 ms per token,    63.00 tokens per second)
llama_perf_context_print:       total time =  2120.00 ms /   144 tokens
"""

    timings = bench_llama_mtp.parse_llama_timings(output)

    assert timings["prompt_eval_seconds"] == 0.06812
    assert timings["prompt_eval_tokens"] == 16
    assert timings["prompt_eval_tps"] == 234.88
    assert timings["generation_seconds"] == 2.0315
    assert timings["generation_tokens"] == 128
    assert timings["generation_tps"] == 63.0
    assert timings["total_seconds"] == 2.12
    assert timings["total_tokens"] == 144


def test_parse_llama_timings_extracts_compact_summary_rates() -> None:
    output = "[ Prompt: 315.2 t/s | Generation: 21.9 t/s ]"

    timings = bench_llama_mtp.parse_llama_timings(output)

    assert timings["prompt_eval_tps"] == 315.2
    assert timings["generation_tps"] == 21.9


def test_build_cases_adds_no_mtp_baseline_and_mtp_draft_runs() -> None:
    cases = bench_llama_mtp.build_cases(
        llama_cli=Path("/tmp/llama-cli"),
        model=Path("/tmp/target.gguf"),
        draft_model=Path("/tmp/drafter.gguf"),
        draft_values=[1, 2],
        prompt="bench prompt",
        prompt_file=None,
        n_predict=32,
        threads=8,
        threads_batch=4,
        ctx_size=2048,
        seed=7,
        temp=0.0,
        draft_gpu_layers=999,
        extra_args=["--no-warmup"],
    )

    assert [case.label for case in cases] == ["no_mtp", "mtp_n1", "mtp_n2"]
    assert "--spec-type" not in cases[0].command
    assert cases[1].command[-8:] == [
        "--spec-type",
        "draft-mtp",
        "--spec-draft-model",
        "/tmp/drafter.gguf",
        "--spec-draft-n-max",
        "1",
        "--spec-draft-ngl",
        "999",
    ]
    assert "--threads" in cases[0].command
    assert "--threads-batch" in cases[0].command
    assert "--ctx-size" in cases[0].command
    assert "--single-turn" in cases[0].command
    assert "--no-warmup" in cases[0].command


def test_add_speedups_uses_generation_throughput_as_the_comparison() -> None:
    results = [
        {"label": "no_mtp", "generation_tps": 45.4},
        {"label": "mtp_n1", "generation_tps": 63.0},
        {"label": "mtp_n2", "generation_tps": 56.2},
    ]

    bench_llama_mtp.add_speedups(results)

    assert results[0]["speedup_vs_no_mtp"] == 1.0
    assert results[1]["speedup_vs_no_mtp"] == 1.388
    assert results[2]["speedup_vs_no_mtp"] == 1.238
