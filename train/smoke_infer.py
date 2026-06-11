from __future__ import annotations

import argparse
import json
from pathlib import Path

from engine.prompt import build_messages
from engine.schema import Turn
from engine.state import GameState, apply_delta, validate_turn


def run_smoke(model: Path, *, grammar: Path, turns: int, seed: int) -> list[Turn]:
    from llama_cpp import Llama, LlamaGrammar

    llm = Llama(
        model_path=str(model),
        n_ctx=2048,
        n_threads=2,
        seed=seed,
        verbose=False,
    )
    grammar_obj = LlamaGrammar.from_file(str(grammar))
    state = GameState(genre="cursed_dungeon", premise="A suspicious spoon hums.")
    emitted: list[Turn] = []
    for _ in range(turns):
        prompt = render_prompt(build_messages(state))
        response = llm(
            prompt,
            max_tokens=340,
            temperature=0.8,
            grammar=grammar_obj,
            stop=["<|im_end|>"],
        )
        raw = response["choices"][0]["text"].strip()
        turn = Turn.model_validate_json(raw)
        errors = validate_turn(state, turn)
        if errors:
            raise RuntimeError(f"invalid turn from model: {errors}; raw={raw}")
        emitted.append(turn)
        state = apply_delta(state, turn)
        if turn.is_ending:
            break
    return emitted


def render_prompt(messages: list[dict[str, str]]) -> str:
    return "\n".join(f"<|im_start|>{m['role']}\n{m['content']}<|im_end|>" for m in messages) + "\n<|im_start|>assistant\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", default="models/pocketdm-2b-Q4_K_M.gguf")
    parser.add_argument("--grammar", default="engine/grammar.gbnf")
    parser.add_argument("--turns", type=int, default=3)
    parser.add_argument("--seed", type=int, default=3407)
    args = parser.parse_args()

    model = Path(args.model)
    grammar = Path(args.grammar)
    if not model.exists():
        raise SystemExit(f"missing model: {model}")
    emitted = run_smoke(model, grammar=grammar, turns=args.turns, seed=args.seed)
    for index, turn in enumerate(emitted, start=1):
        print(f"TURN {index}")
        print(json.dumps(turn.model_dump(mode="json"), indent=2))


if __name__ == "__main__":
    main()
