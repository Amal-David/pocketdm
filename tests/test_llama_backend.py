from __future__ import annotations

import json
from pathlib import Path

import pytest

from app.llama_backend import (
    LlamaServerBackend,
    LlamaServerConfig,
    ManagedLlamaServerBackend,
    ManagedLlamaServerConfig,
    _ensure_llama_server,
    _llama_server_command,
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


def test_configured_backend_can_manage_llama_server(monkeypatch, tmp_path) -> None:
    binary_path = tmp_path / "llama-server"
    model_path = tmp_path / "gemma-4-E2B-it-Q4_K_M.gguf"
    draft_path = tmp_path / "mtp-gemma-4-E2B-it.gguf"
    binary_path.write_text("#!/bin/sh\n")
    model_path.write_text("model")
    draft_path.write_text("draft")
    monkeypatch.setenv("POCKETDM_LLAMA_SERVER_BIN", str(binary_path))
    monkeypatch.setenv("POCKETDM_GGUF", str(model_path))
    monkeypatch.setenv("POCKETDM_LLAMA_DRAFT_GGUF", str(draft_path))
    monkeypatch.setenv("POCKETDM_LLAMA_SERVER_PORT", "8099")
    monkeypatch.setattr("app.llama_backend._ensure_llama_server", lambda config: None)

    backend = configured_backend()

    assert isinstance(backend, ManagedLlamaServerBackend)
    assert backend.config.base_url == "http://127.0.0.1:8099"
    assert backend.model_label == "Gemma 4 E2B Q4_K_M GGUF MTP llama.cpp server"


def test_llama_server_command_includes_mtp_flags(tmp_path) -> None:
    config = ManagedLlamaServerConfig(
        binary_path=tmp_path / "llama-server",
        model_path=tmp_path / "gemma-4-E2B-it-Q4_K_M.gguf",
        draft_model_path=tmp_path / "mtp-gemma-4-E2B-it.gguf",
        base_url="http://127.0.0.1:8081",
        host="127.0.0.1",
        port=8081,
        n_threads=8,
        spec_draft_n_max=1,
    )

    command = _llama_server_command(config)

    assert command == [
        str(config.binary_path),
        "--model",
        str(config.model_path),
        "--ctx-size",
        "2048",
        "--threads",
        "8",
        "-ngl",
        "999",
        "-fa",
        "on",
        "--host",
        "127.0.0.1",
        "--port",
        "8081",
        "--no-ui",
        "--model-draft",
        str(config.draft_model_path),
        "--spec-type",
        "draft-mtp",
        "--spec-draft-n-max",
        "1",
        "--spec-draft-ngl",
        "999",
    ]


def test_llama_server_command_includes_reasoning_when_requested(tmp_path) -> None:
    config = ManagedLlamaServerConfig(
        binary_path=tmp_path / "llama-server",
        model_path=tmp_path / "gemma-4-E2B-it-Q4_K_M.gguf",
        base_url="http://127.0.0.1:8081",
        host="127.0.0.1",
        port=8081,
        reasoning="off",
    )

    command = _llama_server_command(config)

    assert "--reasoning" in command
    assert command[command.index("--reasoning") + 1] == "off"


def test_managed_server_rejects_existing_wrong_model(monkeypatch, tmp_path) -> None:
    config = ManagedLlamaServerConfig(
        binary_path=tmp_path / "llama-server",
        model_path=tmp_path / "gemma-4-E2B-it-Q4_K_M.gguf",
        base_url="http://127.0.0.1:8081",
        host="127.0.0.1",
        port=8081,
    )
    monkeypatch.setattr("app.llama_backend._llama_server_ready", lambda base_url: True)
    monkeypatch.setattr("app.llama_backend._llama_server_model_ids", lambda base_url: ["other.gguf"])

    with pytest.raises(RuntimeError, match="not serving gemma-4-E2B-it-Q4_K_M.gguf"):
        _ensure_llama_server(config)


def test_managed_mtp_server_requires_existing_process_receipt(monkeypatch, tmp_path) -> None:
    config = ManagedLlamaServerConfig(
        binary_path=tmp_path / "llama-server",
        model_path=tmp_path / "gemma-4-E2B-it-Q4_K_M.gguf",
        draft_model_path=tmp_path / "mtp-gemma-4-E2B-it.gguf",
        base_url="http://127.0.0.1:8081",
        host="127.0.0.1",
        port=8081,
    )
    monkeypatch.setattr("app.llama_backend._llama_server_ready", lambda base_url: True)
    monkeypatch.setattr(
        "app.llama_backend._llama_server_model_ids",
        lambda base_url: [config.model_path.name],
    )
    monkeypatch.setattr(
        "app.llama_backend._llama_server_process_commands",
        lambda: [f"llama-server --model {config.model_path} --port 8081"],
    )

    with pytest.raises(RuntimeError, match="cannot verify that it was started with MTP"):
        _ensure_llama_server(config)


def test_managed_mtp_server_accepts_existing_process_receipt(monkeypatch, tmp_path) -> None:
    config = ManagedLlamaServerConfig(
        binary_path=tmp_path / "llama-server",
        model_path=tmp_path / "gemma-4-E2B-it-Q4_K_M.gguf",
        draft_model_path=tmp_path / "mtp-gemma-4-E2B-it.gguf",
        base_url="http://127.0.0.1:8081",
        host="127.0.0.1",
        port=8081,
    )
    monkeypatch.setattr("app.llama_backend._llama_server_ready", lambda base_url: True)
    monkeypatch.setattr(
        "app.llama_backend._llama_server_model_ids",
        lambda base_url: [config.model_path.name],
    )
    monkeypatch.setattr(
        "app.llama_backend._llama_server_process_commands",
        lambda: [
            "llama-server "
            f"--model {config.model_path} "
            f"--model-draft {config.draft_model_path} "
            "--spec-type draft-mtp --port 8081"
        ],
    )

    assert _ensure_llama_server(config) is None


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
