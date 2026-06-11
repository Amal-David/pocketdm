from __future__ import annotations

import pytest

pytest.importorskip("modal")

from data.teacher_gen import _make_adventure


def test_make_adventure_uses_absolute_index_for_chunking() -> None:
    first = _make_adventure(0)
    later = _make_adventure(225)

    assert first.adventure_id == "adv-000000"
    assert first.seed == 10_000
    assert later.adventure_id == "adv-000225"
    assert later.seed == 10_225
    assert later.adventure_id != first.adventure_id
