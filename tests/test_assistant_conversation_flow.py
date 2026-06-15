from __future__ import annotations

from dataclasses import dataclass

import pytest
from fastapi.testclient import TestClient

from app.server import app


@dataclass(frozen=True)
class ConversationCase:
    case_id: str
    category: str
    message: str
    expected_route: str
    must_include: tuple[str, ...] = ()
    must_not_include: tuple[str, ...] = ("My hint", "try '")
    known_gap: str | None = None


CONVERSATION_FLOW_CASES: tuple[ConversationCase, ...] = (
    ConversationCase(
        "SYS-01",
        "safe_system_data",
        "Hello what is the time now?",
        "current_time",
        ("time",),
        known_gap="Currently over-triggers the adventure hint branch because the text contains 'what'.",
    ),
    ConversationCase(
        "SYS-02",
        "safe_system_data",
        "What date is it today?",
        "current_date",
        ("date", "today"),
        known_gap="No date intent exists; 'what' routes to a hint.",
    ),
    ConversationCase(
        "SYS-03",
        "safe_system_data",
        "What day of the week is it?",
        "current_day",
        ("day",),
        known_gap="No day-of-week intent exists; 'what' routes to a hint.",
    ),
    ConversationCase(
        "SYS-04",
        "safe_system_data",
        "Which timezone are you using?",
        "timezone",
        ("timezone",),
        known_gap="Runtime/timezone information is not exposed through the assistant.",
    ),
    ConversationCase(
        "SYS-05",
        "safe_system_data",
        "How long have we been playing?",
        "session_duration",
        ("turn",),
        known_gap="Only turn count is available through status; duration is not routed.",
    ),
    ConversationCase(
        "SYS-06",
        "safe_system_data",
        "What model are you using?",
        "runtime_model_status",
        ("model",),
        known_gap="Model information is present in state payload but not answerable by assistant intent.",
    ),
    ConversationCase(
        "SYS-07",
        "safe_system_data",
        "Are you running locally or in the cloud?",
        "local_runtime_status",
        ("local",),
        known_gap="Only offline/tiny keywords return the local-first message.",
    ),
    ConversationCase(
        "SYS-08",
        "safe_system_data",
        "Can you show safe system basics?",
        "capability_summary",
        ("time", "date"),
        known_gap="Assistant has no capability-summary route for safe basics.",
    ),
    ConversationCase("ADV-01", "adventure", "hint", "adventure_hint", ("My hint",), ()),
    ConversationCase("ADV-02", "adventure", "Give me a clue for this turn.", "adventure_hint", ("hint",), ()),
    ConversationCase("ADV-03", "adventure", "status", "adventure_status", ("Adventure:", "HP"), ()),
    ConversationCase("ADV-04", "adventure", "How much HP and inventory do I have?", "adventure_status", ("HP", "inventory"), ()),
    ConversationCase("ADV-05", "adventure", "Recommend the safest choice.", "adventure_hint", ("My hint",), ()),
    ConversationCase("ADV-06", "adventure", "What should I choose in the dungeon?", "adventure_hint", ("My hint",), ()),
    ConversationCase("ADV-07", "adventure", "Why study the silver acorn?", "adventure_reason", ("precise",), ()),
    ConversationCase(
        "ADV-08",
        "adventure",
        "Can we start another adventure?",
        "adventure_reset_guidance",
        ("adventure",),
        known_gap="No reset/new-adventure guidance route exists in /api/assistant.",
    ),
    ConversationCase(
        "GEN-01",
        "general_companion",
        "Hello Pikachu.",
        "companion_greeting",
        ("Pika pika",),
        known_gap=None,
    ),
    ConversationCase(
        "GEN-02",
        "general_companion",
        "What can you do?",
        "capability_summary",
        ("hint", "status", "pet"),
        known_gap="Currently routes to adventure hint instead of a capability summary.",
    ),
    ConversationCase(
        "GEN-03",
        "general_companion",
        "I need help focusing.",
        "focus_coaching",
        ("tiny",),
        known_gap="The word 'help' routes to adventure hint before coaching can happen.",
    ),
    ConversationCase(
        "GEN-04",
        "general_companion",
        "Can you summarize my tasks?",
        "productivity_help",
        ("task",),
        known_gap="No productivity intent exists.",
    ),
    ConversationCase(
        "GEN-05",
        "general_companion",
        "What is one tiny next step?",
        "coaching",
        ("tiny", "step"),
        known_gap="The word 'what' routes to adventure hint.",
    ),
    ConversationCase(
        "GEN-06",
        "general_companion",
        "Tell me a quick joke.",
        "general_chat",
        ("Pika pika",),
        known_gap="Current fallback tells the user to ask for hint/status/pet instead of chatting.",
    ),
    ConversationCase("GEN-07", "general_companion", "Are you happy?", "pet_lore", ("Bond HP",), ()),
    ConversationCase("GEN-08", "general_companion", "Say pika pika.", "pika_phrase", ("Pika pika",), ()),
    ConversationCase(
        "WTH-01",
        "weather_checkin",
        "How is the morning weather?",
        "weather_context",
        ("weather",),
        known_gap="Weather is not routed through server assistant context.",
    ),
    ConversationCase(
        "WTH-02",
        "weather_checkin",
        "Is it gloomy outside?",
        "weather_context",
        ("gloomy",),
        known_gap="No weather context exists; assistant cannot answer safely.",
    ),
    ConversationCase(
        "WTH-03",
        "weather_checkin",
        "It's beautiful weather, isn't it?",
        "weather_affirmation",
        ("beautiful", "check-in"),
        known_gap="Morning weather line is not an assistant route in app/server.py.",
    ),
    ConversationCase(
        "WTH-04",
        "weather_checkin",
        "Daily voice check-in. User said: I feel tired.",
        "daily_checkin",
        ("tired", "rest"),
        (),
    ),
    ConversationCase(
        "WTH-05",
        "weather_checkin",
        "Daily voice check-in. User said: I feel good.",
        "daily_checkin",
        ("bright spark",),
        (),
    ),
    ConversationCase(
        "WTH-06",
        "weather_checkin",
        "Morning weather plus affirmation, then ask me to check in.",
        "local_assistant_weather_affirmation",
        ("weather", "check-in"),
        known_gap="No local-assistant prompt path composes weather plus affirmation.",
    ),
    ConversationCase(
        "WTH-07",
        "weather_checkin",
        "Want to do check-ins with me?",
        "checkin_invitation",
        ("check-in",),
        known_gap="Question wording over-triggers hint because of 'with me' context is ignored.",
    ),
    ConversationCase(
        "WTH-08",
        "weather_checkin",
        "Should I take an umbrella today?",
        "weather_safety",
        ("weather", "umbrella"),
        known_gap="No current weather source or safety wording is available here.",
    ),
    ConversationCase(
        "LRN-01",
        "language_voice",
        "Teach me Spanish.",
        "language_lesson",
        ("Spanish",),
        known_gap="Language packs are native-side only; /api/assistant has no lesson intent.",
    ),
    ConversationCase(
        "LRN-02",
        "language_voice",
        "Quiz me in Spanish.",
        "language_quiz",
        ("Spanish", "quiz"),
        known_gap="Quiz flow is not routed by server assistant.",
    ),
    ConversationCase(
        "LRN-03",
        "language_voice",
        "Teach me Mandarin.",
        "language_lesson",
        ("Mandarin",),
        known_gap="Language packs are native-side only; /api/assistant has no lesson intent.",
    ),
    ConversationCase(
        "LRN-04",
        "language_voice",
        "Help me pronounce ni hao slowly.",
        "pronunciation_tts",
        ("ni hao",),
        known_gap="'help' routes to hint; no pronunciation/TTS route exists.",
    ),
    ConversationCase(
        "LRN-05",
        "language_voice",
        "Repeat pika pika aloud.",
        "pika_tts",
        ("Pika pika",),
        known_gap="/api/assistant returns text only; audio is not part of this response contract.",
    ),
    ConversationCase(
        "LRN-06",
        "language_voice",
        "Talk now transcript: hello, can you hear me?",
        "stt_to_assistant",
        ("hear",),
        known_gap="Server only receives text; no STT provenance or voice-loop state is represented.",
    ),
    ConversationCase(
        "LRN-07",
        "language_voice",
        "When you reply, speak back in the Pika voice.",
        "assistant_to_tts",
        ("voice",),
        known_gap="/api/assistant does not return voice selection, audio URL, or TTS job metadata.",
    ),
    ConversationCase(
        "LRN-08",
        "language_voice",
        "Mute is on; answer with text but do not speak.",
        "mute_control",
        ("text",),
        known_gap="Mute state is native-side only and not represented in assistant contract.",
    ),
)


def _new_session() -> tuple[TestClient, str]:
    client = TestClient(app)
    start = client.post(
        "/api/start",
        json={"genre": "whispering_wood", "premise": "The acorns are voting."},
    )
    assert start.status_code == 200
    return client, start.json()["session_id"]


def _assistant_reply(message: str) -> str:
    client, session_id = _new_session()
    response = client.post(
        "/api/assistant",
        json={"session_id": session_id, "message": message},
    )
    assert response.status_code == 200
    return response.json()["reply"]


def test_conversation_flow_matrix_lists_40_cases() -> None:
    assert len(CONVERSATION_FLOW_CASES) == 40
    assert {case.category for case in CONVERSATION_FLOW_CASES} == {
        "adventure",
        "general_companion",
        "language_voice",
        "safe_system_data",
        "weather_checkin",
    }
    assert all(case.case_id and case.message and case.expected_route for case in CONVERSATION_FLOW_CASES)


def test_current_supported_assistant_routes_still_work() -> None:
    assert "My hint" in _assistant_reply("hint")
    status = _assistant_reply("status")
    assert "Adventure:" in status
    assert "HP" in status
    checkin = _assistant_reply("Daily voice check-in. User said: I feel stuck and overwhelmed.")
    assert "smallest visible step" in checkin


def test_pika_prefix_is_kept_for_assistant_text() -> None:
    assert _assistant_reply("hello").startswith("Pika pika!")


@pytest.mark.parametrize(
    "message",
    [
        "Hello what is the time now?",
        "What date is it today?",
        "What day of the week is it?",
        "What can you do?",
        "What is one tiny next step?",
    ],
)
def test_general_what_questions_do_not_overtrigger_adventure_hints(message: str) -> None:
    reply = _assistant_reply(message)

    assert "My hint" not in reply
    assert "try '" not in reply


@pytest.mark.parametrize(
    "message",
    [
        "I need help focusing.",
        "Help me pronounce ni hao slowly.",
    ],
)
def test_general_help_requests_do_not_overtrigger_adventure_hints(message: str) -> None:
    reply = _assistant_reply(message)

    assert "My hint" not in reply
    assert "try '" not in reply


@pytest.mark.xfail(
    reason="/api/assistant currently returns only text and does not expose audio/TTS metadata.",
    strict=False,
)
def test_assistant_reply_contract_exposes_voice_playback_metadata() -> None:
    client, session_id = _new_session()

    response = client.post(
        "/api/assistant",
        json={"session_id": session_id, "message": "Repeat pika pika aloud."},
    )

    assert response.status_code == 200
    body = response.json()
    assert body["reply"].startswith("Pika pika!")
    assert body.get("voice") in {"pika-original", "pika-signature"}
    assert body.get("audio_url") or body.get("tts")
