from __future__ import annotations

import json
from pathlib import Path

from data.build_dataset import load_adventures


def write_jsonl(path: Path, rows: list[dict[str, object]]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(json.dumps(row) for row in rows) + "\n")


def test_load_adventures_uniquifies_duplicate_ids_across_sources(tmp_path: Path) -> None:
    left = tmp_path / "clean-a" / "adventures.jsonl"
    right = tmp_path / "clean-b" / "adventures.jsonl"
    adventure = {
        "adventure_id": "adv-000001",
        "genre": "cursed_dungeon",
        "turns": [],
    }
    write_jsonl(left, [adventure])
    write_jsonl(right, [adventure])

    loaded = load_adventures([left, right])

    assert [row["adventure_id"] for row in loaded] == [
        "adv-000001",
        "adv-000001__clean-b__2",
    ]
