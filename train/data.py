from __future__ import annotations

import json
import random
from pathlib import Path
from typing import Any, Protocol, Sequence


class ChatTemplateTokenizer(Protocol):
    def apply_chat_template(
        self,
        conversation: Sequence[dict[str, str]],
        *,
        tokenize: bool,
        add_generation_prompt: bool,
        **kwargs: Any,
    ) -> str:
        ...


ASSISTANT_HEADER = "<|im_start|>assistant\n"


def load_training_rows(path: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    with path.open() as handle:
        for line_number, line in enumerate(handle, start=1):
            stripped = line.strip()
            if not stripped:
                continue
            try:
                row = json.loads(stripped)
            except json.JSONDecodeError as exc:
                raise ValueError(f"{path}:{line_number}: invalid JSONL: {exc}") from exc
            validate_training_row(row, source=f"{path}:{line_number}")
            rows.append(row)
    return rows


def parse_training_jsonl(text: str) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for line_number, line in enumerate(text.splitlines(), start=1):
        stripped = line.strip()
        if not stripped:
            continue
        try:
            row = json.loads(stripped)
        except json.JSONDecodeError as exc:
            raise ValueError(f"training jsonl line {line_number}: invalid JSONL: {exc}") from exc
        validate_training_row(row, source=f"training jsonl line {line_number}")
        rows.append(row)
    return rows


def validate_training_row(row: dict[str, Any], *, source: str = "row") -> None:
    messages = row.get("messages")
    completion = row.get("completion")
    if not isinstance(messages, list) or not messages:
        raise ValueError(f"{source}: messages must be a non-empty list")
    for index, message in enumerate(messages):
        if not isinstance(message, dict):
            raise ValueError(f"{source}: message {index} must be an object")
        if message.get("role") not in {"system", "user", "assistant"}:
            raise ValueError(f"{source}: message {index} has invalid role")
        if not isinstance(message.get("content"), str) or not message["content"]:
            raise ValueError(f"{source}: message {index} has empty content")
    if not isinstance(completion, str) or not completion:
        raise ValueError(f"{source}: completion must be a non-empty string")


def split_train_eval(
    rows: Sequence[dict[str, Any]],
    *,
    eval_fraction: float = 0.02,
    seed: int = 3407,
) -> tuple[list[dict[str, Any]], list[dict[str, Any]]]:
    if not rows:
        return [], []
    ordered = list(rows)
    random.Random(seed).shuffle(ordered)
    eval_count = max(1, round(len(ordered) * eval_fraction)) if len(ordered) > 1 else 0
    eval_count = min(eval_count, max(0, len(ordered) - 1))
    return ordered[eval_count:], ordered[:eval_count]


def training_text(row: dict[str, Any], tokenizer: ChatTemplateTokenizer) -> str:
    validate_training_row(row)
    messages = [
        {"role": str(message["role"]), "content": str(message["content"])}
        for message in row["messages"]
    ]
    messages.append({"role": "assistant", "content": str(row["completion"])})
    try:
        return tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=False,
            enable_thinking=False,
        )
    except TypeError:
        return tokenizer.apply_chat_template(
            messages,
            tokenize=False,
            add_generation_prompt=False,
        )


def fallback_training_text(row: dict[str, Any]) -> str:
    validate_training_row(row)
    parts = []
    for message in row["messages"]:
        parts.append(f"<|im_start|>{message['role']}\n{message['content']}<|im_end|>")
    parts.append(f"{ASSISTANT_HEADER}{row['completion']}<|im_end|>")
    return "\n".join(parts)
