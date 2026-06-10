from __future__ import annotations

import argparse
import sys
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Iterable, Mapping

ROOT = Path(__file__).resolve().parents[2]
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

VOICE_REPO = "hexgrad/Kokoro-82M"
VOICE_FILES = {
    "emma": "voices/bf_emma.pt",
    "heart": "voices/af_heart.pt",
    "bella": "voices/af_bella.pt",
    "nicole": "voices/af_nicole.pt",
}

VOICE_DIR = Path(__file__).resolve().parent
LORE_PT_PATH = VOICE_DIR / "lore_narrator.pt"
LORE_NPY_PATH = VOICE_DIR / "lore_narrator.npy"
AUDITION_DIR = VOICE_DIR / "auditions"

AUDITION_SCRIPT = (
    "Long ago, in the Whispering Wood, a door was carved that should never have "
    "been opened. You stand before it now, torch guttering, as the runes begin "
    "to glow."
)
AUDITION_SPEEDS = (0.78, 0.85)


@dataclass(frozen=True)
class AuditionRecipe:
    slug: str
    weights: dict[str, float]


AUDITION_RECIPES = (
    AuditionRecipe("lore_e45_h35_n20", {"emma": 0.45, "heart": 0.35, "nicole": 0.20}),
    AuditionRecipe("lore_e55_h30_n15", {"emma": 0.55, "heart": 0.30, "nicole": 0.15}),
    AuditionRecipe("lore_e40_h30_n30", {"emma": 0.40, "heart": 0.30, "nicole": 0.30}),
    AuditionRecipe("lore_e50_h50_n00", {"emma": 0.50, "heart": 0.50, "nicole": 0.00}),
    AuditionRecipe("lore_e35_h45_n20", {"emma": 0.35, "heart": 0.45, "nicole": 0.20}),
    AuditionRecipe("lore_e45_b35_n20", {"emma": 0.45, "bella": 0.35, "nicole": 0.20}),
    AuditionRecipe("lore_e35_b45_n20", {"emma": 0.35, "bella": 0.45, "nicole": 0.20}),
)


def normalize_weights(weights: Mapping[str, float]) -> dict[str, float]:
    if not weights:
        raise ValueError("at least one voice weight is required")

    total = sum(weights.values())
    if total <= 0:
        raise ValueError("voice weights must sum to a positive value")

    return {name: weight / total for name, weight in weights.items()}


def blend_styles(styles: Mapping[str, Any], weights: Mapping[str, float]) -> Any:
    normalized = normalize_weights(weights)
    first_name = next(iter(normalized))
    if first_name not in styles:
        raise KeyError(f"missing style tensor {first_name!r}")

    first = styles[first_name]
    shape = _shape(first)
    result = first * 0.0

    for name, weight in normalized.items():
        if name not in styles:
            raise KeyError(f"missing style tensor {name!r}")
        style = styles[name]
        if _shape(style) != shape:
            raise ValueError(f"style tensor {name!r} has shape {_shape(style)}, expected {shape}")
        result = result + (style * weight)

    return squeeze_kokoro_voicepack(_with_dtype(result, first))


def load_voice_tensors(names: Iterable[str] | None = None) -> dict[str, Any]:
    import torch
    from huggingface_hub import hf_hub_download

    selected = tuple(names or VOICE_FILES)
    tensors: dict[str, Any] = {}
    for name in selected:
        filename = VOICE_FILES[name]
        try:
            path = hf_hub_download(
                repo_id=VOICE_REPO,
                filename=filename,
                local_files_only=True,
            )
        except Exception:
            path = hf_hub_download(repo_id=VOICE_REPO, filename=filename)

        try:
            tensor = torch.load(path, map_location="cpu", weights_only=True)
        except TypeError:
            tensor = torch.load(path, map_location="cpu")
        tensors[name] = tensor.detach().cpu()

    return tensors


def run_audition() -> list[Path]:
    import soundfile as sf
    from kokoro_onnx import Kokoro

    from app.tts import apply_lore_reverb, model_paths

    model_path, voices_path = model_paths()
    missing = [path for path in (model_path, voices_path) if not path.exists()]
    if missing:
        raise FileNotFoundError(
            "missing Kokoro ONNX audition asset(s): "
            + ", ".join(str(path) for path in missing)
        )

    AUDITION_DIR.mkdir(parents=True, exist_ok=True)
    tensors = load_voice_tensors()
    kokoro = Kokoro(str(model_path), str(voices_path))

    written: list[Path] = []
    for recipe in AUDITION_RECIPES:
        style = blend_styles(tensors, recipe.weights)
        style_array = to_kokoro_style_array(style)
        for speed in AUDITION_SPEEDS:
            samples, sample_rate = kokoro.create(
                AUDITION_SCRIPT,
                voice=style_array,
                speed=speed,
                lang="en-us",
            )
            samples = apply_lore_reverb(samples, sample_rate)
            output_path = AUDITION_DIR / f"{recipe.slug}_{speed_slug(speed)}.wav"
            sf.write(output_path, samples, sample_rate)
            written.append(output_path)

    return written


def build_lore_voice(recipe: str) -> tuple[Path, Path]:
    import numpy as np
    import torch

    emma, heart, nicole, _speed = parse_build_recipe(recipe)
    tensors = load_voice_tensors(("emma", "heart", "nicole"))
    style = blend_styles(
        tensors,
        {
            "emma": emma,
            "heart": heart,
            "nicole": nicole,
        },
    )

    VOICE_DIR.mkdir(parents=True, exist_ok=True)
    torch.save(style, LORE_PT_PATH)
    np.save(LORE_NPY_PATH, to_numpy(style))
    return LORE_PT_PATH, LORE_NPY_PATH


def parse_build_recipe(recipe: str) -> tuple[float, float, float, float]:
    parts = recipe.split(",")
    if len(parts) != 4:
        raise ValueError("--build must be w_emma,w_heart,w_nicole,speed")

    try:
        emma, heart, nicole, speed = (float(part) for part in parts)
    except ValueError as exc:
        raise ValueError("--build values must be numbers") from exc

    if speed <= 0:
        raise ValueError("speed must be positive")

    normalize_weights({"emma": emma, "heart": heart, "nicole": nicole})
    return emma, heart, nicole, speed


def to_numpy(style: Any) -> Any:
    import numpy as np

    if hasattr(style, "detach"):
        style = style.detach().cpu().numpy()
    return np.asarray(style)


def to_kokoro_style_array(style: Any) -> Any:
    import numpy as np

    array = np.asarray(to_numpy(squeeze_kokoro_voicepack(style)), dtype=np.float32)
    if array.ndim == 3 and array.shape[1] == 1:
        array = array[:, 0, :]
    if array.ndim == 2:
        return _as_kokoro_voicepack(array)
    raise ValueError(
        f"expected Kokoro style tensor shape (510, 1, 256) or (510, 256), got {array.shape}"
    )


def _as_kokoro_voicepack(array: Any) -> Any:
    import numpy as np

    class KokoroVoicePack(np.ndarray):
        def __array_finalize__(self, obj: Any) -> None:
            del obj

        def __getitem__(self, key: Any) -> Any:
            item = super().__getitem__(key)
            if isinstance(key, (int, np.integer)) and getattr(item, "ndim", None) == 1:
                return np.asarray(item, dtype=np.float32)[np.newaxis, :]
            return item

    obj = np.asarray(array, dtype=np.float32).view(KokoroVoicePack)
    if obj.ndim != 2:
        raise ValueError(f"expected Kokoro voicepack shape (510, 256), got {obj.shape}")
    return obj


def squeeze_kokoro_voicepack(style: Any) -> Any:
    shape = _shape(style)
    if len(shape) == 2:
        return style
    if len(shape) == 3 and shape[1] == 1:
        if hasattr(style, "squeeze"):
            return style.squeeze(1)
        import numpy as np

        return np.squeeze(to_numpy(style), axis=1)
    raise ValueError(
        f"expected Kokoro voicepack shape (510, 1, 256) or (510, 256), got {shape}"
    )


def speed_slug(speed: float) -> str:
    return f"s{int(round(speed * 100)):03d}"


def _shape(style: Any) -> tuple[int, ...]:
    shape = getattr(style, "shape", None)
    if shape is None:
        raise TypeError("style tensor must expose a shape")
    return tuple(shape)


def _with_dtype(result: Any, source: Any) -> Any:
    dtype = getattr(source, "dtype", None)
    if dtype is None:
        return result
    if hasattr(result, "to"):
        return result.to(dtype=dtype)
    if hasattr(result, "astype"):
        return result.astype(dtype, copy=False)
    return result


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description="Build or audition the PocketDM lore voice.")
    parser.add_argument(
        "--audition",
        action="store_true",
        help="render the fixed audition grid into app/voices/auditions/",
    )
    parser.add_argument(
        "--build",
        metavar="W_EMMA,W_HEART,W_NICOLE,SPEED",
        help="save the selected blend as lore_narrator.pt and lore_narrator.npy",
    )
    args = parser.parse_args(argv)

    if args.audition == bool(args.build):
        parser.error("choose exactly one of --audition or --build")

    if args.audition:
        written = run_audition()
        print(f"wrote {len(written)} audition WAVs to {AUDITION_DIR}")
        return 0

    pt_path, npy_path = build_lore_voice(args.build)
    print(f"wrote {pt_path}")
    print(f"wrote {npy_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
