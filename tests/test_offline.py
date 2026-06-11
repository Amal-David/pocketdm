from __future__ import annotations

import socket

from fastapi.testclient import TestClient

from app.server import app


def test_scripted_play_loop_and_dragon_need_no_outbound_sockets(monkeypatch) -> None:
    attempted: list[tuple[object, object]] = []
    original_connect = socket.socket.connect

    def guarded_connect(self: socket.socket, address: object) -> None:
        attempted.append((self, address))
        raise AssertionError(f"unexpected outbound socket connect: {address!r}")

    monkeypatch.setattr(socket.socket, "connect", guarded_connect)
    client = TestClient(app)
    start = client.post(
        "/api/start",
        json={"genre": "cursed_dungeon", "premise": "The offline door blinks."},
    )
    assert start.status_code == 200
    body = start.json()

    hint = client.post(
        "/api/assistant",
        json={"session_id": body["session_id"], "message": "hint"},
    )
    assert hint.status_code == 200

    choice = client.post(
        "/api/choose",
        json={"session_id": body["session_id"], "action": body["turn"]["choices"][0]},
    )
    assert choice.status_code == 200

    sprite = client.get("/static/dragon-sprites.png")
    assert sprite.status_code == 200
    assert not attempted
    monkeypatch.setattr(socket.socket, "connect", original_connect)
