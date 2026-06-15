from __future__ import annotations

import argparse
import importlib
import os
import tempfile
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any

from fastapi import FastAPI, File, HTTPException, UploadFile

MAX_AUDIO_BYTES = 30 * 1024 * 1024


@dataclass(frozen=True)
class PikaSTTSettings:
    backend: str
    model_id: str
    device: str
    compute_type: str
    language: str | None


class PikaSTTUnavailable(RuntimeError):
    pass


class StubSpeechToText:
    def transcribe(self, audio_path: Path, language: str | None) -> str:
        transcript = os.environ.get("POCKETDM_PIKA_STT_STUB_TEXT", "").strip()
        return transcript or "hello pikachu"


class FasterWhisperSpeechToText:
    def __init__(self, settings: PikaSTTSettings) -> None:
        try:
            module = importlib.import_module("faster_whisper")
            model_class = getattr(module, "WhisperModel")
        except Exception as exc:  # pragma: no cover - exercised by endpoint status
            raise PikaSTTUnavailable(
                "faster-whisper is not installed; start the STT sidecar first"
            ) from exc

        self.model = model_class(
            settings.model_id,
            device=_resolve_device(settings.device),
            compute_type=settings.compute_type,
        )

    def transcribe(self, audio_path: Path, language: str | None) -> str:
        try:
            segments, _info = self.model.transcribe(
                str(audio_path),
                language=language,
                vad_filter=True,
                beam_size=1,
            )
        except TypeError:
            segments, _info = self.model.transcribe(str(audio_path), language=language)
        text = " ".join(segment.text.strip() for segment in segments if segment.text.strip())
        return " ".join(text.split())


def create_app() -> FastAPI:
    app = FastAPI(title="PocketDM Pika STT", version="0.1.0")

    @app.get("/health")
    async def health() -> dict[str, Any]:
        settings = _settings()
        return {
            "status": "ok",
            "backend": settings.backend,
            "loaded": _engine_loaded(),
            "model": settings.model_id,
            "device": settings.device,
            "compute_type": settings.compute_type,
            "language": settings.language,
        }

    @app.post("/warmup")
    async def warmup() -> dict[str, Any]:
        try:
            _engine()
        except PikaSTTUnavailable as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        return {"status": "ready", "backend": _settings().backend, "loaded": _engine_loaded()}

    @app.post("/transcribe")
    async def transcribe(audio: UploadFile = File(...), language: str | None = None) -> dict[str, str]:
        payload = await audio.read()
        if not payload:
            raise HTTPException(status_code=400, detail="missing audio")
        if len(payload) > MAX_AUDIO_BYTES:
            raise HTTPException(status_code=413, detail="audio file is too large")
        suffix = Path(audio.filename or "speech.wav").suffix or ".wav"
        with tempfile.NamedTemporaryFile(suffix=suffix, delete=False) as temp:
            temp.write(payload)
            temp_path = Path(temp.name)
        try:
            transcript = _engine().transcribe(temp_path, language or _settings().language)
        except PikaSTTUnavailable as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        finally:
            temp_path.unlink(missing_ok=True)
        return {"text": transcript}

    return app


@lru_cache(maxsize=1)
def _engine() -> StubSpeechToText | FasterWhisperSpeechToText:
    settings = _settings()
    if settings.backend == "stub":
        return StubSpeechToText()
    if settings.backend == "faster-whisper":
        return FasterWhisperSpeechToText(settings)
    raise PikaSTTUnavailable(f"unknown Pika STT backend: {settings.backend}")


def _engine_loaded() -> bool:
    return _engine.cache_info().currsize > 0


def _settings() -> PikaSTTSettings:
    language = os.environ.get("POCKETDM_PIKA_STT_LANGUAGE", "en").strip() or None
    return PikaSTTSettings(
        backend=os.environ.get("POCKETDM_PIKA_STT_BACKEND", "faster-whisper").strip().casefold(),
        model_id=os.environ.get("POCKETDM_PIKA_STT_MODEL", "Systran/faster-whisper-small.en").strip(),
        device=os.environ.get("POCKETDM_PIKA_STT_DEVICE", "auto").strip().casefold(),
        compute_type=os.environ.get("POCKETDM_PIKA_STT_COMPUTE_TYPE", "int8").strip(),
        language=language,
    )


def _resolve_device(raw_device: str) -> str:
    if raw_device in {"auto", ""}:
        try:
            import torch

            if torch.backends.mps.is_available():
                return "auto"
            if torch.cuda.is_available():
                return "cuda"
        except Exception:
            return "cpu"
        return "cpu"
    return raw_device


def main() -> int:
    parser = argparse.ArgumentParser(description="Run the local Pika STT sidecar.")
    parser.add_argument("--host", default=os.environ.get("POCKETDM_PIKA_STT_HOST", "127.0.0.1"))
    parser.add_argument("--port", default=os.environ.get("POCKETDM_PIKA_STT_PORT", "7862"))
    parser.add_argument("--backend", choices=("faster-whisper", "stub"), default=os.environ.get("POCKETDM_PIKA_STT_BACKEND", "faster-whisper"))
    parser.add_argument("--warmup", action="store_true")
    args = parser.parse_args()

    os.environ["POCKETDM_PIKA_STT_BACKEND"] = args.backend
    if args.warmup:
        _engine()

    import uvicorn

    uvicorn.run(create_app(), host=args.host, port=int(args.port), log_level="info")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
