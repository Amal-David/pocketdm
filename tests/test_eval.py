from __future__ import annotations

from eval.metrics import aggregate_metrics, compute_session_metrics
from eval.report import render_report


def turn(index: int, *, ending: bool = False, bridge: bool = False) -> dict[str, object]:
    return {
        "turn_json": {
            "narration": f"Scene {index} opens. The path changes.",
            "choices": [f"Choice {index}A", f"Choice {index}B", f"Choice {index}C"],
            "state_delta": {
                "hp": 0,
                "add_items": [],
                "remove_items": [],
                "location": f"Room {index}",
                "add_flags": [],
            },
            "is_ending": ending,
            "ending_type": "victory" if ending else None,
        },
        "used_bridge": bridge,
        "tokens": 20,
        "wall_seconds": 0.5,
    }


def test_compute_session_metrics_counts_valid_zero_bridge_completion() -> None:
    session = {"genre": "cursed_dungeon", "turns": [turn(1), turn(2, ending=True)]}

    metrics = compute_session_metrics(session)

    assert metrics.turns == 2
    assert metrics.schema_valid_turns == 2
    assert metrics.choice_distinct_turns == 2
    assert metrics.delta_legal_turns == 2
    assert metrics.zero_bridge_complete is True
    assert metrics.tokens == 40
    assert metrics.wall_seconds == 1.0


def test_aggregate_metrics_exposes_rates_that_fail_when_business_logic_breaks() -> None:
    sessions = [
        {"genre": "cursed_dungeon", "turns": [turn(1), turn(2, ending=True)]},
        {"genre": "cursed_dungeon", "turns": [turn(1, bridge=True), turn(2, ending=True)]},
    ]

    metrics = aggregate_metrics(sessions)

    assert metrics["sessions"] == 2.0
    assert metrics["turns"] == 4.0
    assert metrics["schema_valid_rate"] == 1.0
    assert metrics["choice_distinct_rate"] == 1.0
    assert metrics["delta_legal_rate"] == 1.0
    assert metrics["zero_bridge_complete_rate"] == 0.5
    assert metrics["mean_tokens_per_turn"] == 20.0
    assert metrics["mean_wall_seconds_per_turn"] == 0.5


def test_schema_valid_rate_uses_grammar_free_raw_output_when_present() -> None:
    valid_raw = '{"narration":"Raw works. It has shape.","choices":["A","B","C"],"state_delta":{"hp":0,"add_items":[],"remove_items":[],"location":"Room","add_flags":[]},"is_ending":false,"ending_type":null}'
    session = {
        "genre": "cursed_dungeon",
        "turns": [
            {**turn(1), "raw": valid_raw},
            {**turn(2, ending=True), "raw": "not json"},
        ],
    }

    metrics = aggregate_metrics([session])

    assert metrics["schema_valid_rate"] == 0.5
    assert metrics["delta_legal_rate"] == 1.0


def test_eval_report_ship_gate_requires_judge_scores() -> None:
    result = {
        "model": "mock",
        "metrics": {
            "schema_valid_rate": 1.0,
            "choice_distinct_rate": 1.0,
            "delta_legal_rate": 1.0,
            "zero_bridge_complete_rate": 0.95,
            "mean_tokens_per_turn": 20.0,
            "mean_wall_seconds_per_turn": 0.5,
        },
    }

    assert "**SHIP GATE: FAIL**" in render_report([result], None)
    assert "**SHIP GATE: PASS**" in render_report(
        [result],
        {
            "verdicts": [
                {
                    "coherence": 4,
                    "choice_meaningfulness": 4,
                    "ending_satisfaction": 4,
                }
            ]
        },
    )
