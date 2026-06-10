from __future__ import annotations


def next_turn_number(state: object) -> int:
    return int(getattr(state, "turn_count", 0)) + 1


def must_end_this_turn(state: object) -> bool:
    return next_turn_number(state) >= 15


def story_pressure(state: object) -> str:
    turn = next_turn_number(state)
    hp = int(getattr(state, "hp", 10))

    if turn <= 5:
        parts = ["Act 1: establish the quest, introduce danger."]
    elif turn <= 10:
        parts = ["Act 2: raise stakes, complicate."]
    elif turn <= 13:
        parts = ["Finale: move decisively toward the climax."]
    else:
        parts = [
            "This is the FINAL turn: set is_ending=true and ending_type, wrap the story."
        ]

    if hp <= 0:
        parts.append("HP is 0: demand a funny, not bleak, death ending.")
    elif hp <= 2:
        parts.append("HP low: the player is near death.")

    return " ".join(parts)
