from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Any

from eval.metrics import aggregate_metrics
from engine.generate import next_turn
from engine.prompt import build_messages
from engine.schema import Turn
from engine.state import GameState, apply_delta


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
    threads: int,
    gpu_layers: int,
    progress: bool,
) -> list[dict[str, Any]]:
    from llama_cpp import Llama, LlamaGrammar

    llm = Llama(
        model_path=str(model_path),
        n_ctx=2048,
        n_threads=threads,
        n_gpu_layers=gpu_layers,
        verbose=False,
    )
    grammar = LlamaGrammar.from_file(str(grammar_path))
    backend = EvalLlamaBackend(llm, grammar)
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
        seed_value = int(seed.get("seed") or 0)
        for turn_index in range(15):
            prompt = render_prompt(build_messages(state))
            started = time.monotonic()
            grammar_free = llm(prompt, max_tokens=340, temperature=0.8, stop=["<|im_end|>"])
            result = next_turn(state, backend)
            elapsed = time.monotonic() - started
            raw_free = grammar_free["choices"][0]["text"].strip()
            turn = result.turn
            action_taken = None if turn.is_ending else choose_action(turn, seed_value, turn_index)
            transcript["turns"].append(
                {
                    "turn_json": turn.model_dump(mode="json"),
                    "raw": raw_free,
                    "grammar_raw": result.raw_attempts[-1] if result.raw_attempts else "",
                    "raw_attempts": result.raw_attempts,
                    "action_taken": action_taken,
                    "used_bridge": result.used_bridge,
                    "tokens": _completion_tokens(result.raw_attempts[-1] if result.raw_attempts else ""),
                    "wall_seconds": elapsed,
                    "validation_errors": ["bridge_after_retries"] if result.used_bridge else [],
                }
            )
            updated_state = apply_delta(state, turn)
            if action_taken:
                updated_state = updated_state.model_copy(
                    update={
                        "recent_turns": [
                            *updated_state.recent_turns,
                            (turn, action_taken),
                        ][-2:]
                    }
                )
            state = updated_state
            if turn.is_ending:
                break
        transcripts.append(transcript)
        if progress:
            print(
                json.dumps(
                    {
                        "session": len(transcripts),
                        "adventure_id": transcript.get("adventure_id"),
                        "turns": len(transcript["turns"]),
                        "ending": bool(
                            transcript["turns"]
                            and transcript["turns"][-1]["turn_json"].get("is_ending")
                        ),
                    },
                    sort_keys=True,
                ),
                flush=True,
            )
    return transcripts


class EvalLlamaBackend:
    def __init__(self, llm: object, grammar: object) -> None:
        self.llm = llm
        self.grammar = grammar

    def complete(self, messages: list[dict[str, str]], *, temperature: float) -> str:
        response = self.llm(
            render_prompt(messages),
            max_tokens=340,
            temperature=temperature,
            grammar=self.grammar,
            stop=["<|im_end|>"],
        )
        return str(response["choices"][0]["text"]).strip()


def choose_action(turn: Turn, seed: int, turn_index: int) -> str:
    return turn.choices[(seed + turn_index) % len(turn.choices)]


def _completion_tokens(text: str) -> int:
    return max(0, len(text.split()))


def render_prompt(messages: list[dict[str, str]]) -> str:
    return "\n".join(f"<|im_start|>{m['role']}\n{m['content']}<|im_end|>" for m in messages) + "\n<|im_start|>assistant\n"


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", required=True)
    parser.add_argument("--seeds", default="data/clean/holdout_seeds.jsonl")
    parser.add_argument("--sessions", type=int, default=50)
    parser.add_argument("--grammar", default="engine/grammar.gbnf")
    parser.add_argument("--threads", type=int, default=2)
    parser.add_argument("--gpu-layers", type=int, default=0)
    parser.add_argument("--progress", action="store_true")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    transcripts = play_sessions(
        model_path=Path(args.model),
        seeds_path=Path(args.seeds),
        sessions=args.sessions,
        grammar_path=Path(args.grammar),
        threads=args.threads,
        gpu_layers=args.gpu_layers,
        progress=args.progress,
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
