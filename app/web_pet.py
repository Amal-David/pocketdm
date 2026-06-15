"""Talking digital pet — a clickable Pikachu you talk to, entirely in the browser.

Build Small hackathon submission. A self-contained Gradio Blocks app that shows a
large, centered Pikachu you click (or type) to talk to. Speech is transcribed,
the pet replies, and the reply is spoken back — 100% local.

The brain / STT / TTS run as local HTTP sidecars (already up during the demo):

  * STT   POST http://127.0.0.1:7862/transcribe   (multipart wav)  -> {"text": ...}
  * brain POST http://127.0.0.1:7860/api/start     {"genre": ...}   -> {"session_id": ...}
          POST http://127.0.0.1:7860/api/assistant {"session_id", "message"} -> {"reply": ...}
  * TTS   POST http://127.0.0.1:7861/tts {"text", "voice", "format"} -> wav bytes

Launch:  uv run python -m app.web_pet   (serves on http://127.0.0.1:7870)
"""

from __future__ import annotations

import os
import tempfile
from pathlib import Path

import gradio as gr
import requests

# --- Optional tool facts hook (a teammate owns app/agent_tools.py) -------------
# Import is best-effort: the app must still run before that module exists.
try:  # pragma: no cover - exercised only once agent_tools lands
    from app.agent_tools import gather_tool_facts
except ImportError:  # the common case today
    def gather_tool_facts(_message: str):  # type: ignore[misc]
        return None


# --- Sidecar endpoints --------------------------------------------------------
STT_URL = os.environ.get("POCKETDM_STT_URL", "http://127.0.0.1:7862/transcribe")
BRAIN_BASE = os.environ.get("POCKETDM_BRAIN_URL", "http://127.0.0.1:7860").rstrip("/")
START_URL = f"{BRAIN_BASE}/api/start"
ASSISTANT_URL = f"{BRAIN_BASE}/api/assistant"
TTS_URL = os.environ.get("POCKETDM_TTS_URL", "http://127.0.0.1:7861/tts")

GENRE = os.environ.get("POCKETDM_GENRE", "cursed_dungeon")
PORT = int(os.environ.get("POCKETDM_WEB_PET_PORT", "7870"))

# Single female VoxCPM reference clip; the sidecar reads its own
# POCKETDM_PIKA_TTS_REF, but we surface the path here so the voice is never
# hardcoded to anything male and can be threaded through later if needed.
VOICE_REF = os.environ.get("POCKETDM_PIKA_VOICE_REF", "").strip() or None
VOICE_NAME = "pika-signature"

STATIC_DIR = Path(__file__).parent / "static"
PIKA_HAPPY = str(STATIC_DIR / "pika-happy.png")
PIKA_HYPER = str(STATIC_DIR / "pika-hyper.png")

REQUEST_TIMEOUT = 60


# --- Sidecar calls ------------------------------------------------------------
def start_session() -> str:
    """Create a brain session and return its id (best-effort)."""
    resp = requests.post(START_URL, json={"genre": GENRE}, timeout=REQUEST_TIMEOUT)
    resp.raise_for_status()
    return resp.json()["session_id"]


def transcribe(audio_path: str) -> str:
    with open(audio_path, "rb") as handle:
        files = {"audio": (Path(audio_path).name, handle, "audio/wav")}
        resp = requests.post(STT_URL, files=files, timeout=REQUEST_TIMEOUT)
    resp.raise_for_status()
    return (resp.json().get("text") or "").strip()


def ask_pet(session_id: str, message: str) -> str:
    resp = requests.post(
        ASSISTANT_URL,
        json={"session_id": session_id, "message": message},
        timeout=REQUEST_TIMEOUT,
    )
    resp.raise_for_status()
    return (resp.json().get("reply") or "").strip()


def speak(text: str) -> str | None:
    """Synthesize ``text`` to a temp wav file; return its path (or None)."""
    if not text:
        return None
    payload = {"text": text, "voice": VOICE_NAME, "format": "wav"}
    if VOICE_REF:
        # Forward the female reference clip if the TTS sidecar accepts it; the
        # current sidecar ignores unknown fields, so this stays safe.
        payload["reference_audio"] = VOICE_REF
    try:
        resp = requests.post(TTS_URL, json=payload, timeout=REQUEST_TIMEOUT)
        resp.raise_for_status()
    except requests.RequestException:
        return None
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    tmp.write(resp.content)
    tmp.close()
    return tmp.name


# --- Turn handling ------------------------------------------------------------
def ensure_session(session_id: str | None) -> str:
    if session_id:
        return session_id
    return start_session()


def take_turn(
    user_text: str,
    history: list[dict],
    session_id: str | None,
) -> tuple[list[dict], str | None, str, str]:
    """Run one full conversation turn and return updated UI state.

    Returns: (chat history, reply audio path, sprite html, session id).
    """
    history = list(history or [])
    user_text = (user_text or "").strip()
    if not user_text:
        return history, None, sprite_html(PIKA_HAPPY), session_id or ""

    session_id = ensure_session(session_id)

    # Best-effort tool facts (no-op until agent_tools lands). The brain may also
    # weave tools in server-side; we keep this hook so the import path is live.
    try:
        gather_tool_facts(user_text)
    except Exception:  # never let a tool hook break a turn
        pass

    history.append({"role": "user", "content": user_text})
    try:
        reply = ask_pet(session_id, user_text) or "Pika?"
    except requests.RequestException as exc:
        reply = f"(Pikachu is napping — brain unreachable: {exc})"
    history.append({"role": "assistant", "content": reply})

    audio = speak(reply)
    return history, audio, sprite_html(PIKA_HYPER), session_id


def handle_text(text: str, history: list[dict], session_id: str | None):
    new_history, audio, sprite, session_id = take_turn(text, history, session_id)
    return new_history, audio, sprite, session_id, ""  # clear the textbox


def handle_voice(audio_path: str | None, history: list[dict], session_id: str | None):
    if not audio_path:
        return history or [], None, sprite_html(PIKA_HAPPY), session_id or "", None
    try:
        text = transcribe(audio_path)
    except requests.RequestException as exc:
        history = list(history or [])
        history.append(
            {"role": "assistant", "content": f"(Couldn't hear you — STT error: {exc})"}
        )
        return history, None, sprite_html(PIKA_HAPPY), session_id or "", None
    new_history, audio, sprite, session_id = take_turn(text, history, session_id)
    return new_history, audio, sprite, session_id, None  # clear the mic


def handle_checkin(history: list[dict], session_id: str | None):
    new_history, audio, sprite, session_id = take_turn(
        "Good morning, Pikachu! How are you today?", history, session_id
    )
    return new_history, audio, sprite, session_id


# --- View helpers -------------------------------------------------------------
def sprite_html(src: str) -> str:
    return (
        "<div class='pet-stage'>"
        f"<img class='pet-sprite' src='/gradio_api/file={src}' alt='Pikachu' />"
        "<div class='pet-shadow'></div>"
        "</div>"
    )


CUSTOM_CSS = """
.gradio-container {
  background: radial-gradient(circle at 50% 12%, #fff6c9 0%, #ffe8a3 28%, #ffd76b 55%, #ffc94a 100%) !important;
  font-family: 'Baloo 2', 'Quicksand', system-ui, -apple-system, sans-serif;
}
#pet-app { max-width: 720px; margin: 0 auto; }
.pet-header { text-align: center; padding: 8px 0 0; }
.pet-title {
  font-size: 2.1rem; font-weight: 800; margin: 0;
  color: #5b3a00; letter-spacing: 0.5px;
  text-shadow: 0 2px 0 #fff2b0;
}
.pet-subtitle { color: #8a6400; margin: 2px 0 10px; font-size: 0.95rem; }
.chip-row { display: flex; gap: 8px; justify-content: center; flex-wrap: wrap; margin-bottom: 6px; }
.chip {
  background: rgba(255,255,255,0.7); color: #6b4a00;
  border: 1.5px solid #ffce4d; border-radius: 999px;
  padding: 4px 12px; font-size: 0.78rem; font-weight: 700;
  box-shadow: 0 2px 6px rgba(180,120,0,0.12);
}
.chip.local { background: #ffe27a; }
.pet-stage { position: relative; display: flex; flex-direction: column; align-items: center; padding: 4px 0; }
.pet-sprite {
  width: 300px; height: 300px; object-fit: contain;
  filter: drop-shadow(0 10px 18px rgba(180,120,0,0.35));
  animation: pet-bob 2.6s ease-in-out infinite;
  cursor: pointer; user-select: none;
}
.pet-sprite:active { transform: scale(0.96); }
.pet-shadow {
  width: 150px; height: 22px; margin-top: -6px;
  background: rgba(120,80,0,0.18);
  border-radius: 50%; filter: blur(4px);
  animation: pet-shadow 2.6s ease-in-out infinite;
}
@keyframes pet-bob {
  0%, 100% { transform: translateY(0); }
  50% { transform: translateY(-14px); }
}
@keyframes pet-shadow {
  0%, 100% { transform: scaleX(1); opacity: 0.6; }
  50% { transform: scaleX(0.82); opacity: 0.4; }
}
/* Chat bubbles */
#pet-chat { border: none !important; background: transparent !important; }
#pet-chat .message-row .message {
  border-radius: 18px !important;
  border: none !important;
  box-shadow: 0 2px 8px rgba(160,110,0,0.15) !important;
}
#pet-chat .user .message { background: #fff7d6 !important; color: #5b3a00 !important; }
#pet-chat .bot .message { background: #ffd76b !important; color: #4a3000 !important; }
/* Buttons */
.talk-btn button, #pet-app button.primary {
  background: linear-gradient(180deg, #ff5a5a 0%, #e23c3c 100%) !important;
  border: none !important; color: #fff !important;
  border-radius: 999px !important; font-weight: 800 !important;
  box-shadow: 0 4px 0 #b32626 !important;
}
.talk-btn button:active { transform: translateY(2px); box-shadow: 0 2px 0 #b32626 !important; }
footer { display: none !important; }
"""

# Force Gradio's light theme so the sunny styling holds even when the browser
# (or OS) prefers dark mode — otherwise components render on a dark shell.
FORCE_LIGHT_HEAD = """
<script>
(function () {
  function forceLight() {
    document.documentElement.classList.remove('dark');
    document.body && document.body.classList.remove('dark');
    document.querySelectorAll('.gradio-container.dark').forEach(function (el) {
      el.classList.remove('dark');
    });
  }
  forceLight();
  new MutationObserver(forceLight).observe(document.documentElement, {
    attributes: true, attributeFilter: ['class'], subtree: true,
  });
  document.addEventListener('DOMContentLoaded', forceLight);
})();
</script>
"""


def build_app() -> gr.Blocks:
    with gr.Blocks(title="Pocket Pikachu — Talking Pet") as demo:
        session_state = gr.State("")

        with gr.Column(elem_id="pet-app"):
            gr.HTML(
                "<div class='pet-header'>"
                "<h1 class='pet-title'>⚡ Pocket Pikachu</h1>"
                "<p class='pet-subtitle'>Click the mic or type — your pocket pet talks back.</p>"
                "<div class='chip-row'>"
                "<span class='chip'>MiniCPM5-1B</span>"
                "<span class='chip'>VoxCPM</span>"
                "<span class='chip'>Whisper</span>"
                "<span class='chip local'>100% local</span>"
                "</div>"
                "</div>"
            )

            sprite = gr.HTML(sprite_html(PIKA_HAPPY))

            reply_audio = gr.Audio(
                label="Pikachu says",
                autoplay=True,
                interactive=False,
                visible=True,
                show_label=False,
            )

            chat = gr.Chatbot(
                elem_id="pet-chat",
                height=260,
                show_label=False,
                avatar_images=(None, PIKA_HAPPY),
            )

            with gr.Row():
                mic = gr.Audio(
                    sources=["microphone"],
                    type="filepath",
                    label="Talk to Pikachu",
                    show_label=False,
                )

            with gr.Row():
                textbox = gr.Textbox(
                    placeholder="…or type something to Pikachu",
                    show_label=False,
                    scale=4,
                    container=False,
                )
                send_btn = gr.Button("Send", scale=1, variant="primary", elem_classes="talk-btn")

            with gr.Row():
                checkin_btn = gr.Button("☀️ Daily check-in", elem_classes="talk-btn")

        # --- Wiring -----------------------------------------------------------
        mic.stop_recording(
            handle_voice,
            inputs=[mic, chat, session_state],
            outputs=[chat, reply_audio, sprite, session_state, mic],
        )
        send_btn.click(
            handle_text,
            inputs=[textbox, chat, session_state],
            outputs=[chat, reply_audio, sprite, session_state, textbox],
        )
        textbox.submit(
            handle_text,
            inputs=[textbox, chat, session_state],
            outputs=[chat, reply_audio, sprite, session_state, textbox],
        )
        checkin_btn.click(
            handle_checkin,
            inputs=[chat, session_state],
            outputs=[chat, reply_audio, sprite, session_state],
        )

    return demo


def main() -> None:
    demo = build_app()
    demo.launch(
        server_name="127.0.0.1",
        server_port=PORT,
        css=CUSTOM_CSS,
        head=FORCE_LIGHT_HEAD,
        allowed_paths=[str(STATIC_DIR)],
    )


if __name__ == "__main__":
    main()
