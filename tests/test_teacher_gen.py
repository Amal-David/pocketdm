from __future__ import annotations

import pytest

pytest.importorskip("modal")

from data.teacher_gen import _make_adventure, _safe_remote_output_path


def test_make_adventure_uses_absolute_index_for_chunking() -> None:
    first = _make_adventure(0)
    later = _make_adventure(225)

    assert first.adventure_id == "adv-000000"
    assert first.seed == 10_000
    assert later.adventure_id == "adv-000225"
    assert later.seed == 10_225
    assert later.adventure_id != first.adventure_id


def test_remote_output_path_stays_inside_modal_volume() -> None:
    assert str(_safe_remote_output_path("chunks/full-v1-000.jsonl")).endswith(
        "/teacher-output/chunks/full-v1-000.jsonl"
    )

    with pytest.raises(ValueError):
        _safe_remote_output_path("../escape.jsonl")

    with pytest.raises(ValueError):
        _safe_remote_output_path("/tmp/escape.jsonl")
