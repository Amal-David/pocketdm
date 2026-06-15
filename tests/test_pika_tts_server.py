from __future__ import annotations

import array
import io
import math
import sys
import wave

from fastapi.testclient import TestClient

from app import pika_tts_server


def _client(monkeypatch) -> TestClient:
    monkeypatch.setenv("POCKETDM_PIKA_TTS_BACKEND", "stub")
    pika_tts_server._voice.cache_clear()
    return TestClient(pika_tts_server.create_app())


def test_pika_tts_health_reports_stub_backend(monkeypatch) -> None:
    client = _client(monkeypatch)

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["backend"] == "stub"
    assert response.json()["loaded"] is False


def test_pika_tts_warmup_loads_stub_backend(monkeypatch) -> None:
    client = _client(monkeypatch)

    response = client.post("/warmup")

    assert response.status_code == 200
    assert response.json()["status"] == "ready"
    assert response.json()["backend"] == "stub"
    assert response.json()["loaded"] is True


def test_pika_original_returns_signature_wav_bytes(monkeypatch) -> None:
    client = _client(monkeypatch)

    response = client.post(
        "/tts",
        json={"text": "Pika pika, you finished one tiny win.", "voice": "pika-original", "format": "wav"},
    )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("audio/wav")
    assert response.headers["x-pocketdm-pika-voice"] == "signature"
    assert response.content[:4] == b"RIFF"
    assert b"WAVE" in response.content[:16]


def test_pika_tts_stub_endpoint_returns_audible_wav(monkeypatch) -> None:
    client = _client(monkeypatch)

    response = client.post(
        "/tts",
        json={"text": "Pika pika, you finished one tiny win.", "voice": "pika-original", "format": "wav"},
    )

    assert response.status_code == 200
    assert response.headers["content-type"].startswith("audio/wav")
    assert response.content[:4] == b"RIFF"
    assert b"WAVE" in response.content[:16]
    with wave.open(io.BytesIO(response.content), "rb") as wav:
        assert wav.getnchannels() == 1
        assert wav.getsampwidth() == 2
        assert wav.getframerate() == pika_tts_server.DEFAULT_SAMPLE_RATE
        duration = wav.getnframes() / wav.getframerate()
        frames = wav.readframes(wav.getnframes())
        samples = array.array("h")
        samples.frombytes(frames)
        if sys.byteorder != "little":
            samples.byteswap()

    rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples))
    assert 0.2 <= duration <= 2.0
    assert rms > 500


def test_pika_tts_signature_voice_bypasses_only_stub_backend(monkeypatch) -> None:
    called = False

    def fake_voice():
        nonlocal called
        called = True
        raise pika_tts_server.PikaVoiceUnavailable("model backend requested")

    monkeypatch.setenv("POCKETDM_PIKA_TTS_BACKEND", "chatterbox")
    monkeypatch.setattr(pika_tts_server, "_voice", fake_voice)
    client = TestClient(pika_tts_server.create_app())

    response = client.post(
        "/tts",
        json={"text": "Pikaa Pikaa!", "voice": "pika-signature", "format": "wav"},
    )

    assert response.status_code == 503
    assert response.json()["detail"] == "model backend requested"
    assert called is True


def test_pika_tts_passes_actual_text_to_voxcpm_backend(monkeypatch) -> None:
    captured: dict[str, str] = {}

    class FakeVoice:
        def synthesize(self, text: str) -> bytes:
            captured["text"] = text
            return b"RIFFfakeWAVE"

    monkeypatch.setenv("POCKETDM_PIKA_TTS_BACKEND", "voxcpm")
    monkeypatch.setattr(pika_tts_server, "_voice", lambda: FakeVoice())
    client = TestClient(pika_tts_server.create_app())

    response = client.post(
        "/tts",
        json={"text": "Pika pika, you finished one tiny win.", "voice": "pika-signature", "format": "wav"},
    )

    assert response.status_code == 200
    assert response.headers["x-pocketdm-pika-voice"] == "voxcpm"
    assert response.content == b"RIFFfakeWAVE"
    # Regression: the model must synthesize the caller's text, not a canned "Pikaa! Pikaaa!".
    assert captured["text"] == "Pika pika, you finished one tiny win."


def test_pika_tts_does_not_rewrite_long_reply_for_model_backend(monkeypatch) -> None:
    captured: dict[str, str] = {}

    class FakeVoice:
        def synthesize(self, text: str) -> bytes:
            captured["text"] = text
            return b"RIFFfakeWAVE"

    monkeypatch.setenv("POCKETDM_PIKA_TTS_BACKEND", "voxcpm")
    monkeypatch.setattr(pika_tts_server, "_voice", lambda: FakeVoice())
    client = TestClient(pika_tts_server.create_app())

    reply = "I am doing very well. How are you doing?"
    response = client.post(
        "/tts",
        json={"text": reply, "voice": "pika-signature", "format": "wav"},
    )

    assert response.status_code == 200
    # The full reply reaches VoxCPM verbatim instead of being squashed to a mascot chirp.
    assert captured["text"] == reply


def test_pika_tts_normalizes_quiet_generation_to_audible_level() -> None:
    quiet = [0.001, -0.001] * 400

    normalized = pika_tts_server._normalized_samples(quiet)
    rms = math.sqrt(sum(sample * sample for sample in normalized) / len(normalized))
    peak = max(abs(sample) for sample in normalized)

    assert 0.09 <= rms <= 0.11
    assert peak <= 10 ** (-3 / 20)


def test_pika_tts_rejects_missing_text(monkeypatch) -> None:
    client = _client(monkeypatch)

    response = client.post("/tts", json={"text": "   "})

    assert response.status_code == 400
    assert response.json()["detail"] == "missing text"


def test_pika_tts_rejects_non_wav_format(monkeypatch) -> None:
    client = _client(monkeypatch)

    response = client.post("/tts", json={"text": "hello", "format": "mp3"})

    assert response.status_code == 400
    assert response.json()["detail"] == "only wav output is supported"
