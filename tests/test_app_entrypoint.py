from __future__ import annotations

import runpy
from pathlib import Path

from app import server
from fastapi.testclient import TestClient


def test_root_entrypoint_binds_companion_server_to_loopback(monkeypatch) -> None:
    launches: list[dict[str, object]] = []
    monkeypatch.setenv("POCKETDM_TTS_PRELOAD", "0")
    monkeypatch.setattr(server.app, "launch", lambda **kwargs: launches.append(kwargs))

    runpy.run_path(Path("app.py"), run_name="__main__")

    assert launches == [{"server_name": "127.0.0.1", "server_port": 7860}]


def test_companion_server_rejects_non_loopback_clients() -> None:
    remote = TestClient(server.app, client=("192.0.2.10", 50000))

    assert remote.get("/health").status_code == 403
    assert remote.post("/api/start", json={"genre": "whispering_wood"}).status_code == 403
