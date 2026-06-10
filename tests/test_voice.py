from __future__ import annotations

import numpy as np
import pytest

from app.tts import VOICE_TABLE, _kokoro_style_array, model_paths, synthesize
from app.voices.build_lore_voice import blend_styles, normalize_weights, to_kokoro_style_array


def test_blend_styles_normalizes_weights_and_squeezes_voicepack_to_2d() -> None:
    styles = {
        "emma": np.array([[[1.0, 2.0]], [[3.0, 4.0]]], dtype=np.float32),
        "heart": np.array([[[5.0, 6.0]], [[7.0, 8.0]]], dtype=np.float32),
        "nicole": np.array([[[9.0, 10.0]], [[11.0, 12.0]]], dtype=np.float32),
    }

    result = blend_styles(
        styles,
        {
            "emma": 2.0,
            "heart": 1.0,
            "nicole": 1.0,
        },
    )

    assert result.shape == (2, 2)
    assert result.dtype == np.float32
    np.testing.assert_allclose(result, np.array([[4.0, 5.0], [6.0, 7.0]], dtype=np.float32))
    assert normalize_weights({"emma": 2.0, "heart": 1.0, "nicole": 1.0}) == {
        "emma": 0.5,
        "heart": 0.25,
        "nicole": 0.25,
    }


def test_kokoro_style_arrays_stay_2d_after_token_count_lookup() -> None:
    style = np.array([[[1.0, 2.0, 3.0]], [[4.0, 5.0, 6.0]]], dtype=np.float64)

    voicepack = to_kokoro_style_array(style)

    assert voicepack.shape == (2, 3)
    assert voicepack.dtype == np.float32
    np.testing.assert_allclose(voicepack[1], np.array([[4.0, 5.0, 6.0]], dtype=np.float32))


def test_runtime_lore_style_loader_returns_kokoro_compatible_2d_voicepack() -> None:
    voicepack = _kokoro_style_array(np.ones((2, 3), dtype=np.float32))

    assert voicepack.shape == (2, 3)
    assert voicepack[0].shape == (1, 3)


def test_voice_table_contains_required_selectable_voices() -> None:
    assert set(VOICE_TABLE) == {"dungeon", "wood", "starship", "lore"}
    assert VOICE_TABLE["dungeon"].style == "am_onyx"
    assert VOICE_TABLE["wood"].style == "af_heart"
    assert VOICE_TABLE["starship"].style == "af_sky"
    assert VOICE_TABLE["lore"].style == "lore_narrator"
    assert VOICE_TABLE["lore"].default_speed == 0.8
    assert VOICE_TABLE["lore"].custom is True
    assert VOICE_TABLE["lore"].reverb is True


@pytest.mark.slow
def test_smoke_synth_if_kokoro_model_files_are_present() -> None:
    model_path, voices_path = model_paths()
    if not model_path.exists() or not voices_path.exists():
        pytest.skip("Kokoro ONNX model files are absent")
    pytest.importorskip("kokoro_onnx", reason="kokoro-onnx is not installed")

    sample_rate, samples = synthesize(
        "The old door opens with a careful sigh.",
        "wood",
        0.9,
    )

    assert sample_rate == 24000
    assert len(samples) > 0
