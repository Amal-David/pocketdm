from __future__ import annotations

import argparse
import json
import os
import time
from pathlib import Path
from typing import Any

from eval.metrics import aggregate_metrics
from engine.generate import TurnBackend, next_turn
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


def play_grammar_sessions(
    *,
    backend: TurnBackend,
    seeds: list[dict[str, Any]],
    max_turns: int = 15,
    progress: bool = False,
) -> list[dict[str, Any]]:
    transcripts: list[dict[str, Any]] = []
    for seed in seeds:
        state = GameState(
            genre=str(seed.get("genre") or "cursed_dungeon"),
            premise=seed.get("premise"),
        )
        transcript: dict[str, Any] = {
            "adventure_id": seed.get("adventure_id"),
            "genre": state.genre,
            "premise": state.premise,
            "seed": seed.get("seed"),
            "turns": [],
        }
        seed_value = int(seed.get("seed") or 0)
        for turn_index in range(max_turns):
            started = time.monotonic()
            result = next_turn(state, backend)
            elapsed = time.monotonic() - started
            turn = result.turn
            action_taken = None if turn.is_ending else choose_action(turn, seed_value, turn_index)
            raw_attempts = result.raw_attempts
            transcript["turns"].append(
                {
                    "turn_json": turn.model_dump(mode="json"),
                    "raw": raw_attempts[-1] if raw_attempts else "",
                    "grammar_raw": raw_attempts[-1] if raw_attempts else "",
                    "raw_attempts": raw_attempts,
                    "raw_schema_failures": count_raw_schema_failures(raw_attempts),
                    "action_taken": action_taken,
                    "used_bridge": result.used_bridge,
                    "tokens": _completion_tokens(raw_attempts[-1] if raw_attempts else ""),
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
            print(json.dumps(session_progress(transcript, len(transcripts)), sort_keys=True), flush=True)
    return transcripts


def play_model_sessions(
    *,
    model_path: Path,
    seeds_path: Path,
    sessions: int,
    grammar_path: Path,
    threads: int,
    gpu_layers: int,
    seed: int,
    max_turns: int,
    progress: bool,
) -> list[dict[str, Any]]:
    seeds = load_holdout(seeds_path, sessions)
    backend = LlamaCppGrammarBackend(
        model_path=model_path,
        grammar_path=grammar_path,
        threads=threads,
        gpu_layers=gpu_layers,
        seed=seed,
    )
    return play_grammar_sessions(
        backend=backend,
        seeds=seeds,
        max_turns=max_turns,
        progress=progress,
    )


class LlamaCppGrammarBackend:
    def __init__(
        self,
        *,
        model_path: Path,
        grammar_path: Path,
        threads: int,
        gpu_layers: int,
        seed: int,
    ) -> None:
        from llama_cpp import Llama, LlamaGrammar

        self.llm = Llama(
            model_path=str(model_path),
            n_ctx=2048,
            n_threads=threads,
            n_gpu_layers=gpu_layers,
            seed=seed,
            verbose=False,
        )
        self.grammar = LlamaGrammar.from_file(str(grammar_path))

    def complete(self, messages: list[dict[str, str]], *, temperature: float) -> str:
        response = self.llm(
            render_prompt(messages),
            max_tokens=340,
            temperature=temperature,
            grammar=self.grammar,
            stop=["<|im_end|>"],
        )
        return str(response["choices"][0]["text"]).strip()


def summarize_gate(
    sessions: list[dict[str, Any]],
    *,
    required_sessions: int,
    max_bridge_turns: int = 0,
) -> dict[str, Any]:
    completed_sessions = 0
    grammar_clean_sessions = 0
    bridge_turns = 0
    raw_schema_failures = 0
    retry_turns = 0
    total_turns = 0

    for session in sessions:
        turns = list(session.get("turns") or [])
        total_turns += len(turns)
        session_bridge_turns = sum(1 for record in turns if record.get("used_bridge"))
        session_schema_failures = sum(int(record.get("raw_schema_failures") or 0) for record in turns)
        session_retry_turns = sum(1 for record in turns if len(record.get("raw_attempts") or []) > 1)
        bridge_turns += session_bridge_turns
        raw_schema_failures += session_schema_failures
        retry_turns += session_retry_turns
        completed = bool(turns and (turns[-1].get("turn_json") or {}).get("is_ending"))
        if completed:
            completed_sessions += 1
        if completed and session_bridge_turns == 0 and session_schema_failures == 0:
            grammar_clean_sessions += 1

    passed = (
        len(sessions) == required_sessions
        and completed_sessions == required_sessions
        and grammar_clean_sessions == required_sessions
        and bridge_turns <= max_bridge_turns
        and raw_schema_failures == 0
    )
    return {
        "required_sessions": required_sessions,
        "sessions": len(sessions),
        "completed_sessions": completed_sessions,
        "grammar_clean_sessions": grammar_clean_sessions,
        "bridge_turns": bridge_turns,
        "max_bridge_turns": max_bridge_turns,
        "raw_schema_failures": raw_schema_failures,
        "retry_turns": retry_turns,
        "turns": total_turns,
        "passed": passed,
    }


def session_progress(transcript: dict[str, Any], session_number: int) -> dict[str, Any]:
    turns = list(transcript.get("turns") or [])
    return {
        "session": session_number,
        "adventure_id": transcript.get("adventure_id"),
        "turns": len(turns),
        "ending": bool(turns and (turns[-1].get("turn_json") or {}).get("is_ending")),
        "bridge_turns": sum(1 for record in turns if record.get("used_bridge")),
        "raw_schema_failures": sum(int(record.get("raw_schema_failures") or 0) for record in turns),
    }


def count_raw_schema_failures(raw_attempts: list[str]) -> int:
    failures = 0
    for raw in raw_attempts:
        try:
            Turn.model_validate_json(raw)
        except Exception:
            failures += 1
    return failures


def choose_action(turn: Turn, seed: int, turn_index: int) -> str:
    return turn.choices[(seed + turn_index) % len(turn.choices)]


def render_prompt(messages: list[dict[str, str]]) -> str:
    return (
        "\n".join(f"<|im_start|>{m['role']}\n{m['content']}<|im_end|>" for m in messages)
        + "\n<|im_start|>assistant\n"
    )


def _completion_tokens(text: str) -> int:
    return max(0, len(text.split()))


def main() -> None:
    parser = argparse.ArgumentParser(
        description="Run grammar-constrained PocketDM sessions against a local GGUF."
    )
    parser.add_argument("--model", required=True)
    parser.add_argument("--seeds", default="data/clean/holdout_seeds.jsonl")
    parser.add_argument("--sessions", type=int, default=50)
    parser.add_argument("--grammar", default="engine/grammar.gbnf")
    parser.add_argument("--threads", type=int, default=int(os.environ.get("POCKETDM_LLAMA_THREADS", "2")))
    parser.add_argument("--gpu-layers", type=int, default=int(os.environ.get("POCKETDM_LLAMA_GPU_LAYERS", "0")))
    parser.add_argument("--seed", type=int, default=3407)
    parser.add_argument("--max-turns", type=int, default=15)
    parser.add_argument("--max-bridge-turns", type=int, default=0)
    parser.add_argument("--progress", action="store_true")
    parser.add_argument("--require-clean", action="store_true")
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    model_path = Path(args.model)
    if not model_path.exists():
        raise SystemExit(f"missing model: {model_path}")

    transcripts = play_model_sessions(
        model_path=model_path,
        seeds_path=Path(args.seeds),
        sessions=args.sessions,
        grammar_path=Path(args.grammar),
        threads=args.threads,
        gpu_layers=args.gpu_layers,
        seed=args.seed,
        max_turns=args.max_turns,
        progress=args.progress,
    )
    gate = summarize_gate(
        transcripts,
        required_sessions=args.sessions,
        max_bridge_turns=args.max_bridge_turns,
    )
    result = {
        "model": str(model_path),
        "seeds": args.seeds,
        "grammar": args.grammar,
        "seed": args.seed,
        "max_turns": args.max_turns,
        "sessions": transcripts,
        "metrics": aggregate_metrics(transcripts),
        "gate": gate,
    }
    out_path = Path(args.out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(result, indent=2))
    print(json.dumps(gate, indent=2, sort_keys=True))
    print(f"wrote {out_path}")

    if args.require_clean and not gate["passed"]:
        raise SystemExit("grammar session gate failed")


if __name__ == "__main__":
    main()
