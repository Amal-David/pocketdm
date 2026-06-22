"""Pattern-aware proactive check-in intent selection for the Pika companion.

Layer 3 of brain-memory: instead of always firing a generic daypart cheer, this
module inspects the user's stored history and decides whether the proactive line
should be *personalized* around a detected pattern -- or whether there isn't
enough signal, in which case the caller falls back to today's generic cheer.

Two intents are detected, in priority order:

1. ``welcome_back`` (ABSENCE): the user has been away for a meaningful gap, so
   the next proactive line should warmly welcome them back rather than launch
   straight into a slump-preempt.
2. ``preempt_slump`` (SLUMP): the *current* daypart has a recurring negative-mood
   pattern across the history window, so the line should gently get ahead of the
   usual dip before it lands.

Otherwise -> ``None`` (insufficient signal): the caller uses the generic cheer
and never fabricates a pattern.

Everything here is deterministic given a pinned ``now`` and stdlib-only, so the
thresholds and ordering stay stable under test.

--- Mood polarity mapping -------------------------------------------------

Moods are classified into three buckets by an explicit, documented table
(``_MOOD_POLARITY``). Matching is case-insensitive and substring-based so common
phrasings ("a bit tired", "feeling low") still land. Anything unmapped is
treated as ``neutral`` (no slump signal), keeping detection conservative.

  positive: happy, great, good, bright, excited, proud, calm, energized, ...
  negative: tired, sad, low, anxious, stressed, overwhelmed, down, burned out, ...
  neutral:  everything else (including unknown moods)

--- Thresholds ------------------------------------------------------------

* ABSENCE (welcome_back): ``last_seen_gap`` >= ``ABSENCE_GAP_DAYS`` (default 2
  days). ``last_seen_gap`` is parsed from the same compact strings the native
  app sends ("3h", "2d", "45m", "90s").
* SLUMP (preempt_slump): within ``HISTORY_WINDOW_DAYS`` (default 14), at the
  current daypart there must be >= ``SLUMP_MIN_NEGATIVE_DAYS`` (default 3)
  *distinct days* carrying a negative mood AND negatives must be a strict
  majority of that daypart's polarized (non-neutral) observations. Counting
  distinct days stops one chatty low afternoon from masquerading as a habit.
"""

from __future__ import annotations

from typing import Any

# Whole-day boundary for the absence welcome-back, in days.
ABSENCE_GAP_DAYS = 2.0

# How far back slump detection looks, in days.
HISTORY_WINDOW_DAYS = 14.0

# Minimum number of *distinct days* at the current daypart that must carry a
# negative mood before we treat the daypart as a recurring slump.
SLUMP_MIN_NEGATIVE_DAYS = 3

# Explicit, documented mood polarity table. Keys are matched case-insensitively
# as substrings of the stored mood string, so "a bit tired" -> negative.
_NEGATIVE_MOODS = (
    "tired", "exhausted", "sleepy", "sad", "low", "down", "blue",
    "anxious", "anxiety", "stressed", "stress", "overwhelmed", "burned out",
    "burnt out", "drained", "frustrated", "lonely", "discouraged", "flat",
    "foggy", "sluggish",
)
_POSITIVE_MOODS = (
    "happy", "great", "good", "bright", "excited", "proud", "calm",
    "content", "energized", "energised", "motivated", "joy", "cheerful",
    "relaxed", "hopeful", "grateful",
)


def classify_mood(mood: str | None) -> str:
    """Return ``"positive"`` / ``"negative"`` / ``"neutral"`` for a mood string.

    Substring + case-insensitive against the documented tables. Negative is
    checked first so a phrase containing both leans cautious. Unknown moods are
    ``neutral`` -- they carry no slump signal, keeping detection conservative.
    """
    text = (mood or "").strip().casefold()
    if not text:
        return "neutral"
    if any(token in text for token in _NEGATIVE_MOODS):
        return "negative"
    if any(token in text for token in _POSITIVE_MOODS):
        return "positive"
    return "neutral"


def parse_gap_days(last_seen_gap: Any) -> float | None:
    """Parse a compact gap string ("3h", "2d", "45m", "90s") into days.

    Returns ``None`` when the value is missing or unparseable, so the caller
    simply skips the absence branch rather than guessing a gap.
    """
    if last_seen_gap is None:
        return None
    text = str(last_seen_gap).strip().casefold()
    if not text:
        return None
    # Numeric suffix unit; default unit when bare number is days (matches the
    # native app's day-granularity streak gaps).
    unit = text[-1]
    number_part = text[:-1] if unit.isalpha() else text
    try:
        value = float(number_part)
    except ValueError:
        return None
    seconds_per = {"s": 1.0, "m": 60.0, "h": 3600.0, "d": 86400.0}
    factor = seconds_per.get(unit, 86400.0)  # bare number -> days
    return (value * factor) / 86400.0


def _distinct_day_index(created_at: float) -> int:
    """Collapse a timestamp to an integer day bucket (UTC-epoch day)."""
    return int(created_at // 86400)


def _detect_slump(
    user_id: str,
    current_daypart: str,
    now: float,
) -> bool:
    """True when ``current_daypart`` shows a recurring negative-mood pattern.

    Requires >= ``SLUMP_MIN_NEGATIVE_DAYS`` distinct negative days at this
    daypart AND negatives forming a strict majority of polarized observations.
    """
    from app.memory_store import observations_by_daypart

    rows = observations_by_daypart(
        user_id, current_daypart, since_days=HISTORY_WINDOW_DAYS, now=now
    )
    if not rows:
        return False

    negative_days: set[int] = set()
    negative = 0
    positive = 0
    for mood, created_at in rows:
        polarity = classify_mood(mood)
        if polarity == "negative":
            negative += 1
            negative_days.add(_distinct_day_index(created_at))
        elif polarity == "positive":
            positive += 1

    if len(negative_days) < SLUMP_MIN_NEGATIVE_DAYS:
        return False
    # Strict majority of the *polarized* observations must be negative, so a
    # daypart that's negative-then-positive doesn't trip the slump.
    polarized = negative + positive
    return polarized > 0 and negative * 2 > polarized


def select_proactive_intent(
    user_id: str,
    current_daypart: str | None,
    last_seen_gap: Any,
    now: float,
) -> dict[str, Any] | None:
    """Pick a proactive intent from stored history, or ``None`` for generic cheer.

    Returns a small structured intent dict or ``None``:

    * ``{"intent": "welcome_back", "gap_days": <float>}`` -- absence gap met.
    * ``{"intent": "preempt_slump", "daypart": <str>}`` -- recurring slump at
      this daypart.
    * ``None`` -- insufficient signal; caller uses the existing generic cheer.

    Absence wins over slump: returning after a break, a warm welcome reads
    better than leading with "you usually dip now". Best-effort: any store
    failure degrades to ``None`` so the caller never errors.
    """
    gap_days = parse_gap_days(last_seen_gap)
    if gap_days is not None and gap_days >= ABSENCE_GAP_DAYS:
        return {"intent": "welcome_back", "gap_days": round(gap_days, 2)}

    daypart = (current_daypart or "").strip()
    if daypart:
        try:
            if _detect_slump(user_id, daypart, now):
                return {"intent": "preempt_slump", "daypart": daypart}
        except Exception:
            # Pattern detection is best-effort; never block the cheer path.
            return None
    return None
