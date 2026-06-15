from __future__ import annotations

import json
from dataclasses import dataclass
from typing import Any, Protocol, Sequence

from pydantic import ValidationError

from engine.bridges import bridge_turn
from engine.prompt import build_messages
from engine.schema import Turn
from engine.state import GameState, drop_missing_remove_items, validate_turn

DEFAULT_TEMPERATURE = 0.8
RETRY_TEMPERATURE_DELTA = 0.15


class TurnBackend(Protocol):
    def complete(self, messages: list[dict[str, str]], *, temperature: float) -> str:
        ...


@dataclass
class TurnResult:
    turn: Turn
    used_bridge: bool
    raw_attempts: list[str]

    @property
    def bridge(self) -> bool:
        return self.used_bridge


def next_turn(
    state: GameState,
    backend: TurnBackend,
    *,
    temperature: float = DEFAULT_TEMPERATURE,
) -> TurnResult:
    messages = build_messages(state)
    raw_attempts: list[str] = []

    for attempt in range(2):
        attempt_temperature = (
            temperature if attempt == 0 else round(temperature + RETRY_TEMPERATURE_DELTA, 2)
        )
        try:
            raw = backend.complete(messages, temperature=attempt_temperature)
            raw_attempts.append(raw)
            turn = Turn.model_validate_json(raw)
            validation_errors = validate_turn(state, turn)
            if validation_errors and any(
                error.startswith("remove_items missing from inventory:")
                for error in validation_errors
            ):
                repaired_turn = drop_missing_remove_items(state, turn)
                repaired_errors = validate_turn(state, repaired_turn)
                if not repaired_errors:
                    return TurnResult(
                        turn=repaired_turn,
                        used_bridge=False,
                        raw_attempts=raw_attempts,
                    )
            if validation_errors:
                raise ValueError("; ".join(validation_errors))
            return TurnResult(turn=turn, used_bridge=False, raw_attempts=raw_attempts)
        except Exception as exc:
            if len(raw_attempts) == attempt:
                raw_attempts.append(f"<{type(exc).__name__}: {exc}>")
            continue

    return TurnResult(
        turn=bridge_turn(state),
        used_bridge=True,
        raw_attempts=raw_attempts,
    )


class MockBackend:
    def __init__(self, responses: Sequence[str | Turn | dict[str, Any]]) -> None:
        self._responses = list(responses)
        self.calls: list[list[dict[str, str]]] = []
        self.temperatures: list[float] = []

    def complete(self, messages: list[dict[str, str]], *, temperature: float) -> str:
        self.calls.append(messages)
        self.temperatures.append(temperature)
        if not self._responses:
            raise RuntimeError("MockBackend has no scripted responses left")

        response = self._responses.pop(0)
        if isinstance(response, Turn):
            return response.model_dump_json()
        if isinstance(response, str):
            return response
        return json.dumps(response, ensure_ascii=True, separators=(",", ":"))
