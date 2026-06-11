from __future__ import annotations

import json

from engine.bridges import BRIDGE_TURNS
from engine.generate import MockBackend, next_turn
from engine.pressure import story_pressure
from engine.prompt import build_messages
from engine.schema import StateDelta, Turn
from engine.state import (
    GameState,
    apply_delta,
    drop_missing_remove_items,
    validate_turn,
)


def make_turn(
    *,
    narration: str = "You step into a useful test chamber. It smells faintly of assertions.",
    choices: list[str] | None = None,
    hp: int = 0,
    add_items: list[str] | None = None,
    remove_items: list[str] | None = None,
    location: str = "Test Chamber",
    add_flags: list[str] | None = None,
    is_ending: bool = False,
    ending_type: str | None = None,
) -> Turn:
    return Turn(
        narration=narration,
        choices=choices
        or ["Check the lever", "Read the plaque", "Open the quiet door"],
        state_delta=StateDelta(
            hp=hp,
            add_items=add_items or [],
            remove_items=remove_items or [],
            location=location,
            add_flags=add_flags or [],
        ),
        is_ending=is_ending,
        ending_type=ending_type,
    )


def render_messages(messages: list[dict[str, str]]) -> str:
    return "\n".join(f"{message['role']}:{message['content']}" for message in messages)


def test_apply_delta_clamps_dedupes_caps_and_updates_location() -> None:
    state = GameState(
        hp=9,
        inventory=["Torch", "rope", "TORCH", "coin", "key", "chalk"],
        flags=["Seen", "seen"],
        location="Old Room",
    )
    turn = make_turn(
        hp=5,
        add_items=["map", "gem", "spoon"],
        remove_items=["absent"],
        location="New Room",
        add_flags=["Seen", "door_open"],
    )

    updated = apply_delta(state, turn)

    assert updated.hp == 10
    assert updated.inventory == ["Torch", "rope", "coin", "key", "chalk", "map"]
    assert updated.flags == ["Seen", "door_open"]
    assert updated.location == "New Room"
    assert updated.turn_count == 1


def test_validate_turn_reports_semantic_failures() -> None:
    previous = make_turn(
        narration="You inspect the old door and hear it sigh.",
        choices=["Open the door", "Light the lamp", "Check the lock"],
    )
    state = GameState(
        inventory=["key"],
        recent_turns=[(previous, "Open the door")],
    )
    turn = make_turn(
        narration="You inspect the old door and hear it sigh.",
        choices=["Open the door", "Open the door", "Open the old door"],
        remove_items=["missing"],
    )

    errors = validate_turn(state, turn)

    assert "choices must be distinct" in errors
    assert "choice repeats a choice offered last turn" in errors
    assert "narration repeats the last narration too closely" in errors
    assert any(error.startswith("remove_items missing") for error in errors)


def test_drop_missing_remove_items_removes_only_absent_inventory() -> None:
    state = GameState(inventory=["key", "coin"])
    turn = make_turn(remove_items=["missing", "KEY", "coin"])

    repaired = drop_missing_remove_items(state, turn)

    assert repaired.state_delta.remove_items == ["KEY", "coin"]
    assert validate_turn(state, repaired) == []


def test_validate_turn_requires_death_ending_when_hp_hits_zero() -> None:
    state = GameState(hp=1)
    non_ending = make_turn(hp=-1)
    wrong_ending = make_turn(hp=-1, is_ending=True, ending_type="bittersweet")
    death_ending = make_turn(hp=-1, is_ending=True, ending_type="death")

    assert "hp at 0 or below requires an ending turn" in validate_turn(state, non_ending)
    assert "hp at 0 or below requires a death ending" in validate_turn(
        state, wrong_ending
    )
    assert validate_turn(state, death_ending) == []


def test_pressure_schedule_and_forced_turn_15_validation() -> None:
    assert "Act 1" in story_pressure(GameState(turn_count=0))
    assert "Act 2" in story_pressure(GameState(turn_count=5))
    assert "move decisively toward the climax" in story_pressure(
        GameState(turn_count=10)
    )
    assert "FINAL turn" in story_pressure(GameState(turn_count=13))
    assert "is_ending=true and ending_type" in story_pressure(GameState(turn_count=14))
    assert "near death" in story_pressure(GameState(turn_count=3, hp=2))

    state = GameState(turn_count=14)
    errors = validate_turn(state, make_turn())

    assert "turn 15 must set is_ending true" in errors


def test_prompt_budget_worst_case_and_stable_prefix() -> None:
    long_turn_a = make_turn(
        narration=("A long prior narration keeps talking without mercy " * 10) + ".",
        choices=["Choice alpha " * 6, "Choice beta " * 6, "Choice gamma " * 6],
        location="Old Extremely Verbose Hallway Name",
    )
    long_turn_b = make_turn(
        narration=("Another long prior narration tries to consume context " * 10) + ".",
        choices=["Choice delta " * 6, "Choice epsilon " * 5, "Choice zeta " * 6],
        location="Second Extremely Verbose Hallway Name",
    )
    state = GameState(
        hp=2,
        inventory=[
            "silver lantern",
            "ancient rope",
            "talking compass",
            "polished key",
            "tin whistle",
            "folded map",
        ],
        location="A location name that is intentionally long and winding",
        flags=["first long flag", "second long flag", "third long flag", "fourth flag"],
        turn_count=12,
        genre="cursed_dungeon",
        premise="A deliberately overstuffed premise about a cautious hero and a rude door.",
        recent_turns=[
            (long_turn_a, "The player chose a long careful action with extra words."),
            (long_turn_b, "The player then tried another wordy action."),
        ],
    )

    messages = build_messages(state)
    rendered = render_messages(messages)
    other_messages = build_messages(
        GameState(genre="cursed_dungeon", location="Elsewhere")
    )
    history_json = messages[1]["content"].split("History=", 1)[1].split(
        "\navoid_choices=",
        1,
    )[0]
    avoid_json = messages[1]["content"].split("avoid_choices=", 1)[1].split(
        "\nRespond",
        1,
    )[0]
    history = json.loads(history_json)
    avoid_choices = json.loads(avoid_json)

    assert len(rendered) <= 1450
    assert messages[0]["content"] == other_messages[0]["content"]
    assert "~" not in rendered
    assert history == [
        {
            "n": (
                "A long prior narration keeps talking without mercy "
                "A long prior narration keeps talking"
            ),
            "d": {"hp": 0, "loc": "Old Extremely"},
            "a": "The player chose a long careful action",
        },
        {
            "n": (
                "Another long prior narration tries to consume context "
                "Another long prior narration tries"
            ),
            "d": {"hp": 0, "loc": "Second Extremely"},
            "a": "The player then tried another wordy",
        },
    ]
    assert avoid_choices == [
        "Choice delta Choice delta Choice delta",
        "Choice epsilon Choice epsilon Choice",
        "Choice zeta Choice zeta Choice zeta",
    ]


def test_retry_then_bridge_path() -> None:
    state = GameState(genre="whispering_wood", location="Fern Gate")
    backend = MockBackend(["not json", {"narration": "missing required keys"}])

    result = next_turn(state, backend)

    assert result.used_bridge is True
    assert result.bridge is True
    assert len(result.raw_attempts) == 2
    assert backend.temperatures == [0.8, 0.95]
    assert result.turn in [
        bridge.model_copy(
            update={
                "state_delta": bridge.state_delta.model_copy(
                    update={"location": state.location}
                )
            }
        )
        for bridge in BRIDGE_TURNS["whispering_wood"]
    ]


def test_missing_remove_items_are_repaired_without_retry() -> None:
    state = GameState(inventory=["key"])
    backend = MockBackend([make_turn(remove_items=["missing"])])

    result = next_turn(state, backend)

    assert result.used_bridge is False
    assert result.turn.state_delta.remove_items == []
    assert len(result.raw_attempts) == 1
    assert backend.temperatures == [0.8]


def test_full_scripted_10_turn_mock_backend_game_reaches_ending() -> None:
    turns = [
        make_turn(
            narration=f"You survive scripted scene {number}. The path keeps moving.",
            choices=[
                f"Advance option {number}A",
                f"Inspect option {number}B",
                f"Rest option {number}C",
            ],
            location=f"Scripted Room {number}",
            is_ending=number == 10,
            ending_type="victory" if number == 10 else None,
        )
        for number in range(1, 11)
    ]
    state = GameState(genre="derelict_starship")
    backend = MockBackend(turns)

    for number in range(1, 11):
        result = next_turn(state, backend)
        assert result.used_bridge is False
        assert validate_turn(state, result.turn) == []
        state = apply_delta(state, result.turn)
        if result.turn.is_ending:
            break
        state = state.model_copy(
            update={
                "recent_turns": [
                    *state.recent_turns,
                    (result.turn, f"Advance option {number}A"),
                ][-2:]
            }
        )

    assert result.turn.is_ending is True
    assert result.turn.ending_type == "victory"
    assert state.turn_count == 10
