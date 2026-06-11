from __future__ import annotations

import html
import io
import uuid
from dataclasses import dataclass, field
from pathlib import Path
from typing import Any

from fastapi import HTTPException, Request
from fastapi.responses import HTMLResponse, JSONResponse, Response
from fastapi.staticfiles import StaticFiles
from gradio import Server

from engine.generate import MockBackend, next_turn
from engine.schema import StateDelta, Turn
from engine.state import GameState, apply_delta

APP_ROOT = Path(__file__).resolve().parent
STATIC_ROOT = APP_ROOT / "static"

GENRE_LABELS = {
    "cursed_dungeon": "Cursed Dungeon",
    "whispering_wood": "Whispering Wood",
    "derelict_starship": "Derelict Starship",
}


@dataclass
class PlaySession:
    state: GameState
    backend: MockBackend
    last_turn: Turn | None = None
    transcript: list[dict[str, Any]] = field(default_factory=list)


app = Server()
app.mount("/static", StaticFiles(directory=STATIC_ROOT), name="static")

_SESSIONS: dict[str, PlaySession] = {}


@app.get("/", response_class=HTMLResponse)
async def homepage() -> HTMLResponse:
    return HTMLResponse((STATIC_ROOT / "index.html").read_text())


@app.get("/health")
async def health() -> dict[str, str]:
    return {"status": "ok"}


@app.post("/api/start")
async def start_adventure(request: Request) -> JSONResponse:
    payload = await request.json()
    genre = _genre(payload.get("genre"))
    premise = _clean_text(payload.get("premise"), limit=140) or None
    session = PlaySession(
        state=GameState(genre=genre, premise=premise),
        backend=MockBackend(_scripted_turns(genre, premise)),
    )
    session_id = uuid.uuid4().hex
    _SESSIONS[session_id] = session
    turn_payload = _advance_to_next_turn(session)
    return JSONResponse(
        {
            "session_id": session_id,
            "turn": turn_payload,
            "state": _state_payload(session.state),
            "assistant": _assistant_opening(genre),
        }
    )


@app.post("/api/choose")
async def choose_action(request: Request) -> JSONResponse:
    payload = await request.json()
    session = _session(payload.get("session_id"))
    action = _clean_text(payload.get("action"), limit=120)
    if not action and session.last_turn is not None:
        action = session.last_turn.choices[0]

    if session.last_turn is not None and session.last_turn.is_ending:
        return JSONResponse(
            {
                "turn": _turn_payload(session.last_turn),
                "state": _state_payload(session.state),
                "assistant": _assistant_for_turn(session, action),
            }
        )

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
    return JSONResponse(
        {
            "turn": turn_payload,
            "state": _state_payload(session.state),
            "assistant": _assistant_for_turn(session, action),
        }
    )


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

        sample_rate, audio = synthesize(text, voice_id=_voice_for_genre(session.state.genre))
    except Exception as exc:
        raise HTTPException(
            status_code=503,
            detail=f"local Kokoro narration unavailable: {type(exc).__name__}",
        ) from exc

    wav = io.BytesIO()
    sf.write(wav, audio, sample_rate, format="WAV")
    return Response(content=wav.getvalue(), media_type="audio/wav")


@app.api(name="start_demo_adventure")
def start_demo_adventure(genre: str = "cursed_dungeon", premise: str = "") -> dict[str, Any]:
    """Gradio API endpoint for external smoke checks; the custom UI uses /api/start."""
    session = PlaySession(
        state=GameState(genre=_genre(genre), premise=_clean_text(premise, limit=140) or None),
        backend=MockBackend(_scripted_turns(_genre(genre), premise or None)),
    )
    return _advance_to_next_turn(session)


def _advance_to_next_turn(session: PlaySession) -> dict[str, Any]:
    result = next_turn(session.state, session.backend)
    turn = result.turn
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


def _state_payload(state: GameState) -> dict[str, Any]:
    return {
        "hp": state.hp,
        "inventory": list(state.inventory),
        "location": state.location,
        "turn_count": state.turn_count,
        "genre": state.genre,
        "premise": state.premise,
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


def _assistant_opening(genre: str) -> str:
    return (
        f"I am Ember, your pocket drake. I will perch here while the "
        f"{GENRE_LABELS[genre]} tries to misbehave."
    )


def _assistant_for_turn(session: PlaySession, action: str) -> str:
    if session.last_turn is None:
        return "I am ready when you are."
    if session.last_turn.is_ending:
        return "That is a proper ending. I am doing a tiny victory scorch."
    if session.state.hp <= 3:
        return "Careful. Your hearts are getting crisp around the edges."
    if "inspect" in action.casefold() or "search" in action.casefold():
        return "Good instinct. Small models love clear intent and shiny clues."
    return "Choice logged. Wings flapping. Narrative pressure rising."


def _dragon_reply(session: PlaySession, message: str) -> str:
    lowered = message.casefold()
    turn = session.last_turn
    if turn is None:
        return "Start an adventure and I will start hovering."
    if "hint" in lowered or "help" in lowered or "what" in lowered:
        if turn.is_ending:
            return "The tale has landed. Start a fresh scroll if you want another flight."
        return f"My hint: try '{turn.choices[0]}'. It gives the engine a clean next move."
    if "fire" in lowered or "flame" in lowered:
        return "A tasteful puff of fire, then. We are dramatic, not reckless."
    if "offline" in lowered or "tiny" in lowered:
        return "The winning trick is receipts: small model, local rules, no hidden cloud calls."
    return "I heard you. Ask me for a hint, a status read, or a little fire."


def _voice_for_genre(genre: str) -> str:
    if genre == "whispering_wood":
        return "wood"
    if genre == "derelict_starship":
        return "starship"
    return "dungeon"


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
