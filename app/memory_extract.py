"""Cheap, local, deterministic durable-fact extraction for the Pika companion.

Given a single user message, ``extract_facts`` returns a small list of
``(kind, text, weight)`` candidates that look durable enough to remember across
sessions -- the caller persists them via ``app.memory_store.add_fact``.

Design choices:

* **No model call.** Extraction runs on every companion turn, so it must be
  near-free. A handful of anchored regexes is enough to catch the high-signal
  cases (name, goal, mood, event) and is fully deterministic, which keeps tests
  stable.
* **Conservative by construction.** Ephemeral chatter ("ok", "lol", "what time
  is it") matches nothing and yields ``[]``. We would rather miss a fact than
  pollute long-term memory with noise, so each pattern requires an explicit
  first-person anchor ("my name is", "I want to", "I feel", "today I ...").
* **Stdlib only.** No new dependencies.
"""

from __future__ import annotations

import re

# Keep extracted snippets short so recall stays inside the brain's token budget.
_MAX_FACT_CHARS = 120

# Filler that, when it is the *entire* captured span, signals non-durable noise.
_EPHEMERAL = {
    "", "ok", "okay", "k", "lol", "lmao", "haha", "hi", "hey", "hello",
    "yes", "no", "yeah", "nah", "sure", "good", "fine", "nice", "cool",
    "thanks", "thank you", "bye", "idk", "hmm", "huh", "yo", "sup",
}

# Each rule: (kind, weight, compiled pattern). The pattern's first group is the
# durable payload. Patterns are anchored to first-person declarations so passing
# chatter never matches. Order matters only for which kind wins on overlap; we
# return all non-empty matches.
_RULES: list[tuple[str, float, re.Pattern[str]]] = [
    # "my name is X" / "I am called X" / "call me X" / "I'm X" (name-shaped only).
    ("name", 2.0, re.compile(r"\bmy name is\s+(.+)", re.IGNORECASE)),
    ("name", 2.0, re.compile(r"\b(?:i am|i'm)\s+called\s+(.+)", re.IGNORECASE)),
    ("name", 2.0, re.compile(r"\bcall me\s+(.+)", re.IGNORECASE)),
    # "my goal is X" / "I want to X" / "I'd like to X" / "I plan to X".
    ("goal", 1.5, re.compile(r"\bmy goal is\s+(.+)", re.IGNORECASE)),
    ("goal", 1.5, re.compile(r"\bi want to\s+(.+)", re.IGNORECASE)),
    ("goal", 1.5, re.compile(r"\bi(?:'d| would) like to\s+(.+)", re.IGNORECASE)),
    ("goal", 1.5, re.compile(r"\bi(?:'m| am) (?:trying|hoping|planning) to\s+(.+)", re.IGNORECASE)),
    # "I feel X" / "I'm <emotion>" -- recurring mood signal.
    ("mood", 1.0, re.compile(r"\bi feel\s+(.+)", re.IGNORECASE)),
    ("mood", 1.0, re.compile(r"\bi(?:'m| am) feeling\s+(.+)", re.IGNORECASE)),
    # "today I did X" / "yesterday I X" -- notable event.
    ("event", 1.0, re.compile(r"\b(?:today|yesterday|this morning|tonight)\s+i\s+(.+)", re.IGNORECASE)),
]


def _clean(span: str) -> str:
    """Trim a captured span to a short, punctuation-bounded fact payload."""
    # Stop at the first sentence boundary so we don't swallow trailing clauses.
    span = re.split(r"[.!?\n]", span, maxsplit=1)[0]
    span = " ".join(span.split()).strip(" ,;:-")
    return span[:_MAX_FACT_CHARS].strip()


def extract_facts(message: str) -> list[tuple[str, str, float]]:
    """Return durable ``(kind, text, weight)`` candidates from ``message``.

    Conservative: junk/ephemeral input yields an empty list. The same payload is
    never returned twice (first/highest-weight rule wins), so the caller can
    persist each candidate without re-deduplicating kinds itself.
    """
    if not message:
        return []

    candidates: list[tuple[str, str, float]] = []
    seen: set[tuple[str, str]] = set()
    for kind, weight, pattern in _RULES:
        match = pattern.search(message)
        if not match:
            continue
        payload = _clean(match.group(1))
        if not payload or payload.casefold() in _EPHEMERAL:
            continue
        key = (kind, payload.casefold())
        if key in seen:
            continue
        seen.add(key)
        candidates.append((kind, payload, weight))
    return candidates
