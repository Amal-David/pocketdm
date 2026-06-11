from __future__ import annotations

import pytest

from train.data import (
    ASSISTANT_HEADER,
    completion_text,
    fallback_training_text,
    parse_training_jsonl,
    prompt_completion_pair,
    prompt_text,
    split_train_eval,
    training_text,
)


class FakeTokenizer:
    def apply_chat_template(self, conversation, *, tokenize, add_generation_prompt, **kwargs):
        assert tokenize is False
        assert add_generation_prompt is False
        assert kwargs.get("enable_thinking") is False
        return "\n".join(f"{message['role']}:{message['content']}" for message in conversation)


class FakePromptTokenizer:
    def apply_chat_template(self, conversation, *, tokenize, add_generation_prompt, **kwargs):
        assert tokenize is False
        assert kwargs.get("enable_thinking") is False
        rendered = "\n".join(
            f"<|im_start|>{message['role']}\n{message['content']}<|im_end|>"
            for message in conversation
        )
        if add_generation_prompt:
            return f"{rendered}\n{ASSISTANT_HEADER}"
        return rendered


def row(index: int = 1) -> dict[str, object]:
    return {
        "messages": [
            {"role": "system", "content": "You are PocketDM."},
            {"role": "user", "content": f"State={index}"},
        ],
        "completion": '{"narration":"Done. Safe.","choices":["A","B","C"],"state_delta":{"hp":0,"add_items":[],"remove_items":[],"location":"Room","add_flags":[]},"is_ending":false,"ending_type":null}',
    }


def test_parse_training_jsonl_validates_rows() -> None:
    rows = parse_training_jsonl("\n".join([__import__("json").dumps(row(1)), ""]))

    assert len(rows) == 1
    assert rows[0]["messages"][1]["content"] == "State=1"

    with pytest.raises(ValueError, match="messages"):
        parse_training_jsonl('{"completion":"{}"}')


def test_training_text_appends_completion_as_assistant_message() -> None:
    rendered = training_text(row(), FakeTokenizer())

    assert rendered.endswith(f"assistant:{row()['completion']}")


def test_fallback_training_text_uses_qwen_style_assistant_marker() -> None:
    rendered = fallback_training_text(row())

    assert ASSISTANT_HEADER in rendered
    assert row()["completion"] in rendered


def test_prompt_completion_pair_splits_at_generation_prompt() -> None:
    pair = prompt_completion_pair(row(), FakePromptTokenizer())

    assert pair["prompt"].endswith(ASSISTANT_HEADER)
    assert not pair["completion"].startswith(ASSISTANT_HEADER)
    assert pair["completion"] == completion_text(row(), FakePromptTokenizer())
    assert pair["prompt"] == prompt_text(row(), FakePromptTokenizer())


def test_split_train_eval_is_deterministic_and_keeps_training_rows() -> None:
    rows = [row(index) for index in range(50)]
    train_a, eval_a = split_train_eval(rows, eval_fraction=0.1, seed=7)
    train_b, eval_b = split_train_eval(rows, eval_fraction=0.1, seed=7)

    assert train_a == train_b
    assert eval_a == eval_b
    assert len(train_a) == 45
    assert len(eval_a) == 5
