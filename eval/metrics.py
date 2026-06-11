from __future__ import annotations

from dataclasses import dataclass
from statistics import mean
from typing import Any, Iterable

from engine.schema import Turn
from engine.state import GameState, apply_delta, validate_turn


@dataclass(frozen=True)
class SessionMetrics:
    turns: int
    schema_valid_turns: int
    choice_distinct_turns: int
    delta_legal_turns: int
    bridge_turns: int
    completed: bool
    zero_bridge_complete: bool
    tokens: int
    wall_seconds: float


def compute_session_metrics(session: dict[str, Any]) -> SessionMetrics:
    state = GameState(genre=str(session.get("genre") or "cursed_dungeon"))
    schema_valid = 0
    choice_distinct = 0
    delta_legal = 0
    bridge_turns = 0
    completed = False
    token_total = 0
    wall_total = 0.0
    parsed_turns = 0

    for record in session.get("turns", []):
        if record.get("used_bridge"):
            bridge_turns += 1
        token_total += int(record.get("tokens") or _rough_tokens(record.get("raw") or ""))
        wall_total += float(record.get("wall_seconds") or 0.0)
        try:
            turn = Turn.model_validate(record.get("turn_json"))
        except Exception:
            continue
        parsed_turns += 1
        schema_valid += 1
        if len({_choice_key(choice) for choice in turn.choices}) == 3:
            choice_distinct += 1
        if not validate_turn(state, turn):
            delta_legal += 1
        state = apply_delta(state, turn)
        completed = completed or bool(turn.is_ending)

    return SessionMetrics(
        turns=parsed_turns,
        schema_valid_turns=schema_valid,
        choice_distinct_turns=choice_distinct,
        delta_legal_turns=delta_legal,
        bridge_turns=bridge_turns,
        completed=completed,
        zero_bridge_complete=completed and bridge_turns == 0 and parsed_turns <= 15,
        tokens=token_total,
        wall_seconds=wall_total,
    )


def aggregate_metrics(sessions: Iterable[dict[str, Any]]) -> dict[str, float]:
    metrics = [compute_session_metrics(session) for session in sessions]
    total_turns = sum(item.turns for item in metrics)
    total_sessions = len(metrics)
    if total_sessions == 0:
        return {
            "sessions": 0,
            "turns": 0,
            "schema_valid_rate": 0.0,
            "choice_distinct_rate": 0.0,
            "delta_legal_rate": 0.0,
            "zero_bridge_complete_rate": 0.0,
            "mean_tokens_per_turn": 0.0,
            "mean_wall_seconds_per_turn": 0.0,
        }
    return {
        "sessions": float(total_sessions),
        "turns": float(total_turns),
        "schema_valid_rate": _rate(sum(item.schema_valid_turns for item in metrics), total_turns),
        "choice_distinct_rate": _rate(sum(item.choice_distinct_turns for item in metrics), total_turns),
        "delta_legal_rate": _rate(sum(item.delta_legal_turns for item in metrics), total_turns),
        "zero_bridge_complete_rate": _rate(
            sum(1 for item in metrics if item.zero_bridge_complete),
            total_sessions,
        ),
        "mean_tokens_per_turn": (
            sum(item.tokens for item in metrics) / total_turns if total_turns else 0.0
        ),
        "mean_wall_seconds_per_turn": (
            sum(item.wall_seconds for item in metrics) / total_turns if total_turns else 0.0
        ),
    }


def _rate(passed: int, total: int) -> float:
    return passed / total if total else 0.0


def _choice_key(choice: str) -> str:
    return " ".join(choice.casefold().split())


def _rough_tokens(text: str) -> int:
    return max(0, len(str(text).split()))


def mean_sd(values: list[float]) -> tuple[float, float]:
    if not values:
        return 0.0, 0.0
    avg = mean(values)
    if len(values) == 1:
        return avg, 0.0
    variance = sum((value - avg) ** 2 for value in values) / (len(values) - 1)
    return avg, variance**0.5
