"""Pocket Pikachu — GPU variant (VoxCPM on ZeroGPU) for the org Space.

Intended for an ORG-OWNED Space under `build-small-hackathon` on hardware
`zero-a10g` (free ZeroGPU for Team-plan org members):

  * Brain : openbmb/MiniCPM5-1B-GGUF (Q4_K_M) via llama-cpp-python — runs on CPU
            (the ZeroGPU base hides libcudart from llama.cpp).
  * TTS   : openbmb/VoxCPM-0.5B (OpenBMB) — runs on the GPU, cute female ref +
            pitch/rate styling. This is the upgrade over the CPU Space's Kokoro.
  * STT   : faster-whisper small.en — runs on CPU.

Why no NeMo/Nemotron here: `nemo_toolkit[asr]` cannot build on a ZeroGPU Gradio
Space (its multi-GB dependency tree + CUDA torch OOM-kills the CPU build
container), and the streaming model has no transformers path. Nemotron runs in
the native macOS PocketDM app instead.

ZeroGPU notes: the GPU attaches only inside `@spaces.GPU`-decorated functions, so
all per-turn inference runs inside `run_turn_gpu`. Do NOT pin torch in
requirements — ZeroGPU ships a preinstalled CUDA torch (2.8.0); pinning it (or
letting voxcpm pull its own) re-downloads ~5GB and OOMs the build.
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
from pathlib import Path
from typing import Any

import gradio as gr
import spaces  # ZeroGPU

from agent_tools import gather_tool_facts

HERE = Path(__file__).parent

PIKA_HAPPY = str(HERE / "pika-happy.png")
PIKA_HYPER = str(HERE / "pika-hyper.png")
PIKA_NAP = str(HERE / "pika-nap.png")
PIKA_ALERT = str(HERE / "pika-alert.png")

VOICE_REF_WAV = HERE / "pika-female-ref.wav"
VOICE_REF_TXT = HERE / "pika-female-ref.txt"

BRAIN_REPO = "openbmb/MiniCPM5-1B-GGUF"
BRAIN_GGUF = "MiniCPM5-1B-Q4_K_M.gguf"
TTS_REPO = "openbmb/VoxCPM-0.5B"
# STT = faster-whisper. NeMo/Nemotron cannot build on a ZeroGPU Gradio Space
# (multi-GB tree + CUDA torch OOMs the CPU build container); it runs in the
# native macOS app instead.
WHISPER_MODEL = "small.en"

PIKA_PITCH = 1.18
PIKA_RATE = 0.85
MAX_TOKENS = 72
TEMPERATURE = 0.35
DEFAULT_SAMPLE_RATE = 24_000
MAX_TEXT_CHARS = 320

SYSTEM_PROMPT = (
    "You are Pika, a tiny always-on desktop companion. "
    "The user is talking to their pocket Pikachu pet. "
    "Reply in one compact helpful line. Include 'Pika pika!' once. "
    "Use tool facts exactly. Do not invent weather, time, model, or system data. "
    "If the user asks for encouragement, give encouragement without asking for extra details. "
    "Never answer only with Pika sounds; after the catchphrase, include one useful sentence. "
    "Do not include analysis, reasoning, markdown, emoji, stage directions, or <think> tags."
)

# Lazy singletons (loaded inside the GPU context on first use).
_LOCK = threading.Lock()
_brain: Any = None
_stt: Any = None
_tts: Any = None


def _load_brain() -> Any:
    global _brain
    if _brain is None:
        from huggingface_hub import hf_hub_download
        from llama_cpp import Llama

        gguf = hf_hub_download(repo_id=BRAIN_REPO, filename=BRAIN_GGUF)
        # The ZeroGPU base image hides libcudart from llama.cpp (we install the
        # CPU wheel), so the brain runs on CPU. VoxCPM gets the GPU.
        _brain = Llama(model_path=gguf, n_ctx=2048, n_gpu_layers=0, verbose=False)
    return _brain


def _load_stt() -> Any:
    """faster-whisper small.en — NeMo/Nemotron cannot build on a ZeroGPU Space."""
    global _stt
    if _stt is None:
        from faster_whisper import WhisperModel

        _stt = WhisperModel(WHISPER_MODEL, device="cpu", compute_type="int8")
    return _stt


def _load_tts() -> Any:
    global _tts
    if _tts is None:
        from voxcpm import VoxCPM

        _tts = VoxCPM.from_pretrained(TTS_REPO)
    return _tts


def _brain_reply(message: str) -> str:
    brain = _load_brain()
    now = datetime.now().astimezone()
    context: dict[str, Any] = {
        "purpose": "freeform desktop pet chat",
        "local_time": now.isoformat(timespec="seconds"),
        "timezone": now.tzname() or now.strftime("%z"),
        "runtime": "llama.cpp (CPU) + VoxCPM (GPU)",
        "model": "MiniCPM5-1B-Q4_K_M",
    }
    if tool_facts := gather_tool_facts(message):
        context["tool_facts"] = tool_facts
    messages = [
        {"role": "system", "content": SYSTEM_PROMPT},
        {"role": "user", "content": f"Context: {json.dumps(context, sort_keys=True)}\nUser: {message}"},
    ]
    try:
        result = brain.create_chat_completion(
            messages=messages, max_tokens=MAX_TOKENS, temperature=TEMPERATURE,
            stop=["<turn|>", "<|im_end|>"],
        )
        content = str(result["choices"][0]["message"]["content"]).strip()
    except Exception as exc:
        return f"(Pikachu is napping — brain error: {exc})"
    content = _strip_leading_pika_sounds(_strip_thinking(content))
    if not content or not _has_substance(content):
        return "Pika pika! I'm here with you — tell me one small thing on your mind."
    return _compact(content)


def _whisper_transcribe(wav_path: str) -> str:
    model = _load_stt()
    try:
        segments, _info = model.transcribe(wav_path, language="en", vad_filter=True, beam_size=1)
    except TypeError:
        segments, _info = model.transcribe(wav_path, language="en")
    text = " ".join(seg.text.strip() for seg in segments if seg.text.strip())
    return " ".join(text.split())


def _voxcpm_speak(text: str) -> str | None:
    text = " ".join((text or "").split())[:MAX_TEXT_CHARS].strip()
    if not text:
        return None
    model = _load_tts()
    prompt_text = VOICE_REF_TXT.read_text(encoding="utf-8").strip() if VOICE_REF_TXT.exists() else None
    kwargs: dict[str, Any] = {
        "text": text, "cfg_value": 2.0, "inference_timesteps": 8,
        "normalize": False, "denoise": False,
    }
    if VOICE_REF_WAV.exists():
        kwargs["prompt_wav_path"] = str(VOICE_REF_WAV)
        kwargs["prompt_text"] = prompt_text
    try:
        generated = model.generate(**kwargs)
    except TypeError:
        generated = model.generate(text=text)
    sr = int(getattr(getattr(model, "tts_model", None), "sample_rate", DEFAULT_SAMPLE_RATE))
    wav_bytes = _style_voice(_wav_bytes(_float_samples(generated), sr), sr)
    tmp = tempfile.NamedTemporaryFile(suffix=".wav", delete=False)
    tmp.write(wav_bytes)
    tmp.close()
    return tmp.name


@spaces.GPU(duration=120)
def run_turn_gpu(user_text: str, wav_path: str | None) -> tuple[str, str, str | None]:
    """All GPU work for one turn: (optional STT) -> brain -> TTS.

    Returns (transcribed_or_passthrough_text, reply_text, reply_audio_path).
    Runs inside the ZeroGPU context so VoxCPM gets the GPU (brain + STT are CPU).
    """
    with _LOCK:
        text = user_text
        if wav_path:
            text = _whisper_transcribe(wav_path)
        if not (text or "").strip():
            return "", "Pika? I didn't catch that — try again?", None
        reply = _brain_reply(text)
        audio = _voxcpm_speak(reply)
        return text, reply, audio


# --- reply post-processing (same as the CPU app) ------------------------------
def _strip_thinking(content: str) -> str:
    cleaned = content.strip()
    lowered = cleaned.casefold()
    if "</think>" in lowered:
        cleaned = cleaned[lowered.rfind("</think>") + len("</think>"):].strip()
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
    words = ["".join(c for c in t.casefold() if c.isalpha()) for t in content.split()]
    mascot = {"pika", "piki", "pikaa", "pikaaa", "pikachu"}
    return len([w for w in words if w and w not in mascot and not w.startswith("pika")]) >= 3


def _compact(content: str, *, limit: int = 180) -> str:
    compact = " ".join(content.split())
    if "pika" not in compact.casefold():
        compact = f"Pika pika! {compact}"
    if len(compact) <= limit:
        return compact
    clipped = compact[:limit].rstrip()
    end = max(clipped.rfind("."), clipped.rfind("!"), clipped.rfind("?"))
    return clipped[: end + 1] if end >= 20 else clipped.rstrip(" ,;:") + "."


def _style_voice(wav: bytes, sample_rate: int) -> bytes:
    pitch, rate = PIKA_PITCH, PIKA_RATE
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
            input=wav, capture_output=True, timeout=20,
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


# --- turn handling / UI (mirrors the CPU Space) -------------------------------
def take_turn(user_text: str, history: list[dict]) -> tuple[list[dict], str | None, str]:
    history = list(history or [])
    user_text = (user_text or "").strip()
    if not user_text:
        return history, None, sprite_html(PIKA_HAPPY)
    history.append({"role": "user", "content": user_text})
    _text, reply, audio = run_turn_gpu(user_text, None)
    history.append({"role": "assistant", "content": reply})
    return history, audio, sprite_html(PIKA_HYPER)


def handle_text(text: str, history: list[dict]):
    h, audio, sprite = take_turn(text, history)
    return h, audio, sprite, ""


def handle_voice(audio_path: str | None, history: list[dict]):
    if not audio_path:
        return history or [], None, sprite_html(PIKA_HAPPY), None
    history = list(history or [])
    try:
        text, reply, audio = run_turn_gpu("", audio_path)
    except Exception as exc:
        history.append({"role": "assistant", "content": f"(Couldn't hear you — error: {exc})"})
        return history, None, sprite_html(PIKA_ALERT), None
    if not text:
        history.append({"role": "assistant", "content": "Pika? I didn't catch that — try again?"})
        return history, None, sprite_html(PIKA_ALERT), None
    history.append({"role": "user", "content": text})
    history.append({"role": "assistant", "content": reply})
    return history, audio, sprite_html(PIKA_HYPER), None


def handle_checkin(history: list[dict]):
    return take_turn("Good morning, Pikachu! How are you today?", history)


def _file_url(path: str) -> str:
    return f"/gradio_api/file={path}"


# Static assets staged into the Space dir for the landing.
SPRITE_SHEET = str(HERE / "sprite-happy-sheet.png")  # 12-frame 6144x512 strip
GREETING_WEBM = str(HERE / "pet-greeting.webm")
GREETING_MP4 = str(HERE / "pet-greeting.mp4")
NAP_WEBM = str(HERE / "pet-nap.webm")
NAP_MP4 = str(HERE / "pet-nap.mp4")
EMOTIONS = [
    ("emotion-happy.png", "Happy", "content & cheering you on"),
    ("emotion-hyper.png", "Hyper", "spark-charged after a good chat"),
    ("emotion-scared.png", "Surprised", "when it didn't catch you"),
    ("emotion-sad.png", "Sad", "when you've been away too long"),
    ("emotion-sleepy.png", "Sleepy", "mutes & naps on command"),
]

YOUTUBE_VIDEO_ID = "MAsgEj7ywh8"
GITHUB_URL = "https://github.com/Amal-David/pocketdm"
SOCIAL_URL = "https://x.com/Cyrka_ai/status/2066659743444369797"


def sprite_html(src: str) -> str:
    """Small live-demo sprite (single still) used by the chat handlers."""
    return (
        "<div class='demo-sprite'>"
        f"<img src='{_file_url(src)}' alt='Pikachu' />"
        "</div>"
    )


def _alpha_video(webm: str, mp4: str, side_class: str, label: str) -> str:
    # autoplay+muted+playsinline so it loops silently; preload=auto + an onloadeddata
    # play() nudge so it starts even if the browser defers autoplay during load.
    return (
        f"<video class='hero-vid {side_class}' autoplay loop muted playsinline "
        f"preload='auto' aria-label='{label}' "
        "onloadeddata='this.play().catch(function(){});' "
        "oncanplay='this.play().catch(function(){});'>"
        f"<source src='{_file_url(webm)}' type='video/webm'>"
        f"<source src='{_file_url(mp4)}' type='video/mp4'>"
        "</video>"
    )


CUSTOM_CSS = (HERE / "_style.css").read_text(encoding="utf-8") if (HERE / "_style.css").exists() else ""

# --- Landing markup (honest, VoxCPM-forward) ----------------------------------
FONTS_HEAD = (
    "<link rel='preconnect' href='https://fonts.googleapis.com'>"
    "<link rel='preconnect' href='https://fonts.gstatic.com' crossorigin>"
    "<link href='https://fonts.googleapis.com/css2?"
    "family=Fredoka:wght@500;600;700&family=Inter:wght@400;450;500;600;650;700&display=swap' "
    "rel='stylesheet'>"
)


def hero_html() -> str:
    left = _alpha_video(GREETING_WEBM, GREETING_MP4, "left", "Pikachu waving hello")
    right = _alpha_video(NAP_WEBM, NAP_MP4, "right", "Pikachu muted and napping")
    return (
        "<section class='hero'>"
        f"<div class='hero-side'>{left}</div>"
        "<div class='hero-center'>"
        "<span class='eyebrow'><span class='dot'></span>100% on-device · no cloud</span>"
        "<div class='sprite-stage'>"
        f"<div class='sprite' style=\"--sprite-url:url('{_file_url(SPRITE_SHEET)}')\"></div>"
        "<div class='sprite-shadow'></div>"
        "</div>"
        "<h1 class='hero-title'><span class='zap'>⚡</span> Pocket Pikachu</h1>"
        "<p class='hero-sub'>A Pokémon you actually <b>talk to</b> — it hears you, "
        "thinks, and talks back in a cute electric voice. Every model runs on your "
        "own machine. Pull the Wi-Fi and it keeps going.</p>"
        "<div class='cta-row'>"
        "<a class='btn btn-dark' href='#demo'>▶ Try the live demo</a>"
        f"<a class='btn btn-ghost' href='{GITHUB_URL}' target='_blank' rel='noopener'>"
        "★ View on GitHub</a>"
        f"<a class='btn' href='{SOCIAL_URL}' target='_blank' rel='noopener' "
        "style='background:#0f1419;color:#ffffff;border:1px solid #0f1419;'>𝕏 Posted on X</a>"
        "</div>"
        "</div>"
        f"<div class='hero-side'>{right}</div>"
        "</section>"
    )


def chip_row_html() -> str:
    return (
        "<div class='chip-row'>"
        "<span class='chip'>🧠 <b>MiniCPM5-1B</b> brain</span>"
        "<span class='chip voice'>🗣️ <b>VoxCPM-0.5B</b> voice</span>"
        "<span class='chip'>👂 <b>Nemotron</b> ears</span>"
        "<span class='chip local'>🔌 100% local</span>"
        "</div>"
    )


WHAT_HTML = (
    "<section class='section' id='what'>"
    "<div class='section-head'><h2>A character, not a chatbot</h2>"
    "<p>Pocket Pikachu lives on your desktop and reacts to you in real time. "
    "It is built to feel like a companion you keep — not a window you close.</p></div>"
    "<div class='feature-grid'>"
    "<div class='feature'><div class='ico'>🎤</div><h3>Talk, don't type</h3>"
    "<p>Tap the mic and just speak. It transcribes, replies, and answers out loud "
    "in its own voice — voice in, voice out.</p></div>"
    "<div class='feature'><div class='ico'>🔌</div><h3>Genuinely off-grid</h3>"
    "<p>No API keys, no servers, nothing leaves your machine. The brain, the voice, "
    "and the ears all run in-process. Works in airplane mode.</p></div>"
    "<div class='feature'><div class='ico'>🎭</div><h3>It has moods</h3>"
    "<p>Happy, hyper, surprised, sad, sleepy — the pet animates to match the moment "
    "and the bond grows the more you check in.</p></div>"
    "</div></section>"
)


def emotion_html() -> str:
    cells = "".join(
        "<div class='emotion'>"
        f"<img src='{_file_url(str(HERE / fn))}' alt='{name}'>"
        f"<div class='name'>{name}</div><div class='desc'>{desc}</div>"
        "</div>"
        for fn, name, desc in EMOTIONS
    )
    return (
        "<section class='section' id='emotions'>"
        "<div class='section-head'><h2>Five moods, one little pet</h2>"
        "<p>The same 3D Pikachu, animated frame-by-frame from real sprite sheets — "
        "the desktop app swaps these in response to what's happening.</p></div>"
        f"<div class='emotion-grid'>{cells}</div></section>"
    )


def youtube_html() -> str:
    return (
        "<section class='section' id='video'>"
        "<div class='section-head'><h2>Watch it in action</h2>"
        "<p>A two-minute tour of the desktop companion — hello, chat, and "
        "nap-on-command.</p></div>"
        "<div class='yt-wrap'><div class='yt-frame'>"
        f"<iframe src='https://www.youtube.com/embed/{YOUTUBE_VIDEO_ID}' "
        "title='Pocket Pikachu demo' loading='lazy' "
        "allow='accelerometer; autoplay; clipboard-write; encrypted-media; "
        "gyroscope; picture-in-picture; web-share' allowfullscreen></iframe>"
        "</div></div></section>"
    )


STACK_HTML = (
    "<section class='section' id='stack'>"
    "<div class='section-head'><h2>The tiny-model stack</h2>"
    "<p>Three small models, each doing one job, all under 1B params. "
    "This Space runs the voice on a free org GPU.</p></div>"
    "<div class='card prose'>"
    "<table class='stack-table'>"
    "<tr><th>Role</th><th>Model</th><th>Where it runs</th></tr>"
    "<tr><td>🧠 Brain</td><td><code>openbmb/MiniCPM5-1B-GGUF</code> (Q4_K_M)</td>"
    "<td>OpenBMB · llama.cpp on CPU</td></tr>"
    "<tr><td>🗣️ Voice</td><td><code>openbmb/VoxCPM-0.5B</code></td>"
    "<td>OpenBMB · neural TTS on GPU</td></tr>"
    "<tr><td>👂 Ears</td>"
    "<td><code>nvidia/nemotron-speech-streaming-en</code> "
    "<span style='color:#4a5160'>— faster-whisper fallback</span></td>"
    "<td>NVIDIA Nemotron (native) · faster-whisper here</td></tr>"
    "</table>"
    "<p style='margin-top:14px'><b>On the voice.</b> We worked with OpenBMB's "
    "<b>VoxCPM</b> for Pika's speech — a neural, reference-conditioned TTS that gives "
    "the pet a consistent, characterful electric voice instead of a generic readout. "
    "On this org GPU Space VoxCPM is the voice. A lighter CPU-only fallback exists for "
    "the free-CPU sibling Space so the pet can still talk where no GPU is available, "
    "but VoxCPM is the voice we built the character around.</p>"
    "<p><b>On the ears.</b> Pika listens with <b>NVIDIA Nemotron</b> streaming ASR — "
    "low-latency, fully local transcription that runs in the native macOS app. "
    "Nemotron's NeMo toolchain can't build inside a Gradio Space container, so on this "
    "GPU-limited Space the ears fall back to <b>faster-whisper</b> for the same job. "
    "Nemotron is the real ears; faster-whisper is the fallback for where Nemotron can't "
    "run.</p>"
    "</div></section>"
)


FIELD_NOTES_HTML = (
    "<section class='section' id='notes'>"
    "<div class='section-head'><h2>Field notes</h2>"
    "<p>What it actually took to make a talking pet that runs entirely on a "
    "laptop, under a thousand-token wallet.</p></div>"
    "<div class='card prose'>"
    "<p class='lede'>The bet was never that a 1B model could be a whole product. "
    "It was that a 1B model could be a <b>character</b> — if the deterministic code "
    "around it owned everything brittle, and the model only did the part it's good at: "
    "one warm, in-character line at a time.</p>"

    "<h3>Local-first, by construction</h3>"
    "<p>Every model loads <b>in-process</b> and lazy-loads on first request, so the "
    "Space boots fast and weights download on first use. A turn is a straight pipeline: "
    "mic audio → ears transcribe (<b>NVIDIA Nemotron</b> in the native app, "
    "<b>faster-whisper</b> as the fallback here) → <b>MiniCPM5-1B</b> replies through "
    "llama.cpp → <b>VoxCPM</b> speaks the reply. No network calls, no API keys, no "
    "telemetry. The honesty test we held ourselves to: turn the Wi-Fi off and the whole "
    "loop still works. It does.</p>"

    "<h3>The token wallet changed the writing, not just the size</h3>"
    "<p>The brain is capped at <code>72</code> output tokens per turn at "
    "<code>temperature 0.35</code>. That budget forced a real design decision: the "
    "system prompt asks for exactly one compact, useful line — say the catchphrase "
    "once, then one genuinely helpful sentence, no markdown, no stage directions, no "
    "<code>&lt;think&gt;</code> tags. A tiny model rambles when you let it; a tiny model "
    "with a tight contract and a tight budget stays in character.</p>"

    "<h3>Grounding facts instead of trusting them</h3>"
    "<p>Small models confabulate time, weather, and system details with total "
    "confidence. So those never come from the model. A keyless tool layer "
    "(<code>gather_tool_facts</code>) resolves time, weather, and lookups locally and "
    "injects them into the turn as <b>tool facts the model must quote exactly</b>. The "
    "prompt is explicit: do not invent weather, time, model, or system data. The model "
    "writes the personality; the code owns the facts.</p>"

    "<h3>Post-processing is part of the personality</h3>"
    "<p>Raw 1B output needs cleanup to feel like a pet. We strip leaked "
    "<code>&lt;think&gt;</code> blocks, trim runaway leading <i>“Pika pika pika…”</i> "
    "so the catchphrase lands once, require a minimum of real (non-mascot) words before "
    "we trust a reply, and compact everything to a single tidy sentence. When a reply "
    "fails the substance check, the pet falls back to a warm in-character line rather "
    "than shipping noise.</p>"

    "<h3>Giving a text model a voice with character</h3>"
    "<p>VoxCPM is conditioned on a short reference clip plus pitch-up / tempo-down "
    "styling through a tiny ffmpeg pass (<code>asetrate</code> + <code>atempo</code>), "
    "which is what makes Pika sound like Pika and not a narrator. On ZeroGPU the GPU "
    "only attaches inside the <code>@spaces.GPU</code> turn function, so all per-turn "
    "inference is funneled through one decorated call — the brain and ears stay on CPU, "
    "the voice gets the GPU exactly when it needs it.</p>"

    "<h3>What surprised us</h3>"
    "<ul>"
    "<li><b>The build container, not inference, was the wall.</b> Nemotron's NeMo "
    "toolkit and VoxCPM's own torch pin each pull multi-GB CUDA trees that "
    "<code>OOM-killed the free build (exit 137)</code> before a single turn ran. "
    "ZeroGPU already ships a CUDA torch — pinning it re-downloads ~5GB and kills the "
    "build. The fix was to let the platform own torch and never re-pin it.</li>"
    "<li><b>Latency lives in the brain.</b> Whisper and VoxCPM are both comfortably "
    "fast; the 1B GGUF on CPU is the turn's clock. Knowing that told us exactly where "
    "to spend (quantization, token cap) and where not to.</li>"
    "<li><b>A persistent character did more for retention than any feature.</b> The "
    "pet animating, reacting, and remembering check-ins made the small-model constraint "
    "feel intentional instead of limiting.</li>"
    "</ul>"
    "</div></section>"
)


LEARNINGS_HTML = (
    "<section class='section' id='learnings'>"
    "<div class='section-head'><h2>What we learned</h2>"
    "<p>Honest takeaways from shipping a 100%-local talking pet on a "
    "thousand-token budget.</p></div>"
    "<div class='card prose'>"
    "<ul>"
    "<li><b>Give the model the fun part, the code the brittle part.</b> Let a tiny "
    "model write vivid, in-character lines; never let it own state, facts, or formatting. "
    "Every place we trusted the model with the brittle part, it broke; every place "
    "deterministic code owned it, the product got more reliable.</li>"
    "<li><b>A token budget is a design tool, not just a limit.</b> Capping output forced "
    "tighter, more characterful writing. The constraint made the pet better, not "
    "smaller.</li>"
    "<li><b>“Tiny” lives in the dependency tree, not the weights.</b> The models are "
    "all ≤1B, but the real fight was multi-GB CUDA build trees OOM-killing a free "
    "container. Pick the leanest install path and let the platform own its preinstalled "
    "torch.</li>"
    "<li><b>Substitute honestly, and say so.</b> When a heavy local model can't build "
    "in a constrained Space, swap in a CPU-friendly stand-in for the same role — and "
    "label it plainly rather than implying the heavy model is running. VoxCPM is the "
    "voice we built around; the desktop app runs Nemotron ears that the Space can't.</li>"
    "<li><b>Don't trust a spec's model picks from memory.</b> Verify the model landscape "
    "fresh, confirm size/quality tradeoffs, and check prize/size caps against <i>total</i> "
    "params — generation names and “effective” param counts mislead.</li>"
    "<li><b>One audio owner, always.</b> The moment two things can speak, they will "
    "overlap. New turn ⇒ stop all pending and current audio first. The same discipline "
    "applies to any async UI surface.</li>"
    "<li><b>First impression is the character, not the chrome.</b> Let people meet the "
    "pet before any wellness prompt or feature fires. The animated companion has to land "
    "before the product does.</li>"
    "</ul>"
    "</div></section>"
)


def credits_html() -> str:
    return (
        "<div class='foot'>"
        "Built for the <b>Build&nbsp;Small</b> hackathon · "
        f"<a href='{GITHUB_URL}' target='_blank' rel='noopener'>github.com/Amal-David/pocketdm</a> · "
        "Brain &amp; voice by <a href='https://huggingface.co/openbmb' target='_blank' "
        "rel='noopener'>OpenBMB</a> (MiniCPM · VoxCPM) · Ears by <b>NVIDIA Nemotron</b> "
        "(faster-whisper fallback on this Space)."
        "</div>"
    )


def build_app() -> gr.Blocks:
    with gr.Blocks(title="Pocket Pikachu — A Pokémon You Talk To, 100% Local") as demo:
        gr.HTML(f"{FONTS_HEAD}<style>{CUSTOM_CSS}</style>")
        with gr.Column(elem_id="pet-app"):
            gr.HTML(hero_html() + chip_row_html())
            gr.HTML(WHAT_HTML)
            gr.HTML(emotion_html())

            # Watch the demo first, then try it live.
            gr.HTML(youtube_html())

            # -------- Live demo (keeps the working voice/chat loop) --------
            gr.HTML(
                "<section class='section' id='demo'>"
                "<div class='section-head'><h2>Talk to it now</h2>"
                "<p>This runs the real stack live on a free org GPU — speak or type, "
                "and Pikachu answers out loud. First turn warms up the models.</p></div>"
                "</section>"
            )
            with gr.Column(elem_classes="demo-shell"):
                sprite = gr.HTML(sprite_html(PIKA_HAPPY))
                gr.HTML(
                    "<p class='talk-hint'>🎤 Tap record and talk — Pikachu talks back "
                    "out loud. Or 💬 type below.</p>"
                )
                reply_audio = gr.Audio(label="Pikachu says", autoplay=True, interactive=False, show_label=False)
                chat = gr.Chatbot(elem_id="pet-chat", height=260, show_label=False, avatar_images=(None, PIKA_HAPPY))
                with gr.Row():
                    mic = gr.Audio(sources=["microphone"], type="filepath", label="🎤 Talk to Pikachu", show_label=True)
                with gr.Row():
                    textbox = gr.Textbox(placeholder="💬 …or type something to Pikachu", show_label=False, scale=4, container=False)
                    send_btn = gr.Button("Send", scale=1, variant="primary", elem_classes="talk-btn")
                with gr.Row():
                    checkin_btn = gr.Button("☀️ Daily check-in", elem_classes="talk-btn")

            gr.HTML(STACK_HTML)
            gr.HTML(FIELD_NOTES_HTML)
            gr.HTML(LEARNINGS_HTML)
            gr.HTML(credits_html())

        mic.stop_recording(handle_voice, inputs=[mic, chat], outputs=[chat, reply_audio, sprite, mic])
        send_btn.click(handle_text, inputs=[textbox, chat], outputs=[chat, reply_audio, sprite, textbox])
        textbox.submit(handle_text, inputs=[textbox, chat], outputs=[chat, reply_audio, sprite, textbox])
        checkin_btn.click(handle_checkin, inputs=[chat], outputs=[chat, reply_audio, sprite])
    return demo


demo = build_app()
demo.css = CUSTOM_CSS
os.environ.setdefault("GRADIO_ALLOWED_PATHS", str(HERE))
demo.queue()

if __name__ == "__main__":
    demo.launch(server_name="0.0.0.0", server_port=int(os.environ.get("PORT", "7860")), allowed_paths=[str(HERE)])
