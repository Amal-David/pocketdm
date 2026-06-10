from __future__ import annotations

import os
import shutil
import urllib.request
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from typing import TYPE_CHECKING

if TYPE_CHECKING:
    import numpy as np

APP_DIR = Path(__file__).resolve().parent
DEFAULT_TTS_DIR = APP_DIR / "voices" / "models"
LORE_VOICE_PATH = APP_DIR / "voices" / "lore_narrator.npy"

MODEL_FILENAME = "kokoro-v1.0.onnx"
VOICES_FILENAME = "voices-v1.0.bin"
LOCAL_ASSET_DIR = Path("/tmp/kokoro-assets")
RELEASE_BASE_URL = (
    "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.0"
)


@dataclass(frozen=True)
class VoiceConfig:
    style: str
    default_speed: float = 1.0
    lang: str = "en-us"
    custom: bool = False
    reverb: bool = False


VOICE_TABLE: dict[str, VoiceConfig] = {
    "dungeon": VoiceConfig(style="am_onyx"),
    "wood": VoiceConfig(style="af_heart"),
    "starship": VoiceConfig(style="af_sky"),
    "lore": VoiceConfig(
        style="lore_narrator",
        default_speed=0.8,
        custom=True,
        reverb=True,
    ),
}

_ENGINE: object | None = None
_ENGINE_PATHS: tuple[Path, Path] | None = None


def tts_dir() -> Path:
    return Path(os.environ.get("POCKETDM_TTS_DIR", DEFAULT_TTS_DIR))


def model_paths(target_dir: Path | None = None) -> tuple[Path, Path]:
    root = target_dir or tts_dir()
    return root / MODEL_FILENAME, root / VOICES_FILENAME


def download(target_dir: Path | None = None) -> tuple[Path, Path]:
    """Fetch Kokoro ONNX model files into the configured local model directory."""
    root = target_dir or tts_dir()
    root.mkdir(parents=True, exist_ok=True)

    for filename in (MODEL_FILENAME, VOICES_FILENAME):
        target = root / filename
        if target.exists() and target.stat().st_size > 0:
            continue

        local_asset = LOCAL_ASSET_DIR / filename
        if local_asset.exists() and local_asset.stat().st_size > 0:
            shutil.copy2(local_asset, target)
            continue

        tmp_target = target.with_name(f"{target.name}.tmp")
        try:
            urllib.request.urlretrieve(f"{RELEASE_BASE_URL}/{filename}", tmp_target)
            tmp_target.replace(target)
        finally:
            if tmp_target.exists():
                tmp_target.unlink()

    return model_paths(root)


def synthesize(
    text: str,
    voice_id: str,
    speed: float | None = None,
) -> tuple[int, "np.ndarray"]:
    """Synchronously synthesize narration with a local Kokoro ONNX model."""
    if voice_id not in VOICE_TABLE:
        raise ValueError(f"unknown voice_id {voice_id!r}; expected one of {sorted(VOICE_TABLE)}")

    import numpy as np

    config = VOICE_TABLE[voice_id]
    engine = _get_engine()
    voice: str | np.ndarray
    if config.custom:
        voice = _load_lore_voice()
    else:
        voice = config.style

    samples, sample_rate = engine.create(
        text,
        voice=voice,
        speed=config.default_speed if speed is None else speed,
        lang=config.lang,
    )
    audio = np.asarray(samples, dtype=np.float32)
    if config.reverb:
        audio = apply_lore_reverb(audio, sample_rate)

    return sample_rate, audio


def apply_lore_reverb(samples: "np.ndarray", sample_rate: int) -> "np.ndarray":
    import numpy as np
    from pedalboard import LowpassFilter, Pedalboard, Reverb

    audio = np.asarray(samples, dtype=np.float32)
    board = Pedalboard(
        [
            Reverb(room_size=0.35, wet_level=0.25, dry_level=0.75),
            LowpassFilter(cutoff_frequency_hz=9000.0),
        ]
    )
    return np.asarray(board(audio, sample_rate), dtype=np.float32)


def _get_engine() -> object:
    global _ENGINE, _ENGINE_PATHS

    paths = model_paths()
    missing = [path for path in paths if not path.exists()]
    if missing:
        missing_list = ", ".join(str(path) for path in missing)
        raise FileNotFoundError(
            f"missing Kokoro model file(s): {missing_list}. "
            "Run app.tts.download() at build/startup or set POCKETDM_TTS_DIR."
        )

    if _ENGINE is None or _ENGINE_PATHS != paths:
        from kokoro_onnx import Kokoro

        model_path, voices_path = paths
        _ENGINE = Kokoro(str(model_path), str(voices_path))
        _ENGINE_PATHS = paths

    return _ENGINE


@lru_cache(maxsize=1)
def _load_lore_voice() -> "np.ndarray":
    import numpy as np

    if not LORE_VOICE_PATH.exists():
        raise FileNotFoundError(
            f"missing lore voice style array: {LORE_VOICE_PATH}. "
            "Run app/voices/build_lore_voice.py --build first."
        )

    return _kokoro_style_array(np.load(LORE_VOICE_PATH))


def _kokoro_style_array(style: "np.ndarray") -> "np.ndarray":
    from app.voices.build_lore_voice import to_kokoro_style_array

    return to_kokoro_style_array(style)
