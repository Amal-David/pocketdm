"""Tests for Layer-3 proactive, pattern-aware check-ins.

Covers: observation append + ``mood_counts_by_daypart`` round-trip across a
simulated restart; ``select_proactive_intent`` over seeded history (slump ->
``preempt_slump``, big gap -> ``welcome_back``, thin/ambiguous -> ``None``); and
the ``/api/proactive`` endpoint returning a brain-generated line when an intent
fires vs. the generic-cheer signal when not.
"""

from __future__ import annotations

import importlib
import json

from app import memory_store
from app import proactive
from app.server import PlaySession, _proactive_payload
from engine.generate import MockBackend
from engine.state import GameState

DAY = 24 * 60 * 60


def _fresh_store(monkeypatch, tmp_path):
    """Point the store at an isolated on-disk DB and reload it like a restart."""
    db_path = tmp_path / "memory.db"
    monkeypatch.setenv("POCKETDM_MEMORY_DB", str(db_path))
    return importlib.reload(memory_store), db_path


# --- Mood polarity + gap parsing (the documented mapping) ------------------


def test_mood_polarity_mapping():
    assert proactive.classify_mood("tired") == "negative"
    assert proactive.classify_mood("a bit overwhelmed") == "negative"
    assert proactive.classify_mood("great") == "positive"
    assert proactive.classify_mood("feeling calm") == "positive"
    assert proactive.classify_mood("meh") == "neutral"
    assert proactive.classify_mood("") == "neutral"
    assert proactive.classify_mood(None) == "neutral"


def test_parse_gap_days_units():
    assert proactive.parse_gap_days("2d") == 2.0
    assert proactive.parse_gap_days("48h") == 2.0
    assert proactive.parse_gap_days("90m") == 90 / 1440
    assert proactive.parse_gap_days("3") == 3.0  # bare number -> days
    assert proactive.parse_gap_days("nope") is None
    assert proactive.parse_gap_days(None) is None


# --- Observation append + query round-trip across restart ------------------


def test_observation_append_and_counts_round_trip_across_restart(monkeypatch, tmp_path):
    store, db_path = _fresh_store(monkeypatch, tmp_path)
    base = 1_000_000.0

    store.add_observation("default", "afternoon", "tired", now=base)
    store.add_observation("default", "afternoon", "low", now=base + DAY)
    store.add_observation("default", "morning", "great", now=base + DAY)
    # Null mood/daypart rows carry no signal and are skipped entirely.
    store.add_observation("default", None, None, now=base + DAY)

    assert db_path.exists()
    # Simulate a process restart: reload the module, read the same on-disk DB.
    reloaded = importlib.reload(memory_store)
    counts = reloaded.mood_counts_by_daypart("default", since_days=30, now=base + DAY + 1)

    assert counts["afternoon"] == {"tired": 1, "low": 1}
    assert counts["morning"] == {"great": 1}


def test_mood_counts_respects_history_window(monkeypatch, tmp_path):
    store, _ = _fresh_store(monkeypatch, tmp_path)
    base = 1_000_000.0

    store.add_observation("default", "afternoon", "tired", now=base - 40 * DAY)  # too old
    store.add_observation("default", "afternoon", "low", now=base)

    counts = store.mood_counts_by_daypart("default", since_days=14, now=base)
    assert counts == {"afternoon": {"low": 1}}


# --- Intent selection ------------------------------------------------------


def _seed_afternoon_slump(store, base):
    """Three distinct afternoon days of negative mood -> a recurring slump."""
    store.add_observation("default", "afternoon", "tired", now=base + 0 * DAY)
    store.add_observation("default", "afternoon", "low", now=base + 1 * DAY)
    store.add_observation("default", "afternoon", "anxious", now=base + 2 * DAY)


def test_seeded_afternoon_slump_selects_preempt_slump(monkeypatch, tmp_path):
    store, _ = _fresh_store(monkeypatch, tmp_path)
    base = 1_000_000.0
    _seed_afternoon_slump(store, base)

    intent = proactive.select_proactive_intent(
        "default", "afternoon", "30m", now=base + 2 * DAY + 1
    )
    assert intent == {"intent": "preempt_slump", "daypart": "afternoon"}


def test_large_gap_selects_welcome_back(monkeypatch, tmp_path):
    _fresh_store(monkeypatch, tmp_path)
    intent = proactive.select_proactive_intent(
        "default", "morning", "3d", now=1_000_000.0
    )
    assert intent["intent"] == "welcome_back"
    assert intent["gap_days"] == 3.0


def test_absence_wins_over_slump(monkeypatch, tmp_path):
    store, _ = _fresh_store(monkeypatch, tmp_path)
    base = 1_000_000.0
    _seed_afternoon_slump(store, base)

    # Both signals present: a returning user gets the warm welcome, not the dip.
    intent = proactive.select_proactive_intent(
        "default", "afternoon", "4d", now=base + 2 * DAY + 1
    )
    assert intent["intent"] == "welcome_back"


def test_thin_history_yields_none(monkeypatch, tmp_path):
    store, _ = _fresh_store(monkeypatch, tmp_path)
    base = 1_000_000.0
    # Only one negative afternoon -> below the distinct-day threshold.
    store.add_observation("default", "afternoon", "tired", now=base)

    intent = proactive.select_proactive_intent(
        "default", "afternoon", "30m", now=base + 1
    )
    assert intent is None


def test_ambiguous_history_majority_positive_yields_none(monkeypatch, tmp_path):
    store, _ = _fresh_store(monkeypatch, tmp_path)
    base = 1_000_000.0
    # Three negative days but four positive days at the same daypart: negatives
    # are not a strict majority, so no slump is claimed.
    store.add_observation("default", "afternoon", "tired", now=base + 0 * DAY)
    store.add_observation("default", "afternoon", "low", now=base + 1 * DAY)
    store.add_observation("default", "afternoon", "anxious", now=base + 2 * DAY)
    store.add_observation("default", "afternoon", "great", now=base + 3 * DAY)
    store.add_observation("default", "afternoon", "calm", now=base + 4 * DAY)
    store.add_observation("default", "afternoon", "proud", now=base + 5 * DAY)
    store.add_observation("default", "afternoon", "happy", now=base + 6 * DAY)

    intent = proactive.select_proactive_intent(
        "default", "afternoon", "30m", now=base + 6 * DAY + 1
    )
    assert intent is None


def test_same_day_negatives_do_not_fake_a_slump(monkeypatch, tmp_path):
    store, _ = _fresh_store(monkeypatch, tmp_path)
    base = 1_000_000.0
    # Three negative afternoon rows but all on ONE day -> not a recurring pattern.
    store.add_observation("default", "afternoon", "tired", now=base)
    store.add_observation("default", "afternoon", "low", now=base + 60)
    store.add_observation("default", "afternoon", "anxious", now=base + 120)

    intent = proactive.select_proactive_intent(
        "default", "afternoon", "30m", now=base + 200
    )
    assert intent is None


# --- /api/proactive endpoint (brain-generated line vs generic cheer) -------


def _stub_brain(monkeypatch):
    """Stub the llama server so a fired intent produces a deterministic line."""
    captured: dict[str, object] = {}

    class FakeResponse:
        def __enter__(self) -> "FakeResponse":
            return self

        def __exit__(self, *args: object) -> None:
            return None

        def read(self) -> bytes:
            return json.dumps(
                {"choices": [{"message": {"content": "Welcome back, friend."}}]}
            ).encode("utf-8")

    def fake_urlopen(request, timeout):  # type: ignore[no-untyped-def]
        captured["payload"] = json.loads(request.data.decode("utf-8"))
        return FakeResponse()

    monkeypatch.setenv("POCKETDM_LLAMA_SERVER_URL", "http://127.0.0.1:8081")
    monkeypatch.setenv("POCKETDM_LLAMA_SERVER_MODEL", "server-model")
    monkeypatch.setattr("app.server.urlrequest.urlopen", fake_urlopen)
    return captured


def _session() -> PlaySession:
    return PlaySession(
        state=GameState(genre="whispering_wood"),
        backend=MockBackend([]),
        backend_label="scripted",
    )


def _brain_context(captured: dict[str, object]) -> dict:
    user_message = captured["payload"]["messages"][1]["content"]  # type: ignore[index]
    context_json = user_message.split("Context: ", 1)[1].split("\nUser:", 1)[0]
    return json.loads(context_json)


def test_proactive_endpoint_returns_brain_line_when_intent_fires(monkeypatch, tmp_path):
    _fresh_store(monkeypatch, tmp_path)
    captured = _stub_brain(monkeypatch)

    result = _proactive_payload(
        _session(), {"daypart": "morning", "user_state": {"last_seen_gap": "3d"}}
    )

    assert result["use_generic_cheer"] is False
    assert result["intent"] == "welcome_back"
    assert result["reply"] == "Pika pika! Welcome back, friend."
    # The selected intent rides in the PRIVATE context (covered by no-recite guard).
    context = _brain_context(captured)
    assert context["proactive_intent"]["intent"] == "welcome_back"


def test_proactive_endpoint_signals_generic_cheer_when_no_intent(monkeypatch, tmp_path):
    _fresh_store(monkeypatch, tmp_path)
    _stub_brain(monkeypatch)

    # No history, no gap -> insufficient signal -> generic-cheer fallback.
    result = _proactive_payload(
        _session(), {"daypart": "morning", "user_state": {"last_seen_gap": "10m"}}
    )

    assert result == {"use_generic_cheer": True}


def test_proactive_endpoint_falls_back_when_brain_unavailable(monkeypatch, tmp_path):
    _fresh_store(monkeypatch, tmp_path)
    # No POCKETDM_LLAMA_SERVER_URL -> brain path returns None -> generic cheer,
    # even though an intent fired.
    monkeypatch.delenv("POCKETDM_LLAMA_SERVER_URL", raising=False)

    result = _proactive_payload(
        _session(), {"daypart": "morning", "user_state": {"last_seen_gap": "5d"}}
    )

    assert result == {"use_generic_cheer": True}
