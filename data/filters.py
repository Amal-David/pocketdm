from __future__ import annotations

import json
import math
import re
from collections import Counter
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any, Iterable, Protocol, Sequence

from engine.prompt import canonical_genre
from engine.schema import Turn
from engine.state import GameState, apply_delta, validate_turn

GATE_SCHEMA = "schema_valid"
GATE_SENTENCES = "narration_2_4_sentences"
GATE_CHOICES_DISTINCT = "choices_embedding_distinct"
GATE_NO_REPEAT = "no_choice_repeated_from_previous_turn"
GATE_DELTA_LEGAL = "delta_legal"
GATE_PROFANITY = "profanity_clean"
GATE_NARRATION_LENGTH = "narration_length_le_600"

TURN_GATES = (
    GATE_SCHEMA,
    GATE_SENTENCES,
    GATE_CHOICES_DISTINCT,
    GATE_NO_REPEAT,
    GATE_DELTA_LEGAL,
    GATE_PROFANITY,
    GATE_NARRATION_LENGTH,
)

ADV_GATE_ENDING = "reached_real_ending"
ADV_GATE_MIN_TURNS = "min_6_turns"
ADV_GATE_DROPPED = "max_1_dropped_turn"
ADVENTURE_GATES = (ADV_GATE_ENDING, ADV_GATE_MIN_TURNS, ADV_GATE_DROPPED)

SENTENCE_RE = re.compile(r"[.!?—–]+")
TOKEN_RE = re.compile(r"[a-z0-9]+")
NON_DELTA_ERROR_PREFIXES = (
    "turn must offer exactly 3 choices",
    "choices must be distinct",
    "choice repeats a choice offered last turn",
    "narration repeats the last narration too closely",
)


class Encoder(Protocol):
    def encode(self, texts: Sequence[str]) -> Sequence[Sequence[float]]:
        ...


class ProfanityChecker(Protocol):
    def contains_profanity(self, text: str) -> bool:
        ...


class SentenceTransformerEncoder:
    def __init__(self, model_name: str = "all-MiniLM-L6-v2") -> None:
        from sentence_transformers import SentenceTransformer

        self.model = SentenceTransformer(model_name, device="cpu")

    def encode(self, texts: Sequence[str]) -> Sequence[Sequence[float]]:
        return self.model.encode(list(texts), normalize_embeddings=True).tolist()


class BetterProfanityChecker:
    def __init__(self) -> None:
        from better_profanity import profanity

        profanity.load_censor_words()
        self._profanity = profanity

    def contains_profanity(self, text: str) -> bool:
        return bool(self._profanity.contains_profanity(text))


@dataclass(frozen=True)
class FilterConfig:
    embedding_threshold: float = 0.85
    min_turns: int = 6
    max_dropped_turns: int = 1
    max_narration_chars: int = 600
    forced_cap_turn: int = 15


@dataclass
class TurnFilterResult:
    passed: bool
    failures: list[str]
    parsed_turn: Turn | None


@dataclass
class AdventureFilterResult:
    adventure: dict[str, Any] | None
    turn_gate_passes: Counter[str] = field(default_factory=Counter)
    turn_gate_totals: Counter[str] = field(default_factory=Counter)
    adventure_gate_passes: Counter[str] = field(default_factory=Counter)
    adventure_gate_totals: Counter[str] = field(default_factory=Counter)
    raw_turns: int = 0
    clean_turns: int = 0
    dropped_turns: int = 0

    @property
    def passed(self) -> bool:
        return self.adventure is not None


def load_jsonl(path: Path) -> list[dict[str, Any]]:
    records: list[dict[str, Any]] = []
    with path.open() as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped:
                continue
            try:
                records.append(json.loads(stripped))
            except json.JSONDecodeError as exc:
                raise ValueError(f"{path}:{line_number}: invalid JSONL: {exc}") from exc
    return records


def filter_many(
    adventures: Iterable[dict[str, Any]],
    *,
    encoder: Encoder,
    profanity_checker: ProfanityChecker,
    config: FilterConfig | None = None,
) -> tuple[list[dict[str, Any]], dict[str, Any]]:
    cfg = config or FilterConfig()
    clean: list[dict[str, Any]] = []
    aggregate = AdventureFilterResult(adventure=None)
    total_adventures = 0

    for adventure in adventures:
        total_adventures += 1
        result = filter_adventure(
            adventure,
            encoder=encoder,
            profanity_checker=profanity_checker,
            config=cfg,
        )
        _merge_counts(aggregate, result)
        if result.adventure is not None:
            clean.append(result.adventure)

    report = {
        "total_adventures": total_adventures,
        "clean_adventures": len(clean),
        "raw_turns": aggregate.raw_turns,
        "clean_turns": aggregate.clean_turns,
        "dropped_turns": aggregate.dropped_turns,
        "turn_gate_passes": dict(aggregate.turn_gate_passes),
        "turn_gate_totals": dict(aggregate.turn_gate_totals),
        "adventure_gate_passes": dict(aggregate.adventure_gate_passes),
        "adventure_gate_totals": dict(aggregate.adventure_gate_totals),
    }
    return clean, report


def filter_adventure(
    adventure: dict[str, Any],
    *,
    encoder: Encoder,
    profanity_checker: ProfanityChecker,
    config: FilterConfig | None = None,
) -> AdventureFilterResult:
    cfg = config or FilterConfig()
    genre = canonical_genre(str(adventure.get("genre", "cursed_dungeon")))
    state = GameState(genre=genre, premise=adventure.get("premise"))
    previous_turn: Turn | None = None
    clean_turn_records: list[dict[str, Any]] = []
    result = AdventureFilterResult(adventure=None)
    raw_turn_records = list(adventure.get("turns") or [])
    result.raw_turns = len(raw_turn_records)

    for turn_record in raw_turn_records:
        turn_result = filter_turn(
            turn_record,
            state=state,
            previous_turn=previous_turn,
            encoder=encoder,
            profanity_checker=profanity_checker,
            config=cfg,
        )
        _record_turn_gates(result, turn_result)
        if turn_result.parsed_turn is None or not turn_result.passed:
            result.dropped_turns += 1
            continue

        turn = turn_result.parsed_turn
        clean_record = {
            "state_summary": turn_record.get("state_summary"),
            "messages": turn_record.get("messages"),
            "turn_json": turn.model_dump(mode="json"),
            "action_taken": turn_record.get("action_taken"),
        }
        clean_turn_records.append(clean_record)
        result.clean_turns += 1

        action_taken = turn_record.get("action_taken")
        updated = apply_delta(state, turn)
        if not turn.is_ending and isinstance(action_taken, str) and action_taken:
            updated = updated.model_copy(
                update={"recent_turns": [*updated.recent_turns, (turn, action_taken)][-2:]}
            )
        state = updated
        previous_turn = turn

    adventure_passes = {
        ADV_GATE_ENDING: _has_real_ending(clean_turn_records, cfg),
        ADV_GATE_MIN_TURNS: len(clean_turn_records) >= cfg.min_turns,
        ADV_GATE_DROPPED: result.dropped_turns <= cfg.max_dropped_turns,
    }
    for gate, passed in adventure_passes.items():
        result.adventure_gate_totals[gate] += 1
        if passed:
            result.adventure_gate_passes[gate] += 1

    if all(adventure_passes.values()):
        result.adventure = {
            "adventure_id": adventure.get("adventure_id"),
            "genre": genre,
            "premise": adventure.get("premise"),
            "persona": adventure.get("persona"),
            "seed": adventure.get("seed"),
            "turns": clean_turn_records,
        }

    return result


def filter_turn(
    turn_record: dict[str, Any],
    *,
    state: GameState,
    previous_turn: Turn | None,
    encoder: Encoder,
    profanity_checker: ProfanityChecker,
    config: FilterConfig | None = None,
) -> TurnFilterResult:
    cfg = config or FilterConfig()
    turn_payload = turn_record.get("turn_json")
    raw_payload = _payload_to_mapping(turn_payload)
    gate_failures: list[str] = []
    parsed_turn: Turn | None = None

    narration = raw_payload.get("narration") if isinstance(raw_payload, dict) else None
    choices = raw_payload.get("choices") if isinstance(raw_payload, dict) else None

    if not isinstance(narration, str) or not (2 <= sentence_count(narration) <= 4):
        gate_failures.append(GATE_SENTENCES)

    if not isinstance(narration, str) or len(narration) > cfg.max_narration_chars:
        gate_failures.append(GATE_NARRATION_LENGTH)

    if not isinstance(choices, list) or not all(isinstance(choice, str) for choice in choices):
        gate_failures.append(GATE_CHOICES_DISTINCT)
        gate_failures.append(GATE_NO_REPEAT)
    else:
        if not choices_embedding_distinct(
            choices,
            encoder=encoder,
            threshold=cfg.embedding_threshold,
        ):
            gate_failures.append(GATE_CHOICES_DISTINCT)
        if previous_turn is not None and choice_repeats_previous(choices, previous_turn):
            gate_failures.append(GATE_NO_REPEAT)

    if isinstance(narration, str) and profanity_checker.contains_profanity(
        " ".join([narration, *[choice for choice in choices or [] if isinstance(choice, str)]])
    ):
        gate_failures.append(GATE_PROFANITY)

    try:
        parsed_turn = parse_turn_payload(turn_payload)
    except Exception:
        gate_failures.append(GATE_SCHEMA)

    if parsed_turn is not None:
        delta_errors = delta_validation_errors(state, parsed_turn)
        if delta_errors:
            gate_failures.append(GATE_DELTA_LEGAL)
    else:
        gate_failures.append(GATE_DELTA_LEGAL)

    failures = _dedupe(gate_failures)
    return TurnFilterResult(
        passed=not failures,
        failures=failures,
        parsed_turn=parsed_turn,
    )


def parse_turn_payload(payload: Any) -> Turn:
    if isinstance(payload, Turn):
        return payload
    if isinstance(payload, str):
        return Turn.model_validate_json(payload)
    return Turn.model_validate(payload)


def sentence_count(text: str) -> int:
    return len([part for part in SENTENCE_RE.split(text) if part.strip()])


def choices_embedding_distinct(
    choices: Sequence[str],
    *,
    encoder: Encoder,
    threshold: float,
) -> bool:
    if len(choices) != 3:
        return False
    embeddings = encoder.encode(choices)
    for left_index, left in enumerate(embeddings):
        for right in embeddings[left_index + 1 :]:
            if cosine(left, right) >= threshold:
                return False
    return True


def choice_repeats_previous(choices: Sequence[str], previous_turn: Turn) -> bool:
    previous = {_normalize_choice(choice) for choice in previous_turn.choices}
    return any(_normalize_choice(choice) in previous for choice in choices)


def delta_validation_errors(state: GameState, turn: Turn) -> list[str]:
    return [
        error
        for error in validate_turn(state, turn)
        if not error.startswith(NON_DELTA_ERROR_PREFIXES)
    ]


def cosine(left: Sequence[float], right: Sequence[float]) -> float:
    dot = sum(a * b for a, b in zip(left, right, strict=True))
    left_norm = math.sqrt(sum(a * a for a in left))
    right_norm = math.sqrt(sum(b * b for b in right))
    if not left_norm or not right_norm:
        return 0.0
    return dot / (left_norm * right_norm)


def render_report(report: dict[str, Any]) -> str:
    lines = [
        "# WP-3 Filter Report",
        "",
        f"- Total adventures: {report['total_adventures']}",
        f"- Clean adventures: {report['clean_adventures']}",
        f"- Raw turns: {report['raw_turns']}",
        f"- Clean turns: {report['clean_turns']}",
        f"- Dropped turns: {report['dropped_turns']}",
        "",
        "## Turn Gates",
        "",
        "| Gate | Passed | Total | Pass rate |",
        "|---|---:|---:|---:|",
    ]
    for gate in TURN_GATES:
        passed = int(report["turn_gate_passes"].get(gate, 0))
        total = int(report["turn_gate_totals"].get(gate, 0))
        lines.append(f"| {gate} | {passed} | {total} | {_rate(passed, total)} |")

    lines.extend(
        [
            "",
            "## Adventure Gates",
            "",
            "| Gate | Passed | Total | Pass rate |",
            "|---|---:|---:|---:|",
        ]
    )
    for gate in ADVENTURE_GATES:
        passed = int(report["adventure_gate_passes"].get(gate, 0))
        total = int(report["adventure_gate_totals"].get(gate, 0))
        lines.append(f"| {gate} | {passed} | {total} | {_rate(passed, total)} |")

    return "\n".join(lines) + "\n"


def _payload_to_mapping(payload: Any) -> dict[str, Any]:
    if isinstance(payload, Turn):
        return payload.model_dump(mode="json")
    if isinstance(payload, str):
        try:
            value = json.loads(payload)
        except json.JSONDecodeError:
            return {}
        return value if isinstance(value, dict) else {}
    return payload if isinstance(payload, dict) else {}


def _record_turn_gates(result: AdventureFilterResult, turn_result: TurnFilterResult) -> None:
    failures = set(turn_result.failures)
    for gate in TURN_GATES:
        result.turn_gate_totals[gate] += 1
        if gate not in failures:
            result.turn_gate_passes[gate] += 1


def _merge_counts(target: AdventureFilterResult, source: AdventureFilterResult) -> None:
    target.turn_gate_passes.update(source.turn_gate_passes)
    target.turn_gate_totals.update(source.turn_gate_totals)
    target.adventure_gate_passes.update(source.adventure_gate_passes)
    target.adventure_gate_totals.update(source.adventure_gate_totals)
    target.raw_turns += source.raw_turns
    target.clean_turns += source.clean_turns
    target.dropped_turns += source.dropped_turns


def _has_real_ending(turn_records: Sequence[dict[str, Any]], config: FilterConfig) -> bool:
    for index, record in enumerate(turn_records, start=1):
        turn = parse_turn_payload(record.get("turn_json"))
        if turn.is_ending:
            return index < config.forced_cap_turn
    return False


def _normalize_choice(choice: str) -> str:
    return " ".join(choice.casefold().split())


def _dedupe(values: Iterable[str]) -> list[str]:
    deduped: list[str] = []
    seen: set[str] = set()
    for value in values:
        if value in seen:
            continue
        deduped.append(value)
        seen.add(value)
    return deduped


def _rate(passed: int, total: int) -> str:
    if total == 0:
        return "n/a"
    return f"{passed / total:.1%}"
