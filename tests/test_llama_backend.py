from __future__ import annotations

import json
from pathlib import Path

from app.llama_backend import (
    LlamaServerBackend,
    LlamaServerConfig,
    _model_label,
    configured_backend,
    render_prompt,
)


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


def test_configured_backend_prefers_llama_server_url(monkeypatch) -> None:
    monkeypatch.setenv("POCKETDM_GGUF", "/tmp/definitely-missing-pocketdm.gguf")
    monkeypatch.setenv("POCKETDM_LLAMA_SERVER_URL", "http://127.0.0.1:8081")

    backend = configured_backend()

    assert isinstance(backend, LlamaServerBackend)
    assert backend.model_label == "llama.cpp server"


def test_llama_server_backend_posts_chat_completion(monkeypatch, tmp_path) -> None:
    grammar_path = tmp_path / "grammar.gbnf"
    grammar_path.write_text('root ::= "ok"')
    seen: dict[str, object] = {}

    class FakeResponse:
        def __enter__(self) -> "FakeResponse":
            return self

        def __exit__(self, *args: object) -> None:
            return None

        def read(self) -> bytes:
            return json.dumps(
                {"choices": [{"message": {"content": '{"narration":"ok"}'}}]}
            ).encode()

    def fake_urlopen(request: object, *, timeout: float) -> FakeResponse:
        seen["url"] = request.full_url
        seen["timeout"] = timeout
        seen["body"] = json.loads(request.data.decode())
        return FakeResponse()

    monkeypatch.setattr("app.llama_backend.urlrequest.urlopen", fake_urlopen)
    backend = LlamaServerBackend(
        LlamaServerConfig(
            base_url="http://127.0.0.1:8081/",
            grammar_path=grammar_path,
            model="gemma-mtp",
            timeout_seconds=3.0,
        )
    )

    raw = backend.complete([{"role": "user", "content": "State={}"}], temperature=0.6)

    assert raw == '{"narration":"ok"}'
    assert seen["url"] == "http://127.0.0.1:8081/v1/chat/completions"
    assert seen["timeout"] == 3.0
    assert seen["body"] == {
        "model": "gemma-mtp",
        "messages": [{"role": "user", "content": "State={}"}],
        "max_tokens": 340,
        "temperature": 0.6,
        "grammar": 'root ::= "ok"',
        "stop": ["<turn|>", "<|im_end|>"],
    }


def test_model_label_distinguishes_gemma_quantization() -> None:
    assert (
        _model_label(Path("models/gemma-4-e2b-it/gguf/gemma-4-E2B-it-Q4_K_M.gguf"))
        == "Gemma 4 E2B Q4_K_M GGUF"
    )
    assert (
        _model_label(Path("models/gemma-4-e2b-it/gguf/gemma-4-E2B-it-Q6_K.gguf"))
        == "Gemma 4 E2B Q6_K GGUF"
    )
    assert (
        _model_label(Path("models/gemma-4-e2b-it/gguf/gemma-4-E2B-it-BF16.gguf"))
        == "Gemma 4 E2B BF16 GGUF"
    )
