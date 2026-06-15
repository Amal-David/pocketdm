"""Offline-safe tests for the keyless agent tools.

Network-backed tools (weather, web search) are monkeypatched so the suite never
touches the network. now_fact and intent routing are exercised directly.
"""

from __future__ import annotations

import re

import pytest

from app import agent_tools


def test_now_fact_format() -> None:
    fact = agent_tools.now_fact()
    # e.g. "It is 2:45 PM on Monday, June 16, 2026."
    assert re.fullmatch(
        r"It is \d{1,2}:\d{2} (?:AM|PM) on "
        r"(?:Monday|Tuesday|Wednesday|Thursday|Friday|Saturday|Sunday), "
        r"[A-Z][a-z]+ \d{1,2}, \d{4}\.",
        fact,
    ), fact
    # No zero-padding on hour or day-of-month.
    assert " 0" not in fact
    assert not fact.startswith("It is 0")


def test_gather_tool_facts_time_intent_is_pure_time(monkeypatch: pytest.MonkeyPatch) -> None:
    # A pure time question must not also fire a web search.
    monkeypatch.setattr(
        agent_tools, "web_search_fact", lambda query: pytest.fail("web search should not run")
    )
    monkeypatch.setattr(
        agent_tools, "weather_fact", lambda location=None: pytest.fail("weather should not run")
    )
    facts = agent_tools.gather_tool_facts("what time is it?")
    assert facts is not None
    assert facts == agent_tools.now_fact()


def test_gather_tool_facts_date_intent() -> None:
    facts = agent_tools.gather_tool_facts("what's the date today?")
    assert facts is not None
    assert facts.startswith("It is ")
    assert facts.endswith(".")


def test_gather_tool_facts_weather_intent_pulls_location(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: dict[str, str | None] = {}

    def fake_weather(location: str | None = None) -> str:
        captured["location"] = location
        return "It's 18°C and clear in Tokyo."

    monkeypatch.setattr(agent_tools, "weather_fact", fake_weather)
    monkeypatch.setattr(
        agent_tools, "web_search_fact", lambda query: pytest.fail("web search should not run")
    )

    facts = agent_tools.gather_tool_facts("what is the weather in Tokyo today?")
    assert facts == "It's 18°C and clear in Tokyo."
    assert captured["location"] == "Tokyo"


def test_gather_tool_facts_weather_without_location(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: dict[str, str | None] = {}

    def fake_weather(location: str | None = None) -> str:
        captured["location"] = location
        return "It's 12°C and rainy in San Francisco."

    monkeypatch.setattr(agent_tools, "weather_fact", fake_weather)
    facts = agent_tools.gather_tool_facts("hey, how's the weather?")
    assert facts == "It's 12°C and rainy in San Francisco."
    # No location named -> None passed so weather_fact uses its own default.
    assert captured["location"] is None


def test_gather_tool_facts_web_search_intent(monkeypatch: pytest.MonkeyPatch) -> None:
    captured: dict[str, str] = {}

    def fake_search(query: str) -> str:
        captured["query"] = query
        return "Mount Everest is the tallest mountain at 8,849 metres."

    monkeypatch.setattr(agent_tools, "web_search_fact", fake_search)
    monkeypatch.setattr(
        agent_tools, "weather_fact", lambda location=None: pytest.fail("weather should not run")
    )

    facts = agent_tools.gather_tool_facts("look up the tallest mountain")
    assert facts == "Mount Everest is the tallest mountain at 8,849 metres."
    assert captured["query"] == "look up the tallest mountain"


def test_gather_tool_facts_question_routes_to_search(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(
        agent_tools, "web_search_fact", lambda query: f"ANSWER<{query}>"
    )
    facts = agent_tools.gather_tool_facts("Who is Ada Lovelace?")
    assert facts == "ANSWER<Who is Ada Lovelace?>"


def test_gather_tool_facts_non_tool_messages_return_none() -> None:
    assert agent_tools.gather_tool_facts("give me a hint for the dungeon") is None
    assert agent_tools.gather_tool_facts("pet me please") is None
    assert agent_tools.gather_tool_facts("") is None
    assert agent_tools.gather_tool_facts("I am proud of finishing my task") is None


def test_weather_fact_graceful_on_geocode_failure(monkeypatch: pytest.MonkeyPatch) -> None:
    # Simulate every network call failing; must degrade, never raise.
    monkeypatch.setattr(agent_tools, "_get_json", lambda url: None)
    result = agent_tools.weather_fact("Nowhereville")
    assert isinstance(result, str)
    assert "Nowhereville" in result or "couldn't" in result.casefold()


def test_weather_fact_formats_live_data(monkeypatch: pytest.MonkeyPatch) -> None:
    def fake_get_json(url: str):
        if "geocoding-api" in url:
            return {"results": [{"latitude": 37.77, "longitude": -122.42, "name": "San Francisco"}]}
        return {"current": {"temperature_2m": 17.6, "weather_code": 0}}

    monkeypatch.setattr(agent_tools, "_get_json", fake_get_json)
    result = agent_tools.weather_fact("San Francisco")
    assert result == "It's 18°C and clear in San Francisco."


def test_web_search_fact_trims_and_prefers_abstract(monkeypatch: pytest.MonkeyPatch) -> None:
    long_text = "Ada Lovelace was a mathematician. " * 20

    def fake_get_json(url: str):
        return {"AbstractText": long_text, "RelatedTopics": [{"Text": "ignored"}]}

    monkeypatch.setattr(agent_tools, "_get_json", fake_get_json)
    result = agent_tools.web_search_fact("Ada Lovelace")
    assert result.startswith("Ada Lovelace was a mathematician.")
    assert len(result) <= 280


def test_web_search_fact_graceful_on_failure(monkeypatch: pytest.MonkeyPatch) -> None:
    monkeypatch.setattr(agent_tools, "_get_json", lambda url: None)
    result = agent_tools.web_search_fact("anything")
    assert isinstance(result, str)
    assert "couldn't" in result.casefold()


def test_web_search_fact_empty_query() -> None:
    assert "look up" in agent_tools.web_search_fact("").casefold()
