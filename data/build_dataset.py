from __future__ import annotations

import argparse
import glob
import json
import random
from collections import Counter, defaultdict
from pathlib import Path
from typing import Any

from engine.schema import Turn


def expand_inputs(patterns: list[str]) -> list[Path]:
    paths: list[Path] = []
    for pattern in patterns:
        matches = sorted(glob.glob(pattern))
        if matches:
            paths.extend(Path(match) for match in matches)
        else:
            paths.append(Path(pattern))
    return paths


def load_adventures(paths: list[Path]) -> list[dict[str, Any]]:
    adventures: list[dict[str, Any]] = []
    seen_ids: Counter[str] = Counter()
    for path in paths:
        with path.open() as handle:
            for line_number, line in enumerate(handle, start=1):
                stripped = line.strip()
                if not stripped:
                    continue
                try:
                    adventure = json.loads(stripped)
                except json.JSONDecodeError as exc:
                    raise ValueError(f"{path}:{line_number}: invalid JSONL: {exc}") from exc
                adventures.append(_with_unique_adventure_id(adventure, path, seen_ids))
    return adventures


def choose_holdout(
    adventures: list[dict[str, Any]],
    *,
    holdout_size: int,
    seed: int,
) -> set[str]:
    if holdout_size <= 0 or not adventures:
        return set()

    by_genre: dict[str, list[dict[str, Any]]] = defaultdict(list)
    for adventure in adventures:
        by_genre[str(adventure.get("genre"))].append(adventure)

    rng = random.Random(seed)
    target = min(holdout_size, len(adventures))
    selected: set[str] = set()
    fractional: list[tuple[float, str]] = []

    for genre, genre_adventures in sorted(by_genre.items()):
        exact = target * len(genre_adventures) / len(adventures)
        quota = min(len(genre_adventures), int(exact))
        rng.shuffle(genre_adventures)
        selected.update(_adventure_id(adventure) for adventure in genre_adventures[:quota])
        fractional.append((exact - quota, genre))

    remaining = target - len(selected)
    for _, genre in sorted(fractional, reverse=True):
        if remaining <= 0:
            break
        for adventure in by_genre[genre]:
            adventure_id = _adventure_id(adventure)
            if adventure_id in selected:
                continue
            selected.add(adventure_id)
            remaining -= 1
            break

    if len(selected) < target:
        for adventure in adventures:
            if len(selected) >= target:
                break
            selected.add(_adventure_id(adventure))

    return selected


def training_pair(turn_record: dict[str, Any]) -> dict[str, Any]:
    turn = Turn.model_validate(turn_record["turn_json"])
    return {
        "messages": turn_record["messages"],
        "completion": turn.model_dump_json(),
    }


def holdout_record(adventure: dict[str, Any]) -> dict[str, Any]:
    return {
        "adventure_id": adventure.get("adventure_id"),
        "genre": adventure.get("genre"),
        "premise": adventure.get("premise"),
        "persona": adventure.get("persona"),
        "seed": adventure.get("seed"),
    }


def write_jsonl(path: Path, rows: list[dict[str, Any]]) -> None:
    with path.open("w") as handle:
        for row in rows:
            handle.write(json.dumps(row, ensure_ascii=True, separators=(",", ":")) + "\n")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("inputs", nargs="*", default=["data/clean/adventures.jsonl"])
    parser.add_argument("--out", default="data/clean/")
    parser.add_argument("--holdout", type=int, default=100)
    parser.add_argument("--seed", type=int, default=20260610)
    args = parser.parse_args()

    adventures = load_adventures(expand_inputs(args.inputs))
    holdout_ids = choose_holdout(
        adventures,
        holdout_size=args.holdout,
        seed=args.seed,
    )

    train_pairs: list[dict[str, Any]] = []
    holdout_rows: list[dict[str, Any]] = []
    for adventure in adventures:
        adventure_id = _adventure_id(adventure)
        if adventure_id in holdout_ids:
            holdout_rows.append(holdout_record(adventure))
            continue
        train_pairs.extend(training_pair(record) for record in adventure.get("turns", []))

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    train_path = out_dir / "train.jsonl"
    holdout_path = out_dir / "holdout_seeds.jsonl"
    write_jsonl(train_path, train_pairs)
    write_jsonl(holdout_path, holdout_rows)

    print(f"adventures: {len(adventures)}")
    print(f"holdout adventures: {len(holdout_rows)}")
    print(f"training pairs: {len(train_pairs)}")
    print(f"wrote {train_path}")
    print(f"wrote {holdout_path}")


def _adventure_id(adventure: dict[str, Any]) -> str:
    value = adventure.get("adventure_id")
    if value is None:
        raise ValueError("adventure missing adventure_id")
    return str(value)


def _with_unique_adventure_id(
    adventure: dict[str, Any],
    path: Path,
    seen_ids: Counter[str],
) -> dict[str, Any]:
    adventure_id = _adventure_id(adventure)
    seen_ids[adventure_id] += 1
    if seen_ids[adventure_id] == 1:
        return adventure
    unique = f"{adventure_id}__{path.parent.name}__{seen_ids[adventure_id]}"
    return {**adventure, "adventure_id": unique}


if __name__ == "__main__":
    main()
