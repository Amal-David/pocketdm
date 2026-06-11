from __future__ import annotations

from app.llama_backend import configured_backend, render_prompt


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
