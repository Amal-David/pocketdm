from fastapi.testclient import TestClient

from app.server import _truthy_env, app, new_game, take_turn


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

    hint = client.post(
        "/api/assistant",
        json={"session_id": body["session_id"], "message": "hint"},
    )
    assert hint.status_code == 200
    assert "My hint" in hint.json()["reply"]
    assert "precise" in hint.json()["reply"] or "state" in hint.json()["reply"]

    status = client.post(
        "/api/assistant",
        json={"session_id": body["session_id"], "message": "status"},
    )
    assert status.status_code == 200
    assert "10/10 HP" in status.json()["reply"]
    assert "Turn 1" in status.json()["reply"]


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
