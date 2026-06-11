from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Any

from eval.metrics import aggregate_metrics
from engine.prompt import build_messages
from engine.schema import Turn
from engine.state import GameState, apply_delta, validate_turn


def load_holdout(path: Path, sessions: int) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open() as handle:
        for line in handle:
            if line.strip():
                rows.append(json.loads(line))
    return rows[:sessions]


def play_sessions(
    *,
    model_path: Path,
    seeds_path: Path,
    sessions: int,
    grammar_path: Path,
) -> list[dict[str, Any]]:
    from llama_cpp import Llama, LlamaGrammar

    llm = Llama(model_path=str(model_path), n_ctx=2048, n_threads=2, verbose=False)
    grammar = LlamaGrammar.from_file(str(grammar_path))
    transcripts: list[dict[str, Any]] = []
    for seed in load_holdout(seeds_path, sessions):
        state = GameState(
            genre=str(seed.get("genre") or "cursed_dungeon"),
            premise=seed.get("premise"),
        )
        transcript = {
            "adventure_id": seed.get("adventure_id"),
            "genre": state.genre,
            "premise": state.premise,
            "turns": [],
        }
        for _ in range(15):
            prompt = render_prompt(build_messages(state))
            started = time.monotonic()
            grammar_free = llm(prompt, max_tokens=340, temperature=0.8, stop=["<|im_end|>"])
            constrained = llm(
                prompt,
                max_tokens=340,
                temperature=0.8,
                grammar=grammar,
                stop=["<|im_end|>"],
            )
            elapsed = time.monotonic() - started
            raw_free = grammar_free["choices"][0]["text"].strip()
            raw = constrained["choices"][0]["text"].strip()
            turn = Turn.model_validate_json(raw)
            errors = validate_turn(state, turn)
            used_bridge = bool(errors)
            transcript["turns"].append(
                {
                    "turn_json": turn.model_dump(mode="json"),
                    "raw": raw_free,
                    "grammar_raw": raw,
                    "used_bridge": used_bridge,
                    "tokens": constrained.get("usage", {}).get("completion_tokens", 0),
                    "wall_seconds": elapsed,
                    "validation_errors": errors,
                }
            )
            state = apply_delta(state, turn)
            if turn.is_ending:
                break
        transcripts.append(transcript)
    return transcripts


def render_prompt(messages: list[dict[str, str]]) -> str:
    return "\n".join(f"<|im_start|>{m['role']}\n{m['content']}<|im_end|>" for m in messages) + "\n<|im_start|>assistant\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True)
    parser.add_argument("--seeds", default="data/clean/holdout_seeds.jsonl")
    parser.add_argument("--sessions", type=int, default=50)
    parser.add_argument("--grammar", default="engine/grammar.gbnf")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    transcripts = play_sessions(
        model_path=Path(args.model),
        seeds_path=Path(args.seeds),
        sessions=args.sessions,
        grammar_path=Path(args.grammar),
    )
    result = {
        "model": args.model,
        "sessions": transcripts,
        "metrics": aggregate_metrics(transcripts),
    }
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(result, indent=2))
    print(json.dumps(result["metrics"], indent=2, sort_keys=True))
    print(f"wrote {out_path}")


if __name__ == "__main__":
    main()
