from __future__ import annotations

from pathlib import Path
from typing import Any

import pytest
from pydantic import ValidationError

from engine.schema import CANONICAL_KEY_ORDER, Turn

ROOT = Path(__file__).resolve().parents[1]
GRAMMAR_PATH = ROOT / "engine" / "grammar.gbnf"


def valid_turns() -> list[dict[str, Any]]:
    return [
        {
            "narration": "You lift the lantern and the stairwell exhales cold dust.",
            "choices": ["Raise the shield", "Search the alcove", "Call into the dark"],
            "state_delta": {
                "hp": 0,
                "add_items": ["lantern"],
                "remove_items": [],
                "location": "Sunken Stair",
                "add_flags": ["heard_whispers"],
            },
            "is_ending": False,
            "ending_type": None,
        },
        {
            "narration": "The mimic snaps your sleeve, but you wrench free with a laugh.",
            "choices": ["Offer it crumbs", "Kick the chest", "Back toward the arch"],
            "state_delta": {
                "hp": -2,
                "add_items": [],
                "remove_items": [],
                "location": "Hungry Vault",
                "add_flags": [],
            },
            "is_ending": False,
            "ending_type": None,
        },
        {
            "narration": "You set the crown on the mushroom throne, and the grove bows.",
            "choices": ["Accept the feast", "Thank the sprites", "Keep the tiny crown"],
            "state_delta": {
                "hp": 1,
                "add_items": ["spore crown"],
                "remove_items": ["iron thorn"],
                "location": "Mooncap Court",
                "add_flags": ["saved_grove"],
            },
            "is_ending": True,
            "ending_type": "victory",
        },
        {
            "narration": "The starship door seals behind you as the reactor sings its last note.",
            "choices": ["Salute the void", "Hug the toolbox", "Record one final joke"],
            "state_delta": {
                "hp": -10,
                "add_items": [],
                "remove_items": ["oxygen key"],
                "location": "Reactor Chapel",
                "add_flags": ["reactor_lost"],
            },
            "is_ending": True,
            "ending_type": "death",
        },
        {
            "narration": "You escape with the map, though the forest keeps your shadow.",
            "choices": ["Follow sunrise", "Name the shadow", "Pocket the map"],
            "state_delta": {
                "hp": 0,
                "add_items": ["living map"],
                "remove_items": [],
                "location": "Dawn Road",
                "add_flags": ["shadow_left_behind"],
            },
            "is_ending": True,
            "ending_type": "bittersweet",
        },
    ]


@pytest.mark.parametrize("sample", valid_turns())
def test_valid_turns_round_trip_stably(sample: dict[str, Any]) -> None:
    turn = Turn.model_validate(sample)

    serialized = turn.model_dump_json()
    reparsed = Turn.model_validate_json(serialized)

    assert reparsed == turn
    assert reparsed.model_dump_json() == serialized
    assert tuple(turn.model_dump().keys()) == (
        "narration",
        "choices",
        "state_delta",
        "is_ending",
        "ending_type",
    )
    assert tuple(turn.state_delta.model_dump().keys()) == (
        "hp",
        "add_items",
        "remove_items",
        "location",
        "add_flags",
    )


@pytest.mark.parametrize(
    ("mutation", "expected_fragment"),
    [
        ({"choices": ["Open the door", "Light a torch"]}, "List should have at least 3 items"),
        (
            {
                "state_delta": {
                    "hp": 11,
                    "add_items": [],
                    "remove_items": [],
                    "location": "Too Bold",
                    "add_flags": [],
                }
            },
            "less than or equal to 10",
        ),
        ({"is_ending": True, "ending_type": None}, "ending_type must be set"),
        ({"narration": "x" * 601}, "at most 600 characters"),
        ({"unexpected": "nope"}, "Extra inputs are not permitted"),
    ],
)
def test_invalid_turns_are_rejected(
    mutation: dict[str, Any], expected_fragment: str
) -> None:
    sample = valid_turns()[0] | mutation

    with pytest.raises(ValidationError) as exc_info:
        Turn.model_validate(sample)

    assert expected_fragment in str(exc_info.value)


def test_extra_state_delta_keys_are_rejected() -> None:
    sample = valid_turns()[0]
    sample["state_delta"] = sample["state_delta"] | {"secret": "nope"}

    with pytest.raises(ValidationError) as exc_info:
        Turn.model_validate(sample)

    assert "Extra inputs are not permitted" in str(exc_info.value)


def test_non_ending_turn_cannot_have_ending_type() -> None:
    sample = valid_turns()[0] | {"ending_type": "victory"}

    with pytest.raises(ValidationError) as exc_info:
        Turn.model_validate(sample)

    assert "ending_type must be null" in str(exc_info.value)


def test_grammar_pins_canonical_keys_and_enums() -> None:
    grammar = GRAMMAR_PATH.read_text()
    key_literals = [f'"\\"{key}\\""' for key in CANONICAL_KEY_ORDER]

    positions = [grammar.index(key_literal) for key_literal in key_literals]

    assert positions == sorted(positions)
    assert '"\\"victory\\""' in grammar
    assert '"\\"death\\""' in grammar
    assert '"\\"bittersweet\\""' in grammar
    assert '"null"' in grammar
    assert "\\d" not in grammar
    assert "\\s" not in grammar
    assert "\\w" not in grammar


def test_grammar_syntax_if_llama_cpp_is_available() -> None:
    llama_cpp = pytest.importorskip(
        "llama_cpp",
        reason="llama_cpp is not installed; WP-6 covers live grammar behavior",
    )

    llama_cpp.LlamaGrammar.from_string(GRAMMAR_PATH.read_text())
