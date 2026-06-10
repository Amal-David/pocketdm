# WP-1 — Freeze the turn schema (the contract everything is built around)

Read `PRD.md` §4.1 (FR-2..FR-6, turn schema JSON) and §5.4 first.

## Deliverables

1. `pyproject.toml` — uv-compatible project `pocketdm`, Python ≥3.11, deps: `pydantic>=2`, dev deps: `pytest`. Keep minimal; later WPs add deps.
2. `engine/__init__.py`, `engine/schema.py` — pydantic v2 models:
   - `StateDelta`: `hp: int` (delta, must satisfy -10 ≤ hp ≤ 10), `add_items: list[str]` (≤3 per turn), `remove_items: list[str]` (≤3), `location: str` (1–60 chars), `add_flags: list[str]` (≤3).
   - `Turn`: `narration: str` (1–600 chars), `choices: list[str]` (exactly 3, each 1–80 chars), `state_delta: StateDelta`, `is_ending: bool`, `ending_type: Literal["victory","death","bittersweet"] | None`.
   - Model-level rule: `ending_type` is non-null iff `is_ending` is true.
   - `Turn.model_json_schema()` is the single source of truth; add `CANONICAL_KEY_ORDER` constants so the GBNF and any prompt examples can be asserted against them.
3. `engine/grammar.gbnf` — **hand-written** GBNF for llama.cpp that admits exactly the canonical JSON serialization of `Turn`:
   - Fixed key order: `narration`, `choices`, `state_delta` (keys: `hp`, `add_items`, `remove_items`, `location`, `add_flags`), `is_ending`, `ending_type`.
   - `choices` array: exactly 3 string elements.
   - `hp`: optional minus sign + 1–2 digits (write digit alternatives explicitly — **no `\d` or PCRE shorthands**, llama.cpp's converter chokes on them; this is hand-written precisely to avoid that class of bug).
   - strings: JSON-escaped, no raw newlines; allow standard `\"` `\\` `\n` escapes.
   - `ending_type`: `null` or one of the three quoted enum strings.
   - Whitespace: allow optional single spaces/newlines between tokens (the model will emit compact-ish JSON; don't be stricter than the fine-tune data will be).
4. `tests/test_schema.py` —
   - Round-trip: ≥5 valid sample turns (include an ending turn, a death turn, a negative-hp turn, empty lists) parse and re-serialize stably.
   - Rejection: wrong choice count, hp out of range, `is_ending=true` with `ending_type=null`, >600-char narration, extra keys (forbid extras).
   - Grammar structural pin: parse `engine/grammar.gbnf` as text and assert every canonical key appears as a quoted literal in canonical order, and the enum strings + `null` are present — this keeps grammar and schema from drifting.
   - Grammar syntax check: if `llama_cpp` is importable, `LlamaGrammar.from_string(...)` must succeed; otherwise skip with reason (full behavioral acceptance happens in WP-6's 50-session live test).
5. `specs/SCHEMA-FROZEN.md` — one page: the canonical JSON example, key order, and the rule "any change here requires regenerating data + grammar + retraining; don't."

## Constraints
- Pure stdlib + pydantic; no other runtime deps in `engine/`.
- Format/style: black-compatible defaults, type hints throughout.
- All tests must pass with `uv run pytest`.
