"""Pocket Pikachu — a fully self-contained talking digital pet for Hugging Face Spaces.

A single Gradio Blocks app: a big, centered Pikachu you click (mic) or type to.
Speech is transcribed, the pet replies, and the reply is spoken back — 100% local,
all models loaded IN-PROCESS (no localhost sidecars), lazy-loaded on first request.

Stack on this free-CPU Space (every model on-device, all <= 4B params):
  * Brain : openbmb/MiniCPM5-1B-GGUF (Q4_K_M) via llama-cpp-python (OpenBMB)
  * STT   : Systran/faster-whisper-small.en (CTranslate2) — runs on free CPU
  * TTS   : kokoro-onnx, cute warm female voice "af_heart" + pitch/rate styling

Why these picks: the Space runs on free HF cpu-basic (2 vCPU / 16 GB). Two of
the native macOS app's models cannot run there:
  * NVIDIA Nemotron ASR — installing NeMo OOM-kills the build (exit 137).
  * OpenBMB VoxCPM-0.5B — pulls torch + funasr + a CUDA stack that OOM-kills the
    build, and CPU inference is too slow to be interactive.
So the hosted Space substitutes faster-whisper (ears) and kokoro-onnx (voice),
both torch-light and CPU-friendly. The native app runs Nemotron + VoxCPM for
real. This file does NOT claim to run Nemotron or VoxCPM on the Space. The
OpenBMB/MiniCPM brain still runs here in full.

This file mirrors app/web_pet.py's UI/CSS and reuses app/server.py's system prompt +
app/agent_tools.gather_tool_facts injection and app/pika_tts_server._style_voice styling.
On Spaces the model weights download from the HF hub on first request.
"""

from __future__ import annotations

import html
import json
import os
import subprocess
import tempfile
import threading
import wave
from datetime import datetime
from functools import lru_cache
from pathlib import Path
from typing import Any

import gradio as gr

# Vendored from app/agent_tools.py so the Space is self-contained (keyless,
# stdlib-only time / weather / web-search facts to ground replies).
from agent_tools import gather_tool_facts

HERE = Path(__file__).parent

# --- Sprites (shipped alongside this file) -------------------------------------
PIKA_HAPPY = str(HERE / "pika-happy.png")
PIKA_HYPER = str(HERE / "pika-hyper.png")
PIKA_NAP = str(HERE / "pika-nap.png")
PIKA_ALERT = str(HERE / "pika-alert.png")

# --- Model ids ----------------------------------------------------------------
BRAIN_REPO = "openbmb/MiniCPM5-1B-GGUF"
BRAIN_GGUF = "MiniCPM5-1B-Q4_K_M.gguf"
# STT on the Space is faster-whisper small.en (CPU-friendly). The native macOS
# app uses NVIDIA Nemotron; NeMo OOM-kills the free Space build, so it is not
# installed here. See the module docstring.
WHISPER_MODEL = "small.en"
# TTS on the Space is kokoro-onnx (ONNX, torch-free) — light enough to run on
# free CPU. The native macOS app uses VoxCPM-0.5B (OpenBMB); VoxCPM needs a GPU
# and OOM-kills the free Space build, so the Space uses Kokoro instead. The cute
# voice is Kokoro's warm female "af_heart", plus the same pitch/rate styling.
KOKORO_ONNX = HERE / "kokoro-v1.0.onnx"
KOKORO_VOICES = HERE / "voices-v1.0.bin"
KOKORO_VOICE = "af_heart"
KOKORO_LANG = "en-us"

# --- Pika voice styling (matches app/pika_tts_server._style_voice) ------------
# Cute high-pitch, slow/deliberate female voice: pitch up, tempo down, independent.
PIKA_PITCH = 1.18
PIKA_RATE = 0.85

# Brain decoding (mirrors app/server defaults)
MAX_TOKENS = 72
TEMPERATURE = 0.35

MAX_TEXT_CHARS = 320


# ---------------------------------------------------------------------------
# Lazy model loading. Spaces must boot fast, so every model loads on first use
# and a "waking up…" status is surfaced to the user while weights download.
# ---------------------------------------------------------------------------
_BRAIN_LOCK = threading.Lock()
_STT_LOCK = threading.Lock()
_TTS_LOCK = threading.Lock()

_brain: Any = None
_stt: Any = None  # callable: (wav_path) -> (text, backend_label)
_tts: Any = None


def _load_brain() -> Any:
    """MiniCPM5-1B GGUF via llama-cpp-python. Downloads the Q4_K_M file on first use."""
    global _brain
    if _brain is not None:
        return _brain
    with _BRAIN_LOCK:
        if _brain is not None:
            return _brain
        from huggingface_hub import hf_hub_download
        from llama_cpp import Llama

        gguf_path = hf_hub_download(repo_id=BRAIN_REPO, filename=BRAIN_GGUF)
        _brain = Llama(
            model_path=gguf_path,
            n_ctx=2048,
            n_threads=int(os.environ.get("POCKETDM_LLAMA_THREADS", os.cpu_count() or 4)),
            verbose=False,
        )
    return _brain


def _load_stt() -> Any:
    """STT = faster-whisper small.en (CTranslate2 int8) — fast/accurate on CPU.

    Returns a callable ``transcribe(wav_path) -> (text, backend_label)``. NeMo /
    Nemotron is intentionally NOT used here: it OOM-kills the free-CPU Space build.
    Nemotron runs in the native macOS PocketDM app instead.
    """
    global _stt
    if _stt is not None:
        return _stt
    with _STT_LOCK:
        if _stt is not None:
            return _stt
        from faster_whisper import WhisperModel

        model = WhisperModel(WHISPER_MODEL, device="cpu", compute_type="int8")

        def transcribe(wav_path: str) -> tuple[str, str]:
            try:
                segments, _info = model.transcribe(
                    wav_path, language="en", vad_filter=True, beam_size=1
                )
            except TypeError:
                segments, _info = model.transcribe(wav_path, language="en")
            text = " ".join(seg.text.strip() for seg in segments if seg.text.strip())
            return " ".join(text.split()), "faster-whisper small.en"

        _stt = transcribe
    return _stt


def _load_tts() -> Any:
    """kokoro-onnx (torch-free, CPU) loaded from the bundled model + voices files."""
    global _tts
    if _tts is not None:
        return _tts
    with _TTS_LOCK:
        if _tts is not None:
            return _tts
        from kokoro_onnx import Kokoro

        _tts = Kokoro(str(KOKORO_ONNX), str(KOKORO_VOICES))
    return _tts


# ---------------------------------------------------------------------------
# Brain reply — same system prompt + gather_tool_facts injection as app/server.py
# ---------------------------------------------------------------------------
SYSTEM_PROMPT = (
    "You are Pika, a tiny always-on desktop companion. "
    "The user is talking to their pocket Pikachu pet. "
    "Reply in one compact helpful line. Include 'Pika pika!' once. "
    "Use tool facts exactly. Do not invent weather, time, model, or system data. "
    "If the user asks for encouragement, give encouragement without asking for extra details. "
    "Never answer only with Pika sounds; after the catchphrase, include one useful sentence. "
    "Do not include analysis, reasoning, markdown, emoji, stage directions, or <think> tags."
)


def brain_reply(message: str) -> str:
    brain = _load_brain()

    now = datetime.now().astimezone()
    context: dict[str, Any] = {
        "purpose": "freeform desktop pet chat",
        "local_time": now.isoformat(timespec="seconds"),
        "timezone": now.tzname() or now.strftime("%z"),
        "runtime": "llama.cpp (in-process)",
        "model": "MiniCPM5-1B-Q4_K_M",
    }
    if tool_facts := gather_tool_facts(message):
        context["tool_facts"] = tool_facts

    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {
            "role": "user",
            "content": f"Context: {json.dumps(context, sort_keys=True)}\nUser: {message}",
        },
    ]
    try:
        result = brain.create_chat_completion(
            messages=messages,
            max_tokens=MAX_TOKENS,
            temperature=TEMPERATURE,
            stop=["<turn|>", "<|im_end|>"],
        )
        content = str(result["choices"][0]["message"]["content"]).strip()
    except Exception as exc:
        return f"(Pikachu is napping — brain error: {exc})"

    content = _strip_thinking(content)
    content = _strip_leading_pika_sounds(content)
    if not content or not _has_substance(content):
        return "Pika pika! I'm here with you — tell me one small thing on your mind."
    return _compact(content)


def _strip_thinking(content: str) -> str:
    cleaned = content.strip()
    lowered = cleaned.casefold()
    if "</think>" in lowered:
        end = lowered.rfind("</think>") + len("</think>")
        cleaned = cleaned[end:].strip()
    if cleaned.casefold().startswith("<think>"):
        return ""
    return cleaned


def _strip_leading_pika_sounds(content: str) -> str:
    cleaned = content.strip()
    prefixes = ("pika pika", "pika piki", "pikaa pikaa", "pikaaa pikaaa", "pikaa", "pika")
    changed = True
    while cleaned and changed:
        changed = False
        lowered = cleaned.casefold()
        for prefix in prefixes:
            if lowered.startswith(prefix):
                rest = cleaned[len(prefix):].lstrip(" ,.!?-")
                if rest:
                    cleaned = rest
                    changed = True
                break
    return cleaned


def _has_substance(content: str) -> bool:
    words = [
        "".join(c for c in token.casefold() if c.isalpha())
        for token in content.split()
    ]
    mascot = {"pika", "piki", "pikaa", "pikaaa", "pikachu"}
    meaningful = [w for w in words if w and w not in mascot and not w.startswith("pika")]
    return len(meaningful) >= 3


def _compact(content: str, *, limit: int = 180) -> str:
    compact = " ".join(content.split())
    # Ensure the catchphrase is present once, like the desktop companion.
    if "pika" not in compact.casefold():
        compact = f"Pika pika! {compact}"
    if len(compact) <= limit:
        return compact
    clipped = compact[:limit].rstrip()
    sentence_end = max(clipped.rfind("."), clipped.rfind("!"), clipped.rfind("?"))
    if sentence_end >= 20:
        return clipped[: sentence_end + 1]
    return clipped.rstrip(" ,;:") + "."


# ---------------------------------------------------------------------------
# TTS — kokoro-onnx (af_heart) + _style_voice pitch/rate styling
# (same cute-voice styling as app/pika_tts_server._style_voice)
# ---------------------------------------------------------------------------
def speak(text: str) -> str | None:
    text = " ".join((text or "").split())[:MAX_TEXT_CHARS].strip()
    if not text:
        return None
    try:
        model = _load_tts()
    except Exception as exc:
        print(f"[tts] kokoro-onnx unavailable: {exc}", flush=True)
        return None

    try:
        samples, sample_rate = model.create(
            text, voice=KOKORO_VOICE, speed=1.0, lang=KOKORO_LANG
        )
    except Exception as exc:
        print(f"[tts] kokoro-onnx create failed: {exc}", flush=True)
        return None

    wav_bytes = _wav_bytes(_float_samples(samples), int(sample_rate))
    wav_bytes = _style_voice(wav_bytes, int(sample_rate))

    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    tmp.write(wav_bytes)
    tmp.close()
    return tmp.name


def _style_voice(wav: bytes, sample_rate: int) -> bytes:
    """High-pitch + slow-tempo Pika styling via ffmpeg (pitch/tempo independent).

    asetrate shifts pitch+tempo together, atempo compensates tempo (pitch-preserving)
    so the two stay independent. Falls back to the unstyled wav if ffmpeg is missing.
    Mirrors app/pika_tts_server._style_voice with PIKA_PITCH=1.18 / PIKA_RATE=0.85.
    """
    pitch = PIKA_PITCH
    rate = PIKA_RATE
    if abs(pitch - 1.0) < 0.01 and abs(rate - 1.0) < 0.01:
        return wav
    atempo = max(0.5, min(2.0, rate / pitch))
    flt = f"asetrate={sample_rate}*{pitch:.4f},aresample={sample_rate},atempo={atempo:.4f}"
    out_path = None
    try:
        with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as handle:
            out_path = handle.name
        proc = subprocess.run(
            ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", "pipe:0", "-af", flt, out_path],
            input=wav,
            capture_output=True,
            timeout=20,
        )
        if proc.returncode == 0:
            data = Path(out_path).read_bytes()
            if data[:4] == b"RIFF":
                return data
    except Exception:
        pass
    finally:
        if out_path:
            try:
                os.unlink(out_path)
            except OSError:
                pass
    return wav


def _float_samples(generated: Any) -> list[float]:
    if isinstance(generated, tuple) and generated:
        generated = generated[0]
    if hasattr(generated, "detach"):
        generated = generated.detach().cpu()
    if hasattr(generated, "numpy"):
        generated = generated.numpy()
    if hasattr(generated, "tolist"):
        generated = generated.tolist()
    return [float(v) for v in _flatten(generated)]


def _flatten(value: Any) -> list[float]:
    if isinstance(value, (list, tuple)):
        out: list[float] = []
        for item in value:
            out.extend(_flatten(item))
        return out
    return [float(value)]


def _wav_bytes(samples: list[float], sample_rate: int) -> bytes:
    import io

    buffer = io.BytesIO()
    with wave.open(buffer, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(sample_rate)
        frames = bytearray()
        for sample in samples:
            clipped = max(-1.0, min(1.0, sample))
            frames.extend(int(clipped * 32767).to_bytes(2, "little", signed=True))
        wav.writeframes(bytes(frames))
    return buffer.getvalue()


# ---------------------------------------------------------------------------
# Turn handling
# ---------------------------------------------------------------------------
def take_turn(user_text: str, history: list[dict]) -> tuple[list[dict], str | None, str]:
    history = list(history or [])
    user_text = (user_text or "").strip()
    if not user_text:
        return history, None, sprite_html(PIKA_HAPPY)

    history.append({"role": "user", "content": user_text})
    reply = brain_reply(user_text)
    history.append({"role": "assistant", "content": reply})

    audio = speak(reply)
    return history, audio, sprite_html(PIKA_HYPER)


def handle_text(text: str, history: list[dict]):
    new_history, audio, sprite = take_turn(text, history)
    return new_history, audio, sprite, ""  # clear textbox


def handle_voice(audio_path: str | None, history: list[dict]):
    if not audio_path:
        return history or [], None, sprite_html(PIKA_HAPPY), None
    try:
        transcribe = _load_stt()
        text, _backend = transcribe(audio_path)
    except Exception as exc:
        history = list(history or [])
        history.append({"role": "assistant", "content": f"(Couldn't hear you — STT error: {exc})"})
        return history, None, sprite_html(PIKA_ALERT), None
    if not text:
        history = list(history or [])
        history.append({"role": "assistant", "content": "Pika? I didn't catch that — try again?"})
        return history, None, sprite_html(PIKA_ALERT), None
    new_history, audio, sprite = take_turn(text, history)
    return new_history, audio, sprite, None  # clear mic


def handle_checkin(history: list[dict]):
    return take_turn("Good morning, Pikachu! How are you today?", history)


# ---------------------------------------------------------------------------
# View
# ---------------------------------------------------------------------------
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
/* --- "Wow" UI additions --- */
.pet-hero {
  color: #6b4a00; margin: 6px auto 10px; max-width: 560px;
  font-size: 1.02rem; font-weight: 600; line-height: 1.45;
}
.talk-hint {
  text-align: center; color: #7a5600; font-weight: 700;
  font-size: 0.95rem; margin: 4px 0 8px;
}
.yt-section { text-align: center; margin: 18px 0 6px; }
.yt-title { color: #5b3a00; font-weight: 800; margin: 6px 0; }
.yt-section iframe { max-width: 100%; border-radius: 14px; box-shadow: 0 6px 18px rgba(160,110,0,0.25); }
.yt-note { color: #8a6400; font-size: 0.8rem; margin: 4px 0 0; }
.yt-note code { background: #fff3c4; padding: 1px 5px; border-radius: 5px; }
"""

# Force Gradio's light theme so the sunny styling holds in dark mode.
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

# --- Marketing copy (honest; this free Space runs MiniCPM + Whisper + Kokoro) -
HERO_HTML = (
    "<div class='pet-header'>"
    "<h1 class='pet-title'>⚡ Pocket Pikachu</h1>"
    "<p class='pet-hero'>The Pokémon you actually talk to — 100% on your own machine. "
    "No cloud, no internet. Pull the WiFi and it still listens, thinks, and talks back.</p>"
    "</div>"
)

CHIP_ROW_HTML = (
    "<div class='chip-row'>"
    "<span class='chip'>MiniCPM5-1B</span>"
    "<span class='chip'>Kokoro voice</span>"
    "<span class='chip'>Whisper</span>"
    "<span class='chip local'>100% local</span>"
    "</div>"
)

# Published demo video (matches the README and the zerogpu Space variant).
YOUTUBE_VIDEO_ID = "MAsgEj7ywh8"
YOUTUBE_HTML = (
    "<div class='yt-section'>"
    "<h3 class='yt-title'>🎥 Watch the story</h3>"
    "<div style='text-align:center;margin:14px 0;'>"
    f"<iframe width='560' height='315' src='https://www.youtube.com/embed/{YOUTUBE_VIDEO_ID}' "
    "title='Pocket Pikachu' frameborder='0' allow='accelerometer; autoplay; clipboard-write; "
    "encrypted-media; gyroscope; picture-in-picture' allowfullscreen></iframe></div>"
    "</div>"
)

ABOUT_MD = (
    "- 🎤 **Talk to it anytime** — by voice or text. It answers out loud in a cute, high-energy voice.\n"
    "- ☀️ **Starts your day right** — cheerful morning check-ins and affirmations that keep you positive and moving.\n"
    "- 💧 **Looks after you** — drink-water nudges, a bond that grows when you care for it, and it learns your daily patterns so it genuinely feels like it knows you.\n"
    "- 📓 **Remembers with you** — a built-in journal for your moods, wins, and memories.\n"
    "- 🗣️ **Teaches you** — practice a new language (Spanish & Mandarin) with one friendly voice.\n"
    "- 🎭 **More moods coming** — today it's your hyper-positive cheerleader; emotion-aware modes for your whole range are next."
)

# CPU Space honestly credits its actual stack (Kokoro voice + Whisper ears);
# the native app / org GPU Space run VoxCPM + Nemotron.
WHY_MD = (
    "- **100% LOCAL** — every model runs on-device. No API keys, no servers, nothing leaves your machine. Works in airplane mode.\n"
    "- **Tiny by design** — MiniCPM5-1B brain (OpenBMB) + Kokoro voice + Whisper ears, each ≤1B. A whole talking companion that fits on a laptop. "
    "(The native app and the org GPU build use OpenBMB's VoxCPM voice + NVIDIA Nemotron ears.)\n"
    "- **A character, not a chatbot** — it reacts, remembers, cheers you on, and has a personality built to make your day brighter."
)


def build_app() -> gr.Blocks:
    with gr.Blocks(title="Pocket Pikachu — Talking Pet") as demo:
        # Inject styling + force-light inline so it applies however the host
        # (HF Spaces or local) launches the app — HF calls demo.launch() itself
        # without our css/head args, so we cannot rely on those alone.
        gr.HTML(f"<style>{CUSTOM_CSS}</style>{FORCE_LIGHT_HEAD}")
        with gr.Column(elem_id="pet-app"):
            gr.HTML(HERO_HTML + CHIP_ROW_HTML)

            sprite = gr.HTML(sprite_html(PIKA_HAPPY))

            gr.HTML(
                "<p class='talk-hint'>🎤 Tap record and talk — Pikachu talks back out loud. "
                "Or 💬 type below. (First message wakes the models.)</p>"
            )

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
                    label="🎤 Talk to Pikachu",
                    show_label=True,
                )

            with gr.Row():
                textbox = gr.Textbox(
                    placeholder="💬 …or type something to Pikachu",
                    show_label=False,
                    scale=4,
                    container=False,
                )
                send_btn = gr.Button("Send", scale=1, variant="primary", elem_classes="talk-btn")

            with gr.Row():
                checkin_btn = gr.Button("☀️ Daily check-in", elem_classes="talk-btn")

            gr.HTML(YOUTUBE_HTML)

            with gr.Accordion("✨ What can it do?", open=False):
                gr.Markdown(ABOUT_MD)
            with gr.Accordion("🔒 Why is it different?", open=False):
                gr.Markdown(WHY_MD)

        # --- Wiring -----------------------------------------------------------
        mic.stop_recording(
            handle_voice,
            inputs=[mic, chat],
            outputs=[chat, reply_audio, sprite, mic],
        )
        send_btn.click(
            handle_text,
            inputs=[textbox, chat],
            outputs=[chat, reply_audio, sprite, textbox],
        )
        textbox.submit(
            handle_text,
            inputs=[textbox, chat],
            outputs=[chat, reply_audio, sprite, textbox],
        )
        checkin_btn.click(
            handle_checkin,
            inputs=[chat],
            outputs=[chat, reply_audio, sprite],
        )

    return demo


demo = build_app()
# Also set as Blocks attributes so they apply when the HF Spaces runtime calls
# demo.launch() for us (it does not pass our css/head/allowed_paths args).
demo.css = CUSTOM_CSS
demo.head = FORCE_LIGHT_HEAD
# Let Gradio serve the bundled sprites regardless of how launch() is invoked.
os.environ.setdefault("GRADIO_ALLOWED_PATHS", str(HERE))
demo.queue()

if __name__ == "__main__":
    demo.launch(
        server_name="0.0.0.0",
        server_port=int(os.environ.get("PORT", "7860")),
        allowed_paths=[str(HERE)],
    )
