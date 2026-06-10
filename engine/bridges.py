from __future__ import annotations

from engine.pressure import must_end_this_turn
from engine.prompt import canonical_genre
from engine.schema import StateDelta, Turn


def _turn(
    narration: str,
    choices: list[str],
    location: str,
    *,
    is_ending: bool = False,
    ending_type: str | None = None,
) -> Turn:
    return Turn(
        narration=narration,
        choices=choices,
        state_delta=StateDelta(
            hp=0,
            add_items=[],
            remove_items=[],
            location=location,
            add_flags=[],
        ),
        is_ending=is_ending,
        ending_type=ending_type,
    )


BRIDGE_TURNS: dict[str, tuple[Turn, Turn, Turn]] = {
    "cursed_dungeon": (
        _turn(
            "A curtain of grey mist rolls between you and the trouble. For one breath, the dungeon gives you room to choose.",
            ["Step through the mist", "Check the cracked wall", "Tell the curse to wait"],
            "Fogged Hall",
        ),
        _turn(
            "The torches gutter in a pattern that almost seems helpful. Somewhere nearby, stone teeth politely grind shut.",
            ["Follow the torchlight", "Listen at the floor", "Hold perfectly still"],
            "Guttering Passage",
        ),
        _turn(
            "A dusty omen lands at your feet and refuses to explain itself. The silence feels staged.",
            ["Pocket the omen", "Question the silence", "Move before it notices"],
            "Omen Step",
        ),
    ),
    "whispering_wood": (
        _turn(
            "The path folds under a lace of leaves and pretends it was always there. The trees whisper encouragement with suspicious timing.",
            ["Follow the new path", "Ask the oldest oak", "Leave a tiny offering"],
            "Leaflace Path",
        ),
        _turn(
            "Moonmoths drift around you like floating punctuation. A root taps three patient beats against the soil.",
            ["Follow the moths", "Tap back on the root", "Search the fern shade"],
            "Moonmoth Bend",
        ),
        _turn(
            "A brook giggles over stones that look recently rearranged. The wood is clearly trying to look innocent.",
            ["Cross the brook", "Inspect the stones", "Compliment the forest"],
            "Giggling Brook",
        ),
    ),
    "derelict_starship": (
        _turn(
            "Emergency lights blink in a rhythm no manual would approve. The deck hums as if remembering better decisions.",
            ["Cycle the bulkhead", "Scan the deck plates", "Question the alert"],
            "Amber Corridor",
        ),
        _turn(
            "A maintenance panel pops open with theatrical timing. Inside, three wires sparkle like they have opinions.",
            ["Trace the blue wire", "Reseat the panel", "Ask the ship nicely"],
            "Service Junction",
        ),
        _turn(
            "The ship-AI clears its speaker with a burst of static. It says nothing, which is somehow more insulting.",
            ["Check the speaker", "Proceed in silence", "Run a quick diagnostic"],
            "Static Junction",
        ),
    ),
}

FORCED_ENDINGS: dict[str, Turn] = {
    "cursed_dungeon": _turn(
        "The dungeon exhales, and every curse chooses the same exit sign. You escape changed, dusty, and reasonably certain the door winked.",
        ["Take the last step", "Bow to the stones", "Promise not to return"],
        "Dungeon Threshold",
        is_ending=True,
        ending_type="bittersweet",
    ),
    "whispering_wood": _turn(
        "The wood parts at dawn, keeping only the shadow it fairly won. You leave with birdsong in your pockets and questions in your boots.",
        ["Step into sunrise", "Thank the branches", "Name the road home"],
        "Dawn Verge",
        is_ending=True,
        ending_type="bittersweet",
    ),
    "derelict_starship": _turn(
        "The final hatch opens onto cold starlight and a shuttle that mostly believes in you. The ship powers down like it is trying to be dignified.",
        ["Launch the shuttle", "Salute the console", "Save the flight log"],
        "Escape Shuttle",
        is_ending=True,
        ending_type="bittersweet",
    ),
}

DEATH_ENDINGS: dict[str, Turn] = {
    "cursed_dungeon": _turn(
        "The trap wins, but only after slipping on its own dramatic cape. Your legend ends as dungeon safety training for future fools.",
        ["Haunt the trap", "Demand a plaque", "Rattle one last chain"],
        "Final Pit",
        is_ending=True,
        ending_type="death",
    ),
    "whispering_wood": _turn(
        "The forest claims you softly, then assigns a squirrel to manage your estate. It is a terrible accountant but a loyal mourner.",
        ["Accept the acorn crown", "Haunt the footpath", "Correct the squirrel"],
        "Mossy Rest",
        is_ending=True,
        ending_type="death",
    ),
    "derelict_starship": _turn(
        "Your suit gives up with a beep that sounds apologetic and slightly smug. The ship files your ending under heroic maintenance incident.",
        ["Become a cautionary log", "Haunt the airlock", "Blame the manual"],
        "Silent Airlock",
        is_ending=True,
        ending_type="death",
    ),
}


def bridge_turn(state: object) -> Turn:
    key = canonical_genre(str(getattr(state, "genre")))
    location = str(getattr(state, "location", "")) or "Bridge"

    if int(getattr(state, "hp", 10)) <= 0:
        return _with_location(DEATH_ENDINGS[key], location)
    if must_end_this_turn(state):
        return _with_location(FORCED_ENDINGS[key], location)

    bridges = BRIDGE_TURNS[key]
    index = int(getattr(state, "turn_count", 0)) % len(bridges)
    return _with_location(bridges[index], location)


def _with_location(turn: Turn, location: str) -> Turn:
    delta = turn.state_delta.model_copy(update={"location": location})
    return turn.model_copy(update={"state_delta": delta})
