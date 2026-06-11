from __future__ import annotations

import argparse
import json
import os
import re
import shlex
import subprocess
import time
from dataclasses import dataclass
from datetime import datetime, timezone
from pathlib import Path
from typing import Any


REPO_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_LLAMA_CLI = Path("/Users/amal/.cache/pocketdm-mtp/llama.cpp/build/bin/llama-cli")
DEFAULT_MODEL = REPO_ROOT / "models/gemma-4-e2b-it/gguf/gemma-4-E2B-it-Q4_K_M.gguf"
DEFAULT_DRAFT_MODEL = REPO_ROOT / "models/gemma-4-e2b-it/gguf/mtp-gemma-4-E2B-it.gguf"
DEFAULT_PROMPT = (
    "You are PocketDM, a concise offline dungeon master. "
    "Write the next turn as vivid JSON with narration, three choices, and state_delta. "
    "The adventurer opens a copper door under a silent mountain."
)

TIMING_RE = re.compile(
    r"(?P<label>prompt eval|eval|total)\s+time\s*=\s*"
    r"(?P<milliseconds>[0-9.]+)\s*ms"
    r"(?:\s*/\s*(?P<count>[0-9]+)\s*(?P<unit>tokens|runs))?"
    r"(?:\s*\(\s*(?P<ms_per_token>[0-9.]+)\s*ms per token,\s*"
    r"(?P<tokens_per_second>[0-9.]+)\s*tokens per second\s*\))?",
    re.IGNORECASE,
)
COMPACT_TIMING_RE = re.compile(
    r"\[\s*Prompt:\s*(?P<prompt_tps>[0-9.]+)\s*t/s\s*\|\s*"
    r"Generation:\s*(?P<generation_tps>[0-9.]+)\s*t/s\s*\]",
    re.IGNORECASE,
)


@dataclass(frozen=True)
class BenchmarkCase:
    label: str
    draft_n: int | None
    command: list[str]


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description=(
            "Benchmark a llama.cpp target GGUF with a no-MTP baseline and one or "
            "more MTP drafter draft lengths."
        )
    )
    parser.add_argument(
        "--llama-cli",
        type=Path,
        default=Path(os.environ.get("POCKETDM_LLAMA_CLI", DEFAULT_LLAMA_CLI)),
        help="Path to llama.cpp llama-cli.",
    )
    parser.add_argument(
        "--model",
        type=Path,
        default=Path(os.environ.get("POCKETDM_GGUF", DEFAULT_MODEL)),
        help="Target GGUF model.",
    )
    parser.add_argument(
        "--draft-model",
        type=Path,
        default=Path(os.environ.get("POCKETDM_MTP_GGUF", DEFAULT_DRAFT_MODEL)),
        help="MTP drafter GGUF model.",
    )
    parser.add_argument(
        "--draft-values",
        default=os.environ.get("POCKETDM_MTP_DRAFT_VALUES", "1,2,4"),
        help="Comma-separated --spec-draft-n-max values. Empty means baseline only.",
    )
    parser.add_argument("--prompt", default=DEFAULT_PROMPT)
    parser.add_argument("--prompt-file", type=Path)
    parser.add_argument("-n", "--n-predict", type=int, default=256)
    parser.add_argument("-t", "--threads", type=int, default=0)
    parser.add_argument("--threads-batch", type=int, default=0)
    parser.add_argument("-c", "--ctx-size", type=int, default=0)
    parser.add_argument(
        "--draft-gpu-layers",
        type=int,
        default=int(os.environ.get("POCKETDM_LLAMA_SPEC_DRAFT_GPU_LAYERS", "999")),
        help="GPU layers for the draft model in MTP runs.",
    )
    parser.add_argument("--seed", type=int, default=1)
    parser.add_argument("--temp", type=float, default=0.0)
    parser.add_argument("--timeout", type=float, default=300.0)
    parser.add_argument("--dry-run", action="store_true", help="Print planned commands without running them.")
    parser.add_argument(
        "--format",
        choices=("text", "json", "both"),
        default="text",
        help="Summary format.",
    )
    parser.add_argument(
        "llama_args",
        nargs=argparse.REMAINDER,
        help="Extra llama-cli args after --, for example: -- --gpu-layers all",
    )
    return parser


def parse_draft_values(raw: str) -> list[int]:
    if not raw.strip():
        return []
    values: list[int] = []
    for item in raw.split(","):
        item = item.strip()
        if not item:
            continue
        value = int(item)
        if value < 1:
            raise ValueError("draft values must be positive integers")
        values.append(value)
    return values


def normalize_extra_args(args: list[str]) -> list[str]:
    if args and args[0] == "--":
        return args[1:]
    return args


def build_cases(
    *,
    llama_cli: Path,
    model: Path,
    draft_model: Path | None,
    draft_values: list[int],
    prompt: str,
    prompt_file: Path | None,
    n_predict: int,
    threads: int,
    threads_batch: int,
    ctx_size: int,
    seed: int,
    temp: float,
    draft_gpu_layers: int,
    extra_args: list[str],
) -> list[BenchmarkCase]:
    base = [
        str(llama_cli),
        "-m",
        str(model),
        "-n",
        str(n_predict),
        "--seed",
        str(seed),
        "--temp",
        str(temp),
        "--no-display-prompt",
        "--single-turn",
        "--perf",
        "--show-timings",
    ]
    if prompt_file is not None:
        base.extend(["-f", str(prompt_file)])
    else:
        base.extend(["-p", prompt])
    if threads > 0:
        base.extend(["--threads", str(threads)])
    if threads_batch > 0:
        base.extend(["--threads-batch", str(threads_batch)])
    if ctx_size > 0:
        base.extend(["--ctx-size", str(ctx_size)])
    base.extend(extra_args)

    cases = [BenchmarkCase(label="no_mtp", draft_n=None, command=base)]
    if draft_model is not None:
        for draft_n in draft_values:
            command = [
                *base,
                "--spec-type",
                "draft-mtp",
                "--spec-draft-model",
                str(draft_model),
                "--spec-draft-n-max",
                str(draft_n),
                "--spec-draft-ngl",
                str(draft_gpu_layers),
            ]
            cases.append(BenchmarkCase(label=f"mtp_n{draft_n}", draft_n=draft_n, command=command))
    return cases


def parse_llama_timings(output: str) -> dict[str, Any]:
    parsed: dict[str, Any] = {}
    for line in output.splitlines():
        compact_match = COMPACT_TIMING_RE.search(line)
        if compact_match:
            parsed["prompt_eval_tps"] = round(float(compact_match.group("prompt_tps")), 3)
            parsed["generation_tps"] = round(float(compact_match.group("generation_tps")), 3)
            continue

        match = TIMING_RE.search(line)
        if not match:
            continue
        label = match.group("label").lower()
        prefix = "generation" if label == "eval" else label.replace(" ", "_")
        milliseconds = float(match.group("milliseconds"))
        parsed[f"{prefix}_seconds"] = round(milliseconds / 1000.0, 6)
        count = match.group("count")
        if count is not None:
            parsed[f"{prefix}_tokens"] = int(count)
        tps = match.group("tokens_per_second")
        if tps is not None:
            parsed[f"{prefix}_tps"] = round(float(tps), 3)
        ms_per_token = match.group("ms_per_token")
        if ms_per_token is not None:
            parsed[f"{prefix}_ms_per_token"] = round(float(ms_per_token), 3)
    return parsed


def run_case(case: BenchmarkCase, timeout: float) -> dict[str, Any]:
    started = time.monotonic()
    try:
        completed = subprocess.run(
            case.command,
            check=False,
            capture_output=True,
            text=True,
            timeout=timeout,
        )
    except subprocess.TimeoutExpired as exc:
        raise SystemExit(f"{case.label} timed out after {timeout:.1f}s") from exc

    wall_seconds = round(time.monotonic() - started, 3)
    output = f"{completed.stdout}\n{completed.stderr}"
    if completed.returncode != 0:
        tail = "\n".join(output.splitlines()[-30:])
        raise SystemExit(f"{case.label} failed with exit code {completed.returncode}\n{tail}")

    timings = parse_llama_timings(output)
    result = {
        "label": case.label,
        "draft_n": case.draft_n,
        "command": shlex.join(case.command),
        "wall_seconds": wall_seconds,
        **timings,
    }
    if "generation_tps" not in result:
        result["warning"] = "generation throughput was not found in llama-cli timings"
    return result


def add_speedups(results: list[dict[str, Any]]) -> None:
    baseline = next((item.get("generation_tps") for item in results if item["label"] == "no_mtp"), None)
    if not baseline:
        return
    for item in results:
        tps = item.get("generation_tps")
        item["speedup_vs_no_mtp"] = round(tps / baseline, 3) if tps else None


def prompt_char_count(args: argparse.Namespace) -> int | None:
    if args.prompt_file is None:
        return len(args.prompt)
    try:
        return len(args.prompt_file.read_text())
    except FileNotFoundError:
        return None


def build_payload(
    args: argparse.Namespace,
    draft_values: list[int],
    cases: list[BenchmarkCase],
    results: list[dict[str, Any]],
) -> dict[str, Any]:
    return {
        "generated_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
        "llama_cli": str(args.llama_cli),
        "model": str(args.model),
        "draft_model": str(args.draft_model) if draft_values else None,
        "n_predict": args.n_predict,
        "prompt_chars": prompt_char_count(args),
        "dry_run": args.dry_run,
        "cases": [
            {
                "label": case.label,
                "draft_n": case.draft_n,
                "command": shlex.join(case.command),
            }
            for case in cases
        ],
        "results": results,
    }


def format_number(value: object, suffix: str = "") -> str:
    if value is None:
        return "-"
    if isinstance(value, float):
        return f"{value:.3f}{suffix}"
    return f"{value}{suffix}"


def format_text(payload: dict[str, Any]) -> str:
    lines = [
        "llama.cpp MTP benchmark",
        f"model: {payload['model']}",
        f"draft: {payload['draft_model'] or '-'}",
        f"predict: {payload['n_predict']} tokens, prompt: {payload['prompt_chars']} chars",
    ]
    rows = payload["results"] if payload["results"] else payload["cases"]
    if payload["dry_run"]:
        lines.append("dry_run: true")
        lines.extend(f"{row['label']}: {row['command']}" for row in rows)
        return "\n".join(lines)

    lines.append("case       prompt_tps  gen_tps  wall_s  llama_total_s  speedup")
    for row in rows:
        speedup = row.get("speedup_vs_no_mtp")
        lines.append(
            f"{row['label']:<10} "
            f"{format_number(row.get('prompt_eval_tps')):>10} "
            f"{format_number(row.get('generation_tps')):>8} "
            f"{format_number(row.get('wall_seconds')):>7} "
            f"{format_number(row.get('total_seconds')):>14} "
            f"{format_number(speedup, 'x'):>7}"
        )
    warnings = [row["warning"] for row in rows if isinstance(row, dict) and row.get("warning")]
    lines.extend(f"warning: {warning}" for warning in warnings)
    return "\n".join(lines)


def validate_paths(args: argparse.Namespace, draft_values: list[int]) -> None:
    checks = [("llama-cli", args.llama_cli), ("model", args.model)]
    if draft_values:
        checks.append(("draft model", args.draft_model))
    for label, path in checks:
        if not path.exists():
            raise SystemExit(f"missing {label}: {path}")
    if args.prompt_file and not args.prompt_file.exists():
        raise SystemExit(f"missing prompt file: {args.prompt_file}")
    if args.n_predict < 1:
        raise SystemExit("--n-predict must be positive")


def print_summary(payload: dict[str, Any], output_format: str) -> None:
    if output_format in {"text", "both"}:
        print(format_text(payload))
    if output_format == "both":
        print()
    if output_format in {"json", "both"}:
        print(json.dumps(payload, sort_keys=True, separators=(",", ":")))


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    try:
        draft_values = parse_draft_values(args.draft_values)
    except ValueError as exc:
        raise SystemExit(str(exc)) from exc

    extra_args = normalize_extra_args(args.llama_args)
    if not args.dry_run:
        validate_paths(args, draft_values)

    cases = build_cases(
        llama_cli=args.llama_cli,
        model=args.model,
        draft_model=args.draft_model if draft_values else None,
        draft_values=draft_values,
        prompt=args.prompt,
        prompt_file=args.prompt_file,
        n_predict=args.n_predict,
        threads=args.threads,
        threads_batch=args.threads_batch,
        ctx_size=args.ctx_size,
        seed=args.seed,
        temp=args.temp,
        draft_gpu_layers=args.draft_gpu_layers,
        extra_args=extra_args,
    )
    results = [] if args.dry_run else [run_case(case, args.timeout) for case in cases]
    add_speedups(results)
    payload = build_payload(args, draft_values, cases, results)
    print_summary(payload, args.format)


if __name__ == "__main__":
    main()
