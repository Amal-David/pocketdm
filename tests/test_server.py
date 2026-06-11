from fastapi.testclient import TestClient

from app.server import app


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
    assert "Ember" in body["assistant"]

    hint = client.post(
        "/api/assistant",
        json={"session_id": body["session_id"], "message": "hint"},
    )
    assert hint.status_code == 200
    assert "My hint" in hint.json()["reply"]


def test_custom_server_rejects_unknown_session() -> None:
    client = TestClient(app)

    response = client.post(
        "/api/assistant",
        json={"session_id": "missing", "message": "hint"},
    )

    assert response.status_code == 404


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
