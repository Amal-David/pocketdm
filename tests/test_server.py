import json

from fastapi.testclient import TestClient

from app.server import (
    PlaySession,
    _compact_overlay_text,
    _dragon_reply,
    _has_companion_substance,
    _local_companion_llm_reply,
    _strip_leading_pika_sounds,
    _strip_thinking,
    _truthy_env,
    app,
    new_game,
    take_turn,
)
from engine.generate import MockBackend
from engine.state import GameState


def _assert_concise_overlay_reply(reply: str, *, limit: int = 180) -> None:
    assert reply.startswith("Pika pika!")
    assert "\n" not in reply
    assert len(reply) <= limit


def test_custom_server_starts_adventure_and_dragon_hint() -> None:
    client = TestClient(app)

    assert client.get("/health").json() == {"status": "ok"}

    start = client.post(
        "/api/start",
        json={"genre": "cursed_dungeon", "premise": "A spoon has vanished."},
    )
    assert start.status_code == 200
    body = start.json()
    assert body["session_id"]
    assert body["turn"]["choices"]
    assert body["state"]["turn_count"] == 1
    assert body["state"]["voice"] == "dungeon"
    assert body["state"]["backend"] == "scripted"
    assert body["state"]["model"] == "Scripted safety mode"
    assert body["state"]["last_turn_seconds"] > 0
    assert body["state"]["last_turn_tokens"] > 0
    assert body["state"]["last_turn_tokens_per_second"] is None
    assert "Pikachu" in body["assistant"]
    assert "Pika pika!" in body["assistant"]

    hint = client.post(
        "/api/assistant",
        json={"session_id": body["session_id"], "message": "hint"},
    )
    assert hint.status_code == 200
    assert "My hint" in hint.json()["reply"]
    assert "Pika pika!" in hint.json()["reply"]
    assert "precise" in hint.json()["reply"] or "state" in hint.json()["reply"]

    status = client.post(
        "/api/assistant",
        json={"session_id": body["session_id"], "message": "status"},
    )
    assert status.status_code == 200
    assert "10/10 HP" in status.json()["reply"]
    assert "Turn 1" in status.json()["reply"]

    daily = client.post(
        "/api/assistant",
        json={
            "session_id": body["session_id"],
            "message": "Daily voice check-in. User said: I feel stuck and overwhelmed.",
        },
    )
    assert daily.status_code == 200
    assert "Pika pika!" in daily.json()["reply"]
    assert "smallest visible step" in daily.json()["reply"]


def test_local_companion_reply_strips_thinking_tags() -> None:
    assert _strip_thinking("<think>hidden scratchpad</think>\nPika pika! Ready.") == "Pika pika! Ready."
    assert _strip_thinking("<think>still thinking") == ""


def test_local_companion_reply_strips_leading_pika_only_syllables() -> None:
    assert _strip_leading_pika_sounds("Pika piki! You're ready to chat.") == "You're ready to chat."
    assert _strip_leading_pika_sounds("Pikaa Pikaa! One tiny win is enough.") == "One tiny win is enough."
    assert _has_companion_substance("Pika piki!") is False
    assert _has_companion_substance("Pika pika! I am here for you.") is True


def test_local_companion_reply_compacts_long_overlay_text() -> None:
    reply = _compact_overlay_text(
        "First useful sentence. "
        "Second sentence keeps going with extra detail that is too long for the tiny overlay bubble.",
        limit=48,
    )

    assert reply == "First useful sentence."


def test_local_companion_reply_uses_canonical_llama_server_model(monkeypatch) -> None:
    captured: dict[str, object] = {}

    class FakeResponse:
        def __enter__(self) -> "FakeResponse":
            return self

        def __exit__(self, *args: object) -> None:
            return None

        def read(self) -> bytes:
            return json.dumps({"choices": [{"message": {"content": "Ready for one tiny step."}}]}).encode("utf-8")

    def fake_urlopen(request, timeout):  # type: ignore[no-untyped-def]
        captured["url"] = request.full_url
        captured["timeout"] = timeout
        captured["payload"] = json.loads(request.data.decode("utf-8"))
        return FakeResponse()

    monkeypatch.setenv("POCKETDM_LLAMA_SERVER_URL", "http://127.0.0.1:8081")
    monkeypatch.setenv("POCKETDM_LLAMA_SERVER_MODEL", "server-model")
    monkeypatch.setenv("POCKETDM_ASSISTANT_LLAMA_MODEL", "assistant-model")
    monkeypatch.setattr("app.server.urlrequest.urlopen", fake_urlopen)
    session = PlaySession(
        state=GameState(genre="whispering_wood"),
        backend=MockBackend([]),
        backend_label="scripted",
    )

    reply = _local_companion_llm_reply(session, "hello", purpose="chat")

    assert reply == "Pika pika! Ready for one tiny step."
    assert captured["url"] == "http://127.0.0.1:8081/v1/chat/completions"
    assert captured["payload"]["model"] == "server-model"


def test_companion_chat_without_active_turn_still_answers_encouragement() -> None:
    session = PlaySession(
        state=GameState(genre="whispering_wood"),
        backend=MockBackend([]),
        backend_label="scripted",
    )

    reply = _dragon_reply(session, "Give me one tiny encouragement")

    assert reply.startswith("Pika pika!")
    assert "one tiny win" in reply.lower()
    assert "Start an adventure" not in reply


def test_assistant_answers_safe_system_data_without_adventure_hint() -> None:
    client = TestClient(app)
    start = client.post("/api/start", json={"genre": "whispering_wood"})
    assert start.status_code == 200
    session_id = start.json()["session_id"]

    time_reply = client.post(
        "/api/assistant",
        json={"session_id": session_id, "message": "Hello what is the time now?"},
    )
    assert time_reply.status_code == 200
    time_text = time_reply.json()["reply"]
    _assert_concise_overlay_reply(time_text, limit=110)
    assert "Time here:" in time_text
    assert "My hint" not in time_text
    assert "silver acorn" not in time_text

    date_reply = client.post(
        "/api/assistant",
        json={"session_id": session_id, "message": "What day of the week is it?"},
    )
    assert date_reply.status_code == 200
    date_text = date_reply.json()["reply"]
    _assert_concise_overlay_reply(date_text, limit=120)
    assert "Today is" in date_text
    assert "My hint" not in date_text

    system_reply = client.post(
        "/api/assistant",
        json={"session_id": session_id, "message": "What is your system status?"},
    )
    assert system_reply.status_code == 200
    system_text = system_reply.json()["reply"]
    _assert_concise_overlay_reply(system_text)
    assert "System: API awake" in system_text
    assert "backend" in system_text
    assert "model" in system_text
    assert "Adventure:" not in system_text
    assert "My hint" not in system_text


def test_assistant_routes_weather_questions_without_inventing_forecast() -> None:
    client = TestClient(app)
    start = client.post("/api/start", json={"genre": "whispering_wood"})
    assert start.status_code == 200
    session_id = start.json()["session_id"]

    umbrella = client.post(
        "/api/assistant",
        json={"session_id": session_id, "message": "Should I take an umbrella today?"},
    )
    assert umbrella.status_code == 200
    umbrella_text = umbrella.json()["reply"]
    _assert_concise_overlay_reply(umbrella_text)
    assert "Weather:" in umbrella_text
    assert "umbrella" in umbrella_text
    assert "live forecast" in umbrella_text
    assert "My hint" not in umbrella_text

    beautiful = client.post(
        "/api/assistant",
        json={"session_id": session_id, "message": "It's beautiful weather, isn't it?"},
    )
    assert beautiful.status_code == 200
    beautiful_text = beautiful.json()["reply"]
    _assert_concise_overlay_reply(beautiful_text)
    assert "beautiful" in beautiful_text
    assert "check-in" in beautiful_text
    assert "My hint" not in beautiful_text


def test_assistant_does_not_treat_general_help_as_adventure_hint() -> None:
    client = TestClient(app)
    start = client.post("/api/start", json={"genre": "whispering_wood"})
    assert start.status_code == 200
    session_id = start.json()["session_id"]

    response = client.post(
        "/api/assistant",
        json={"session_id": session_id, "message": "I need help focusing."},
    )

    assert response.status_code == 200
    reply = response.json()["reply"]
    assert "tiny visible step" in reply
    assert "My hint" not in reply


def test_assistant_hi_returns_non_empty_chat_reply(monkeypatch) -> None:
    monkeypatch.setattr("app.llama_backend.configured_backend", lambda: None)
    monkeypatch.delenv("POCKETDM_LLAMA_SERVER_URL", raising=False)
    monkeypatch.delenv("POCKETDM_ASSISTANT_LLAMA_URL", raising=False)
    client = TestClient(app)
    start = client.post("/api/start", json={"genre": "whispering_wood"})
    assert start.status_code == 200
    session_id = start.json()["session_id"]

    response = client.post(
        "/api/assistant",
        json={"session_id": session_id, "message": "hi"},
    )

    assert response.status_code == 200
    reply = response.json()["reply"]
    assert isinstance(reply, str)
    assert reply.strip()
    assert reply.startswith("Pika pika!")
    assert "My hint" not in reply
    assert "silver acorn" not in reply


def test_assistant_composes_weather_affirmation_checkin() -> None:
    client = TestClient(app)
    start = client.post("/api/start", json={"genre": "whispering_wood"})
    assert start.status_code == 200
    session_id = start.json()["session_id"]

    response = client.post(
        "/api/assistant",
        json={
            "session_id": session_id,
            "message": (
                "Morning weather check-in.\n"
                "Weather line: It's beautiful weather 72°, isn't it?\n"
                "Affirmation title: Morning Spark\n"
                "Affirmation line: Start with one tiny win.\n"
                "Requirements: Do not give an adventure hint."
            ),
        },
    )

    assert response.status_code == 200
    reply = response.json()["reply"]
    assert "Pika pika!" in reply
    assert "beautiful weather" in reply
    assert "Morning Spark" in reply
    assert "check-in" in reply
    assert "My hint" not in reply


def test_custom_server_accepts_explicit_lore_voice_selection() -> None:
    client = TestClient(app)

    start = client.post(
        "/api/start",
        json={"genre": "derelict_starship", "voice": "lore"},
    )

    assert start.status_code == 200
    assert start.json()["state"]["voice"] == "lore"


def test_named_gradio_api_wrappers_share_session_flow() -> None:
    first = new_game(
        genre="derelict_starship",
        premise="The hatch is judging us.",
        voice="lore",
    )

    assert first["session_id"]
    assert first["state"]["voice"] == "lore"
    assert first["turn"]["choices"]

    second = take_turn(
        session_id=first["session_id"],
        action=first["turn"]["choices"][0],
    )

    assert second["state"]["turn_count"] == 2
    assert second["state"]["last_turn_tokens_per_second"] is None
    assert second["turn"]["choices"]


def test_custom_server_rejects_unknown_session() -> None:
    client = TestClient(app)

    response = client.post(
        "/api/assistant",
        json={"session_id": "missing", "message": "hint"},
    )

    assert response.status_code == 404


def test_tts_preload_env_flag_is_explicit(monkeypatch) -> None:
    monkeypatch.delenv("POCKETDM_TTS_PRELOAD", raising=False)
    assert _truthy_env("POCKETDM_TTS_PRELOAD") is False

    monkeypatch.setenv("POCKETDM_TTS_PRELOAD", "1")
    assert _truthy_env("POCKETDM_TTS_PRELOAD") is True

    monkeypatch.setenv("POCKETDM_TTS_PRELOAD", "off")
    assert _truthy_env("POCKETDM_TTS_PRELOAD") is False


def test_custom_server_scripted_demo_reaches_one_stable_ending_without_bridge() -> None:
    client = TestClient(app)

    start = client.post(
        "/api/start",
        json={"genre": "whispering_wood", "premise": "The acorns are voting."},
    )
    assert start.status_code == 200
    body = start.json()
    session_id = body["session_id"]

    turns = [body["turn"]]
    state = body["state"]
    while not turns[-1]["is_ending"]:
        response = client.post(
            "/api/choose",
            json={"session_id": session_id, "action": turns[-1]["choices"][0]},
        )
        assert response.status_code == 200
        body = response.json()
        turns.append(body["turn"])
        state = body["state"]

    assert len(turns) == 9
    assert all(turn["used_bridge"] is False for turn in turns)
    assert turns[-1]["ending_type"] == "victory"
    assert state["turn_count"] == 9

    after_ending = client.post(
        "/api/choose",
        json={"session_id": session_id, "action": turns[-1]["choices"][0]},
    )
    assert after_ending.status_code == 200
    after_body = after_ending.json()
    assert after_body["state"]["turn_count"] == 9
    assert after_body["turn"]["is_ending"] is True
