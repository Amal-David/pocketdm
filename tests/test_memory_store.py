import importlib
import json

from app import memory_store
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


def test_save_state_then_get_state_round_trips_across_restart(monkeypatch, tmp_path):
    store, db_path = _fresh_store(monkeypatch, tmp_path)

    snapshot = {
        "streak": 7,
        "bond_hp": 42,
        "mood": "calm",
        "daypart": "evening",
        "last_seen_gap": "3h",
    }
    store.save_state("default", snapshot)

    # Simulate a process restart: reload the module so no in-memory state leaks,
    # and confirm the on-disk SQLite file still has the snapshot.
    assert db_path.exists()
    reloaded = importlib.reload(memory_store)
    assert reloaded.get_state("default") == snapshot


def test_save_state_preserves_free_form_extra_fields(monkeypatch, tmp_path):
    store, _ = _fresh_store(monkeypatch, tmp_path)

    store.save_state("default", {"streak": 2, "favorite_food": "ketchup"})
    restored = store.get_state("default")

    assert restored["streak"] == 2
    assert restored["favorite_food"] == "ketchup"


def test_get_state_returns_empty_dict_when_unset(monkeypatch, tmp_path):
    store, _ = _fresh_store(monkeypatch, tmp_path)

    assert store.get_state("default") == {}


def _capture_brain_context(monkeypatch):
    """Stub the llama server and return a dict that captures the sent payload."""
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
    # Pin the model so the reply path skips the /v1/models discovery round-trip.
    monkeypatch.setenv("POCKETDM_LLAMA_SERVER_MODEL", "server-model")
    monkeypatch.setattr("app.server.urlrequest.urlopen", fake_urlopen)
    return captured


def _brain_context(captured: dict[str, object]) -> dict:
    user_message = captured["payload"]["messages"][1]["content"]  # type: ignore[index]
    context_json = user_message.split("Context: ", 1)[1].split("\nUser:", 1)[0]
    return json.loads(context_json)


def test_persisted_pet_state_is_injected_into_brain_context(monkeypatch, tmp_path):
    _fresh_store(monkeypatch, tmp_path)
    from app import memory_store as store

    store.save_state("default", {"streak": 5, "bond_hp": 10, "mood": "tired"})

    captured = _capture_brain_context(monkeypatch)
    session = PlaySession(
        state=GameState(genre="whispering_wood"),
        backend=MockBackend([]),
        backend_label="scripted",
    )

    reply = _local_companion_llm_reply(session, "hello", purpose="chat")

    assert reply == "Pika pika! Ready for one tiny step."
    context = _brain_context(captured)
    assert context["pet_state"] == {"streak": 5, "bond_hp": 10, "mood": "tired"}


def test_no_persisted_state_keeps_context_unchanged(monkeypatch, tmp_path):
    _fresh_store(monkeypatch, tmp_path)

    captured = _capture_brain_context(monkeypatch)
    session = PlaySession(
        state=GameState(genre="whispering_wood"),
        backend=MockBackend([]),
        backend_label="scripted",
    )

    reply = _local_companion_llm_reply(session, "hello", purpose="chat")

    assert reply == "Pika pika! Ready for one tiny step."
    context = _brain_context(captured)
    # No user_state ever saved -> path is identical to today's stateless behavior.
    assert "pet_state" not in context
    assert set(context) <= {"local_time", "timezone", "tool_facts"}


def test_assistant_endpoint_persists_user_state(monkeypatch, tmp_path):
    from fastapi.testclient import TestClient

    _fresh_store(monkeypatch, tmp_path)
    from app import memory_store as store
    from app.server import app

    client = TestClient(app)
    start = client.post("/api/start", json={"genre": "whispering_wood"})
    session_id = start.json()["session_id"]

    response = client.post(
        "/api/assistant",
        json={
            "session_id": session_id,
            "message": "hi",
            "user_state": {"streak": 3, "bond_hp": 8, "mood": "bright"},
        },
    )
    assert response.status_code == 200

    assert store.get_state("default") == {"streak": 3, "bond_hp": 8, "mood": "bright"}


def test_partial_state_update_preserves_prior_fields(monkeypatch, tmp_path):
    # A partial snapshot must merge, not wipe fields it omits. Regression for the
    # ON CONFLICT overwrite that nulled prior values on partial updates.
    store, _ = _fresh_store(monkeypatch, tmp_path)
    store.save_state("default", {"streak": 7, "bond_hp": 42, "mood": "calm"})

    store.save_state("default", {"mood": "bright"})

    assert store.get_state("default") == {"streak": 7, "bond_hp": 42, "mood": "bright"}
