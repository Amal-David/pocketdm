from __future__ import annotations

import argparse
import io
import importlib
import json
import os
import tempfile
import time
import wave
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any
from urllib.error import URLError
from urllib.request import Request, urlopen

from fastapi import FastAPI, File, HTTPException, UploadFile, WebSocket, WebSocketDisconnect

MAX_AUDIO_BYTES = 30 * 1024 * 1024
DEFAULT_MODEL_ID = "nvidia/nemotron-speech-streaming-en-0.6b"
DEFAULT_NIM_FUNCTION_ID = "bb0837de-8c7b-481f-9ec8-ef5663e9c1fa"
DEFAULT_NIM_SERVER = "grpc.nvcf.nvidia.com:443"
DEFAULT_FALLBACK_URL = "http://127.0.0.1:7862"


@dataclass(frozen=True)
class NemotronASRSettings:
    backend: str
    model_id: str
    chunk_ms: int
    language: str
    fallback_backend: str
    fallback_url: str
    nim_server: str
    nim_function_id: str
    nim_use_ssl: bool
    local_model_path: str
    allow_download: bool


@dataclass(frozen=True)
class NemotronASRResult:
    text: str
    backend: str
    fallback_used: bool = False
    primary_error: str | None = None
    streaming_mode: str = "buffered-offline"
    audio_ms: float | None = None
    asr_request_ms: float | None = None
    chunks_received: int | None = None
    buffer_ms_to_end: float | None = None
    final_response_ms: float | None = None
    rtfx: float | None = None


class NemotronASRUnavailable(RuntimeError):
    pass


def _frames_for_result(result: NemotronASRResult, settings: NemotronASRSettings) -> list[dict[str, Any]]:
    text = result.text.strip()
    words = text.split()
    partial = " ".join(words[: max(1, min(2, len(words)))]) if words else ""
    frame_base: dict[str, Any] = {
        "chunk_ms": settings.chunk_ms,
        "backend": result.backend,
        "fallback_used": result.fallback_used,
        "streaming_mode": result.streaming_mode,
    }
    for key, value in _result_metrics(result).items():
        frame_base[key] = value
    if result.primary_error:
        frame_base["primary_error"] = result.primary_error
    return [
        {"type": "partial", "text": partial or "Transcribing...", **frame_base},
        {"type": "final", "text": text, **frame_base},
    ]


def _listening_frame(settings: NemotronASRSettings, backend: str) -> dict[str, Any]:
    return {
        "type": "partial",
        "text": "Nemotron ASR listening...",
        "chunk_ms": settings.chunk_ms,
        "backend": backend,
        "streaming_mode": "buffered-offline",
    }


class StubNemotronStreamingASR:
    def __init__(self, settings: NemotronASRSettings) -> None:
        self.settings = settings

    def transcript(self) -> str:
        return os.environ.get("POCKETDM_NEMOTRON_ASR_STUB_TEXT", "").strip() or "hello pika"

    def transcribe(self, _audio: bytes) -> NemotronASRResult:
        return NemotronASRResult(text=self.transcript(), backend="stub", streaming_mode="stub")

    def frames(self, audio: bytes) -> list[dict[str, Any]]:
        return _frames_for_result(self.transcribe(audio), self.settings)

    def preview_frame(self, audio: bytes) -> dict[str, Any]:
        return self.frames(audio)[0]


class RivaNIMNemotronStreamingASR:
    def __init__(self, settings: NemotronASRSettings) -> None:
        api_key = os.environ.get("NVIDIA_API_KEY", "").strip()
        if not api_key:
            raise NemotronASRUnavailable("NVIDIA_API_KEY is required for the hosted Nemotron/NIM ASR backend")
        self.settings = settings
        try:
            self.riva_client = importlib.import_module("riva.client")
        except Exception as exc:
            raise NemotronASRUnavailable(
                "nvidia-riva-client is not installed; install macos/PocketDMCompanion/scripts/nemotron_asr_requirements.txt"
            ) from exc

        auth = self.riva_client.Auth(
            uri=settings.nim_server,
            use_ssl=settings.nim_use_ssl,
            metadata_args=[
                ["function-id", settings.nim_function_id],
                ["authorization", f"Bearer {api_key}"],
            ],
        )
        self.asr_service = self.riva_client.ASRService(auth)

    def transcribe(self, audio: bytes) -> NemotronASRResult:
        config = self.riva_client.RecognitionConfig(
            language_code=self.settings.language,
            max_alternatives=1,
            enable_automatic_punctuation=True,
            enable_word_time_offsets=True,
        )
        try:
            response = self.asr_service.offline_recognize(audio, config)
        except Exception as exc:
            raise NemotronASRUnavailable(f"Nemotron/Riva ASR request failed: {exc}") from exc
        text = _extract_riva_transcript(response)
        if not text:
            raise NemotronASRUnavailable("Nemotron/Riva ASR returned no transcript")
        return NemotronASRResult(text=text, backend="riva-nim", streaming_mode="hosted-riva-offline")

    def frames(self, audio: bytes) -> list[dict[str, Any]]:
        return _frames_for_result(self.transcribe(audio), self.settings)

    def preview_frame(self, _audio: bytes) -> dict[str, Any]:
        return _listening_frame(self.settings, "riva-nim")


class LocalNemotronStreamingASR:
    def __init__(self, settings: NemotronASRSettings) -> None:
        self.settings = settings
        try:
            nemo_asr = importlib.import_module("nemo.collections.asr")
        except Exception as exc:
            raise NemotronASRUnavailable(
                "NeMo ASR is not installed; install NVIDIA NeMo ASR in the Nemotron environment for local-nemotron"
            ) from exc

        model_path = settings.local_model_path.strip()
        try:
            if model_path:
                path = Path(model_path).expanduser()
                if not path.exists():
                    raise NemotronASRUnavailable(f"local Nemotron model path does not exist: {path}")
                self.model = self._load_from_path(nemo_asr, path)
            else:
                cached_path = _cached_nemotron_model_file(settings.model_id)
                if cached_path is None and not settings.allow_download:
                    raise NemotronASRUnavailable(
                        "local Nemotron model is not cached; run `huggingface-cli download "
                        f"{settings.model_id} nemotron-speech-streaming-en-0.6b.nemo` or set "
                        "POCKETDM_NEMOTRON_ASR_ALLOW_DOWNLOAD=1"
                    )
                self.model = nemo_asr.models.ASRModel.from_pretrained(model_name=settings.model_id)
        except NemotronASRUnavailable:
            raise
        except Exception as exc:
            raise NemotronASRUnavailable(f"local Nemotron model load failed: {exc}") from exc

        if hasattr(self.model, "eval"):
            self.model.eval()

    @staticmethod
    def _load_from_path(nemo_asr: Any, path: Path) -> Any:
        model_file = path
        if path.is_dir():
            candidates = sorted(path.glob("*.nemo"))
            if not candidates:
                raise NemotronASRUnavailable(f"no .nemo file found in {path}")
            model_file = candidates[0]
        return nemo_asr.models.ASRModel.restore_from(restore_path=str(model_file))

    def transcribe(self, audio: bytes) -> NemotronASRResult:
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as temp:
            temp.write(audio)
            temp_path = Path(temp.name)
        try:
            text = self._transcribe_file(temp_path)
        finally:
            temp_path.unlink(missing_ok=True)
        if not text:
            raise NemotronASRUnavailable("local Nemotron returned no transcript")
        return NemotronASRResult(text=text, backend="local-nemotron", streaming_mode="local-nemotron-buffered")

    def _transcribe_file(self, path: Path) -> str:
        try:
            result = self.model.transcribe([str(path)], batch_size=1)
        except TypeError:
            result = self.model.transcribe(paths2audio_files=[str(path)], batch_size=1)
        return _extract_nemo_transcript(result)

    def frames(self, audio: bytes) -> list[dict[str, Any]]:
        return _frames_for_result(self.transcribe(audio), self.settings)

    def preview_frame(self, _audio: bytes) -> dict[str, Any]:
        return _listening_frame(self.settings, "local-nemotron")


class PikaSTTFallbackASR:
    def __init__(self, settings: NemotronASRSettings) -> None:
        self.settings = settings
        if not settings.fallback_url:
            raise NemotronASRUnavailable("POCKETDM_NEMOTRON_ASR_FALLBACK_URL is required for pika-stt fallback")

    def transcribe(self, audio: bytes) -> NemotronASRResult:
        endpoint = _pika_stt_transcribe_endpoint(self.settings.fallback_url)
        boundary = "PocketDMNemotronFallback"
        body = (
            f"--{boundary}\r\n"
            'Content-Disposition: form-data; name="audio"; filename="speech.wav"\r\n'
            "Content-Type: audio/wav\r\n\r\n"
        ).encode("utf-8") + audio + f"\r\n--{boundary}--\r\n".encode("utf-8")
        request = Request(
            endpoint,
            data=body,
            method="POST",
            headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
        )
        try:
            with urlopen(request, timeout=45) as response:
                payload = response.read()
        except (OSError, URLError, TimeoutError) as exc:
            raise NemotronASRUnavailable(f"faster-whisper fallback STT is unavailable at {endpoint}: {exc}") from exc
        try:
            data = json.loads(payload.decode("utf-8"))
        except json.JSONDecodeError as exc:
            raise NemotronASRUnavailable("faster-whisper fallback STT returned invalid JSON") from exc
        text = str(data.get("text", "")).strip()
        if not text:
            raise NemotronASRUnavailable("faster-whisper fallback STT returned no transcript")
        return NemotronASRResult(
            text=text,
            backend="pika-stt-fallback",
            fallback_used=True,
            streaming_mode="faster-whisper-fallback",
        )

    def frames(self, audio: bytes) -> list[dict[str, Any]]:
        return _frames_for_result(self.transcribe(audio), self.settings)

    def preview_frame(self, _audio: bytes) -> dict[str, Any]:
        return _listening_frame(self.settings, "pika-stt-fallback")


class FallbackNemotronStreamingASR:
    def __init__(
        self,
        settings: NemotronASRSettings,
        primary: RivaNIMNemotronStreamingASR | LocalNemotronStreamingASR | None,
        fallback: PikaSTTFallbackASR | StubNemotronStreamingASR | None,
        primary_error: str | None = None,
    ) -> None:
        self.settings = settings
        self.primary = primary
        self.fallback = fallback
        self.primary_error = primary_error

    def transcribe(self, audio: bytes) -> NemotronASRResult:
        if self.primary is not None:
            try:
                return self.primary.transcribe(audio)
            except NemotronASRUnavailable as exc:
                self.primary_error = str(exc)
        if self.fallback is None:
            raise NemotronASRUnavailable(self.primary_error or "Nemotron ASR backend is unavailable")
        result = self.fallback.transcribe(audio)
        return NemotronASRResult(
            text=result.text,
            backend=result.backend,
            fallback_used=True,
            primary_error=self.primary_error,
            streaming_mode=result.streaming_mode,
        )

    def frames(self, audio: bytes) -> list[dict[str, Any]]:
        return _frames_for_result(self.transcribe(audio), self.settings)

    def preview_frame(self, audio: bytes) -> dict[str, Any]:
        if self.primary is not None:
            return self.primary.preview_frame(audio)
        if self.fallback is not None:
            frame = self.fallback.preview_frame(audio)
            if self.primary_error:
                frame["primary_error"] = self.primary_error
            return frame
        return _listening_frame(self.settings, "unavailable")


def _extract_riva_transcript(response: Any) -> str:
    parts: list[str] = []
    for result in getattr(response, "results", []) or []:
        alternatives = getattr(result, "alternatives", []) or []
        if not alternatives:
            continue
        transcript = str(getattr(alternatives[0], "transcript", "")).strip()
        if transcript:
            parts.append(transcript)
    return " ".join(" ".join(parts).split())


def _extract_nemo_transcript(result: Any) -> str:
    if isinstance(result, str):
        return result.strip()
    if isinstance(result, (list, tuple)):
        if not result:
            return ""
        return _extract_nemo_transcript(result[0])
    if isinstance(result, dict):
        for key in ("text", "transcript", "pred_text"):
            if key in result:
                return str(result[key]).strip()
    for attr in ("text", "transcript", "pred_text"):
        value = getattr(result, attr, None)
        if value:
            return str(value).strip()
    return str(result).strip()


def _cached_nemotron_model_file(model_id: str) -> Path | None:
    try:
        hub = importlib.import_module("huggingface_hub")
    except Exception:
        return None
    try:
        sentinel = getattr(hub, "_CACHED_NO_EXIST", object())
        cached = hub.try_to_load_from_cache(model_id, "nemotron-speech-streaming-en-0.6b.nemo")
    except Exception:
        return None
    if not cached or cached is sentinel:
        return None
    path = Path(str(cached))
    return path if path.exists() else None


def _audio_duration_ms(audio: bytes) -> float | None:
    try:
        with wave.open(io.BytesIO(audio), "rb") as wav:
            frames = wav.getnframes()
            rate = wav.getframerate()
            if rate <= 0:
                return None
            return frames / rate * 1000
    except Exception:
        return None


def _with_metrics(
    result: NemotronASRResult,
    *,
    audio: bytes,
    asr_request_ms: float,
    chunks_received: int | None = None,
    buffer_ms_to_end: float | None = None,
    final_response_ms: float | None = None,
) -> NemotronASRResult:
    audio_ms = _audio_duration_ms(audio)
    rtfx = None
    if audio_ms is not None and asr_request_ms > 0:
        rtfx = audio_ms / asr_request_ms
    return NemotronASRResult(
        text=result.text,
        backend=result.backend,
        fallback_used=result.fallback_used,
        primary_error=result.primary_error,
        streaming_mode=result.streaming_mode,
        audio_ms=audio_ms,
        asr_request_ms=asr_request_ms,
        chunks_received=chunks_received,
        buffer_ms_to_end=buffer_ms_to_end,
        final_response_ms=final_response_ms,
        rtfx=rtfx,
    )


def _transcribe_with_metrics(
    audio: bytes,
    *,
    chunks_received: int | None = None,
    buffer_ms_to_end: float | None = None,
) -> NemotronASRResult:
    started = time.perf_counter()
    result = _engine().transcribe(audio)
    asr_request_ms = (time.perf_counter() - started) * 1000
    return _with_metrics(
        result,
        audio=audio,
        asr_request_ms=asr_request_ms,
        chunks_received=chunks_received,
        buffer_ms_to_end=buffer_ms_to_end,
        final_response_ms=asr_request_ms,
    )


def _result_metrics(result: NemotronASRResult) -> dict[str, Any]:
    metrics: dict[str, Any] = {}
    for key in (
        "audio_ms",
        "asr_request_ms",
        "chunks_received",
        "buffer_ms_to_end",
        "final_response_ms",
        "rtfx",
    ):
        value = getattr(result, key)
        if value is not None:
            metrics[key] = round(value, 3) if isinstance(value, float) else value
    return metrics


def _pika_stt_transcribe_endpoint(raw_url: str) -> str:
    base = raw_url.strip().rstrip("/")
    if base.endswith("/transcribe"):
        return base
    return f"{base}/transcribe"


def _fallback_engine(settings: NemotronASRSettings) -> PikaSTTFallbackASR | StubNemotronStreamingASR | None:
    if settings.fallback_backend in {"", "none", "off"}:
        return None
    if settings.fallback_backend == "pika-stt":
        return PikaSTTFallbackASR(settings)
    if settings.fallback_backend == "stub":
        return StubNemotronStreamingASR(settings)
    raise NemotronASRUnavailable(f"unknown Nemotron ASR fallback backend: {settings.fallback_backend}")


def create_app() -> FastAPI:
    app = FastAPI(title="PocketDM Nemotron Streaming ASR", version="0.1.0")

    @app.get("/health")
    async def health() -> dict[str, Any]:
        settings = _settings()
        return {
            "status": "ok",
            "backend": settings.backend,
            "loaded": _engine_loaded(),
            "model": settings.model_id,
            "chunk_ms": settings.chunk_ms,
            "language": settings.language,
            "nim_server": settings.nim_server,
            "nim_function_id": settings.nim_function_id,
            "fallback_backend": settings.fallback_backend,
            "fallback_url": settings.fallback_url,
            "local_model_path": settings.local_model_path,
            "allow_download": settings.allow_download,
            "websocket_protocol": "chunked-v1",
        }

    @app.post("/warmup")
    async def warmup() -> dict[str, Any]:
        try:
            _engine()
        except NemotronASRUnavailable as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        return {
            "status": "ready",
            "backend": _settings().backend,
            "loaded": _engine_loaded(),
            "fallback_backend": _settings().fallback_backend,
        }

    @app.post("/transcribe-file")
    async def transcribe_file(audio: UploadFile = File(...)) -> dict[str, Any]:
        payload = await audio.read()
        if not payload:
            raise HTTPException(status_code=400, detail="missing audio")
        if len(payload) > MAX_AUDIO_BYTES:
            raise HTTPException(status_code=413, detail="audio file is too large")
        try:
            result = _transcribe_with_metrics(payload)
        except NemotronASRUnavailable as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        response: dict[str, Any] = {
            "text": result.text,
            "backend": result.backend,
            "fallback_used": result.fallback_used,
            "model": _settings().model_id,
            "streaming_mode": result.streaming_mode,
            "metrics": _result_metrics(result),
        }
        if result.primary_error:
            response["primary_error"] = result.primary_error
        return response

    @app.websocket("/ws/transcribe")
    async def websocket_transcribe(websocket: WebSocket) -> None:
        await websocket.accept()
        chunks: list[bytes] = []
        streaming = False
        partial_sent = False
        stream_started_at: float | None = None
        try:
            while True:
                message = await websocket.receive()
                if message.get("type") == "websocket.disconnect":
                    return

                if payload := message.get("bytes"):
                    if not streaming:
                        if len(payload) > MAX_AUDIO_BYTES:
                            await websocket.send_json({"type": "error", "message": "audio file is too large"})
                            return
                        result = _transcribe_with_metrics(payload, chunks_received=1)
                        for frame in _frames_for_result(result, _settings()):
                            await websocket.send_json(frame)
                        return

                    chunks.append(payload)
                    total_bytes = sum(len(chunk) for chunk in chunks)
                    if total_bytes > MAX_AUDIO_BYTES:
                        await websocket.send_json({"type": "error", "message": "audio file is too large"})
                        return
                    if not partial_sent:
                        await websocket.send_json(_engine().preview_frame(b"".join(chunks)) | {"streaming": True})
                        partial_sent = True
                    continue

                text = (message.get("text") or "").strip()
                if not text:
                    continue
                try:
                    control = json.loads(text)
                except json.JSONDecodeError:
                    payload = text.encode("utf-8")
                    if len(payload) > MAX_AUDIO_BYTES:
                        await websocket.send_json({"type": "error", "message": "audio file is too large"})
                        return
                    result = _transcribe_with_metrics(payload, chunks_received=1)
                    for frame in _frames_for_result(result, _settings()):
                        await websocket.send_json(frame)
                    return

                control_type = str(control.get("type", "")).casefold()
                if control_type == "start":
                    streaming = True
                    stream_started_at = time.perf_counter()
                    chunks.clear()
                    partial_sent = False
                    await websocket.send_json({"type": "ready", "chunk_ms": _settings().chunk_ms})
                elif control_type == "end":
                    if not chunks:
                        await websocket.send_json({"type": "error", "message": "missing audio"})
                        return
                    final_started = time.perf_counter()
                    buffer_ms_to_end = None
                    if stream_started_at is not None:
                        buffer_ms_to_end = (final_started - stream_started_at) * 1000
                    result = _transcribe_with_metrics(
                        b"".join(chunks),
                        chunks_received=len(chunks),
                        buffer_ms_to_end=buffer_ms_to_end,
                    )
                    result = NemotronASRResult(
                        text=result.text,
                        backend=result.backend,
                        fallback_used=result.fallback_used,
                        primary_error=result.primary_error,
                        streaming_mode=result.streaming_mode,
                        audio_ms=result.audio_ms,
                        asr_request_ms=result.asr_request_ms,
                        chunks_received=result.chunks_received,
                        buffer_ms_to_end=result.buffer_ms_to_end,
                        final_response_ms=(time.perf_counter() - final_started) * 1000,
                        rtfx=result.rtfx,
                    )
                    for frame in _frames_for_result(result, _settings()):
                        if frame["type"] == "partial" and partial_sent:
                            continue
                        await websocket.send_json(frame | {"streaming": True})
                    return
                else:
                    await websocket.send_json({"type": "error", "message": f"unknown control frame: {control_type or 'missing'}"})
                    return
        except NemotronASRUnavailable as exc:
            await websocket.send_json({"type": "error", "message": str(exc)})
        except WebSocketDisconnect:
            return

    return app


@lru_cache(maxsize=1)
def _engine() -> StubNemotronStreamingASR | LocalNemotronStreamingASR | RivaNIMNemotronStreamingASR | FallbackNemotronStreamingASR:
    settings = _settings()
    if settings.backend == "stub":
        return StubNemotronStreamingASR(settings)
    if settings.backend == "pika-stt":
        return PikaSTTFallbackASR(settings)
    if settings.backend in {"local-nemotron", "nemo-local"}:
        primary: LocalNemotronStreamingASR | None = None
        primary_error: str | None = None
        try:
            primary = LocalNemotronStreamingASR(settings)
        except NemotronASRUnavailable as exc:
            primary_error = str(exc)
        fallback = _fallback_engine(settings)
        if primary is None and fallback is None:
            raise NemotronASRUnavailable(primary_error or "local Nemotron ASR is unavailable")
        return FallbackNemotronStreamingASR(settings, primary, fallback, primary_error)
    if settings.backend == "auto":
        primary: LocalNemotronStreamingASR | RivaNIMNemotronStreamingASR | None = None
        errors: list[str] = []
        try:
            primary = LocalNemotronStreamingASR(settings)
        except NemotronASRUnavailable as exc:
            errors.append(str(exc))
        if primary is None and os.environ.get("NVIDIA_API_KEY", "").strip():
            try:
                primary = RivaNIMNemotronStreamingASR(settings)
            except NemotronASRUnavailable as exc:
                errors.append(str(exc))
        return FallbackNemotronStreamingASR(settings, primary, _fallback_engine(settings), " | ".join(errors) or None)
    if settings.backend == "riva-nim":
        primary: RivaNIMNemotronStreamingASR | None = None
        primary_error: str | None = None
        try:
            primary = RivaNIMNemotronStreamingASR(settings)
        except NemotronASRUnavailable as exc:
            primary_error = str(exc)
        fallback = _fallback_engine(settings)
        if primary is None and fallback is None:
            raise NemotronASRUnavailable(primary_error or "Nemotron/Riva ASR is unavailable")
        return FallbackNemotronStreamingASR(settings, primary, fallback, primary_error)
    raise NemotronASRUnavailable(f"unknown Nemotron ASR backend: {settings.backend}")


def _engine_loaded() -> bool:
    return _engine.cache_info().currsize > 0


def _settings() -> NemotronASRSettings:
    fallback_url = (
        os.environ.get("POCKETDM_NEMOTRON_ASR_FALLBACK_URL", "").strip()
        or os.environ.get("POCKETDM_PIKA_STT_URL", "").strip()
        or DEFAULT_FALLBACK_URL
    )
    return NemotronASRSettings(
        backend=os.environ.get("POCKETDM_NEMOTRON_ASR_BACKEND", "auto").strip().casefold(),
        model_id=os.environ.get("POCKETDM_NEMOTRON_ASR_MODEL", DEFAULT_MODEL_ID).strip(),
        chunk_ms=int(os.environ.get("POCKETDM_NEMOTRON_ASR_CHUNK_MS", "560")),
        language=os.environ.get("POCKETDM_NEMOTRON_ASR_LANGUAGE", "en-US").strip(),
        fallback_backend=os.environ.get("POCKETDM_NEMOTRON_ASR_FALLBACK_BACKEND", "pika-stt").strip().casefold(),
        fallback_url=fallback_url,
        nim_server=os.environ.get("POCKETDM_NEMOTRON_ASR_NIM_SERVER", DEFAULT_NIM_SERVER).strip(),
        nim_function_id=os.environ.get("POCKETDM_NEMOTRON_ASR_FUNCTION_ID", DEFAULT_NIM_FUNCTION_ID).strip(),
        nim_use_ssl=os.environ.get("POCKETDM_NEMOTRON_ASR_USE_SSL", "1").strip().casefold() not in {"0", "false", "no"},
        local_model_path=os.environ.get("POCKETDM_NEMOTRON_ASR_MODEL_PATH", "").strip(),
        allow_download=os.environ.get("POCKETDM_NEMOTRON_ASR_ALLOW_DOWNLOAD", "0").strip().casefold() in {"1", "true", "yes"},
    )


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the opt-in Nemotron streaming ASR sidecar.")
    parser.add_argument("--host", default=os.environ.get("POCKETDM_NEMOTRON_ASR_HOST", "127.0.0.1"))
    parser.add_argument("--port", default=os.environ.get("POCKETDM_NEMOTRON_ASR_PORT", "7863"))
    parser.add_argument(
        "--backend",
        choices=("auto", "stub", "local-nemotron", "riva-nim", "pika-stt", "nemo-local"),
        default=os.environ.get("POCKETDM_NEMOTRON_ASR_BACKEND", "auto"),
    )
    parser.add_argument("--fallback-backend", choices=("pika-stt", "stub", "none"), default=os.environ.get("POCKETDM_NEMOTRON_ASR_FALLBACK_BACKEND", "pika-stt"))
    parser.add_argument("--fallback-url", default=os.environ.get("POCKETDM_NEMOTRON_ASR_FALLBACK_URL", ""))
    parser.add_argument("--warmup", action="store_true")
    args = parser.parse_args()

    os.environ["POCKETDM_NEMOTRON_ASR_BACKEND"] = args.backend
    os.environ["POCKETDM_NEMOTRON_ASR_FALLBACK_BACKEND"] = args.fallback_backend
    if args.fallback_url:
        os.environ["POCKETDM_NEMOTRON_ASR_FALLBACK_URL"] = args.fallback_url
    if args.warmup:
        _engine()

    import uvicorn

    uvicorn.run(create_app(), host=args.host, port=int(args.port), log_level="info")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
