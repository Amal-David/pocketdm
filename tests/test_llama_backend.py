from __future__ import annotations

from pathlib import Path

from app.llama_backend import _model_label, configured_backend, render_prompt


def test_render_prompt_uses_qwen_chat_markers_and_generation_prompt() -> None:
    rendered = render_prompt(
        [
            {"role": "system", "content": "Rules"},
            {"role": "user", "content": "State={}"},
        ]
    )

    assert rendered.startswith("<|im_start|>system\nRules<|im_end|>")
    assert "<|im_start|>user\nState={}<|im_end|>" in rendered
    assert rendered.endswith("<|im_start|>assistant\n")


def test_configured_backend_stays_none_without_existing_model(monkeypatch) -> None:
    monkeypatch.setenv("POCKETDM_GGUF", "/tmp/definitely-missing-pocketdm.gguf")

    assert configured_backend() is None


def test_model_label_distinguishes_gemma_quantization() -> None:
    assert (
        _model_label(Path("models/gemma-4-e2b-it/gguf/gemma-4-E2B-it-Q4_K_M.gguf"))
        == "Gemma 4 E2B Q4_K_M GGUF"
    )
    assert (
        _model_label(Path("models/gemma-4-e2b-it/gguf/gemma-4-E2B-it-BF16.gguf"))
        == "Gemma 4 E2B BF16 GGUF"
    )
