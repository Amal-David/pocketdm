from __future__ import annotations

from typing import Annotated, Literal

from pydantic import BaseModel, ConfigDict, Field, StringConstraints, model_validator

CANONICAL_TURN_KEY_ORDER: tuple[str, ...] = (
    "narration",
    "choices",
    "state_delta",
    "is_ending",
    "ending_type",
)
CANONICAL_STATE_DELTA_KEY_ORDER: tuple[str, ...] = (
    "hp",
    "add_items",
    "remove_items",
    "location",
    "add_flags",
)
CANONICAL_KEY_ORDER: tuple[str, ...] = (
    "narration",
    "choices",
    "state_delta",
    "hp",
    "add_items",
    "remove_items",
    "location",
    "add_flags",
    "is_ending",
    "ending_type",
)

ShortText = Annotated[str, StringConstraints(min_length=1, max_length=80)]


class StateDelta(BaseModel):
    model_config = ConfigDict(extra="forbid")

    hp: int = Field(ge=-10, le=10)
    add_items: list[str] = Field(max_length=3)
    remove_items: list[str] = Field(max_length=3)
    location: str = Field(min_length=1, max_length=60)
    add_flags: list[str] = Field(max_length=3)


class Turn(BaseModel):
    model_config = ConfigDict(extra="forbid")

    narration: str = Field(min_length=1, max_length=600)
    choices: list[ShortText] = Field(min_length=3, max_length=3)
    state_delta: StateDelta
    is_ending: bool
    ending_type: Literal["victory", "death", "bittersweet"] | None

    @model_validator(mode="after")
    def ending_type_matches_is_ending(self) -> Turn:
        if self.is_ending and self.ending_type is None:
            raise ValueError("ending_type must be set when is_ending is true")
        if not self.is_ending and self.ending_type is not None:
            raise ValueError("ending_type must be null when is_ending is false")
        return self
