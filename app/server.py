from __future__ import annotations

import html
import io
import os
import time
import uuid
from contextlib import asynccontextmanager
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from fastapi import HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse, Response
from fastapi.staticfiles import StaticFiles
from gradio import Server

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
    last_turn: Turn | None = None
    last_turn_seconds: float = 0.0
    last_turn_tokens: int = 0
    transcript: list[dict[str, Any]] = field(default_factory=list)


app = Server(lifespan=lifespan)
app.mount("/static", StaticFiles(directory=STATIC_ROOT), name="static")

_SESSIONS: dict[str, PlaySession] = {}


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
    reply = _dragon_reply(session, message)
    return JSONResponse({"reply": reply})


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
    turn = session.last_turn
    if turn is None:
        return _pika("Start an adventure and I will start hovering.")
    if "status" in lowered or "hp" in lowered or "inventory" in lowered:
        return _pika(
            f"Adventure: {session.state.hp}/10 HP. Location {session.state.location}, "
            f"inventory {_inventory_list(session)}. Turn {session.state.turn_count}. "
            "Pet Bond HP lives in the desktop companion."
        )
    if "pet" in lowered or "care" in lowered or "happy" in lowered:
        return _pika("Pet me from the desktop companion once a day to charge Bond HP and keep my joy high.")
    if "hint" in lowered or "help" in lowered or "what" in lowered:
        if turn.is_ending:
            return _pika("The tale has landed. Start a fresh scroll if you want another flight.")
        choice = _recommended_choice(session)
        return _pika(f"My hint: try '{choice}'. {_choice_reason(session, choice)}")
    if "hyper" in lowered or "fire" in lowered or "flame" in lowered or "bolt" in lowered:
        return _pika("Hyper mode. Quick and bright, not reckless.")
    if "offline" in lowered or "tiny" in lowered:
        return _pika("The winning trick is receipts: small model, local rules, no hidden cloud calls.")
    return _pika("I heard you. Ask me for a hint, check status, or pet me for today's spark.")


def _pika(text: str) -> str:
    if "pika pika" in text.casefold():
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
