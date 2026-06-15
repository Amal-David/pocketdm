from __future__ import annotations

import io
from types import SimpleNamespace
import wave

import pytest
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


def _speech_like_wav(*, lead_silence_ms: int = 400, speech_ms: int = 800, tail_silence_ms: int = 400) -> bytes:
    """A 16 kHz mono WAV with detectable speech-like energy bracketed by silence.

    Used to prove VAD trims silence: the trimmed clip must be shorter than the input.
    """
    import math

    rate = 16_000

    def _ms_to_samples(ms: int) -> int:
        return rate * ms // 1000

    silence_lead = b"\x00\x00" * _ms_to_samples(lead_silence_ms)
    silence_tail = b"\x00\x00" * _ms_to_samples(tail_silence_ms)
    speech = bytearray()
    for index in range(_ms_to_samples(speech_ms)):
        # ~180 Hz tone at high amplitude reads as voiced energy to the VAD.
        sample = int(22_000 * math.sin(2 * math.pi * 180 * index / rate))
        speech += int(sample).to_bytes(2, "little", signed=True)
    out = io.BytesIO()
    with wave.open(out, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(rate)
        wav.writeframes(silence_lead + bytes(speech) + silence_tail)
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


def test_preprocess_audio_disabled_returns_original_bytes(monkeypatch) -> None:
    # When both VAD and denoise are off, the audio must be passed through untouched
    # so we never alter what Nemotron hears unless preprocessing was explicitly asked for.
    monkeypatch.setenv("POCKETDM_NEMOTRON_VAD", "0")
    monkeypatch.setenv("POCKETDM_NEMOTRON_DENOISE", "0")
    audio = _speech_like_wav()

    assert nemotron_streaming_asr_server._preprocess_audio(audio) is audio


def test_preprocess_audio_non_wav_falls_back_to_original(monkeypatch) -> None:
    # A decode failure must never break STT: garbage in -> same garbage back out,
    # so the downstream transcriber still receives exactly what the caller sent.
    monkeypatch.setenv("POCKETDM_NEMOTRON_VAD", "1")
    junk = b"this is not a wav file"

    assert nemotron_streaming_asr_server._preprocess_audio(junk) == junk


def test_preprocess_audio_no_speech_detected_falls_back_to_original(monkeypatch) -> None:
    # When the VAD finds no speech spans, fall back to the original clip rather than
    # hand Nemotron an empty buffer (which would yield no transcript and a false failure).
    pytest.importorskip("silero_vad")
    import silero_vad

    monkeypatch.setenv("POCKETDM_NEMOTRON_VAD", "1")
    monkeypatch.setenv("POCKETDM_NEMOTRON_DENOISE", "0")
    nemotron_streaming_asr_server._silero_vad_model.cache_clear()
    monkeypatch.setattr(silero_vad, "get_speech_timestamps", lambda *a, **k: [])
    audio = _speech_like_wav(lead_silence_ms=300, speech_ms=600, tail_silence_ms=300)

    assert nemotron_streaming_asr_server._preprocess_audio(audio) == audio


def test_preprocess_audio_trims_to_detected_speech_spans(monkeypatch) -> None:
    # The core promise: VAD-detected speech is kept and the surrounding silence is
    # dropped, so the trimmed clip is strictly shorter than the padded input and only
    # contains the detected span. We stub the detector to assert OUR slicing/re-encode
    # logic, not Silero's acoustic model.
    pytest.importorskip("silero_vad")
    import silero_vad

    monkeypatch.setenv("POCKETDM_NEMOTRON_VAD", "1")
    monkeypatch.setenv("POCKETDM_NEMOTRON_DENOISE", "0")
    nemotron_streaming_asr_server._silero_vad_model.cache_clear()

    # Keep only the middle 600 ms (samples 4800..14400) of a 1200 ms clip.
    speech_span = [{"start": 4_800, "end": 14_400}]
    monkeypatch.setattr(silero_vad, "get_speech_timestamps", lambda *a, **k: speech_span)
    audio = _speech_like_wav(lead_silence_ms=300, speech_ms=600, tail_silence_ms=300)

    trimmed = nemotron_streaming_asr_server._preprocess_audio(audio)

    assert trimmed != audio
    with wave.open(io.BytesIO(audio), "rb") as original:
        original_frames = original.getnframes()
    with wave.open(io.BytesIO(trimmed), "rb") as result:
        assert result.getframerate() == 16_000
        assert result.getnchannels() == 1
        assert result.getnframes() == 14_400 - 4_800
        assert result.getnframes() < original_frames


# --- VAD-gated streaming turn loop ---------------------------------------------
#
# These tests prove OUR turn-loop wiring (the WebSocket VAD branch,
# ``_handle_vad_bytes``, ``_finalize_vad_turn``, and the click/cough drop rule)
# without depending on Silero's acoustic model: a scripted fake detector replays
# start/end events so the assertions encode *why* each frame is emitted.


class _ScriptedVADTurnDetector:
    """Fake StreamingVADTurnDetector: replays a pre-baked list of events per feed().

    Each ``feed`` call pops the next event group, so we can drive a precise
    multi-turn timeline (start -> end -> start -> end) and assert the server reacts.
    """

    def __init__(self, script: "list[list[tuple[str, float]]]") -> None:
        self._script = list(script)
        self.reset_calls = 0

    def feed(self, _pcm_bytes: bytes) -> "list[tuple[str, float]]":
        if not self._script:
            return []
        return self._script.pop(0)

    def reset(self) -> None:
        self.reset_calls += 1


def _pcm_chunk(num_samples: int = 512) -> bytes:
    return b"\x10\x00" * num_samples


def test_websocket_vad_turn_loop_finalizes_on_speech_ended_and_stays_open(monkeypatch) -> None:
    # The core promise of the VAD path: the SERVER decides a turn ended (no client
    # timer), emits speech_started/speech_ended, transcribes THAT turn, and keeps the
    # socket open so a second utterance is detected on the same connection.
    client = _client(monkeypatch, transcript="first turn text")

    # Turn 1 ends on the first byte chunk; turn 2 ends on the second.
    script = [
        [("start", 0.1), ("end", 0.9)],
        [("start", 1.5), ("end", 2.3)],
    ]
    detector = _ScriptedVADTurnDetector(script)
    monkeypatch.setattr(
        nemotron_streaming_asr_server,
        "StreamingVADTurnDetector",
        lambda _config: detector,
    )

    with client.websocket_connect("/ws/transcribe") as websocket:
        websocket.send_json({"type": "start", "sample_rate": 16_000, "vad": True})
        ready = websocket.receive_json()

        # Turn 1
        websocket.send_bytes(_pcm_chunk())
        started1 = websocket.receive_json()
        ended1 = websocket.receive_json()
        partial1 = websocket.receive_json()
        final1 = websocket.receive_json()

        # Turn 2 on the SAME socket (multi-turn).
        websocket.send_bytes(_pcm_chunk())
        started2 = websocket.receive_json()
        ended2 = websocket.receive_json()
        partial2 = websocket.receive_json()
        final2 = websocket.receive_json()

    assert ready == {"type": "ready", "chunk_ms": 560, "vad": True}
    assert started1 == {"type": "speech_started", "t": 0.1}
    assert ended1 == {"type": "speech_ended", "t": 0.9}
    assert partial1["type"] == "partial"
    assert final1["type"] == "final"
    assert final1["text"] == "first turn text"
    assert final1["streaming_mode"] == "vad-turn"
    assert final1["vad"] is True
    # Socket stayed open and detected a second utterance.
    assert started2 == {"type": "speech_started", "t": 1.5}
    assert ended2 == {"type": "speech_ended", "t": 2.3}
    assert final2["type"] == "final"
    assert final2["text"] == "first turn text"
    # The turn buffer + Silero state were reset between turns.
    assert detector.reset_calls >= 2


def test_websocket_vad_falls_back_to_legacy_when_detector_unavailable(monkeypatch) -> None:
    # If the VADIterator can't be built (silero missing), the server must NOT break
    # the socket: it advertises vad=False and the legacy end-triggers-transcribe path
    # still works, so older/degraded environments keep transcribing.
    client = _client(monkeypatch, transcript="legacy fallback works")

    def _boom(_config):
        raise RuntimeError("no silero_vad here")

    monkeypatch.setattr(nemotron_streaming_asr_server, "StreamingVADTurnDetector", _boom)

    with client.websocket_connect("/ws/transcribe") as websocket:
        websocket.send_json({"type": "start", "sample_rate": 16_000, "vad": True})
        ready = websocket.receive_json()
        websocket.send_bytes(_wav_bytes())
        partial = websocket.receive_json()
        websocket.send_json({"type": "end"})
        final = websocket.receive_json()

    assert ready["type"] == "ready"
    assert ready["vad"] is False
    assert "vad_error" in ready
    assert partial["type"] == "partial"
    assert final["type"] == "final"
    assert final["text"] == "legacy fallback works"


def test_websocket_without_vad_flag_keeps_legacy_end_triggered_behavior(monkeypatch) -> None:
    # Backward compat: a start frame WITHOUT vad:true must behave exactly as before —
    # the client's {"type":"end"} triggers the single buffered transcribe.
    client = _client(monkeypatch, transcript="legacy chunked")

    with client.websocket_connect("/ws/transcribe") as websocket:
        websocket.send_json({"type": "start", "format": "wav", "sample_rate": 16_000})
        ready = websocket.receive_json()
        websocket.send_bytes(_wav_bytes())
        partial = websocket.receive_json()
        websocket.send_json({"type": "end"})
        final = websocket.receive_json()

    assert ready == {"type": "ready", "chunk_ms": 560}
    assert "vad" not in ready
    assert partial["type"] == "partial"
    assert final["type"] == "final"
    assert final["text"] == "legacy chunked"


def test_streaming_vad_detector_drops_sub_min_speech_blips() -> None:
    # A start immediately followed by an end inside min_speech_ms is a click/cough,
    # not speech: the detector must retract the start so no turn is opened.
    pytest.importorskip("silero_vad")
    nemotron_streaming_asr_server._silero_vad_model.cache_clear()

    config = nemotron_streaming_asr_server.VADTurnConfig(
        threshold=0.5, min_silence_ms=700, speech_pad_ms=300, min_speech_ms=200
    )
    detector = nemotron_streaming_asr_server.StreamingVADTurnDetector(config)

    # Replace Silero's per-frame call with a scripted sequence: a 50 ms blip
    # (start 0.00 -> end 0.05) then real speech (start 0.20 -> end 1.00).
    frame_events = iter(
        [{"start": 0.0}, None, {"end": 0.05}, None, {"start": 0.20}, None, {"end": 1.00}]
    )
    detector._iterator = lambda *_a, **_k: next(frame_events, None)  # type: ignore[assignment]

    # 7 full 512-sample frames so the loop calls the scripted iterator 7 times.
    events = detector.feed(b"\x10\x00" * (512 * 7))

    # The blip's start is retracted (no "start"/"end" pair for it); only the real
    # utterance survives.
    starts = [t for kind, t in events if kind == "start"]
    ends = [t for kind, t in events if kind == "end"]
    assert starts == [0.20]
    assert ends == [1.00]


def test_streaming_vad_detector_runs_real_vaditerator_start_then_end(monkeypatch) -> None:
    # Integration through the REAL Silero VADIterator state machine (its
    # silence-duration counting, speech padding, and 512-sample contract), driven by
    # a controlled per-frame speech probability so the test does not depend on a
    # real-speech audio fixture (a pure synthetic tone reads as non-speech to Silero).
    pytest.importorskip("silero_vad")
    import torch

    nemotron_streaming_asr_server._silero_vad_model.cache_clear()

    config = nemotron_streaming_asr_server.VADTurnConfig(
        threshold=0.5, min_silence_ms=128, speech_pad_ms=0, min_speech_ms=0
    )
    detector = nemotron_streaming_asr_server.StreamingVADTurnDetector(config)

    # 6 silent frames, 12 "loud" frames, 12 silent frames. We override only the model's
    # speech probability; VADIterator still does all start/end bookkeeping itself.
    loud = [False] * 6 + [True] * 12 + [False] * 12
    call = {"i": 0}
    inner_model = detector._iterator.model  # the real Silero callable

    def fake_prob(_x, _sr):  # mimic model(frame, sr) -> tensor probability
        idx = call["i"]
        call["i"] += 1
        is_loud = loud[idx] if idx < len(loud) else False
        return torch.tensor([[0.95 if is_loud else 0.02]])

    monkeypatch.setattr(detector._iterator, "model", fake_prob)

    events: list[tuple[str, float]] = []
    pcm_one_frame = b"\x10\x00" * 512
    for _ in range(len(loud)):
        events.extend(detector.feed(pcm_one_frame))

    kinds = [kind for kind, _ in events]
    assert "start" in kinds
    assert "end" in kinds
    # Start precedes end, exactly one confirmed turn.
    assert kinds.index("start") < kinds.index("end")
    assert kinds.count("start") == 1
    assert kinds.count("end") == 1
    # ``inner_model`` is the same object we patched off of; sanity that we used the real iterator.
    assert inner_model is not fake_prob
