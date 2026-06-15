from __future__ import annotations

from typing import Sequence

from data.filters import (
    ADV_GATE_DROPPED,
    ADV_GATE_ENDING,
    ADV_GATE_MIN_TURNS,
    GATE_CHOICES_DISTINCT,
    GATE_DELTA_LEGAL,
    GATE_NARRATION_LENGTH,
    GATE_NO_REPEAT,
    GATE_PROFANITY,
    GATE_SCHEMA,
    GATE_SENTENCES,
    FilterConfig,
    choice_repeats_previous,
    filter_adventure,
    filter_turn,
    sentence_count,
)
from engine.schema import StateDelta, Turn
from engine.state import GameState


class FakeEncoder:
    def __init__(self, vectors: dict[str, list[float]] | None = None) -> None:
        self.vectors = vectors or {}

    def encode(self, texts: Sequence[str]) -> Sequence[Sequence[float]]:
        fallback = {
            0: [1.0, 0.0, 0.0],
            1: [0.0, 1.0, 0.0],
            2: [0.0, 0.0, 1.0],
        }
        return [self.vectors.get(text, fallback[index % 3]) for index, text in enumerate(texts)]


class FakeProfanityChecker:
    def __init__(self, banned: str = "crud") -> None:
        self.banned = banned

    def contains_profanity(self, text: str) -> bool:
        return self.banned in text.casefold()


def make_turn(
    *,
    narration: str = "You enter the chamber. A brass lever hums beside the door.",
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
        choices=choices or ["Pull the lever", "Read the plaque", "Open the door"],
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


def turn_record(turn: Turn | dict[str, object]) -> dict[str, object]:
    payload = turn.model_dump(mode="json") if isinstance(turn, Turn) else turn
    return {
        "state_summary": {},
        "messages": [{"role": "user", "content": "State={}"}],
        "turn_json": payload,
        "action_taken": "Pull the lever",
    }


def bridge_record(turn: Turn) -> dict[str, object]:
    record = turn_record(turn)
    record["used_bridge"] = True
    return record


def test_sentence_count_uses_terminal_punctuation() -> None:
    assert sentence_count("One. Two! Three?") == 3
    assert sentence_count("No terminal punctuation") == 1
    assert sentence_count("The glade shivers—roots unfurl beneath your feet.") == 1


def test_schema_gate_rejects_missing_required_fields() -> None:
    result = filter_turn(
        {"turn_json": {"narration": "Only a narration. Still incomplete."}},
        state=GameState(),
        previous_turn=None,
        encoder=FakeEncoder(),
        profanity_checker=FakeProfanityChecker(),
    )

    assert GATE_SCHEMA in result.failures
    assert result.parsed_turn is None


def test_narration_sentence_gate_requires_two_to_four_sentences() -> None:
    turn = make_turn(narration="Only one sentence.")

    result = filter_turn(
        turn_record(turn),
        state=GameState(),
        previous_turn=None,
        encoder=FakeEncoder(),
        profanity_checker=FakeProfanityChecker(),
    )

    assert GATE_SENTENCES in result.failures


def test_choice_embedding_gate_rejects_semantically_duplicate_choices() -> None:
    choices = ["Open the door", "Open that door", "Read the plaque"]
    encoder = FakeEncoder(
        {
            "Open the door": [1.0, 0.0],
            "Open that door": [1.0, 0.0],
            "Read the plaque": [0.0, 1.0],
        }
    )

    result = filter_turn(
        turn_record(make_turn(choices=choices)),
        state=GameState(),
        previous_turn=None,
        encoder=encoder,
        profanity_checker=FakeProfanityChecker(),
    )

    assert GATE_CHOICES_DISTINCT in result.failures


def test_previous_choice_repeat_gate_rejects_verbatim_repeat() -> None:
    previous = make_turn(choices=["Open the door", "Check the lock", "Light the lamp"])
    current = make_turn(choices=["Open the door", "Ask the statue", "Take the key"])

    assert choice_repeats_previous(current.choices, previous)

    result = filter_turn(
        turn_record(current),
        state=GameState(),
        previous_turn=previous,
        encoder=FakeEncoder(),
        profanity_checker=FakeProfanityChecker(),
    )

    assert GATE_NO_REPEAT in result.failures


def test_delta_legal_gate_rejects_removing_missing_inventory() -> None:
    turn = make_turn(remove_items=["silver key"])

    result = filter_turn(
        turn_record(turn),
        state=GameState(inventory=[]),
        previous_turn=None,
        encoder=FakeEncoder(),
        profanity_checker=FakeProfanityChecker(),
    )

    assert GATE_DELTA_LEGAL in result.failures


def test_profanity_gate_checks_narration_and_choices() -> None:
    turn = make_turn(narration="You enter the chamber. A crud sigil glows.")

    result = filter_turn(
        turn_record(turn),
        state=GameState(),
        previous_turn=None,
        encoder=FakeEncoder(),
        profanity_checker=FakeProfanityChecker(),
    )

    assert GATE_PROFANITY in result.failures


def test_narration_length_gate_rejects_over_600_chars() -> None:
    payload = make_turn().model_dump(mode="json")
    payload["narration"] = ("Long sentence. " * 60).strip()

    result = filter_turn(
        turn_record(payload),
        state=GameState(),
        previous_turn=None,
        encoder=FakeEncoder(),
        profanity_checker=FakeProfanityChecker(),
    )

    assert GATE_NARRATION_LENGTH in result.failures


def test_adventure_gate_accepts_real_ending_after_six_turns() -> None:
    turns = [
        turn_record(
            make_turn(
                narration=f"You cross chamber {index}. The exit keeps moving.",
                choices=[
                    f"Advance {index}A",
                    f"Search {index}B",
                    f"Rest {index}C",
                ],
                location=f"Room {index}",
                is_ending=index == 6,
                ending_type="victory" if index == 6 else None,
            )
        )
        for index in range(1, 7)
    ]
    adventure = {
        "adventure_id": "adv-test",
        "genre": "cursed_dungeon",
        "premise": None,
        "persona": "greedy",
        "seed": 1,
        "turns": turns,
    }

    result = filter_adventure(
        adventure,
        encoder=FakeEncoder(),
        profanity_checker=FakeProfanityChecker(),
    )

    assert result.passed is True
    assert result.adventure_gate_passes[ADV_GATE_ENDING] == 1
    assert result.adventure_gate_passes[ADV_GATE_MIN_TURNS] == 1
    assert result.adventure_gate_passes[ADV_GATE_DROPPED] == 1


def test_adventure_gate_drops_cap_forced_only_ending() -> None:
    turns = [
        turn_record(
            make_turn(
                narration=f"You cross chamber {index}. The exit keeps moving.",
                choices=[
                    f"Advance {index}A",
                    f"Search {index}B",
                    f"Rest {index}C",
                ],
                location=f"Room {index}",
                is_ending=index == 15,
                ending_type="victory" if index == 15 else None,
            )
        )
        for index in range(1, 16)
    ]
    adventure = {
        "adventure_id": "adv-cap",
        "genre": "cursed_dungeon",
        "premise": None,
        "persona": "greedy",
        "seed": 1,
        "turns": turns,
    }

    result = filter_adventure(
        adventure,
        encoder=FakeEncoder(),
        profanity_checker=FakeProfanityChecker(),
    )

    assert result.passed is False
    assert result.adventure_gate_passes[ADV_GATE_ENDING] == 0


def test_adventure_gate_limits_dropped_turns() -> None:
    valid = [
        turn_record(
            make_turn(
                narration=f"You cross chamber {index}. The exit keeps moving.",
                choices=[
                    f"Advance {index}A",
                    f"Search {index}B",
                    f"Rest {index}C",
                ],
                location=f"Room {index}",
                is_ending=index == 6,
                ending_type="victory" if index == 6 else None,
            )
        )
        for index in range(1, 7)
    ]
    invalid = [
        {"turn_json": {"narration": "Broken. Missing fields."}},
        {"turn_json": {"narration": "Still broken. Missing fields."}},
    ]
    adventure = {
        "adventure_id": "adv-drops",
        "genre": "cursed_dungeon",
        "premise": None,
        "persona": "greedy",
        "seed": 1,
        "turns": [valid[0], *invalid, *valid[1:]],
    }

    result = filter_adventure(
        adventure,
        encoder=FakeEncoder(),
        profanity_checker=FakeProfanityChecker(),
        config=FilterConfig(max_dropped_turns=1),
    )

    assert result.passed is False
    assert result.dropped_turns == 2
    assert result.adventure_gate_passes[ADV_GATE_DROPPED] == 0


def test_bridge_turn_is_dropped_but_keeps_state_history_aligned() -> None:
    bridge = make_turn(
        narration="Mist covers the stalled moment. A safer path opens.",
        choices=["Cross the mist", "Mark the stone", "Ask the silence"],
        location="Bridge Room",
    )
    clean_turns = [
        turn_record(
            make_turn(
                narration=f"You cross chamber {index}. The exit keeps moving.",
                choices=[
                    f"Advance {index}A",
                    f"Search {index}B",
                    f"Rest {index}C",
                ],
                location=f"Room {index}",
                is_ending=index == 6,
                ending_type="victory" if index == 6 else None,
            )
        )
        for index in range(1, 7)
    ]
    adventure = {
        "adventure_id": "adv-bridge",
        "genre": "cursed_dungeon",
        "premise": None,
        "persona": "curious",
        "seed": 3,
        "turns": [clean_turns[0], bridge_record(bridge), *clean_turns[1:]],
    }

    result = filter_adventure(
        adventure,
        encoder=FakeEncoder(),
        profanity_checker=FakeProfanityChecker(),
        config=FilterConfig(max_dropped_turns=1),
    )

    assert result.passed is True
    assert result.clean_turns == 6
    assert result.dropped_turns == 1
    assert result.bridge_turns == 1
    assert result.adventure is not None
    assert len(result.adventure["turns"]) == 6
