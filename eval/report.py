from __future__ import annotations

import argparse
import json
from pathlib import Path
from statistics import mean, stdev
from typing import Any


def load_json(path: Path) -> dict[str, Any]:
    return json.loads(path.read_text())


def judge_summary(judge: dict[str, Any]) -> dict[str, str]:
    verdicts = judge.get("verdicts", [])
    fields = ("coherence", "choice_meaningfulness", "ending_satisfaction")
    summary = {}
    for field in fields:
        values = [float(verdict[field]) for verdict in verdicts if field in verdict]
        if not values:
            summary[field] = "n/a"
        elif len(values) == 1:
            summary[field] = f"{values[0]:.2f}+/-0.00"
        else:
            summary[field] = f"{mean(values):.2f}+/-{stdev(values):.2f}"
    return summary


def render_report(results: list[dict[str, Any]], judge: dict[str, Any] | None) -> str:
    lines = ["# PocketDM Eval Report", ""]
    lines.extend(
        [
            "| Model | Schema valid | Choice distinct | Delta legal | Zero-bridge complete | Tokens/turn | Sec/turn |",
            "|---|---:|---:|---:|---:|---:|---:|",
        ]
    )
    for result in results:
        metrics = result["metrics"]
        lines.append(
            "| "
            f"{result.get('model', 'unknown')} | "
            f"{metrics['schema_valid_rate']:.1%} | "
            f"{metrics['choice_distinct_rate']:.1%} | "
            f"{metrics['delta_legal_rate']:.1%} | "
            f"{metrics['zero_bridge_complete_rate']:.1%} | "
            f"{metrics['mean_tokens_per_turn']:.1f} | "
            f"{metrics['mean_wall_seconds_per_turn']:.2f} |"
        )
    if judge:
        summary = judge_summary(judge)
        lines.extend(
            [
                "",
                "## Judge Scores",
                "",
                "| Coherence | Choice meaningfulness | Ending satisfaction |",
                "|---:|---:|---:|",
                (
                    f"| {summary['coherence']} | {summary['choice_meaningfulness']} | "
                    f"{summary['ending_satisfaction']} |"
                ),
            ]
        )
    best = results[-1]["metrics"] if results else {}
    coherence = None
    if judge:
        verdicts = judge.get("verdicts", [])
        values = [float(verdict["coherence"]) for verdict in verdicts if "coherence" in verdict]
        coherence = mean(values) if values else None
    pass_gate = (
        bool(best)
        and best.get("zero_bridge_complete_rate", 0.0) >= 0.90
        and coherence is not None
        and coherence >= 3.5
    )
    lines.extend(["", f"**SHIP GATE: {'PASS' if pass_gate else 'FAIL'}**"])
    return "\n".join(lines) + "\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("results", nargs="+")
    parser.add_argument("--judge")
    parser.add_argument("--out", default="eval/results/REPORT.md")
    args = parser.parse_args()

    results = [load_json(Path(path)) for path in args.results]
    judge = load_json(Path(args.judge)) if args.judge else None
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(render_report(results, judge))
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
