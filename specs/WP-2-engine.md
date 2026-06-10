# WP-2 — Deterministic game engine (the model never does logic)

Read `PRD.md` §4.1 and §5.4, plus `engine/schema.py` (frozen — do not touch).

## Deliverables

1. `engine/state.py`
   - `GameState`: `hp: int = 10`, `inventory: list[str]` (≤6), `location: str`, `flags: list[str]`, `turn_count: int = 0`, `genre: str`, `premise: str | None`, plus `recent_turns: list[tuple[Turn, str]]` (last 2 (turn, chosen_action) pairs).
   - `apply_delta(state, turn) -> GameState`: clamp hp to 0–10; cap inventory at 6 (drop overflow adds, keep order); removing an absent item is a no-op; dedupe items/flags case-insensitively; bump `turn_count`; update location.
   - `validate_turn(state, turn) -> list[str]` (empty = valid): exactly-3 distinct choices (distinctness = lowercased token-set Jaccard < 0.8 pairwise — cheap, no embeddings at inference), no choice identical to a choice offered last turn, narration not near-verbatim repeat of last narration (Jaccard < 0.9), `remove_items` must exist in inventory, death/ending consistency (`hp + delta ≤ 0` ⇒ ending turn expected; see pressure rules).
2. `engine/pressure.py` — story pressure injected into the prompt, pure function of state:
   - turns 1–5 → act-1 hint ("establish the quest, introduce danger"), 6–10 → act-2 ("raise stakes, complicate"), 11–13 → "move decisively toward a climax", 14 → "next turn MUST end the story", 15 → instruct `is_ending: true` (and the engine *requires* it: a non-ending turn at 15 fails validation).
   - hp ≤ 2 → "the player is near death" hint; hp 0 after delta → demand a (funny, not bleak) death ending.
3. `engine/prompt.py` — `build_messages(state) -> list[dict]` per PRD DR-3: system prompt (DM persona + schema instructions + genre flavor) and a user message containing: compact state summary (hp, inventory, location, flags, turn, act pressure), the last 2 turns as compact JSON + the action the player took, and "Respond with ONLY the turn JSON." Genre flavor table for the 3 launch genres lives here. **This module is shared by the teacher generator (WP-3) and inference — keep it dependency-free.**
   **HARD TOKEN BUDGET (from the measured 35.6 tok/s prefill on the 2 vCPU Space — TTFT is the bottleneck):** the full rendered prompt must stay ≤ 350 tokens (~1,400 chars), structured as a **byte-identical stable prefix** (system + genre flavor, ≤ 200 tokens — llama-server prefix-caches it) followed by the dynamic suffix (state summary + last 2 turns compacted, ≤ 150 tokens; truncate prior narrations to their first sentence in the history block). Add a unit test that renders a worst-case state (full inventory, 2 long turns) and asserts `len(rendered) <= 1400` chars and that the prefix is byte-identical across two different states of the same genre.
4. `engine/generate.py` — backend protocol + retry policy:
   - `TurnBackend` protocol: `complete(messages, *, temperature: float) -> str` (returns raw JSON text).
   - `next_turn(state, backend) -> Turn`: parse → schema-validate → `validate_turn`; on any failure retry ONCE at temperature+0.15; then return the genre's canned bridge turn (3 canned bridge turns per genre in `engine/bridges.py`, schema-valid, neutral delta) and mark it `bridge=True` in the returned wrapper `TurnResult(turn, used_bridge, raw_attempts)`.
   - `MockBackend` for tests (plays scripted adventures).
5. `engine/repl.py` + console entry `pocketdm-repl` — plays a full game in the terminal against any backend (`--backend mock|openai`, where `openai` is any OpenAI-compatible base URL e.g. a Modal vLLM endpoint; env `POCKETDM_BASE_URL`, `POCKETDM_MODEL`). Renders narration, numbered choices, hp/inventory line; accepts 1/2/3 or freeform text.
6. `tests/test_engine.py` — clamping, validation failures, pressure schedule (incl. forced ending at 15), retry→bridge path, and a full scripted 10-turn MockBackend game reaching an ending with zero exceptions.

## Constraints
- Runtime deps: pydantic only (openai client optional import for the repl backend; add `openai` as an optional dependency group `repl`).
- Determinism: same state + same backend responses ⇒ identical results. No randomness in the engine itself.
- `uv run pytest` green.
