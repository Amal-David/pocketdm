from __future__ import annotations

import re
from typing import Iterable

from pydantic import BaseModel, Field, model_validator

from engine.pressure import must_end_this_turn
from engine.schema import Turn

MAX_HP = 10
MAX_INVENTORY = 6
DEFAULT_LOCATION = "Starting Point"

_TOKEN_RE = re.compile(r"[a-z0-9]+")


class GameState(BaseModel):
    hp: int = 10
    inventory: list[str] = Field(default_factory=list)
    location: str = DEFAULT_LOCATION
    flags: list[str] = Field(default_factory=list)
    turn_count: int = 0
    genre: str = "cursed_dungeon"
    premise: str | None = None
    recent_turns: list[tuple[Turn, str]] = Field(default_factory=list)

    @model_validator(mode="after")
    def normalize_bounds(self) -> GameState:
        self.hp = _clamp(self.hp, 0, MAX_HP)
        self.inventory = _dedupe_casefold(self.inventory)[:MAX_INVENTORY]
        self.flags = _dedupe_casefold(self.flags)
        self.turn_count = max(0, self.turn_count)
        self.location = self.location or DEFAULT_LOCATION
        self.recent_turns = self.recent_turns[-2:]
        return self


def apply_delta(state: GameState, turn: Turn) -> GameState:
    delta = turn.state_delta
    inventory = list(state.inventory)

    for item in delta.remove_items:
        inventory = [
            existing
            for existing in inventory
            if existing.casefold() != item.casefold()
        ]

    seen_items = {item.casefold() for item in inventory}
    for item in delta.add_items:
        key = item.casefold()
        if key in seen_items:
            continue
        if len(inventory) >= MAX_INVENTORY:
            break
        inventory.append(item)
        seen_items.add(key)

    data = state.model_dump()
    data.update(
        hp=_clamp(state.hp + delta.hp, 0, MAX_HP),
        inventory=inventory,
        location=delta.location,
        flags=_dedupe_casefold([*state.flags, *delta.add_flags]),
        turn_count=state.turn_count + 1,
    )
    return GameState.model_validate(data)


def drop_missing_remove_items(state: GameState, turn: Turn) -> Turn:
    inventory_keys = {item.casefold() for item in state.inventory}
    remove_items = [
        item
        for item in turn.state_delta.remove_items
        if item.casefold() in inventory_keys
    ]
    if remove_items == turn.state_delta.remove_items:
        return turn
    return turn.model_copy(
        update={
            "state_delta": turn.state_delta.model_copy(
                update={"remove_items": remove_items}
            )
        }
    )


def validate_turn(state: GameState, turn: Turn) -> list[str]:
    errors: list[str] = []

    if len(turn.choices) != 3:
        errors.append("turn must offer exactly 3 choices")

    for left_index, left in enumerate(turn.choices):
        for right in turn.choices[left_index + 1 :]:
            if _jaccard(left, right) >= 0.8:
                errors.append("choices must be distinct")
                break

    if state.recent_turns:
        last_turn = state.recent_turns[-1][0]
        last_choices = {_normalize_choice(choice) for choice in last_turn.choices}
        for choice in turn.choices:
            if _normalize_choice(choice) in last_choices:
                errors.append("choice repeats a choice offered last turn")
                break

        if _jaccard(turn.narration, last_turn.narration) >= 0.9:
            errors.append("narration repeats the last narration too closely")

    inventory_keys = {item.casefold() for item in state.inventory}
    missing = [
        item for item in turn.state_delta.remove_items if item.casefold() not in inventory_keys
    ]
    if missing:
        errors.append(f"remove_items missing from inventory: {', '.join(missing)}")

    projected_hp = state.hp + turn.state_delta.hp
    if projected_hp <= 0:
        if not turn.is_ending:
            errors.append("hp at 0 or below requires an ending turn")
        elif turn.ending_type != "death":
            errors.append("hp at 0 or below requires a death ending")

    if must_end_this_turn(state) and not turn.is_ending:
        errors.append("turn 15 must set is_ending true")

    return errors


def _clamp(value: int, low: int, high: int) -> int:
    return min(high, max(low, value))


def _dedupe_casefold(values: Iterable[str]) -> list[str]:
    deduped: list[str] = []
    seen: set[str] = set()
    for value in values:
        key = value.casefold()
        if key in seen:
            continue
        deduped.append(value)
        seen.add(key)
    return deduped


def _normalize_choice(choice: str) -> str:
    return " ".join(choice.casefold().split())


def _tokens(text: str) -> set[str]:
    return set(_TOKEN_RE.findall(text.casefold()))


def _jaccard(left: str, right: str) -> float:
    left_tokens = _tokens(left)
    right_tokens = _tokens(right)
    if not left_tokens and not right_tokens:
        return 1.0
    if not left_tokens or not right_tokens:
        return 0.0
    return len(left_tokens & right_tokens) / len(left_tokens | right_tokens)
