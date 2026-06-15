"""Keyless agent tools for the local Pika companion.

These helpers give the offline assistant a few real, deterministic facts to
ground its replies: the current local time, live weather (via the keyless
Open-Meteo API), and a keyless web lookup (via the DuckDuckGo Instant Answer
API). Every network call has a short timeout and degrades gracefully -- these
functions never raise so the assistant path stays safe to call inline.

No API keys and no third-party dependencies: stdlib ``urllib`` only.
"""

from __future__ import annotations

import json
import os
from datetime import datetime
from typing import Any
from urllib import error as urlerror
from urllib import parse as urlparse
from urllib import request as urlrequest

_NETWORK_TIMEOUT = 6.0
_DEFAULT_LOCATION = "San Francisco"
_USER_AGENT = "PocketDM-Pika/1.0 (keyless agent tools)"

_WEATHER_CODES = {
    0: "clear",
    1: "mostly clear",
    2: "partly cloudy",
    3: "overcast",
    45: "foggy",
    48: "foggy",
    51: "drizzly",
    53: "drizzly",
    55: "drizzly",
    56: "freezing drizzle",
    57: "freezing drizzle",
    61: "rainy",
    63: "rainy",
    65: "heavy rain",
    66: "freezing rain",
    67: "freezing rain",
    71: "snowy",
    73: "snowy",
    75: "heavy snow",
    77: "snow grains",
    80: "rain showers",
    81: "rain showers",
    82: "heavy rain showers",
    85: "snow showers",
    86: "snow showers",
    95: "thunderstorms",
    96: "thunderstorms with hail",
    99: "thunderstorms with hail",
}


def now_fact() -> str:
    """Return the current local time and date as a single sentence.

    Example: ``"It is 2:45 PM on Monday, June 16, 2026."``. No network access.
    """

    now = datetime.now().astimezone()
    time_text = now.strftime("%I:%M %p").lstrip("0")
    date_text = now.strftime("%A, %B %d, %Y").replace(" 0", " ")
    return f"It is {time_text} on {date_text}."


def weather_fact(location: str | None = None) -> str:
    """Return a short live-weather line via the keyless Open-Meteo API.

    Geocodes ``location`` with Open-Meteo's free geocoding endpoint. When
    ``location`` is ``None`` it falls back to ``POCKETDM_DEFAULT_LOCATION`` or a
    sensible default. On any failure it returns a graceful string instead of
    raising.
    """

    query = (location or os.environ.get("POCKETDM_DEFAULT_LOCATION") or _DEFAULT_LOCATION).strip()
    if not query:
        query = _DEFAULT_LOCATION
    try:
        place = _geocode_location(query)
        if place is None:
            return f"I couldn't find weather for {query} right now."
        latitude, longitude, label = place
        weather = _fetch_current_weather(latitude, longitude)
        if weather is None:
            return "I couldn't reach a live forecast right now."
        temperature, code = weather
        condition = _WEATHER_CODES.get(code, "cloudy")
        return f"It's {temperature}°C and {condition} in {label}."
    except Exception:
        return "I couldn't reach a live forecast right now."


def web_search_fact(query: str) -> str:
    """Return a short keyless web-search answer via the DuckDuckGo Instant Answer API.

    Prefers the ``AbstractText`` / ``Answer`` fields, then falls back to the
    first related topic. Trimmed to ~280 characters. On any failure it returns a
    graceful string instead of raising.
    """

    cleaned = (query or "").strip()
    if not cleaned:
        return "I need something to look up first."
    try:
        params = urlparse.urlencode(
            {"q": cleaned, "format": "json", "no_html": "1", "skip_disambig": "1"}
        )
        data = _get_json(f"https://api.duckduckgo.com/?{params}")
        if not isinstance(data, dict):
            return "I couldn't find a quick answer for that right now."
        answer = _best_duckduckgo_text(data)
        if not answer:
            return f"I couldn't find a quick answer about {cleaned}."
        return _trim(answer, 280)
    except Exception:
        return "I couldn't reach a search source right now."


def gather_tool_facts(user_message: str) -> str | None:
    """Detect tool intent in ``user_message`` and return grounded facts, or None.

    Returns a combined facts string to inject into the LLM prompt when the
    message asks about the time/date, the weather, or is a general factual
    question / explicit lookup. Returns ``None`` when no tool applies.
    """

    message = (user_message or "").strip()
    if not message:
        return None
    lowered = message.casefold()

    wants_time = _wants_time(lowered)
    wants_weather = _wants_weather(lowered)

    facts: list[str] = []
    if wants_time:
        facts.append(now_fact())
    if wants_weather:
        facts.append(weather_fact(_extract_location(message)))
    # Web search is the fallback only when the message is not already a
    # time/weather question, so "what time is it?" stays a pure time answer.
    if not wants_time and not wants_weather and _wants_web_search(lowered):
        facts.append(web_search_fact(message))

    if not facts:
        return None
    return " ".join(facts)


def _wants_time(lowered: str) -> bool:
    text = lowered.strip(" ?!.")
    if text in {"time", "date", "day"}:
        return True
    return any(
        phrase in lowered
        for phrase in (
            "what time",
            "time is it",
            "the time",
            "time now",
            "current time",
            "what date",
            "what day",
            "today's date",
            "todays date",
            "date today",
            "day of the week",
        )
    )


def _wants_weather(lowered: str) -> bool:
    return any(
        word in lowered
        for word in (
            "weather",
            "forecast",
            "temperature",
            "how hot",
            "how cold",
            "raining",
            "snowing",
            "umbrella",
        )
    )


_SEARCH_TRIGGERS = (
    "search",
    "look up",
    "lookup",
    "google",
    "who is",
    "who was",
    "what is",
    "what was",
    "what are",
    "when is",
    "when was",
    "where is",
    "where was",
    "how many",
    "how tall",
    "how far",
    "tell me about",
    "find out",
)


def _wants_web_search(lowered: str) -> bool:
    if any(trigger in lowered for trigger in _SEARCH_TRIGGERS):
        return True
    # A bare question that is not about the pet/adventure itself.
    return lowered.rstrip().endswith("?") and lowered.startswith(
        ("who ", "what ", "when ", "where ", "why ", "how ", "which ")
    )


_LOCATION_PREPOSITIONS = (" in ", " at ", " for ", " near ", " around ")


def _extract_location(message: str) -> str | None:
    """Pull a named location out of a weather question, if one is present."""

    lowered = message.casefold()
    cut = len(message)
    for preposition in _LOCATION_PREPOSITIONS:
        index = lowered.rfind(preposition)
        if index >= 0:
            tail = message[index + len(preposition):].strip()
            tail = tail.rstrip(" ?!.").strip()
            tail = _strip_trailing_time_words(tail)
            if tail:
                return tail
            cut = min(cut, index)
    return None


def _strip_trailing_time_words(text: str) -> str:
    for suffix in (" today", " tonight", " tomorrow", " right now", " now", " this week"):
        if text.casefold().endswith(suffix):
            return text[: -len(suffix)].strip()
    return text


def _geocode_location(query: str) -> tuple[float, float, str] | None:
    params = urlparse.urlencode({"name": query, "count": 1, "language": "en", "format": "json"})
    data = _get_json(f"https://geocoding-api.open-meteo.com/v1/search?{params}")
    if not isinstance(data, dict):
        return None
    results = data.get("results")
    if not results:
        return None
    top = results[0]
    latitude = top.get("latitude")
    longitude = top.get("longitude")
    if latitude is None or longitude is None:
        return None
    label = top.get("name") or query
    return float(latitude), float(longitude), str(label)


def _fetch_current_weather(latitude: float, longitude: float) -> tuple[int, int] | None:
    params = urlparse.urlencode(
        {
            "latitude": latitude,
            "longitude": longitude,
            "current": "temperature_2m,weather_code",
        }
    )
    data = _get_json(f"https://api.open-meteo.com/v1/forecast?{params}")
    if not isinstance(data, dict):
        return None
    current = data.get("current")
    if not isinstance(current, dict):
        return None
    temperature = current.get("temperature_2m")
    code = current.get("weather_code")
    if temperature is None or code is None:
        return None
    return round(float(temperature)), int(code)


def _best_duckduckgo_text(data: dict[str, Any]) -> str:
    for key in ("AbstractText", "Answer"):
        value = data.get(key)
        if isinstance(value, str) and value.strip():
            return value.strip()
    definition = data.get("Definition")
    if isinstance(definition, str) and definition.strip():
        return definition.strip()
    for topic in data.get("RelatedTopics", []) or []:
        if isinstance(topic, dict):
            text = topic.get("Text")
            if isinstance(text, str) and text.strip():
                return text.strip()
            for nested in topic.get("Topics", []) or []:
                if isinstance(nested, dict):
                    nested_text = nested.get("Text")
                    if isinstance(nested_text, str) and nested_text.strip():
                        return nested_text.strip()
    return ""


def _get_json(url: str) -> Any:
    request = urlrequest.Request(url, headers={"User-Agent": _USER_AGENT, "Accept": "application/json"})
    try:
        with urlrequest.urlopen(request, timeout=_NETWORK_TIMEOUT) as response:
            raw = response.read().decode("utf-8")
    except (OSError, urlerror.URLError, ValueError):
        return None
    try:
        return json.loads(raw)
    except (ValueError, TypeError):
        return None


def _trim(text: str, limit: int) -> str:
    compact = " ".join(text.split())
    if len(compact) <= limit:
        return compact
    clipped = compact[: limit - 1].rstrip()
    sentence_end = max(clipped.rfind("."), clipped.rfind("!"), clipped.rfind("?"))
    if sentence_end >= limit // 2:
        return clipped[: sentence_end + 1]
    return clipped.rstrip(" ,;:") + "…"
