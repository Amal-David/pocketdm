from __future__ import annotations

import json
import math
import random
import re
import time
from dataclasses import dataclass, field
from datetime import date
from pathlib import Path
from typing import Any, Iterable

import modal

from engine.generate import DEFAULT_TEMPERATURE
from engine.prompt import GENRE_FLAVORS, build_messages
from engine.schema import Turn
from engine.state import GameState, apply_delta, validate_turn

MODEL_ID = "Qwen/Qwen3-32B"
CACHE_DIR = "/cache"
HF_HOME = f"{CACHE_DIR}/huggingface"
DEFAULT_WAVE_SIZE = 64
MAX_TURNS = 15
H100_RATE_PER_HOUR = 3.95
A100_80GB_RATE_PER_HOUR = 2.50

app = modal.App("pocketdm-wp3-teacher")
hf_cache = modal.Volume.from_name("pocketdm-hf-cache", create_if_missing=True)

teacher_image = (
    modal.Image.from_registry("vllm/vllm-openai:v0.10.2")
    .pip_install(
        "pydantic>=2",
        "transformers>=4.51.0",
        "xgrammar>=0.1.18",
        "sentencepiece>=0.2.0",
        "huggingface-hub[hf_transfer]>=0.30.0",
    )
    .env(
        {
            "HF_HOME": HF_HOME,
            "HF_HUB_ENABLE_HF_TRANSFER": "1",
            "VLLM_ATTENTION_BACKEND": "FLASH_ATTN",
        }
    )
    .add_local_python_source("engine")
)

GENRES = tuple(GENRE_FLAVORS.keys())
PERSONAS = ("greedy", "curious", "chaotic")

PREMISE_TEMPLATES: dict[str, tuple[str, ...]] = {
    "cursed_dungeon": (
        "A polite skeleton insists the treasure chest is his apartment.",
        "The dungeon rearranges itself whenever someone sneezes.",
        "A cursed soup ladle points toward the missing monarch.",
        "Every locked door asks a riddle about breakfast.",
        "A choir of trapped helmets hums whenever danger is near.",
        "The floor tiles are trying to elect a new hero.",
        "A dragon has outsourced guarding its hoard to interns.",
        "A wizard's shopping list is carved into the tomb wall.",
        "The magic torch only burns when complimented sincerely.",
        "A goblet keeps predicting minor inconveniences with flair.",
        "The dungeon map is accurate except for one jealous room.",
        "A mimic wants career advice before it opens.",
        "A sleepy curse turns brave speeches into limericks.",
        "The oldest trap in the dungeon is embarrassed by modern traps.",
        "A lost lunchbox contains the key to a royal vault.",
    ),
    "whispering_wood": (
        "The moonlit mushrooms are holding a tiny court case.",
        "A forgetful dryad has misplaced the path home.",
        "The river will answer one question, but only in gossip.",
        "Every acorn in the grove claims to be royalty.",
        "A fox with spectacles sells maps that argue back.",
        "The trees whisper prophecies about a missing teacup.",
        "A cloud of fireflies forms arrows toward bad decisions.",
        "The oldest root wants a bedtime story before helping.",
        "A sprite orchestra is tuning up for a dangerous waltz.",
        "The forest gate opens only for someone carrying a joke.",
        "A mossy statue keeps trading secrets for buttons.",
        "A runaway shadow hides inside a ring of blue flowers.",
        "The thorn hedge is allergic to lies and dramatic pauses.",
        "A talking owl has forgotten which quest it assigned.",
        "The dawn path appears only to travelers who share snacks.",
    ),
    "derelict_starship": (
        "The ship AI has become obsessed with antique doorbells.",
        "A vending machine claims command of the bridge.",
        "The reactor sings sea shanties when it overheats.",
        "A maintenance drone mistakes the hero for its supervisor.",
        "Every airlock sign has been translated into sarcasm.",
        "The captain's chair refuses to rotate without applause.",
        "A distress beacon broadcasts recipes instead of coordinates.",
        "The cargo bay contains one crate labeled definitely harmless.",
        "The navigation computer wants a rematch at tic-tac-toe.",
        "A spacesuit pockets small tools when nobody is looking.",
        "The cryo pods are thawing in alphabetical order.",
        "The gravity deck hiccups whenever someone says emergency.",
        "A lonely satellite keeps knocking on the hull.",
        "The medbay scanner diagnoses everyone with mild heroism.",
        "A rogue cleaning bot guards the last oxygen key.",
    ),
}

FREEFORM_ACTIONS = (
    "I befriend the {noun}",
    "I dramatically apologize to the {noun}",
    "I trade a button for help from the {noun}",
    "I ask the {noun} for directions",
    "I inspect the {noun} for secret hinges",
    "I challenge the {noun} to a staring contest",
    "I use the {noun} as a distraction",
    "I quietly follow the {noun}",
)

GREEDY_TERMS = {
    "treasure",
    "gold",
    "coin",
    "gem",
    "reward",
    "loot",
    "chest",
    "crown",
    "key",
    "relic",
    "map",
    "tool",
    "weapon",
    "crystal",
    "cache",
    "vault",
}

TOKEN_RE = re.compile(r"[a-z0-9]+")


@dataclass
class AdventureRuntime:
    adventure_id: str
    genre: str
    premise: str | None
    persona: str
    seed: int
    rng: random.Random
    state: GameState
    turns: list[dict[str, Any]] = field(default_factory=list)
    done: bool = False


def _make_adventure(index: int) -> AdventureRuntime:
    genre = GENRES[index % len(GENRES)]
    persona = PERSONAS[index % len(PERSONAS)]
    seed = 10_000 + index
    rng = random.Random(seed)
    premise = rng.choice(PREMISE_TEMPLATES[genre]) if rng.random() < 0.30 else None
    adventure_id = f"adv-{index:06d}"
    state = GameState(genre=genre, premise=premise)
    return AdventureRuntime(
        adventure_id=adventure_id,
        genre=genre,
        premise=premise,
        persona=persona,
        seed=seed,
        rng=rng,
        state=state,
    )


def _state_summary(state: GameState) -> dict[str, Any]:
    return {
        "hp": state.hp,
        "inventory": list(state.inventory),
        "location": state.location,
        "flags": list(state.flags),
        "turn_count": state.turn_count,
    }


def _parse_turn(raw: str, state: GameState) -> tuple[Turn | None, list[str], bool]:
    try:
        turn = Turn.model_validate_json(raw)
    except Exception as exc:
        return None, [f"schema: {type(exc).__name__}: {exc}"], True

    errors = validate_turn(state, turn)
    if errors:
        return None, errors, False
    return turn, [], False


def _record_turn(
    runtime: AdventureRuntime,
    *,
    messages: list[dict[str, str]],
    turn: Turn,
    action_taken: str | None,
) -> None:
    runtime.turns.append(
        {
            "state_summary": _state_summary(runtime.state),
            "messages": messages,
            "turn_json": turn.model_dump(mode="json"),
            "action_taken": action_taken,
        }
    )


def _advance(runtime: AdventureRuntime, turn: Turn, action_taken: str | None) -> None:
    updated = apply_delta(runtime.state, turn)
    if not turn.is_ending and action_taken:
        updated = updated.model_copy(
            update={
                "recent_turns": [*updated.recent_turns, (turn, action_taken)][-2:],
            }
        )
    runtime.state = updated
    runtime.done = turn.is_ending or runtime.state.turn_count >= MAX_TURNS


def _choose_action(runtime: AdventureRuntime, turn: Turn) -> str | None:
    if turn.is_ending:
        return None

    if runtime.persona == "greedy":
        return _greedy_choice(runtime.rng, turn.choices)
    if runtime.persona == "curious":
        return _curious_choice(runtime.rng, runtime.state, turn.choices)
    return _chaotic_choice(runtime.rng, runtime.state, turn.choices)


def _greedy_choice(rng: random.Random, choices: list[str]) -> str:
    scored = []
    for choice in choices:
        tokens = set(TOKEN_RE.findall(choice.casefold()))
        scored.append(len(tokens & GREEDY_TERMS))
    best = max(scored)
    candidates = [choice for choice, score in zip(choices, scored, strict=True) if score == best]
    return rng.choice(candidates)


def _curious_choice(rng: random.Random, state: GameState, choices: list[str]) -> str:
    history_tokens: set[str] = set()
    for prior_turn, action in state.recent_turns:
        history_tokens.update(TOKEN_RE.findall(prior_turn.narration.casefold()))
        history_tokens.update(TOKEN_RE.findall(action.casefold()))

    scored: list[tuple[float, str]] = []
    for choice in choices:
        tokens = set(TOKEN_RE.findall(choice.casefold()))
        overlap = len(tokens & history_tokens) / max(1, len(tokens | history_tokens))
        scored.append((1.0 - overlap, choice))

    best = max(score for score, _ in scored)
    candidates = [choice for score, choice in scored if math.isclose(score, best)]
    return rng.choice(candidates)


def _chaotic_choice(rng: random.Random, state: GameState, choices: list[str]) -> str:
    if rng.random() >= 0.20:
        return rng.choice(choices)
    noun = _sample_noun(rng, state, choices)
    return rng.choice(FREEFORM_ACTIONS).format(noun=noun)


def _sample_noun(rng: random.Random, state: GameState, choices: Iterable[str]) -> str:
    candidates: list[str] = []
    candidates.extend(state.inventory)
    candidates.extend(state.flags)
    candidates.append(state.location)
    for choice in choices:
        tokens = [token for token in TOKEN_RE.findall(choice.casefold()) if len(token) >= 4]
        candidates.extend(tokens)
    cleaned = [candidate.strip().lower() for candidate in candidates if candidate.strip()]
    return rng.choice(cleaned or ["mystery"])


def _output_line(runtime: AdventureRuntime) -> str:
    return json.dumps(
        {
            "adventure_id": runtime.adventure_id,
            "genre": runtime.genre,
            "premise": runtime.premise,
            "persona": runtime.persona,
            "seed": runtime.seed,
            "turns": runtime.turns,
        },
        ensure_ascii=True,
        separators=(",", ":"),
    )


def _cost_line(
    *,
    adventures: int,
    turns: int,
    duration_seconds: float,
    schema_failures: int,
    gpu_name: str,
) -> str:
    rate = A100_80GB_RATE_PER_HOUR if gpu_name == "A100-80GB" else H100_RATE_PER_HOUR
    cost = duration_seconds / 3600.0 * rate
    minutes = duration_seconds / 60.0
    return (
        f"| {date.today().isoformat()} | WP-3 teacher gen ({adventures} adventures) | "
        f"Modal {gpu_name} | {minutes:.1f} min | {cost:.2f} | "
        f"{turns} turns; schema_failures={schema_failures}; "
        f"{(adventures / minutes) if minutes else 0.0:.2f} adventures/min |"
    )


def _sampling_params() -> Any:
    from vllm.sampling_params import SamplingParams, StructuredOutputsParams

    return SamplingParams(
        temperature=DEFAULT_TEMPERATURE,
        top_p=0.95,
        repetition_penalty=1.15,
        max_tokens=512,
        structured_outputs=StructuredOutputsParams(
            json=Turn.model_json_schema(),
            disable_additional_properties=True,
        ),
    )


def _load_llm() -> Any:
    from vllm import LLM

    return LLM(
        model=MODEL_ID,
        tensor_parallel_size=1,
        dtype="bfloat16",
        max_model_len=4096,
        max_num_seqs=128,
        gpu_memory_utilization=0.92,
        generation_config="vllm",
        structured_outputs_config={"backend": "xgrammar"},
    )


def _run_remote(adventures: int, wave_size: int, gpu_name: str) -> dict[str, Any]:
    llm = _load_llm()
    sampling_params = _sampling_params()
    runtimes = [_make_adventure(index) for index in range(adventures)]
    schema_failures = 0
    validation_failures = 0
    started = time.monotonic()

    while True:
        active = [runtime for runtime in runtimes if not runtime.done]
        if not active:
            break

        wave = active[: max(1, wave_size)]
        message_batch = [build_messages(runtime.state) for runtime in wave]
        outputs = llm.chat(
            message_batch,
            sampling_params=sampling_params,
            use_tqdm=False,
            chat_template_kwargs={"enable_thinking": False},
        )

        for runtime, messages, output in zip(wave, message_batch, outputs, strict=True):
            raw = output.outputs[0].text.strip()
            turn, errors, schema_failed = _parse_turn(raw, runtime.state)
            if turn is None:
                if schema_failed:
                    schema_failures += 1
                else:
                    validation_failures += 1
                runtime.done = True
                continue

            action_taken = _choose_action(runtime, turn)
            _record_turn(
                runtime,
                messages=messages,
                turn=turn,
                action_taken=action_taken,
            )
            _advance(runtime, turn, action_taken)

    duration_seconds = time.monotonic() - started
    turn_count = sum(len(runtime.turns) for runtime in runtimes)
    return {
        "lines": [_output_line(runtime) for runtime in runtimes],
        "adventures": adventures,
        "turns": turn_count,
        "duration_seconds": duration_seconds,
        "schema_failures": schema_failures,
        "validation_failures": validation_failures,
        "gpu_name": gpu_name,
        "cost_line": _cost_line(
            adventures=adventures,
            turns=turn_count,
            duration_seconds=duration_seconds,
            schema_failures=schema_failures,
            gpu_name=gpu_name,
        ),
    }


@app.function(
    image=teacher_image,
    gpu="H100",
    timeout=60 * 60 * 4,
    volumes={CACHE_DIR: hf_cache},
)
def generate_h100(adventures: int, wave_size: int) -> dict[str, Any]:
    result = _run_remote(adventures, wave_size, "H100")
    hf_cache.commit()
    return result


@app.function(
    image=teacher_image,
    gpu="A100-80GB",
    timeout=60 * 60 * 4,
    volumes={CACHE_DIR: hf_cache},
)
def generate_a100(adventures: int, wave_size: int) -> dict[str, Any]:
    result = _run_remote(adventures, wave_size, "A100-80GB")
    hf_cache.commit()
    return result


@app.local_entrypoint()
def main(
    adventures: int = 50,
    out: str = "data/out/smoke.jsonl",
    wave_size: int = DEFAULT_WAVE_SIZE,
    gpu: str = "H100",
) -> None:
    if adventures <= 0:
        raise ValueError("--adventures must be positive")
    if wave_size <= 0:
        raise ValueError("--wave-size must be positive")
    if gpu not in {"H100", "A100-80GB"}:
        raise ValueError("--gpu must be H100 or A100-80GB")

    remote = generate_a100 if gpu == "A100-80GB" else generate_h100
    result = remote.remote(adventures, wave_size)

    out_path = Path(out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text("\n".join(result["lines"]) + "\n")

    minutes = result["duration_seconds"] / 60.0
    adventures_per_min = result["adventures"] / minutes if minutes else 0.0
    print(f"wrote {result['adventures']} adventures / {result['turns']} turns to {out_path}")
    print(f"adventures/min: {adventures_per_min:.2f}")
    print(f"schema-failure count: {result['schema_failures']}")
    print(result["cost_line"])
