from __future__ import annotations

import os
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path

from engine.generate import TurnBackend

DEFAULT_GRAMMAR_PATH = Path(__file__).resolve().parents[1] / "engine" / "grammar.gbnf"


@dataclass(frozen=True)
class LlamaBackendConfig:
    model_path: Path
    grammar_path: Path = DEFAULT_GRAMMAR_PATH
    n_ctx: int = 2048
    n_threads: int = 2
    max_tokens: int = 340
    use_chat_template: bool = False


class LlamaCppBackend:
    def __init__(self, config: LlamaBackendConfig) -> None:
        self.config = config
        self.model_label = _model_label(config.model_path)

    def complete(self, messages: list[dict[str, str]], *, temperature: float) -> str:
        llm, grammar = _load_llama(
            str(self.config.model_path),
            str(self.config.grammar_path),
            self.config.n_ctx,
            self.config.n_threads,
        )
        if self.config.use_chat_template:
            response = llm.create_chat_completion(
                messages=messages,
                max_tokens=self.config.max_tokens,
                temperature=temperature,
                grammar=grammar,
                stop=["<turn|>", "<|im_end|>"],
            )
            return str(response["choices"][0]["message"]["content"]).strip()

        response = llm(
            render_prompt(messages),
            max_tokens=self.config.max_tokens,
            temperature=temperature,
            grammar=grammar,
            stop=["<|im_end|>"],
        )
        return str(response["choices"][0]["text"]).strip()


def configured_backend() -> TurnBackend | None:
    raw_model_path = os.environ.get("POCKETDM_GGUF") or os.environ.get("POCKETDM_GGUF_MODEL")
    if not raw_model_path:
        return None
    model_path = Path(raw_model_path)
    if not model_path.exists():
        return None
    grammar_path = Path(os.environ.get("POCKETDM_GRAMMAR", str(DEFAULT_GRAMMAR_PATH)))
    n_threads = int(os.environ.get("POCKETDM_LLAMA_THREADS", "2"))
    chat_template = _use_chat_template(model_path)
    return LlamaCppBackend(
        LlamaBackendConfig(
            model_path=model_path,
            grammar_path=grammar_path,
            n_threads=n_threads,
            use_chat_template=chat_template,
        )
    )


def render_prompt(messages: list[dict[str, str]]) -> str:
    rendered = "\n".join(
        f"<|im_start|>{message['role']}\n{message['content']}<|im_end|>"
        for message in messages
    )
    return f"{rendered}\n<|im_start|>assistant\n"


def _use_chat_template(model_path: Path) -> bool:
    raw = os.environ.get("POCKETDM_CHAT_TEMPLATE", "auto").casefold()
    if raw in {"1", "true", "yes", "on"}:
        return True
    if raw in {"0", "false", "no", "off"}:
        return False
    name = model_path.name.casefold()
    return "gemma" in name


def _model_label(model_path: Path) -> str:
    name = model_path.name.casefold()
    if "gemma-4-e2b" in name:
        return "Gemma 4 E2B Q4_K_M GGUF"
    if "gemma" in name:
        return "Gemma GGUF"
    if "2b-v1-lora" in str(model_path).casefold() or "qwen" in name:
        return "2B Q4_K_M GGUF"
    return model_path.stem


@lru_cache(maxsize=2)
def _load_llama(
    model_path: str,
    grammar_path: str,
    n_ctx: int,
    n_threads: int,
) -> tuple[object, object]:
    from llama_cpp import Llama, LlamaGrammar

    return (
        Llama(
            model_path=model_path,
            n_ctx=n_ctx,
            n_threads=n_threads,
            verbose=False,
        ),
        LlamaGrammar.from_file(grammar_path),
    )
