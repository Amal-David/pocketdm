from __future__ import annotations

import io
from types import SimpleNamespace
import wave

from fastapi.testclient import TestClient

from app import nemotron_streaming_asr_server


def _client(monkeypatch, transcript: str = "hello streaming pika") -> TestClient:
    monkeypatch.setenv("POCKETDM_NEMOTRON_ASR_BACKEND", "stub")
    monkeypatch.setenv("POCKETDM_NEMOTRON_ASR_STUB_TEXT", transcript)
    nemotron_streaming_asr_server._engine.cache_clear()
    return TestClient(nemotron_streaming_asr_server.create_app())


def _wav_bytes() -> bytes:
    out = io.BytesIO()
    with wave.open(out, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(16_000)
        wav.writeframes(b"\x00\x00" * 160)
    return out.getvalue()


def test_nemotron_health_reports_stub_backend(monkeypatch) -> None:
    client = _client(monkeypatch)

    response = client.get("/health")

    assert response.status_code == 200
    assert response.json()["backend"] == "stub"
    assert response.json()["model"] == "nvidia/nemotron-speech-streaming-en-0.6b"
    assert response.json()["websocket_protocol"] == "chunked-v1"
    assert response.json()["nim_function_id"] == "bb0837de-8c7b-481f-9ec8-ef5663e9c1fa"


def test_nemotron_warmup_loads_stub_backend(monkeypatch) -> None:
    client = _client(monkeypatch)

    response = client.post("/warmup")

    assert response.status_code == 200
    assert response.json()["loaded"] is True


def test_nemotron_transcribe_file_uses_stub_final(monkeypatch) -> None:
    client = _client(monkeypatch, transcript="water break logged")

    response = client.post(
        "/transcribe-file",
        files={"audio": ("speech.wav", _wav_bytes(), "audio/wav")},
    )

    assert response.status_code == 200
    assert response.json()["text"] == "water break logged"
    assert response.json()["backend"] == "stub"
    assert response.json()["fallback_used"] is False


def test_nemotron_websocket_emits_partial_and_final(monkeypatch) -> None:
    client = _client(monkeypatch, transcript="hello streaming pika")

    with client.websocket_connect("/ws/transcribe") as websocket:
        websocket.send_bytes(_wav_bytes())
        partial = websocket.receive_json()
        final = websocket.receive_json()

    assert partial["type"] == "partial"
    assert partial["text"] == "hello streaming"
    assert partial["chunk_ms"] == 560
    assert partial["backend"] == "stub"
    assert partial["fallback_used"] is False
    assert final["type"] == "final"
    assert final["text"] == "hello streaming pika"
    assert final["chunk_ms"] == 560
    assert final["backend"] == "stub"
    assert final["fallback_used"] is False
    assert final["streaming_mode"] == "stub"
    assert final["audio_ms"] > 0
    assert final["asr_request_ms"] >= 0
    assert final["rtfx"] >= 0


def test_nemotron_websocket_accepts_chunked_audio_protocol(monkeypatch) -> None:
    client = _client(monkeypatch, transcript="chunked voice works")
    payload = _wav_bytes()

    with client.websocket_connect("/ws/transcribe") as websocket:
        websocket.send_json({"type": "start", "format": "wav", "sample_rate": 16_000})
        ready = websocket.receive_json()
        websocket.send_bytes(payload[:32])
        partial = websocket.receive_json()
        websocket.send_bytes(payload[32:])
        websocket.send_json({"type": "end"})
        final = websocket.receive_json()

    assert ready == {"type": "ready", "chunk_ms": 560}
    assert partial["type"] == "partial"
    assert partial["text"] == "chunked voice"
    assert partial["chunk_ms"] == 560
    assert partial["backend"] == "stub"
    assert partial["fallback_used"] is False
    assert partial["streaming"] is True
    assert partial["streaming_mode"] == "stub"
    assert final["type"] == "final"
    assert final["text"] == "chunked voice works"
    assert final["chunk_ms"] == 560
    assert final["backend"] == "stub"
    assert final["fallback_used"] is False
    assert final["streaming"] is True
    assert final["chunks_received"] == 2
    assert final["buffer_ms_to_end"] >= 0
    assert final["final_response_ms"] >= 0


def test_nemotron_riva_nim_without_key_uses_visible_stub_fallback(monkeypatch) -> None:
    monkeypatch.setenv("POCKETDM_NEMOTRON_ASR_BACKEND", "riva-nim")
    monkeypatch.setenv("POCKETDM_NEMOTRON_ASR_FALLBACK_BACKEND", "stub")
    monkeypatch.setenv("POCKETDM_NEMOTRON_ASR_STUB_TEXT", "fallback transcript")
    monkeypatch.delenv("NVIDIA_API_KEY", raising=False)
    nemotron_streaming_asr_server._engine.cache_clear()
    client = TestClient(nemotron_streaming_asr_server.create_app())

    response = client.post("/warmup")

    assert response.status_code == 200

    response = client.post(
        "/transcribe-file",
        files={"audio": ("speech.wav", _wav_bytes(), "audio/wav")},
    )

    assert response.status_code == 200
    payload = response.json()
    assert payload["text"] == "fallback transcript"
    assert payload["backend"] == "stub"
    assert payload["fallback_used"] is True
    assert "NVIDIA_API_KEY" in payload["primary_error"]


def test_nemotron_riva_nim_calls_nvidia_riva_client(monkeypatch) -> None:
    calls: dict[str, object] = {}

    class FakeRecognitionConfig:
        def __init__(self, **kwargs) -> None:
            calls["config"] = kwargs

    class FakeASRService:
        def __init__(self, auth) -> None:
            calls["auth"] = auth

        def offline_recognize(self, audio_bytes: bytes, config: FakeRecognitionConfig):
            calls["audio"] = audio_bytes
            calls["offline_config"] = config
            return SimpleNamespace(
                results=[
                    SimpleNamespace(
                        alternatives=[SimpleNamespace(transcript="hello from real nemotron")]
                    )
                ]
            )

    class FakeRivaClient:
        RecognitionConfig = FakeRecognitionConfig
        ASRService = FakeASRService

        class Auth:
            def __init__(self, **kwargs) -> None:
                calls["auth_kwargs"] = kwargs

    def fake_import(name: str):
        assert name == "riva.client"
        return FakeRivaClient

    monkeypatch.setenv("POCKETDM_NEMOTRON_ASR_BACKEND", "riva-nim")
    monkeypatch.setenv("POCKETDM_NEMOTRON_ASR_FALLBACK_BACKEND", "none")
    monkeypatch.setenv("NVIDIA_API_KEY", "nvapi-test")
    monkeypatch.setattr(nemotron_streaming_asr_server.importlib, "import_module", fake_import)
    nemotron_streaming_asr_server._engine.cache_clear()
    client = TestClient(nemotron_streaming_asr_server.create_app())

    response = client.post(
        "/transcribe-file",
        files={"audio": ("speech.wav", _wav_bytes(), "audio/wav")},
    )

    assert response.status_code == 200
    assert response.json()["text"] == "hello from real nemotron"
    assert response.json()["backend"] == "riva-nim"
    assert response.json()["fallback_used"] is False
    assert calls["auth_kwargs"] == {
        "uri": "grpc.nvcf.nvidia.com:443",
        "use_ssl": True,
        "metadata_args": [
            ["function-id", "bb0837de-8c7b-481f-9ec8-ef5663e9c1fa"],
            ["authorization", "Bearer nvapi-test"],
        ],
    }
    assert calls["config"] == {
        "language_code": "en-US",
        "max_alternatives": 1,
        "enable_automatic_punctuation": True,
        "enable_word_time_offsets": True,
    }


def test_nemotron_local_backend_loads_nemo_model_from_local_path(monkeypatch, tmp_path) -> None:
    calls: dict[str, object] = {}
    model_path = tmp_path / "nemotron-speech-streaming-en-0.6b.nemo"
    model_path.write_bytes(b"fake")

    class FakeModel:
        @classmethod
        def restore_from(cls, restore_path: str):
            calls["restore_path"] = restore_path
            return cls()

        def eval(self) -> None:
            calls["eval"] = True

        def transcribe(self, paths, batch_size: int):
            calls["transcribe_paths"] = paths
            calls["batch_size"] = batch_size
            return ["local nemotron transcript"]

    fake_nemo = SimpleNamespace(models=SimpleNamespace(ASRModel=FakeModel))

    def fake_import(name: str):
        if name == "nemo.collections.asr":
            return fake_nemo
        return importlib.import_module(name)

    import importlib

    monkeypatch.setenv("POCKETDM_NEMOTRON_ASR_BACKEND", "local-nemotron")
    monkeypatch.setenv("POCKETDM_NEMOTRON_ASR_FALLBACK_BACKEND", "none")
    monkeypatch.setenv("POCKETDM_NEMOTRON_ASR_MODEL_PATH", str(model_path))
    monkeypatch.setattr(nemotron_streaming_asr_server.importlib, "import_module", fake_import)
    nemotron_streaming_asr_server._engine.cache_clear()
    client = TestClient(nemotron_streaming_asr_server.create_app())

    response = client.post(
        "/transcribe-file",
        files={"audio": ("speech.wav", _wav_bytes(), "audio/wav")},
    )

    assert response.status_code == 200
    assert response.json()["text"] == "local nemotron transcript"
    assert response.json()["backend"] == "local-nemotron"
    assert response.json()["streaming_mode"] == "local-nemotron-buffered"
    assert response.json()["metrics"]["audio_ms"] > 0
    assert calls["restore_path"] == str(model_path)
    assert calls["eval"] is True
