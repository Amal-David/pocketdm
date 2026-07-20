from __future__ import annotations

import html
import ipaddress
import io
import json
import os
import time
import uuid
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from datetime import datetime
from pathlib import Path
from typing import Any
from urllib import error as urlerror
from urllib import request as urlrequest

from fastapi import HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse, Response
from fastapi.staticfiles import StaticFiles
from gradio import Server

from app.agent_tools import gather_tool_facts
from engine.generate import MockBackend, next_turn
from engine.generate import TurnBackend
from engine.schema import StateDelta, Turn
from engine.state import GameState, apply_delta

APP_ROOT = Path(__file__).resolve().parent
STATIC_ROOT = APP_ROOT / "static"

GENRE_LABELS = {
    "cursed_dungeon": "Cursed Dungeon",
    "whispering_wood": "Whispering Wood",
    "derelict_starship": "Derelict Starship",
}


@asynccontextmanager
async def lifespan(_app: Server):
    _prepare_optional_tts_assets()
    yield


@dataclass
class PlaySession:
    state: GameState
    backend: TurnBackend
    backend_label: str
    voice_id: str | None = None
    started_at: float = field(default_factory=time.time)
    last_turn: Turn | None = None
    last_turn_seconds: float = 0.0
    last_turn_tokens: int = 0
    transcript: list[dict[str, Any]] = field(default_factory=list)


app = Server(lifespan=lifespan)
app.mount("/static", StaticFiles(directory=STATIC_ROOT), name="static")

_SESSIONS: dict[str, PlaySession] = {}
_MAX_SESSIONS = 500


def _evict_stale_sessions() -> None:
    # Cap the in-memory session map so a long-running public Space can't grow
    # unbounded (Devin review). Dict preserves insertion order, so the front is
    # the oldest session — evict from there until back under the cap.
    while len(_SESSIONS) > _MAX_SESSIONS:
        oldest_id = next(iter(_SESSIONS))
        _SESSIONS.pop(oldest_id, None)


def _prepare_optional_tts_assets() -> None:
    """Best-effort Kokoro asset warmup for Space startup, never for turn-time play."""
    if not _truthy_env("POCKETDM_TTS_PRELOAD"):
        return

    try:
        from app.tts import download

        download()
    except Exception:
        # Text-first play remains the product contract; /api/tts will expose
        # unavailable status without breaking the adventure.
        return


@app.get("/", response_class=HTMLResponse)
async def homepage() -> HTMLResponse:
    return HTMLResponse((STATIC_ROOT / "index.html").read_text())


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


def _require_loopback(request: Request) -> None:
    client = request.client
    if client is None:
        raise HTTPException(status_code=403, detail="local request required")
    try:
        is_loopback = ipaddress.ip_address(client.host).is_loopback
    except ValueError:
        # ``testclient`` is Starlette's in-process ASGI test transport, never a
        # network hostname supplied by an HTTP header.
        is_loopback = client.host in {"localhost", "testclient"}
    if not is_loopback:
        raise HTTPException(status_code=403, detail="local request required")


@app.middleware("http")
async def local_requests_only(request: Request, call_next):
    try:
        _require_loopback(request)
    except HTTPException as exc:
        return JSONResponse(status_code=exc.status_code, content={"detail": exc.detail})
    return await call_next(request)


@app.post("/api/memory/delete")
async def delete_memory(request: Request) -> JSONResponse:
    """Delete the local user's durable companion memory.

    This destructive endpoint is deliberately local-only even though the
    standard launcher also binds the whole app to loopback. The peer check
    protects a future direct rebind; the non-simple header also prevents a web
    page from triggering deletion with a cross-origin form or no-CORS request.
    """
    _require_loopback(request)
    if request.headers.get("x-pocketdm-local-action") != "delete-memory-v1":
        raise HTTPException(status_code=403, detail="local action header required")
    from app.memory_store import DEFAULT_USER_ID, delete_user_memory

    counts = delete_user_memory(DEFAULT_USER_ID)
    # All current sessions belong to the one local profile. Invalidating them
    # turns deletion into a barrier: an already-queued request with a stale
    # session cannot immediately repopulate the freshly cleared memory.
    _SESSIONS.clear()
    return JSONResponse({"deleted": True, "counts": counts})


@app.post("/api/start")
async def start_adventure(request: Request) -> JSONResponse:
    payload = await request.json()
    return JSONResponse(_start_payload(payload))


@app.post("/api/choose")
async def choose_action(request: Request) -> JSONResponse:
    payload = await request.json()
    return JSONResponse(_choose_payload(payload.get("session_id"), payload.get("action")))


@app.post("/api/assistant")
async def assistant_chat(request: Request) -> JSONResponse:
    payload = await request.json()
    session = _session(payload.get("session_id"))
    message = _clean_text(payload.get("message"), limit=180)
    # Optional pet-state snapshot (streak, bond_hp, mood, daypart, last_seen_gap).
    # When present, persist it so the brain can personalize tone across restarts;
    # absent or partial input degrades cleanly to today's stateless behavior.
    _persist_user_state(payload.get("user_state"))
    reply = _dragon_reply(session, message)
    # Best-effort durable-fact extraction: learn name/goal/mood/event from this
    # turn so future replies can recall it. Never let it break the chat reply.
    # Extract from the un-escaped text so stored facts hold the user's original
    # words ("Ben & Co"), not HTML entities ("Ben &amp; Co").
    _extract_and_store_facts(html.unescape(message))
    return JSONResponse({"reply": reply})


@app.post("/api/proactive")
async def proactive_checkin(request: Request) -> JSONResponse:
    payload = await request.json()
    session = _session(payload.get("session_id"))
    return JSONResponse(_proactive_payload(session, payload))


@app.post("/api/tts")
async def narration_tts(request: Request) -> Response:
    payload = await request.json()
    session = _session(payload.get("session_id"))
    text = _clean_text(payload.get("text"), limit=420)
    if not text:
        raise HTTPException(status_code=400, detail="missing narration text")

    try:
        import soundfile as sf

        from app.tts import synthesize

        sample_rate, audio = synthesize(text, voice_id=_voice_for_session(session))
    except Exception as exc:
        return Response(
            status_code=204,
            headers={"x-pocketdm-tts": f"unavailable:{type(exc).__name__}"},
        )

    wav = io.BytesIO()
    sf.write(wav, audio, sample_rate, format="WAV")
    return Response(content=wav.getvalue(), media_type="audio/wav")


@app.api(name="start_demo_adventure")
def start_demo_adventure(genre: str = "cursed_dungeon", premise: str = "") -> dict[str, Any]:
    """Gradio API endpoint for external smoke checks; the custom UI uses /api/start."""
    session = PlaySession(
        state=GameState(genre=_genre(genre), premise=_clean_text(premise, limit=140) or None),
        backend=MockBackend(_scripted_turns(_genre(genre), premise or None)),
        backend_label="scripted",
    )
    return _advance_to_next_turn(session)


@app.api(name="new_game")
def new_game(
    genre: str = "cursed_dungeon",
    premise: str = "",
    voice: str = "auto",
) -> dict[str, Any]:
    """Named Gradio API wrapper; the custom frontend uses /api/start."""
    return _start_payload({"genre": genre, "premise": premise, "voice": voice})


@app.api(name="take_turn")
def take_turn(session_id: str, action: str = "") -> dict[str, Any]:
    """Named Gradio API wrapper; the custom frontend uses /api/choose."""
    return _choose_payload(session_id, action)


def _start_payload(payload: dict[str, Any]) -> dict[str, Any]:
    genre = _genre(payload.get("genre"))
    premise = _clean_text(payload.get("premise"), limit=140) or None
    backend, backend_label = _backend_for_adventure(genre, premise)
    session = PlaySession(
        state=GameState(genre=genre, premise=premise),
        backend=backend,
        backend_label=backend_label,
        voice_id=_voice_id(payload.get("voice"), genre),
    )
    session_id = uuid.uuid4().hex
    _SESSIONS[session_id] = session
    _evict_stale_sessions()
    turn_payload = _advance_to_next_turn(session)
    return {
        "session_id": session_id,
        "turn": turn_payload,
        "state": _state_payload(session),
        "assistant": _assistant_opening(genre),
    }


def _choose_payload(raw_session_id: Any, raw_action: Any) -> dict[str, Any]:
    session = _session(raw_session_id)
    action = _clean_text(raw_action, limit=120)
    if not action and session.last_turn is not None:
        action = session.last_turn.choices[0]

    if session.last_turn is not None and session.last_turn.is_ending:
        return {
            "turn": _turn_payload(session.last_turn),
            "state": _state_payload(session),
            "assistant": _assistant_for_turn(session, action),
        }

    if session.last_turn is not None and not session.last_turn.is_ending:
        session.state = session.state.model_copy(
            update={
                "recent_turns": [
                    *session.state.recent_turns,
                    (session.last_turn, action),
                ][-2:]
            }
        )

    turn_payload = _advance_to_next_turn(session)
    return {
        "turn": turn_payload,
        "state": _state_payload(session),
        "assistant": _assistant_for_turn(session, action),
    }


def _advance_to_next_turn(session: PlaySession) -> dict[str, Any]:
    started = time.perf_counter()
    result = next_turn(session.state, session.backend)
    session.last_turn_seconds = max(time.perf_counter() - started, 0.001)
    turn = result.turn
    session.last_turn_tokens = _estimated_turn_tokens(turn)
    session.state = apply_delta(session.state, turn)
    session.last_turn = turn
    payload = _turn_payload(turn, result.used_bridge)
    session.transcript.append(payload)
    return payload


def _turn_payload(turn: Turn, used_bridge: bool = False) -> dict[str, Any]:
    return {
        "narration": turn.narration,
        "choices": list(turn.choices),
        "is_ending": turn.is_ending,
        "ending_type": turn.ending_type,
        "used_bridge": used_bridge,
    }


def _state_payload(session: PlaySession) -> dict[str, Any]:
    state = session.state
    return {
        "hp": state.hp,
        "inventory": list(state.inventory),
        "location": state.location,
        "turn_count": state.turn_count,
        "genre": state.genre,
        "premise": state.premise,
        "voice": _voice_for_session(session),
        "backend": session.backend_label,
        "model": _model_label(session),
        "last_turn_seconds": max(0.01, round(session.last_turn_seconds, 2)),
        "last_turn_tokens": session.last_turn_tokens,
        "last_turn_tokens_per_second": _turn_tokens_per_second(session),
    }


def _session(raw_session_id: Any) -> PlaySession:
    session_id = str(raw_session_id or "")
    try:
        return _SESSIONS[session_id]
    except KeyError as exc:
        raise HTTPException(status_code=404, detail="unknown or expired adventure session") from exc


def _genre(raw_genre: Any) -> str:
    genre = str(raw_genre or "cursed_dungeon")
    if genre not in GENRE_LABELS:
        return "cursed_dungeon"
    return genre


def _clean_text(value: Any, *, limit: int) -> str:
    text = " ".join(str(value or "").split())
    return html.escape(text[:limit], quote=False)


def _truthy_env(name: str) -> bool:
    return str(os.environ.get(name, "")).casefold() in {"1", "true", "yes", "on"}


# Pet-state fields the companion brain may receive on /api/assistant requests.
# These mirror app.memory_store._STATE_FIELDS; all are optional.
_PET_STATE_FIELDS = ("streak", "bond_hp", "mood", "daypart", "last_seen_gap")


def _persist_user_state(raw_state: Any) -> None:
    """Persist an optional pet-state snapshot from the request to the store.

    Accepts a partial dict; non-dict or empty input is ignored so the path
    stays a clean no-op for today's stateless callers.
    """
    if not isinstance(raw_state, dict):
        return
    snapshot = {field: raw_state[field] for field in _PET_STATE_FIELDS if raw_state.get(field) is not None}
    if not snapshot:
        return
    try:
        from app.memory_store import DEFAULT_USER_ID, add_observation, save_state

        save_state(DEFAULT_USER_ID, snapshot)
        # Append a timestamped (daypart, mood) row so proactive pattern detection
        # has history. save_state overwrites the latest snapshot; this accrues.
        add_observation(DEFAULT_USER_ID, snapshot.get("daypart"), snapshot.get("mood"))
    except Exception:
        # Memory persistence is best-effort; never break a chat reply over it.
        return


def _proactive_payload(session: PlaySession, payload: dict[str, Any]) -> dict[str, Any]:
    """Select and (if warranted) generate a pattern-aware proactive line.

    Reads the current daypart + last-seen gap (from the request, falling back to
    the persisted pet-state snapshot), runs ``select_proactive_intent`` over the
    stored observation history, and:

    * if an intent fires, generates a short personalized line THROUGH THE BRAIN
      (same ``_local_companion_llm_reply`` path, so pet_state + recalled
      memories + the intent are injected and the no-recite guard applies);
    * if no intent fires -- or the brain is unavailable / produces nothing --
      returns ``{"use_generic_cheer": True}`` so the caller uses its existing
      generic daypart cheer rather than this endpoint fabricating a pattern.

    This endpoint only SELECTS/GENERATES a line. Cadence and the 45-min cooldown
    already live in the native cheer path; we deliberately do not duplicate them.
    Best-effort throughout: any failure degrades to the generic-cheer signal.
    """
    # Persist any state the caller passed so future proactive runs have history.
    _persist_user_state(payload.get("user_state"))

    raw_state = payload.get("user_state") if isinstance(payload.get("user_state"), dict) else {}
    persisted = _persisted_pet_state()
    current_daypart = (
        payload.get("daypart")
        or raw_state.get("daypart")
        or persisted.get("daypart")
    )
    last_seen_gap = raw_state.get("last_seen_gap", persisted.get("last_seen_gap"))

    try:
        from app.memory_store import DEFAULT_USER_ID
        from app.proactive import select_proactive_intent

        intent = select_proactive_intent(
            DEFAULT_USER_ID, current_daypart, last_seen_gap, time.time()
        )
    except Exception:
        intent = None

    if not intent:
        return {"use_generic_cheer": True}

    prompt = _proactive_prompt(intent, current_daypart)
    line = _local_companion_llm_reply(
        session, prompt, purpose="proactive check-in", intent=intent
    )
    if not line:
        # Brain unavailable or empty -> caller falls back to generic cheer.
        return {"use_generic_cheer": True}
    return {"use_generic_cheer": False, "intent": intent["intent"], "reply": line}


def _proactive_prompt(intent: dict[str, Any], daypart: Any) -> str:
    """Build the brain user-prompt for a selected proactive intent.

    The prompt describes the *moment* to react to (not the raw data) so the brain
    composes a fresh line; the structured intent itself rides in the private
    Context block for tone, never to be recited.
    """
    when = str(daypart or "now").strip() or "now"
    if intent["intent"] == "welcome_back":
        return (
            "Open a warm, brief proactive check-in: the user has been away for a "
            "little while and just came back. Welcome them back gently and invite "
            "one tiny next step. Do not mention how long they were gone."
        )
    if intent["intent"] == "preempt_slump":
        return (
            f"Open a gentle, brief proactive check-in for the {when}. This is a "
            "time the user often feels low, so get ahead of the dip with warmth "
            "and one tiny, doable lift. Do not state that they usually feel low."
        )
    return "Open a short, warm proactive check-in and invite one tiny next step."


def _assistant_opening(genre: str) -> str:
    return _pika(
        f"I am Pikachu, your pocket electric familiar. I will hover here while "
        f"the {GENRE_LABELS[genre]} tries to misbehave."
    )


def _assistant_for_turn(session: PlaySession, action: str) -> str:
    if session.last_turn is None:
        return _pika("I am ready when you are.")
    if session.last_turn.is_ending:
        return _pika("That is a proper ending. Tiny victory jump.")
    if session.state.hp <= 3:
        return _pika(
            f"Careful: {session.state.hp}/10 HP at {session.state.location}. "
            f"I would avoid swagger and pick: {_recommended_choice(session)}"
        )
    if "inspect" in action.casefold() or "search" in action.casefold():
        inventory = _inventory_hint(session)
        return _pika(
            "Good instinct. Inspection gives the engine a concrete next move"
            f"{inventory}."
        )
    return _pika(
        "Choice logged. Tail glowing. "
        f"My current read: {_choice_reason(session, _recommended_choice(session))}"
    )


def _dragon_reply(session: PlaySession, message: str) -> str:
    lowered = message.casefold()
    if system_reply := _system_reply(session, lowered):
        return system_reply
    if "daily voice check-in" in lowered or "daily check-in" in lowered:
        return _daily_checkin_reply(lowered)
    if "morning weather check-in" in lowered or (
        "weather line:" in lowered and "affirmation" in lowered
    ):
        return _weather_affirmation_reply(session, message)
    turn = session.last_turn
    if turn is None:
        if _is_hint_request(lowered) or any(
            term in lowered for term in ("adventure", "quest", "dungeon", "turn", "choice", "tale")
        ):
            return _pika("Start an adventure and I will start hovering.")
        if local_reply := _local_companion_llm_reply(session, message, purpose="freeform desktop pet chat"):
            return local_reply
        if "encourag" in lowered or "affirm" in lowered or "motivat" in lowered:
            return _pika("One tiny win is enough for the next minute. Take it, and I will cheer when it lands.")
        return _pika("I am here with you. Ask for a check-in, log water, or start an adventure when you want a quest.")
    if "status" in lowered or "hp" in lowered or "inventory" in lowered:
        return _pika(
            f"Adventure: {session.state.hp}/10 HP. Location {session.state.location}, "
            f"inventory {_inventory_list(session)}. Turn {session.state.turn_count}. "
            "Pet Bond HP lives in the desktop companion."
        )
    if "pet" in lowered or "care" in lowered or "happy" in lowered:
        return _pika("Pet me from the desktop companion once a day to charge Bond HP and keep my joy high.")
    if _is_hint_request(lowered):
        if turn.is_ending:
            return _pika("The tale has landed. Start a fresh scroll if you want another flight.")
        choice = _recommended_choice(session)
        return _pika(f"My hint: try '{choice}'. {_choice_reason(session, choice)}")
    if "what can you do" in lowered or "safe system basics" in lowered:
        return _pika(
            "I can answer safe basics like time and date, give adventure hints "
            "when you explicitly ask, check status, run daily check-ins, and hand "
            "voice replies to the local Pika sound path."
        )
    if "focus" in lowered or "tiny next step" in lowered:
        return _pika("Pick one tiny visible step, set a ten-minute focus window, and stop when that one step lands.")
    if "spanish" in lowered or "mandarin" in lowered or "pronounce" in lowered or "quiz" in lowered:
        return _pika("Use Learn for Spanish or Mandarin. I can teach, replay slowly, quiz you, and reward practice.")
    if "hyper" in lowered or "fire" in lowered or "flame" in lowered or "bolt" in lowered:
        return _pika("Hyper mode. Quick and bright, not reckless.")
    if "offline" in lowered or "tiny" in lowered:
        return _pika("The winning trick is receipts: small model, local rules, no hidden cloud calls.")
    if local_reply := _local_companion_llm_reply(session, message, purpose="freeform desktop pet chat"):
        return local_reply
    return _pika("I heard you. Ask me for a hint, check status, or pet me for today's spark.")


def _system_reply(session: PlaySession, lowered: str) -> str | None:
    now = datetime.now().astimezone()
    if _asks_current_time(lowered):
        time_text = now.strftime("%I:%M %p").lstrip("0")
        date_text = f"{now.strftime('%A, %B')} {now.day}"
        zone = now.tzname() or now.strftime("%z")
        return _pika(f"Time here: {time_text} {zone}, {date_text}.")
    if _asks_current_date(lowered):
        return _pika(f"Today is {now.strftime('%A, %B')} {now.day}, {now.year}.")
    if "timezone" in lowered or "time zone" in lowered:
        zone = now.tzname() or now.strftime("%z")
        return _pika(f"Timezone: {zone} from this Mac server.")
    if "how long" in lowered and ("playing" in lowered or "session" in lowered):
        elapsed = max(0, int(time.time() - session.started_at))
        minutes, seconds = divmod(elapsed, 60)
        return _pika(f"Session open: {minutes}m {seconds}s, turn {session.state.turn_count}.")
    if _asks_weather(lowered):
        return _weather_context_reply(lowered)
    if _asks_system_status(lowered):
        return _pika(_system_status_text(session))
    if "what model" in lowered or "which model" in lowered or "model are you using" in lowered:
        return _pika(f"Runtime: {session.backend_label}; model: {_model_label(session)}.")
    if "running locally" in lowered or "in the cloud" in lowered or "local or cloud" in lowered:
        if session.backend_label == "llama.cpp":
            return _pika(f"Local llama.cpp is active with {_model_label(session)}.")
        return _pika("Local scripted safety mode is active until llama.cpp is configured.")
    return None


def _asks_current_time(lowered: str) -> bool:
    text = lowered.strip(" ?!.")
    return text == "time" or any(
        phrase in lowered
        for phrase in (
            "what time",
            "time is it",
            "the time",
            "time now",
            "current time",
            "tell me time",
            "tell me the time",
            "clock",
        )
    )


def _asks_current_date(lowered: str) -> bool:
    return any(
        phrase in lowered
        for phrase in (
            "what date",
            "date today",
            "today's date",
            "todays date",
            "what day is it",
            "what day is today",
            "day of the week",
        )
    )


def _asks_weather(lowered: str) -> bool:
    if "weather line:" in lowered or "morning weather check-in" in lowered:
        return False
    return any(
        word in lowered
        for word in (
            "weather",
            "forecast",
            "outside",
            "umbrella",
            "rain",
            "raining",
            "gloomy",
            "sunny",
            "hot out",
            "cold out",
        )
    )


def _weather_context_reply(lowered: str) -> str:
    if "umbrella" in lowered:
        return _pika("Weather: I do not have live forecast data here; check local radar before deciding on an umbrella.")
    if "beautiful weather" in lowered:
        return _pika("Weather noted: beautiful. Want a quick check-in with that spark?")
    if "gloomy" in lowered:
        return _pika("Weather: I cannot see live conditions here; if it feels gloomy, try one small indoor reset.")
    return _pika("Weather: I do not have a live forecast source here. Share a weather line and I will make a check-in.")


def _asks_system_status(lowered: str) -> bool:
    return any(
        phrase in lowered
        for phrase in (
            "system status",
            "server status",
            "backend status",
            "runtime status",
            "api status",
            "llm status",
            "model status",
        )
    ) or ("status" in lowered and any(
        word in lowered for word in ("system", "server", "backend", "runtime", "api", "llm", "model")
    ))


def _system_status_text(session: PlaySession) -> str:
    speed = ""
    if tokens_per_second := _turn_tokens_per_second(session):
        speed = f", last turn {tokens_per_second} tok/s"
    return (
        f"System: API awake, backend {session.backend_label}, "
        f"model {_model_label(session)}, turn {session.state.turn_count}{speed}."
    )


def _is_hint_request(lowered: str) -> bool:
    if "hint" in lowered or "clue" in lowered:
        return True
    adventure_terms = ("adventure", "quest", "dungeon", "turn", "choice", "choose", "tale")
    if any(term in lowered for term in ("what should i", "which choice", "recommend", "safest choice")):
        return True
    return "help" in lowered and any(term in lowered for term in adventure_terms)


def _weather_affirmation_reply(session: PlaySession, message: str) -> str:
    weather = _field_value(message, "Weather line:")
    title = _field_value(message, "Affirmation title:")
    line = _field_value(message, "Affirmation line:")
    llm_prompt = (
        "Compose the morning weather check-in from these facts. "
        f"Weather: {weather or 'unknown'}. Affirmation: {title} - {line}. "
        "Ask exactly one friendly check-in question."
    )
    if local_reply := _local_companion_llm_reply(session, llm_prompt, purpose="morning weather check-in"):
        return local_reply
    pieces = [piece for piece in (weather, f"{title}: {line}" if title and line else line) if piece]
    if not pieces:
        pieces = ["The weather check-in is ready."]
    return _pika(" ".join(pieces) + " Want to do a check-in with me?")


def _field_value(message: str, label: str) -> str:
    try:
        start = message.index(label) + len(label)
    except ValueError:
        return ""
    tail = message[start:]
    stops = [
        index for marker in ("\n", " Affirmation title:", " Affirmation line:", " Requirements:")
        if (index := tail.find(marker)) >= 0
    ]
    if stops:
        tail = tail[: min(stops)]
    return " ".join(tail.split()).strip(" .")


def _daily_checkin_reply(lowered: str) -> str:
    if any(word in lowered for word in ("tired", "exhausted", "sleep", "burned out")):
        return _pika("I hear tired energy. Take one slow breath, pick one tiny finish line, then rest on purpose.")
    if any(word in lowered for word in ("stuck", "blocked", "confused", "overwhelmed")):
        return _pika("That sounds heavy, and you are still here. Name the next smallest visible step, then do only that.")
    if any(word in lowered for word in ("good", "great", "happy", "excited", "proud")):
        return _pika("I hear a bright spark. Save the win, then use that energy on one kind next move.")
    return _pika("Daily check-in logged. I am with you; choose one tiny next step and make it easy to start.")


def _persisted_pet_state() -> dict[str, Any]:
    """Read the latest persisted pet-state snapshot for the local user.

    Returns an empty dict when nothing has been saved or the store is
    unavailable, so the brain context falls back to today's stateless shape.
    """
    try:
        from app.memory_store import DEFAULT_USER_ID, get_state

        return get_state(DEFAULT_USER_ID)
    except Exception:
        return {}


# Char budget for recalled durable facts injected into the brain prompt. Kept
# small (~400 chars, a few short facts) so the recalled block stays a sliver of
# POCKETDM_LLAMA_CTX (default 2048 tokens) alongside the system + user turns.
_MEMORY_RECALL_MAX_CHARS = 400


def _extract_and_store_facts(message: str) -> None:
    """Best-effort: persist durable facts detected in a user turn.

    Extraction is cheap and local; any failure (store unavailable, bad input)
    is swallowed so a memory write never breaks the companion reply.
    """
    try:
        from app.memory_extract import extract_facts
        from app.memory_store import DEFAULT_USER_ID, add_fact

        for kind, text, weight in extract_facts(message):
            add_fact(DEFAULT_USER_ID, kind, text, weight)
    except Exception:
        return


def _recalled_memories() -> list[dict[str, Any]]:
    """Return the most relevant durable facts for the local user, within budget.

    Empty list when nothing has been learned or the store is unavailable, so the
    brain context falls back to today's shape.
    """
    try:
        from app.memory_store import DEFAULT_USER_ID, recall_facts

        return recall_facts(DEFAULT_USER_ID, max_chars=_MEMORY_RECALL_MAX_CHARS)
    except Exception:
        return []


def _local_companion_llm_reply(
    session: PlaySession,
    message: str,
    *,
    purpose: str,
    intent: dict[str, Any] | None = None,
) -> str | None:
    from app.llama_backend import configured_llama_server_model, configured_llama_server_url

    base_url = configured_llama_server_url()
    if not base_url:
        return None

    now = datetime.now().astimezone()
    # Keep context minimal so the tiny 1B model doesn't recite it back as its answer.
    # Only facts it might actually need: the time, plus live tool facts when relevant.
    context = {
        "local_time": now.isoformat(timespec="seconds"),
        "timezone": now.tzname() or now.strftime("%z"),
    }
    if tool_facts := gather_tool_facts(message):
        context["tool_facts"] = tool_facts
    # A selected proactive intent (welcome_back / preempt_slump) personalizes the
    # check-in. Like pet_state/memories it is PRIVATE background the brain uses to
    # shape tone, never reads back -- covered by the same no-recite guard below.
    if intent:
        context["proactive_intent"] = intent
    # Persisted pet-state snapshot personalizes tone (e.g. low Bond HP -> gentler).
    # Kept tiny on purpose: 5 short fields + an optional small extra dict serialize
    # to ~100-160 bytes of JSON (well under POCKETDM_LLAMA_CTX, default 2048 tokens
    # ~= 8 KB; the whole prompt with system + user stays a few hundred tokens).
    if pet_state := _persisted_pet_state():
        context["pet_state"] = pet_state
    # Durable facts recalled from past turns (name, goals, moods, events), capped
    # to a small char budget so they stay well inside the model's context window.
    if memories := _recalled_memories():
        context["memories"] = memories
    payload = {
        "model": configured_llama_server_model(base_url),
        "messages": [
            {
                "role": "system",
                "content": (
                    "You are Pikachu, a cheerful, high-energy desktop pet companion. "
                    "Answer the user's actual message directly, warmly, and briefly (one or two short sentences). "
                    "Start with 'Pika pika!' exactly once, then a genuine, upbeat, helpful reply. "
                    "The Context line (including any pet_state, memories, proactive_intent, tool facts, or profile) "
                    "is PRIVATE background only: never repeat, recite, quote, mention, or describe it. Use pet_state, "
                    "memories, and proactive_intent only to color your tone and keep continuity (warmer when energy is "
                    "low, brighter on a long streak, a warm welcome after time away, a gentle lift before a usual dip, "
                    "naturally aware of what the user told you before); never read them back verbatim. "
                    "Do not talk about timezones, runtime, models, or being 'scripted' or a 'demo' "
                    "unless the user explicitly asks. Use the tool facts exactly for time/weather/search questions "
                    "and never invent facts. Only give a hint or clue if the user explicitly asks for one. "
                    "Be encouraging without asking for extra details. "
                    "No analysis, reasoning, markdown, emoji, stage directions, or <think> tags."
                ),
            },
            {"role": "user", "content": f"Context: {json.dumps(context, sort_keys=True)}\nUser: {message}"},
        ],
        "max_tokens": int(os.environ.get("POCKETDM_ASSISTANT_LLAMA_MAX_TOKENS", "72")),
        "temperature": float(os.environ.get("POCKETDM_ASSISTANT_LLAMA_TEMPERATURE", "0.35")),
        "stop": ["<turn|>", "<|im_end|>"],
    }
    request = urlrequest.Request(
        f"{base_url.rstrip('/')}/v1/chat/completions",
        data=json.dumps(payload).encode("utf-8"),
        headers={"content-type": "application/json"},
    )
    try:
        with urlrequest.urlopen(
            request,
            timeout=float(os.environ.get("POCKETDM_ASSISTANT_LLAMA_TIMEOUT", "8")),
        ) as response:
            result = json.loads(response.read().decode("utf-8"))
        content = _strip_leading_pika_sounds(
            _strip_thinking(str(result["choices"][0]["message"]["content"]).strip())
        )
    except (OSError, ValueError, KeyError, IndexError, urlerror.URLError):
        return None

    if not content or not _has_companion_substance(content):
        return None
    return _pika(html.escape(_compact_overlay_text(content), quote=False))


def _compact_overlay_text(content: str, *, limit: int = 180) -> str:
    compact = " ".join(content.split())
    if len(compact) <= limit:
        return compact

    clipped = compact[:limit].rstrip()
    sentence_end = max(clipped.rfind("."), clipped.rfind("!"), clipped.rfind("?"))
    if sentence_end >= 20:
        return clipped[: sentence_end + 1]
    return clipped.rstrip(" ,;:") + "."


def _strip_thinking(content: str) -> str:
    cleaned = content.strip()
    lowered = cleaned.casefold()
    if "</think>" in lowered:
        end = lowered.rfind("</think>") + len("</think>")
        cleaned = cleaned[end:].strip()
    if cleaned.casefold().startswith("<think>"):
        return ""
    return cleaned


def _has_companion_substance(content: str) -> bool:
    words = [
        "".join(character for character in token.casefold() if character.isalpha())
        for token in content.split()
    ]
    mascot_words = {"pika", "piki", "pikaa", "pikaaa", "pikachu"}
    meaningful = [
        word for word in words
        if word and word not in mascot_words and not word.startswith("pika")
    ]
    return len(meaningful) >= 3


def _strip_leading_pika_sounds(content: str) -> str:
    cleaned = content.strip()
    prefixes = (
        "pika pika",
        "pika piki",
        "pikaa pikaa",
        "pikaaa pikaaa",
        "pikaa",
        "pika",
    )
    while cleaned:
        lowered = cleaned.casefold().lstrip()
        matched = next((prefix for prefix in prefixes if lowered.startswith(prefix)), None)
        if matched is None:
            break
        cleaned = cleaned[len(matched):].lstrip(" ,.!?-:")
    return cleaned.strip() or content.strip()


def _pika(text: str) -> str:
    if "pika pika" in text.casefold().replace("-", " "):
        return text
    return f"Pika pika! {text}"


def _voice_for_genre(genre: str) -> str:
    if genre == "whispering_wood":
        return "wood"
    if genre == "derelict_starship":
        return "starship"
    return "dungeon"


def _voice_id(raw_voice: Any, genre: str) -> str | None:
    voice = str(raw_voice or "auto")
    if voice == "auto":
        return None
    if voice in {"dungeon", "wood", "starship", "lore"}:
        return voice
    return _voice_for_genre(genre)


def _voice_for_session(session: PlaySession) -> str:
    return session.voice_id or _voice_for_genre(session.state.genre)


def _backend_for_adventure(genre: str, premise: str | None) -> tuple[TurnBackend, str]:
    from app.llama_backend import configured_backend

    backend = configured_backend()
    if backend is not None:
        return backend, "llama.cpp"
    return MockBackend(_scripted_turns(genre, premise)), "scripted"


def _model_label(session: PlaySession) -> str:
    if session.backend_label == "llama.cpp":
        return str(getattr(session.backend, "model_label", "GGUF model"))
    return "Scripted safety mode"


def _estimated_turn_tokens(turn: Turn) -> int:
    text = " ".join([turn.narration, *turn.choices])
    return max(1, len(text.split()))


def _turn_tokens_per_second(session: PlaySession) -> float | None:
    if session.backend_label != "llama.cpp":
        return None
    return round(session.last_turn_tokens / session.last_turn_seconds, 1)


def _recommended_choice(session: PlaySession) -> str:
    turn = session.last_turn
    if turn is None:
        return "start the tale"
    choices = list(turn.choices)
    if session.state.hp <= 3:
        safe_terms = ("rest", "shield", "duck", "cautious", "safe", "steady", "mark")
        for choice in choices:
            if any(term in choice.casefold() for term in safe_terms):
                return choice
    if session.state.inventory:
        item_terms = tuple(item.casefold() for item in session.state.inventory)
        for choice in choices:
            lowered = choice.casefold()
            if any(item in lowered for item in item_terms):
                return choice
    info_terms = ("study", "inspect", "search", "read", "question", "trace")
    for choice in choices:
        if any(term in choice.casefold() for term in info_terms):
            return choice
    return choices[0]


def _choice_reason(session: PlaySession, choice: str) -> str:
    lowered = choice.casefold()
    if session.state.hp <= 3:
        return "Low HP makes a defensive or information-gathering move safer than a flashy one."
    if session.state.inventory:
        inventory = _inventory_list(session)
        if any(item.casefold() in lowered for item in session.state.inventory):
            return f"It uses what you already have ({inventory}), so the state can pay off."
        return f"You have {inventory}; a clear clue-finding action may reveal where to use it."
    if any(term in lowered for term in ("study", "inspect", "search", "read", "question")):
        return "It gives the model a precise investigation verb, which usually keeps turns grounded."
    return "It is specific enough for the engine to validate cleanly and move the scene forward."


def _inventory_hint(session: PlaySession) -> str:
    if not session.state.inventory:
        return ""
    return f"; you can now look for a payoff for {_inventory_list(session)}"


def _inventory_list(session: PlaySession) -> str:
    return ", ".join(session.state.inventory) if session.state.inventory else "empty"


def _scripted_turns(genre: str, premise: str | None) -> list[Turn]:
    if genre == "whispering_wood":
        place = "Moonlit Rootway"
        threat = "the bargaining trees"
        prize = "silver acorn"
    elif genre == "derelict_starship":
        place = "Static Bridge"
        threat = "the sulking ship AI"
        prize = "oxygen key"
    else:
        place = "Dusty Threshold"
        threat = "the hungry relic"
        prize = "brass key"

    premise_line = (
        f" Your premise follows you: {premise.rstrip('.!?')}."
        if premise
        else ""
    )
    beats = [
        (
            f"You cross into {place} and the air tilts toward trouble. "
            f"{threat.capitalize()} stirs as the {prize} glints nearby."
            f"{premise_line}",
            [f"Study the {prize}", f"Challenge {threat}", "Take the cautious path"],
            0,
            [],
        ),
        (
            f"A narrow signal flashes from beneath a cracked tile. "
            f"The {prize} clicks free, but {threat} notices the sound.",
            [f"Pocket the {prize}", "Trace the cold draft", "Whisper the old password"],
            0,
            [prize],
        ),
        (
            f"The passage bucks like it has opinions about heroes. "
            f"Loose grit cuts your sleeve while a hidden route opens ahead.",
            ["Lift the cracked lantern", "Duck beneath the chain", "Offer a fearless grin"],
            -1,
            [],
        ),
        (
            f"Carved faces in the wall begin arguing over your odds. "
            f"One face blinks twice and reveals a safer archway.",
            ["Question the carved faces", "Swap routes through the arch", "Mark the safest stone"],
            0,
            [],
        ),
        (
            f"An echo copies your footsteps, then adds one extra step. "
            f"The {prize} warms as if it recognizes the lie.",
            ["Bargain with the echo", "Search behind the banner", "Hum to steady the torch"],
            0,
            [],
        ),
        (
            f"{threat.capitalize()} lunges from the dark with terrible manners. "
            f"You stumble clear, but the scrape costs you a little breath.",
            ["Sprint past the bite marks", "Shield yourself with the map", "Kick loose the hinge"],
            -1,
            [],
        ),
        (
            f"A warning glows across the floor in letters too polite to trust. "
            f"The path beyond it hums with a final kind of dare.",
            ["Read the glowing warning", "Trust the tiny compass", "Press the silver switch"],
            0,
            [],
        ),
        (
            f"The last chamber unfolds around a ring of warm light. "
            f"{threat.capitalize()} hesitates when the {prize} points at its name.",
            ["Step into the final ring", f"Raise the {prize}", f"Call {threat} by name"],
            0,
            [],
        ),
    ]

    turns: list[Turn] = []
    for index, (narration, choices, hp, add_items) in enumerate(beats, start=1):
        turns.append(
            _turn(
                narration=narration,
                choices=choices,
                hp=hp,
                add_items=add_items,
                location=f"{place} {index}",
                add_flags=[f"beat_{index}"],
            )
        )

    turns.append(
        _turn(
            narration=(
                f"The final choice lands, and {threat} loses its hold. You escape "
                f"with the {prize}, a smoking sleeve, and a story worth retelling."
            ),
            choices=["Take a bow", "Pocket the proof", "Begin another tale"],
            location="Safe Threshold",
            is_ending=True,
            ending_type="victory",
        )
    )
    return turns


def _turn(
    *,
    narration: str,
    choices: list[str],
    location: str,
    hp: int = 0,
    add_items: list[str] | None = None,
    add_flags: list[str] | None = None,
    is_ending: bool = False,
    ending_type: str | None = None,
) -> Turn:
    return Turn(
        narration=narration,
        choices=choices,
        state_delta=StateDelta(
            hp=hp,
            add_items=add_items or [],
            remove_items=[],
            location=location,
            add_flags=add_flags or [],
        ),
        is_ending=is_ending,
        ending_type=ending_type,
    )
