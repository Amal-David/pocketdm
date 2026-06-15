from __future__ import annotations

import argparse
import io
import json
import statistics
import time
import wave
from pathlib import Path
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen


def main() -> int:
    parser = argparse.ArgumentParser(description="Benchmark the local Nemotron ASR bridge.")
    parser.add_argument("--url", default="http://127.0.0.1:7863/transcribe-file")
    parser.add_argument("--audio", type=Path, help="WAV file to transcribe. Defaults to a 1s silent 16kHz WAV plumbing check.")
    parser.add_argument("--repeat", type=int, default=3)
    args = parser.parse_args()

    audio = args.audio.read_bytes() if args.audio else silent_wav()
    audio_ms = wav_duration_ms(audio)
    rows: list[dict[str, object]] = []
    for index in range(max(1, args.repeat)):
        started = time.perf_counter()
        try:
            payload = post_audio(args.url, audio)
        except (HTTPError, URLError, TimeoutError) as exc:
            print(json.dumps({"ok": False, "error": str(exc), "attempt": index + 1}, indent=2))
            return 1
        wall_ms = (time.perf_counter() - started) * 1000
        metrics = payload.get("metrics", {}) if isinstance(payload, dict) else {}
        rows.append(
            {
                "attempt": index + 1,
                "backend": payload.get("backend"),
                "fallback_used": payload.get("fallback_used"),
                "streaming_mode": payload.get("streaming_mode"),
                "audio_ms": metrics.get("audio_ms", audio_ms),
                "server_asr_ms": metrics.get("asr_request_ms"),
                "wall_ms": round(wall_ms, 3),
                "rtfx": metrics.get("rtfx"),
                "text_preview": str(payload.get("text", ""))[:80],
            }
        )

    wall_values = [float(row["wall_ms"]) for row in rows]
    summary = {
        "ok": True,
        "url": args.url,
        "repeat": len(rows),
        "audio_ms": audio_ms,
        "wall_ms_avg": round(statistics.mean(wall_values), 3),
        "wall_ms_p50": round(statistics.median(wall_values), 3),
        "wall_ms_min": round(min(wall_values), 3),
        "wall_ms_max": round(max(wall_values), 3),
        "rows": rows,
    }
    print(json.dumps(summary, indent=2))
    return 0


def post_audio(url: str, audio: bytes) -> dict[str, object]:
    boundary = "PocketDMNemotronBenchmark"
    body = (
        f"--{boundary}\r\n"
        'Content-Disposition: form-data; name="audio"; filename="benchmark.wav"\r\n'
        "Content-Type: audio/wav\r\n\r\n"
    ).encode("utf-8") + audio + f"\r\n--{boundary}--\r\n".encode("utf-8")
    request = Request(
        url,
        data=body,
        method="POST",
        headers={"Content-Type": f"multipart/form-data; boundary={boundary}"},
    )
    with urlopen(request, timeout=120) as response:
        return json.loads(response.read().decode("utf-8"))


def silent_wav() -> bytes:
    out = io.BytesIO()
    with wave.open(out, "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(16_000)
        wav.writeframes(b"\x00\x00" * 16_000)
    return out.getvalue()


def wav_duration_ms(audio: bytes) -> float | None:
    try:
        with wave.open(io.BytesIO(audio), "rb") as wav:
            return round(wav.getnframes() / wav.getframerate() * 1000, 3)
    except Exception:
        return None


if __name__ == "__main__":
    raise SystemExit(main())
