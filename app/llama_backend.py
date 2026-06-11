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


class LlamaCppBackend:
    def __init__(self, config: LlamaBackendConfig) -> None:
        self.config = config

    def complete(self, messages: list[dict[str, str]], *, temperature: float) -> str:
        llm, grammar = _load_llama(
            str(self.config.model_path),
            str(self.config.grammar_path),
            self.config.n_ctx,
            self.config.n_threads,
        )
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
    return LlamaCppBackend(
        LlamaBackendConfig(
            model_path=model_path,
            grammar_path=grammar_path,
            n_threads=n_threads,
        )
    )


def render_prompt(messages: list[dict[str, str]]) -> str:
    rendered = "\n".join(
        f"<|im_start|>{message['role']}\n{message['content']}<|im_end|>"
        for message in messages
    )
    return f"{rendered}\n<|im_start|>assistant\n"


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
