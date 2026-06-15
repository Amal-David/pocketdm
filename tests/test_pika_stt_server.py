from __future__ import annotations

import io
import wave

from fastapi.testclient import TestClient

from app import pika_stt_server


def _client(monkeypatch, transcript: str = "hello pika") -> TestClient:
    monkeypatch.setenv("POCKETDM_PIKA_STT_BACKEND", "stub")
    monkeypatch.setenv("POCKETDM_PIKA_STT_STUB_TEXT", transcript)
    pika_stt_server._engine.cache_clear()
    return TestClient(pika_stt_server.create_app())


def _wav_bytes() -> bytes:
    out = io.BytesIO()
    with wave.open(out, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(16_000)
        wav.writeframes(b"\x00\x00" * 160)
    return out.getvalue()


def test_pika_stt_health_reports_stub_backend(monkeypatch) -> None:
    client = _client(monkeypatch)

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["backend"] == "stub"
    assert response.json()["loaded"] is False


def test_pika_stt_warmup_loads_stub_backend(monkeypatch) -> None:
    client = _client(monkeypatch)

    response = client.post("/warmup")

    assert response.status_code == 200
    assert response.json()["loaded"] is True


def test_pika_stt_transcribes_uploaded_audio_with_stub(monkeypatch) -> None:
    client = _client(monkeypatch, transcript="time for a daily check in")

    response = client.post(
        "/transcribe",
        files={"audio": ("speech.wav", _wav_bytes(), "audio/wav")},
    )

    assert response.status_code == 200
    assert response.json() == {"text": "time for a daily check in"}


def test_pika_stt_rejects_missing_audio(monkeypatch) -> None:
    client = _client(monkeypatch)

    response = client.post("/transcribe", files={"audio": ("speech.wav", b"", "audio/wav")})

    assert response.status_code == 400
    assert response.json()["detail"] == "missing audio"
