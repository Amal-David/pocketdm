from __future__ import annotations

from fastapi.testclient import TestClient

from app import nemotron_streaming_asr_server, pika_stt_server, pika_tts_server


def _tts_client(monkeypatch) -> TestClient:
    monkeypatch.setenv("POCKETDM_PIKA_TTS_BACKEND", "stub")
    pika_tts_server._voice.cache_clear()
    return TestClient(pika_tts_server.create_app())


def _pika_stt_client(monkeypatch, transcript: str) -> TestClient:
    monkeypatch.setenv("POCKETDM_PIKA_STT_BACKEND", "stub")
    monkeypatch.setenv("POCKETDM_PIKA_STT_STUB_TEXT", transcript)
    pika_stt_server._engine.cache_clear()
    return TestClient(pika_stt_server.create_app())


def _nemotron_client(monkeypatch, transcript: str) -> TestClient:
    monkeypatch.setenv("POCKETDM_NEMOTRON_ASR_BACKEND", "stub")
    monkeypatch.setenv("POCKETDM_NEMOTRON_ASR_STUB_TEXT", transcript)
    nemotron_streaming_asr_server._engine.cache_clear()
    return TestClient(nemotron_streaming_asr_server.create_app())


def _generated_pika_wav(monkeypatch) -> bytes:
    response = _tts_client(monkeypatch).post(
        "/tts",
        json={"text": "Pika pika, voice loop check.", "voice": "pika-original", "format": "wav"},
    )
    assert response.status_code == 200
    assert response.content[:4] == b"RIFF"
    assert b"WAVE" in response.content[:16]
    return response.content


def test_generated_tts_wav_can_be_uploaded_to_pika_stt_stub(monkeypatch) -> None:
    audio = _generated_pika_wav(monkeypatch)
    client = _pika_stt_client(monkeypatch, transcript="voice loop check")

    response = client.post(
        "/transcribe",
        files={"audio": ("pika.wav", audio, "audio/wav")},
    )

    assert response.status_code == 200
    assert response.json() == {"text": "voice loop check"}


def test_generated_tts_wav_can_be_uploaded_to_nemotron_asr_stub(monkeypatch) -> None:
    audio = _generated_pika_wav(monkeypatch)
    client = _nemotron_client(monkeypatch, transcript="voice loop check")

    response = client.post(
        "/transcribe-file",
        files={"audio": ("pika.wav", audio, "audio/wav")},
    )

    assert response.status_code == 200
    assert response.json()["text"] == "voice loop check"
    assert response.json()["backend"] == "stub"
