from __future__ import annotations

import json
import re
from typing import Any

from engine.pressure import must_end_this_turn, next_turn_number, story_pressure

GENRE_FLAVORS: dict[str, str] = {
    "cursed_dungeon": (
        "Genre: Cursed Dungeon. Dusty stone, old curses, hungry relics; eerie, "
        "brisk, and a little ridiculous."
    ),
    "whispering_wood": (
        "Genre: Whispering Wood. Talking roots, moonlit bargains, sly sprites; "
        "warm, strange, and gently dangerous."
    ),
    "derelict_starship": (
        "Genre: Derelict Starship. Failing bulkheads, rogue ship-AI, cold stars; "
        "tense, clever, and dryly comic."
    ),
}

_GENRE_ALIASES = {
    "dungeon": "cursed_dungeon",
    "cursed": "cursed_dungeon",
    "cursed_dungeon": "cursed_dungeon",
    "wood": "whispering_wood",
    "forest": "whispering_wood",
    "whispering_wood": "whispering_wood",
    "starship": "derelict_starship",
    "ship": "derelict_starship",
    "derelict_starship": "derelict_starship",
}

SYSTEM_BASE = (
    "You are PocketDM. Return only JSON keys narration, choices, state_delta, "
    "is_ending, ending_type. Narration: 2 short sentences. Choices: 3 actions. "
    "Legal deltas only. Never use avoid_choices. If must_end true, set "
    "is_ending true and ending_type. No absent-item removes, quotes, ellipsis, "
    "markdown, kill/blood/dead/drunk/snatch/snuff."
)

_TOKEN_RE = re.compile(r"[a-z0-9]+")


def build_messages(state: object) -> list[dict[str, str]]:
    return [
        {"role": "system", "content": stable_prefix(str(getattr(state, "genre")))},
        {"role": "user", "content": _dynamic_suffix(state)},
    ]


def stable_prefix(genre: str) -> str:
    key = canonical_genre(genre)
    return f"{SYSTEM_BASE}\n{GENRE_FLAVORS[key]}"


def canonical_genre(genre: str) -> str:
    slug = "_".join(_TOKEN_RE.findall(genre.casefold()))
    key = _GENRE_ALIASES.get(slug, slug)
    if key not in GENRE_FLAVORS:
        raise ValueError(f"unsupported genre: {genre}")
    return key


def _dynamic_suffix(state: object) -> str:
    summary: dict[str, Any] = {
        "hp": int(getattr(state, "hp", 10)),
        "inv": [_clip(item, 16) for item in list(getattr(state, "inventory", []))[:6]],
        "loc": _clip(str(getattr(state, "location", "")), 42),
        "flags": [_clip(flag, 16) for flag in list(getattr(state, "flags", []))[-4:]],
        "turn": next_turn_number(state),
        "must_end": must_end_this_turn(state),
        "pressure": story_pressure(state),
    }
    premise = getattr(state, "premise", None)
    if premise:
        summary["premise"] = _clip(str(premise), 70)

    recent_turns = list(getattr(state, "recent_turns", []))
    history = []
    avoid_choices = [
        _clip(choice, 42)
        for choice in (
            recent_turns[-1][0].choices
            if recent_turns
            else []
        )
    ]
    for turn, action in recent_turns[-2:]:
        history.append(
            {
                "n": _clip(_first_sentence(turn.narration), 90),
                "d": {
                    "hp": turn.state_delta.hp,
                    "loc": _clip(turn.state_delta.location, 18),
                },
                "a": _clip(action, 42),
            }
        )

    state_json = json.dumps(summary, ensure_ascii=True, separators=(",", ":"))
    history_json = json.dumps(history, ensure_ascii=True, separators=(",", ":"))
    avoid_json = json.dumps(avoid_choices, ensure_ascii=True, separators=(",", ":"))
    return (
        f"State={state_json}\nHistory={history_json}\n"
        f"avoid_choices={avoid_json}\nRespond with ONLY the turn JSON."
    )


def _first_sentence(text: str) -> str:
    for index, char in enumerate(text):
        if char in ".!?":
            return text[: index + 1]
    return text


def _clip(text: str, max_len: int) -> str:
    compact = " ".join(text.split())
    if len(compact) <= max_len:
        return compact
    if max_len <= 0:
        return ""

    clipped = compact[:max_len].rstrip()
    boundary = clipped.rfind(" ")
    if boundary > 0:
        return clipped[:boundary].rstrip()
    return clipped
