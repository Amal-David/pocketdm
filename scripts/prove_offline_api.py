from __future__ import annotations

import argparse
import json
import os
import socket
import time
from pathlib import Path
from typing import Any

from fastapi.testclient import TestClient


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--model", help="Optional local GGUF path for llama.cpp-backed play.")
    parser.add_argument("--genre", default="cursed_dungeon")
    parser.add_argument("--voice", default="lore")
    parser.add_argument("--premise", default="The offline door blinks twice before judging you.")
    parser.add_argument("--max-turns", type=int, default=15)
    parser.add_argument("--require-wav", action="store_true")
    args = parser.parse_args()

    if args.model:
        model = Path(args.model)
        if not model.exists():
            raise SystemExit(f"missing model: {model}")
        os.environ["POCKETDM_GGUF"] = str(model)
        os.environ.setdefault("POCKETDM_LLAMA_THREADS", "8")

    from app.server import app

    attempted_connections: list[str] = []
    original_connect = socket.socket.connect

    def guarded_connect(self: socket.socket, address: object) -> None:
        attempted_connections.append(repr(address))
        raise AssertionError(f"unexpected outbound socket connect: {address!r}")

    socket.socket.connect = guarded_connect
    started = time.monotonic()
    try:
        result = run_session(
            app=app,
            genre=args.genre,
            voice=args.voice,
            premise=args.premise,
            max_turns=args.max_turns,
            require_wav=args.require_wav,
        )
    finally:
        socket.socket.connect = original_connect

    result["duration_seconds"] = round(time.monotonic() - started, 2)
    result["outbound_connect_attempts"] = attempted_connections
    result["network_clean"] = not attempted_connections
    print(json.dumps(result, indent=2, sort_keys=True))

    if attempted_connections:
        raise SystemExit("offline proof failed: outbound socket attempt detected")
    if args.require_wav and result["tts_wav_turns"] != result["turns"]:
        raise SystemExit("offline proof failed: not every turn returned WAV narration")


def run_session(
    *,
    app: Any,
    genre: str,
    voice: str,
    premise: str,
    max_turns: int,
    require_wav: bool,
) -> dict[str, Any]:
    client = TestClient(app)
    start = client.post(
        "/api/start",
        json={"genre": genre, "voice": voice, "premise": premise},
    )
    start.raise_for_status()
    body = start.json()
    session_id = body["session_id"]
    turns = [body["turn"]]
    states = [body["state"]]
    tts_statuses = [tts_status(client, session_id, body["turn"]["narration"])]
    assistant = client.post(
        "/api/assistant",
        json={"session_id": session_id, "message": "status and hint please"},
    )
    assistant.raise_for_status()

    while not turns[-1]["is_ending"] and len(turns) < max_turns:
        choice = choose_action(turns[-1], len(turns))
        response = client.post(
            "/api/choose",
            json={"session_id": session_id, "action": choice},
        )
        response.raise_for_status()
        body = response.json()
        turns.append(body["turn"])
        states.append(body["state"])
        tts_statuses.append(tts_status(client, session_id, body["turn"]["narration"]))

    tts_wav_turns = sum(1 for status in tts_statuses if status["status"] == 200)
    if require_wav and tts_wav_turns != len(turns):
        missing = [status for status in tts_statuses if status["status"] != 200]
        raise RuntimeError(f"expected WAV for every turn, got missing statuses: {missing}")

    return {
        "backend": states[-1]["backend"],
        "voice": states[-1]["voice"],
        "session_id": session_id,
        "turns": len(turns),
        "ended": bool(turns[-1]["is_ending"]),
        "ending_type": turns[-1]["ending_type"],
        "bridges": sum(1 for turn in turns if turn["used_bridge"]),
        "tts_wav_turns": tts_wav_turns,
        "tts_statuses": tts_statuses,
        "final_state": states[-1],
        "assistant_reply": assistant.json()["reply"],
    }


def choose_action(turn: dict[str, Any], index: int) -> str:
    choices = list(turn["choices"])
    return choices[index % len(choices)]


def tts_status(client: TestClient, session_id: str, text: str) -> dict[str, Any]:
    response = client.post(
        "/api/tts",
        json={"session_id": session_id, "text": text},
    )
    return {
        "status": response.status_code,
        "content_type": response.headers.get("content-type"),
        "bytes": len(response.content),
        "x_pocketdm_tts": response.headers.get("x-pocketdm-tts"),
    }


if __name__ == "__main__":
    main()
