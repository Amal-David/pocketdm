from __future__ import annotations

import argparse
import html
import importlib
import io
import math
import os
import wave
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import Any

from fastapi import FastAPI, HTTPException
from fastapi.responses import Response
from pydantic import BaseModel

DEFAULT_SAMPLE_RATE = 24_000
MAX_TEXT_CHARS = 320


class PikaTTSRequest(BaseModel):
    text: str
    voice: str = "pika-original"
    format: str = "wav"


@dataclass(frozen=True)
class PikaVoiceSettings:
    backend: str
    reference_audio: Path | None
    device: str
    model_id: str
    cfg_value: float
    inference_timesteps: int
    normalize: bool
    denoise: bool


class PikaVoiceUnavailable(RuntimeError):
    pass


class GeneratedChirpVoice:
    """Tiny original fallback for tests and sound checks, not a full TTS voice."""

    sample_rate = DEFAULT_SAMPLE_RATE

    def synthesize(self, text: str) -> bytes:
        signature = _signature_samples(text)
        if signature:
            return _wav_bytes(signature, self.sample_rate)

        chirps = 2 if len(text) < 60 else 3
        samples: list[float] = []
        for chirp_index in range(chirps):
            samples.extend(_chirp_samples(0.16, 660 + chirp_index * 150, 1260))
            samples.extend([0.0] * int(self.sample_rate * 0.045))
        samples.extend(_chirp_samples(0.11, 920, 1520, volume=0.24))
        return _wav_bytes(samples, self.sample_rate)


class ChatterboxPikaVoice:
    """Local Chatterbox backend with an optional consented/generated reference clip."""

    def __init__(self, settings: PikaVoiceSettings) -> None:
        try:
            module = importlib.import_module("chatterbox.tts")
            tts_class = getattr(module, "ChatterboxTTS")
        except Exception as exc:  # pragma: no cover - exercised by endpoint status
            raise PikaVoiceUnavailable(
                "chatterbox-tts is not installed; run with the pika-voice dependency group"
            ) from exc

        self.model = tts_class.from_pretrained(device=_resolve_device(settings.device))
        self.reference_audio = settings.reference_audio
        self.sample_rate = int(getattr(self.model, "sr", DEFAULT_SAMPLE_RATE))

    def synthesize(self, text: str) -> bytes:
        kwargs: dict[str, Any] = {}
        if self.reference_audio is not None:
            kwargs["audio_prompt_path"] = str(self.reference_audio)
        try:
            generated = self.model.generate(text, **kwargs)
        except TypeError:
            generated = self.model.generate(text)
        samples = _float_samples(generated)
        return _wav_bytes(samples, self.sample_rate)


class VoxCPMPikaVoice:
    """Local VoxCPM backend for crisp original Pika-like syllable speech."""

    def __init__(self, settings: PikaVoiceSettings) -> None:
        try:
            module = importlib.import_module("voxcpm")
            model_class = getattr(module, "VoxCPM")
        except Exception as exc:  # pragma: no cover - exercised by endpoint status
            raise PikaVoiceUnavailable(
                "voxcpm is not installed; start the sidecar with --backend voxcpm first"
            ) from exc

        try:
            self.model = model_class.from_pretrained(settings.model_id)
        except TypeError:
            self.model = model_class.from_pretrained(settings.model_id, device=_resolve_device(settings.device))

        self.reference_audio = settings.reference_audio
        self.prompt_text = os.environ.get("POCKETDM_PIKA_TTS_PROMPT_TEXT", "").strip() or None
        self.cfg_value = settings.cfg_value
        self.inference_timesteps = settings.inference_timesteps
        self.normalize = settings.normalize
        self.denoise = settings.denoise
        self.sample_rate = int(
            getattr(getattr(self.model, "tts_model", None), "sample_rate", DEFAULT_SAMPLE_RATE)
        )

    def synthesize(self, text: str) -> bytes:
        kwargs: dict[str, Any] = {
            "text": text,
            "cfg_value": self.cfg_value,
            "inference_timesteps": self.inference_timesteps,
            "normalize": self.normalize,
            "denoise": self.denoise,
        }
        if self.reference_audio is not None:
            kwargs["prompt_wav_path"] = str(self.reference_audio)
            kwargs["prompt_text"] = self.prompt_text
        try:
            generated = self.model.generate(**kwargs)
        except TypeError:
            generated = self.model.generate(text=text)
        samples = _float_samples(generated)
        return _wav_bytes(samples, self.sample_rate)


def create_app() -> FastAPI:
    app = FastAPI(title="PocketDM Pika TTS", version="0.1.0")

    @app.get("/health")
    async def health() -> dict[str, Any]:
        settings = _settings()
        return {
            "status": "ok",
            "backend": settings.backend,
            "loaded": _voice_loaded(),
            "reference_audio": str(settings.reference_audio) if settings.reference_audio else None,
            "device": settings.device,
        }

    @app.post("/warmup")
    async def warmup() -> dict[str, Any]:
        try:
            _voice()
        except PikaVoiceUnavailable as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc
        settings = _settings()
        return {
            "status": "ready",
            "backend": settings.backend,
            "loaded": _voice_loaded(),
            "device": settings.device,
        }

    @app.post("/tts")
    async def tts(payload: PikaTTSRequest) -> Response:
        if payload.format.casefold() != "wav":
            raise HTTPException(status_code=400, detail="only wav output is supported")
        text = _clean_text(payload.text)
        if not text:
            raise HTTPException(status_code=400, detail="missing text")
        settings = _settings()
        try:
            if _is_signature_voice(payload.voice) and settings.backend == "stub":
                audio = GeneratedChirpVoice().synthesize(text)
                voice_label = "signature"
            else:
                audio = _voice().synthesize(text)
                voice_label = settings.backend
        except PikaVoiceUnavailable as exc:
            raise HTTPException(status_code=503, detail=str(exc)) from exc

        return Response(
            content=audio,
            media_type="audio/wav",
            headers={"x-pocketdm-pika-voice": voice_label},
        )

    return app


def _clean_text(value: str) -> str:
    text = " ".join(str(value or "").split())
    return html.unescape(text[:MAX_TEXT_CHARS]).strip()


def _is_signature_voice(voice: str) -> bool:
    return voice.strip().casefold() in {"pika-original", "pika-signature", "pika-crisp", "signature"}


@lru_cache(maxsize=1)
def _voice() -> GeneratedChirpVoice | ChatterboxPikaVoice | VoxCPMPikaVoice:
    settings = _settings()
    if settings.backend == "stub":
        return GeneratedChirpVoice()
    if settings.backend == "chatterbox":
        return ChatterboxPikaVoice(settings)
    if settings.backend == "voxcpm":
        return VoxCPMPikaVoice(settings)
    raise PikaVoiceUnavailable(f"unknown Pika TTS backend: {settings.backend}")


def _voice_loaded() -> bool:
    return _voice.cache_info().currsize > 0


def _settings() -> PikaVoiceSettings:
    backend = os.environ.get("POCKETDM_PIKA_TTS_BACKEND", "chatterbox").strip().casefold()
    raw_reference = os.environ.get("POCKETDM_PIKA_TTS_REF", "").strip()
    reference_audio = Path(raw_reference).expanduser() if raw_reference else None
    if reference_audio is not None and not reference_audio.exists():
        raise PikaVoiceUnavailable(f"reference audio not found: {reference_audio}")
    return PikaVoiceSettings(
        backend=backend,
        reference_audio=reference_audio,
        device=os.environ.get("POCKETDM_PIKA_TTS_DEVICE", "auto").strip().casefold(),
        model_id=os.environ.get("POCKETDM_PIKA_TTS_MODEL", "openbmb/VoxCPM-0.5B").strip(),
        cfg_value=float(os.environ.get("POCKETDM_PIKA_TTS_CFG", "2.0")),
        inference_timesteps=int(os.environ.get("POCKETDM_PIKA_TTS_STEPS", "8")),
        normalize=_env_flag("POCKETDM_PIKA_TTS_NORMALIZE", default=False),
        denoise=_env_flag("POCKETDM_PIKA_TTS_DENOISE", default=False),
    )


def _env_flag(name: str, *, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.strip().casefold() in {"1", "true", "yes", "on"}


def _resolve_device(raw_device: str) -> str:
    if raw_device in {"cpu", "cuda", "mps"}:
        return raw_device
    try:
        torch = importlib.import_module("torch")
        if getattr(torch.backends, "mps", None) and torch.backends.mps.is_available():
            return "mps"
        if torch.cuda.is_available():
            return "cuda"
    except Exception:
        pass
    return "cpu"


def _float_samples(generated: Any) -> list[float]:
    if isinstance(generated, tuple) and generated:
        generated = generated[0]
    if hasattr(generated, "detach"):
        generated = generated.detach().cpu()
    if hasattr(generated, "numpy"):
        generated = generated.numpy()
    if hasattr(generated, "tolist"):
        generated = generated.tolist()
    return [float(value) for value in _flatten(generated)]


def _flatten(value: Any) -> list[float]:
    if isinstance(value, (list, tuple)):
        flattened: list[float] = []
        for item in value:
            flattened.extend(_flatten(item))
        return flattened
    return [float(value)]


def _chirp_samples(
    seconds: float,
    start_hz: float,
    end_hz: float,
    *,
    volume: float = 0.32,
) -> list[float]:
    count = max(1, int(DEFAULT_SAMPLE_RATE * seconds))
    samples: list[float] = []
    for index in range(count):
        progress = index / max(count - 1, 1)
        frequency = start_hz + (end_hz - start_hz) * progress
        envelope = math.sin(math.pi * progress) ** 0.65
        wobble = 1.0 + 0.08 * math.sin(2 * math.pi * 9 * progress)
        phase = 2 * math.pi * frequency * (index / DEFAULT_SAMPLE_RATE)
        samples.append(volume * envelope * math.sin(phase) * wobble)
    return samples


def _signature_samples(text: str) -> list[float]:
    lowered = text.casefold()
    if "pika" not in lowered and "pikaa" not in lowered and "piiika" not in lowered:
        return []

    sleepy = "..." in text or "piiika" in lowered
    question = "?" in text
    excited = "!" in text and not sleepy
    words = 1 if sleepy else 2
    samples: list[float] = []
    for index in range(words):
        if index > 0:
            samples.extend([0.0] * int(DEFAULT_SAMPLE_RATE * 0.065))
        samples.extend(
            _pika_word_samples(
                excited=excited,
                question=question and index == words - 1,
                sleepy=sleepy,
            )
        )
    samples.extend([0.0] * int(DEFAULT_SAMPLE_RATE * 0.025))
    return samples


def _pika_word_samples(*, excited: bool, question: bool, sleepy: bool) -> list[float]:
    if sleepy:
        return [
            *_noise_burst(0.014, volume=0.035),
            *_vowel_syllable(0.13, 840, 690, volume=0.15),
            *([0.0] * int(DEFAULT_SAMPLE_RATE * 0.024)),
            *_noise_burst(0.01, volume=0.03),
            *_vowel_syllable(0.34, 610, 510, volume=0.18),
        ]

    if question:
        ka_start, ka_end = 760, 1050
    elif excited:
        ka_start, ka_end = 820, 980
    else:
        ka_start, ka_end = 760, 870

    return [
        *_noise_burst(0.017, volume=0.07),
        *_vowel_syllable(0.088, 1240, 1570, volume=0.22 if excited else 0.19),
        *([0.0] * int(DEFAULT_SAMPLE_RATE * 0.018)),
        *_noise_burst(0.012, volume=0.05),
        *_vowel_syllable(0.235 if excited else 0.255, ka_start, ka_end, volume=0.29 if excited else 0.24),
    ]


def _vowel_syllable(seconds: float, start_hz: float, end_hz: float, *, volume: float) -> list[float]:
    count = max(1, int(DEFAULT_SAMPLE_RATE * seconds))
    samples: list[float] = []
    phase = 0.0
    for index in range(count):
        progress = index / max(count - 1, 1)
        frequency = start_hz + (end_hz - start_hz) * progress
        phase += 2 * math.pi * frequency / DEFAULT_SAMPLE_RATE
        envelope = math.sin(math.pi * progress) ** 0.52
        shimmer = 1.0 + 0.035 * math.sin(2 * math.pi * 7 * progress)
        tone = (
            math.sin(phase)
            + 0.32 * math.sin(phase * 2.0)
            + 0.12 * math.sin(phase * 3.0)
        ) / 1.44
        samples.append(volume * envelope * shimmer * tone)
    return samples


def _noise_burst(seconds: float, *, volume: float) -> list[float]:
    count = max(1, int(DEFAULT_SAMPLE_RATE * seconds))
    samples: list[float] = []
    for index in range(count):
        progress = index / max(count - 1, 1)
        envelope = (1.0 - progress) ** 2.2
        noise = math.sin(index * 12.9898) + 0.5 * math.sin(index * 78.233)
        samples.append(volume * envelope * noise)
    return samples


def _wav_bytes(samples: list[float], sample_rate: int) -> bytes:
    samples = _normalized_samples(samples)
    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        frames = bytearray()
        for sample in samples:
            clipped = max(-1.0, min(1.0, sample))
            frames.extend(int(clipped * 32767).to_bytes(2, "little", signed=True))
        wav.writeframes(bytes(frames))
    return buffer.getvalue()


def _normalized_samples(samples: list[float]) -> list[float]:
    if not samples:
        return samples

    peak = max(abs(sample) for sample in samples)
    if peak <= 0:
        return samples

    rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples))
    if rms <= 0:
        return samples

    target_rms = 10 ** (-20 / 20)
    peak_limit = 10 ** (-3 / 20)
    gain = min(target_rms / rms, peak_limit / peak)
    if abs(gain - 1.0) < 0.01:
        return samples
    return [sample * gain for sample in samples]


def main() -> None:
    parser = argparse.ArgumentParser(description="Run the local PocketDM Pika TTS sidecar.")
    parser.add_argument("--host", default=os.environ.get("POCKETDM_PIKA_TTS_HOST", "127.0.0.1"))
    parser.add_argument("--port", type=int, default=int(os.environ.get("POCKETDM_PIKA_TTS_PORT", "7861")))
    parser.add_argument("--backend", choices=("chatterbox", "voxcpm", "stub"), default=None)
    parser.add_argument("--warmup", action="store_true", help="Load the selected backend before accepting requests.")
    args = parser.parse_args()
    if args.backend:
        os.environ["POCKETDM_PIKA_TTS_BACKEND"] = args.backend

    import uvicorn

    application = create_app()
    if args.warmup or os.environ.get("POCKETDM_PIKA_TTS_WARMUP", "").casefold() in {"1", "true", "yes", "on"}:
        _voice()
    uvicorn.run(application, host=args.host, port=args.port)


if __name__ == "__main__":
    main()
