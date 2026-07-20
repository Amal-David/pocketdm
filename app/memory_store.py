"""Tiny on-disk memory store for the local Pika companion.

This module persists two kinds of memory so the offline brain can personalize
its tone across process restarts:

1. The pet's latest *state snapshot* (streak, Bond HP, mood, daypart, last-seen
   gap), upserted by ``user_id`` -- only the newest snapshot is kept.
2. Durable *facts* about the user (name, goals, recurring moods, notable
   events), accumulated over time and recalled by relevance. Unlike the
   snapshot, facts are append-and-bump: a new fact adds a row, while a near
   duplicate bumps the existing row's weight and recency instead.

It uses the stdlib ``sqlite3`` module only -- no new pip dependencies, no
network calls, a single SQLite file on local disk.

Storage path resolution matches the repo's ``POCKETDM_`` env-var convention:
``POCKETDM_MEMORY_DB`` overrides the default ``~/.pocketdm/memory.db``.
"""

from __future__ import annotations

import json
import os
import re
import sqlite3
import time
from pathlib import Path
from typing import Any

DEFAULT_MEMORY_DB = Path.home() / ".pocketdm" / "memory.db"
DEFAULT_USER_ID = "default"

# The discrete columns the brain cares about for tone. Anything else the caller
# passes is preserved under the free-form ``extra`` JSON blob.
_STATE_FIELDS = ("streak", "bond_hp", "mood", "daypart", "last_seen_gap")

# The durable fact kinds the brain understands. ``other`` is the catch-all.
FACT_KINDS = ("name", "goal", "mood", "event", "other")

# Recency half-life for the relevance score, in seconds (7 days). A fact loses
# half its recency contribution every ``_RECENCY_HALF_LIFE_SECONDS`` since it was
# last used, so fresh, oft-touched facts win without ever fully discarding old
# high-weight ones. See ``recall_facts`` for the full formula.
_RECENCY_HALF_LIFE_SECONDS = 7 * 24 * 60 * 60


def _db_path() -> Path:
    raw = os.environ.get("POCKETDM_MEMORY_DB", "").strip()
    return Path(raw).expanduser() if raw else DEFAULT_MEMORY_DB


def _connect() -> sqlite3.Connection:
    path = _db_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    connection = sqlite3.connect(str(path))
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS pet_state (
            user_id TEXT PRIMARY KEY,
            streak INTEGER,
            bond_hp INTEGER,
            mood TEXT,
            daypart TEXT,
            last_seen_gap TEXT,
            extra TEXT
        )
        """
    )
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS facts (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            kind TEXT NOT NULL,
            text TEXT NOT NULL,
            norm TEXT NOT NULL,
            weight REAL NOT NULL DEFAULT 1.0,
            created_at REAL NOT NULL,
            last_used_at REAL NOT NULL
        )
        """
    )
    # One row per (user, kind, normalized-text) so de-duplication is enforced at
    # the storage layer, not just in application code.
    connection.execute(
        "CREATE UNIQUE INDEX IF NOT EXISTS facts_dedupe "
        "ON facts(user_id, kind, norm)"
    )
    # Append-only mood-by-daypart history. Unlike ``pet_state`` (which keeps only
    # the latest snapshot) this table accumulates one row every time a state is
    # observed, so proactive pattern detection can ask "is this daypart usually
    # low-mood?" across many days. Kept tiny: just the columns slump/absence
    # detection needs.
    connection.execute(
        """
        CREATE TABLE IF NOT EXISTS observations (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id TEXT NOT NULL,
            daypart TEXT,
            mood TEXT,
            created_at REAL NOT NULL
        )
        """
    )
    return connection


def save_state(user_id: str, state: dict[str, Any], *, db_path: str | None = None) -> dict[str, Any]:
    """Upsert the latest pet-state snapshot for ``user_id``.

    Known fields (streak, bond_hp, mood, daypart, last_seen_gap) land in their
    own columns; any other keys are preserved under a free-form JSON blob.
    Partial updates are merged: a field that is absent/None in ``state`` keeps
    its previously stored value (COALESCE) rather than being nulled out.
    Returns the persisted state as a plain dict (the same shape ``get_state``
    returns).
    """
    if db_path is not None:
        os.environ["POCKETDM_MEMORY_DB"] = db_path

    user_id = user_id or DEFAULT_USER_ID
    known = {field: state.get(field) for field in _STATE_FIELDS}
    extra = {key: value for key, value in state.items() if key not in _STATE_FIELDS}

    connection = _connect()
    try:
        connection.execute(
            """
            INSERT INTO pet_state (user_id, streak, bond_hp, mood, daypart, last_seen_gap, extra)
            VALUES (:user_id, :streak, :bond_hp, :mood, :daypart, :last_seen_gap, :extra)
            ON CONFLICT(user_id) DO UPDATE SET
                streak = COALESCE(excluded.streak, pet_state.streak),
                bond_hp = COALESCE(excluded.bond_hp, pet_state.bond_hp),
                mood = COALESCE(excluded.mood, pet_state.mood),
                daypart = COALESCE(excluded.daypart, pet_state.daypart),
                last_seen_gap = COALESCE(excluded.last_seen_gap, pet_state.last_seen_gap),
                extra = COALESCE(excluded.extra, pet_state.extra)
            """,
            {
                "user_id": user_id,
                "extra": json.dumps(extra) if extra else None,
                **known,
            },
        )
        connection.commit()
    finally:
        connection.close()

    return get_state(user_id)


def get_state(user_id: str = DEFAULT_USER_ID) -> dict[str, Any]:
    """Return the persisted pet-state snapshot for ``user_id`` as a plain dict.

    Returns an empty dict when no snapshot has been saved yet, so callers can
    degrade cleanly to today's stateless behavior.
    """
    user_id = user_id or DEFAULT_USER_ID
    connection = _connect()
    try:
        row = connection.execute(
            "SELECT streak, bond_hp, mood, daypart, last_seen_gap, extra FROM pet_state WHERE user_id = ?",
            (user_id,),
        ).fetchone()
    finally:
        connection.close()

    if row is None:
        return {}

    streak, bond_hp, mood, daypart, last_seen_gap, extra = row
    state: dict[str, Any] = {
        "streak": streak,
        "bond_hp": bond_hp,
        "mood": mood,
        "daypart": daypart,
        "last_seen_gap": last_seen_gap,
    }
    # Drop columns that were never set so absent input stays absent on read.
    state = {key: value for key, value in state.items() if value is not None}
    if extra:
        state.update(json.loads(extra))
    return state


# --- Durable facts ---------------------------------------------------------


def _normalize_fact(text: str) -> str:
    """Collapse a fact to a comparison key so near-duplicates dedupe.

    Lowercases, strips surrounding/inner punctuation, and squeezes whitespace so
    ``"My name is Amal."`` and ``"my name is  amal"`` map to the same key.
    """
    lowered = re.sub(r"[^\w\s]", " ", text.casefold())
    return " ".join(lowered.split())


def add_fact(
    user_id: str,
    kind: str,
    text: str,
    weight: float = 1.0,
    *,
    db_path: str | None = None,
    now: float | None = None,
) -> None:
    """Persist a durable fact for ``user_id``, de-duplicating near-identical text.

    A fact whose normalized text already exists (same ``user_id`` + ``kind``) is
    NOT inserted twice: instead its ``weight`` is increased by the incoming
    weight and its ``last_used_at`` is refreshed, so repetition reinforces a
    memory rather than cluttering the table. ``kind`` outside ``FACT_KINDS`` is
    coerced to ``"other"``. Blank text is ignored.
    """
    if db_path is not None:
        os.environ["POCKETDM_MEMORY_DB"] = db_path

    text = " ".join((text or "").split())
    if not text:
        return
    user_id = user_id or DEFAULT_USER_ID
    kind = kind if kind in FACT_KINDS else "other"
    norm = _normalize_fact(text)
    stamp = time.time() if now is None else now

    connection = _connect()
    try:
        connection.execute(
            """
            INSERT INTO facts (user_id, kind, text, norm, weight, created_at, last_used_at)
            VALUES (:user_id, :kind, :text, :norm, :weight, :stamp, :stamp)
            ON CONFLICT(user_id, kind, norm) DO UPDATE SET
                weight = weight + excluded.weight,
                last_used_at = excluded.last_used_at
            """,
            {
                "user_id": user_id,
                "kind": kind,
                "text": text,
                "norm": norm,
                "weight": float(weight),
                "stamp": stamp,
            },
        )
        connection.commit()
    finally:
        connection.close()


def _relevance(weight: float, last_used_at: float, now: float) -> float:
    """Deterministic relevance score: weight scaled by recency decay.

    ``score = weight * 0.5 ** (age / half_life)`` where ``age`` is seconds since
    the fact was last used and ``half_life`` is ``_RECENCY_HALF_LIFE_SECONDS``
    (7 days). A just-used fact keeps its full weight; one untouched for a
    half-life keeps half. Pure function of stored values + ``now``, so ordering
    is stable across runs given a fixed clock.
    """
    age = max(0.0, now - last_used_at)
    return float(weight) * (0.5 ** (age / _RECENCY_HALF_LIFE_SECONDS))


def recall_facts(
    user_id: str = DEFAULT_USER_ID,
    *,
    limit: int = 8,
    max_chars: int = 400,
    now: float | None = None,
) -> list[dict[str, Any]]:
    """Return the most relevant durable facts for ``user_id``.

    Facts are ordered by descending relevance (``_relevance``); ties break by
    most-recent ``last_used_at`` then highest ``id`` so ordering is fully
    deterministic. At most ``limit`` facts are considered, and the running total
    of their ``text`` lengths is capped at ``max_chars`` -- once adding a fact
    would exceed the cap it (and every less-relevant fact) is dropped, so the
    most relevant memories survive the token budget. Each entry is a dict with
    ``kind``, ``text``, and ``weight``.
    """
    user_id = user_id or DEFAULT_USER_ID
    stamp = time.time() if now is None else now

    connection = _connect()
    try:
        rows = connection.execute(
            "SELECT id, kind, text, weight, last_used_at FROM facts WHERE user_id = ?",
            (user_id,),
        ).fetchall()
    finally:
        connection.close()

    ranked = sorted(
        rows,
        key=lambda row: (
            _relevance(row[3], row[4], stamp),
            row[4],  # last_used_at
            row[0],  # id
        ),
        reverse=True,
    )

    recalled: list[dict[str, Any]] = []
    used_chars = 0
    for _id, kind, text, weight, _last_used in ranked[: max(0, limit)]:
        if used_chars + len(text) > max_chars:
            break
        used_chars += len(text)
        recalled.append({"kind": kind, "text": text, "weight": float(weight)})
    return recalled


# --- Observation history (for proactive pattern detection) -----------------


def add_observation(
    user_id: str,
    daypart: str | None,
    mood: str | None,
    *,
    db_path: str | None = None,
    now: float | None = None,
) -> None:
    """Append a timestamped (daypart, mood) observation for ``user_id``.

    Unlike ``save_state`` (which overwrites the single latest snapshot), this
    is append-only: every persisted pet-state adds one row so proactive
    detection has history to spot a recurring daypart slump. A row with neither
    a daypart nor a mood carries no pattern signal, so it is skipped.
    """
    if db_path is not None:
        os.environ["POCKETDM_MEMORY_DB"] = db_path

    daypart = (daypart or "").strip() or None
    mood = (mood or "").strip() or None
    if daypart is None and mood is None:
        return

    user_id = user_id or DEFAULT_USER_ID
    stamp = time.time() if now is None else now

    connection = _connect()
    try:
        connection.execute(
            "INSERT INTO observations (user_id, daypart, mood, created_at) "
            "VALUES (?, ?, ?, ?)",
            (user_id, daypart, mood, stamp),
        )
        connection.commit()
    finally:
        connection.close()


def mood_counts_by_daypart(
    user_id: str = DEFAULT_USER_ID,
    *,
    since_days: float = 14.0,
    now: float | None = None,
) -> dict[str, dict[str, int]]:
    """Return per-daypart mood tallies over the recent history window.

    Shape: ``{daypart: {mood: count, ...}, ...}`` counting observations newer
    than ``since_days`` ago. Rows with a null mood or daypart are skipped (they
    carry no slump signal). Deterministic given a pinned ``now``; the caller
    (``app.proactive``) turns these tallies into a slump decision.
    """
    user_id = user_id or DEFAULT_USER_ID
    stamp = time.time() if now is None else now
    cutoff = stamp - max(0.0, since_days) * 24 * 60 * 60

    connection = _connect()
    try:
        rows = connection.execute(
            "SELECT daypart, mood FROM observations "
            "WHERE user_id = ? AND created_at >= ? "
            "AND daypart IS NOT NULL AND mood IS NOT NULL",
            (user_id, cutoff),
        ).fetchall()
    finally:
        connection.close()

    counts: dict[str, dict[str, int]] = {}
    for daypart, mood in rows:
        bucket = counts.setdefault(daypart, {})
        bucket[mood] = bucket.get(mood, 0) + 1
    return counts


def observations_by_daypart(
    user_id: str = DEFAULT_USER_ID,
    daypart: str = "",
    *,
    since_days: float = 14.0,
    now: float | None = None,
) -> list[tuple[str, float]]:
    """Return ``(mood, created_at)`` observations for one daypart, oldest first.

    Used by slump detection to count *distinct days* (not just raw rows) at a
    daypart so a single chatty afternoon can't fake a recurring pattern.
    """
    user_id = user_id or DEFAULT_USER_ID
    stamp = time.time() if now is None else now
    cutoff = stamp - max(0.0, since_days) * 24 * 60 * 60

    connection = _connect()
    try:
        rows = connection.execute(
            "SELECT mood, created_at FROM observations "
            "WHERE user_id = ? AND daypart = ? AND mood IS NOT NULL "
            "AND created_at >= ? ORDER BY created_at ASC",
            (user_id, daypart, cutoff),
        ).fetchall()
    finally:
        connection.close()
    return [(mood, float(created_at)) for mood, created_at in rows]


def delete_user_memory(
    user_id: str = DEFAULT_USER_ID,
) -> dict[str, int]:
    """Delete one user's state, facts, and observations in one transaction.

    The database file is intentionally preserved: deleting rows avoids racing a
    live server connection, respects ``POCKETDM_MEMORY_DB``, and leaves any
    other local profiles untouched. ``BEGIN IMMEDIATE`` ensures another writer
    cannot interleave a partial reset. Any failure rolls the whole reset back.
    """
    user_id = user_id or DEFAULT_USER_ID
    connection = _connect()
    try:
        connection.execute("BEGIN IMMEDIATE")
        counts = {
            table: int(
                connection.execute(
                    f"SELECT COUNT(*) FROM {table} WHERE user_id = ?",
                    (user_id,),
                ).fetchone()[0]
            )
            for table in ("pet_state", "facts", "observations")
        }
        for table in ("pet_state", "facts", "observations"):
            connection.execute(f"DELETE FROM {table} WHERE user_id = ?", (user_id,))
        connection.commit()
        return counts
    except Exception:
        connection.rollback()
        raise
    finally:
        connection.close()
