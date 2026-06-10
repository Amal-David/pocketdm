from __future__ import annotations

import argparse
import os
from typing import Sequence

from engine.generate import MockBackend, TurnBackend, next_turn
from engine.schema import StateDelta, Turn
from engine.state import GameState, apply_delta


class OpenAIBackend:
    def __init__(self, *, base_url: str, model: str) -> None:
        try:
            from openai import OpenAI
        except ImportError as exc:
            raise SystemExit(
                "Install the repl dependency group to use --backend openai."
            ) from exc

        self._client = OpenAI(
            base_url=base_url,
            api_key=os.environ.get("POCKETDM_API_KEY", "not-needed"),
        )
        self._model = model

    def complete(self, messages: list[dict[str, str]], *, temperature: float) -> str:
        response = self._client.chat.completions.create(
            model=self._model,
            messages=messages,
            temperature=temperature,
        )
        content = response.choices[0].message.content
        if content is None:
            raise ValueError("OpenAI-compatible backend returned no content")
        return content


def main(argv: Sequence[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Play PocketDM in the terminal.")
    parser.add_argument(
        "--genre",
        default="cursed_dungeon",
        choices=["cursed_dungeon", "whispering_wood", "derelict_starship"],
    )
    parser.add_argument("--premise")
    parser.add_argument("--backend", default="mock", choices=["mock", "openai"])
    args = parser.parse_args(argv)

    backend = _backend(args.backend)
    state = GameState(genre=args.genre, premise=args.premise)

    while True:
        result = next_turn(state, backend)
        turn = result.turn
        state = apply_delta(state, turn)
        _render_turn(state, turn, result.used_bridge)

        if turn.is_ending:
            print(f"\nEnding: {turn.ending_type}")
            return 0

        chosen_action = _read_action(turn.choices)
        state = state.model_copy(
            update={"recent_turns": [*state.recent_turns, (turn, chosen_action)][-2:]}
        )


def _backend(name: str) -> TurnBackend:
    if name == "mock":
        return MockBackend(_mock_script())

    base_url = os.environ.get("POCKETDM_BASE_URL")
    model = os.environ.get("POCKETDM_MODEL")
    if not base_url or not model:
        raise SystemExit("Set POCKETDM_BASE_URL and POCKETDM_MODEL for --backend openai.")
    return OpenAIBackend(base_url=base_url, model=model)


def _render_turn(state: GameState, turn: Turn, used_bridge: bool) -> None:
    bridge_note = " [bridge]" if used_bridge else ""
    print(f"\n{turn.narration}{bridge_note}")
    for index, choice in enumerate(turn.choices, start=1):
        print(f"{index}. {choice}")
    inventory = ", ".join(state.inventory) if state.inventory else "-"
    print(f"HP {state.hp}/10 | Inventory: {inventory} | Location: {state.location}")


def _read_action(choices: list[str]) -> str:
    raw = input("> ").strip()
    if raw in {"1", "2", "3"}:
        return choices[int(raw) - 1]
    return raw or choices[0]


def _mock_script() -> list[Turn]:
    turns: list[Turn] = []
    for number in range(1, 10):
        turns.append(
            _mock_turn(
                f"You advance through mock danger number {number}. The adventure stays neatly on rails.",
                [
                    f"Mock choice {number}A",
                    f"Mock choice {number}B",
                    f"Mock choice {number}C",
                ],
                f"Mock Room {number}",
            )
        )
    turns.append(
        _mock_turn(
            "You reach the final mock door and it opens with excellent test coverage. The tiny adventure ends cleanly.",
            ["Celebrate carefully", "Record the tale", "Close the door"],
            "Mock Exit",
            is_ending=True,
            ending_type="victory",
        )
    )
    return turns


def _mock_turn(
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


if __name__ == "__main__":
    raise SystemExit(main())
