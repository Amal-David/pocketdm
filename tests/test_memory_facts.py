import importlib
import json

from app import memory_store
from app.memory_extract import extract_facts
from app.server import (
    PlaySession,
    _local_companion_llm_reply,
)
from engine.generate import MockBackend
from engine.state import GameState


def _fresh_store(monkeypatch, tmp_path):
    """Point the store at an isolated on-disk DB and reload it like a restart."""
    db_path = tmp_path / "memory.db"
    monkeypatch.setenv("POCKETDM_MEMORY_DB", str(db_path))
    return importlib.reload(memory_store), db_path


# --- Extraction ------------------------------------------------------------


def test_extractor_is_conservative_for_ephemeral_chatter():
    # Pure filler / a time question must NOT become a durable memory.
    assert extract_facts("ok") == []
    assert extract_facts("lol") == []
    assert extract_facts("what time is it?") == []
    assert extract_facts("") == []


def test_extractor_pulls_name_fact():
    facts = extract_facts("Hi! My name is Amal.")
    assert ("name", "Amal", 2.0) in facts


def test_extractor_pulls_goal_mood_event():
    assert any(k == "goal" for k, _, _ in extract_facts("I want to learn Spanish"))
    assert any(k == "mood" for k, _, _ in extract_facts("I feel anxious today"))
    assert any(k == "event" for k, _, _ in extract_facts("today I shipped my first app"))


# --- Persistence + recall across a simulated restart -----------------------


def test_extract_persist_recall_survives_restart(monkeypatch, tmp_path):
    store, db_path = _fresh_store(monkeypatch, tmp_path)

    for kind, text, weight in extract_facts("My name is Amal"):
        store.add_fact("default", kind, text, weight)

    assert db_path.exists()
    # Simulate a process restart: reload the module so nothing leaks in memory,
    # then read the same on-disk DB.
    reloaded = importlib.reload(memory_store)
    recalled = reloaded.recall_facts("default")
    assert any(f["kind"] == "name" and f["text"] == "Amal" for f in recalled)


def test_add_fact_deduplicates_near_identical_text(monkeypatch, tmp_path):
    store, _ = _fresh_store(monkeypatch, tmp_path)

    store.add_fact("default", "name", "My friend calls me Amal", 1.0)
    store.add_fact("default", "name", "my friend calls me amal.", 1.0)

    # No second row; weight is bumped instead.
    facts = store.recall_facts("default", limit=50, max_chars=10_000)
    matching = [f for f in facts if f["text"].casefold().startswith("my friend calls me")]
    assert len(matching) == 1
    assert matching[0]["weight"] == 2.0


def test_recall_drops_least_relevant_when_over_budget(monkeypatch, tmp_path):
    store, _ = _fresh_store(monkeypatch, tmp_path)

    base = 1_000_000.0  # fixed clock so relevance ordering is deterministic
    # Higher weight + newer = more relevant. Add three ~30-char facts.
    store.add_fact("default", "goal", "goal one is to do thing aaaa", 1.0, now=base)
    store.add_fact("default", "goal", "goal two is to do thing bbbb", 2.0, now=base + 1)
    store.add_fact("default", "goal", "goal three is to do thing cc", 3.0, now=base + 2)

    # Cap fits ~2 facts of ~28 chars. Most relevant (highest weight/newest) win.
    recalled = store.recall_facts("default", limit=50, max_chars=60, now=base + 2)
    total = sum(len(f["text"]) for f in recalled)
    assert total <= 60
    assert len(recalled) == 2
    texts = [f["text"] for f in recalled]
    # The two highest-weight facts survive; the least relevant is dropped first.
    assert "goal three is to do thing cc" in texts
    assert "goal two is to do thing bbbb" in texts
    assert "goal one is to do thing aaaa" not in texts


# --- Recall injected into the brain context --------------------------------


def _capture_brain_context(monkeypatch):
    captured: dict[str, object] = {}

    class FakeResponse:
        def __enter__(self) -> "FakeResponse":
            return self

        def __exit__(self, *args: object) -> None:
            return None

        def read(self) -> bytes:
            return json.dumps(
                {"choices": [{"message": {"content": "Ready for one tiny step."}}]}
            ).encode("utf-8")

    def fake_urlopen(request, timeout):  # type: ignore[no-untyped-def]
        captured["payload"] = json.loads(request.data.decode("utf-8"))
        return FakeResponse()

    monkeypatch.setenv("POCKETDM_LLAMA_SERVER_URL", "http://127.0.0.1:8081")
    monkeypatch.setenv("POCKETDM_LLAMA_SERVER_MODEL", "server-model")
    monkeypatch.setattr("app.server.urlrequest.urlopen", fake_urlopen)
    return captured


def _brain_context(captured: dict[str, object]) -> dict:
    user_message = captured["payload"]["messages"][1]["content"]  # type: ignore[index]
    context_json = user_message.split("Context: ", 1)[1].split("\nUser:", 1)[0]
    return json.loads(context_json)


def test_recalled_facts_injected_into_brain_context(monkeypatch, tmp_path):
    _fresh_store(monkeypatch, tmp_path)
    from app import memory_store as store

    store.add_fact("default", "name", "Amal", 2.0)

    captured = _capture_brain_context(monkeypatch)
    session = PlaySession(
        state=GameState(genre="whispering_wood"),
        backend=MockBackend([]),
        backend_label="scripted",
    )

    reply = _local_companion_llm_reply(session, "hello", purpose="chat")

    assert reply == "Pika pika! Ready for one tiny step."
    context = _brain_context(captured)
    assert any(
        f["kind"] == "name" and f["text"] == "Amal" for f in context["memories"]
    )


def test_no_facts_keeps_memories_out_of_context(monkeypatch, tmp_path):
    _fresh_store(monkeypatch, tmp_path)

    captured = _capture_brain_context(monkeypatch)
    session = PlaySession(
        state=GameState(genre="whispering_wood"),
        backend=MockBackend([]),
        backend_label="scripted",
    )

    _local_companion_llm_reply(session, "hello", purpose="chat")

    context = _brain_context(captured)
    assert "memories" not in context
