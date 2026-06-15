from __future__ import annotations

import argparse
import os
import signal
import subprocess
import sys
import time
from pathlib import Path
from urllib.error import URLError
from urllib.request import urlopen


SCRIPT_DIR = Path(__file__).resolve().parent
REPO_ROOT = SCRIPT_DIR.parents[2]
START_SCRIPT = SCRIPT_DIR / "start_nemotron_asr.sh"
PID_FILE = Path(os.environ.get("POCKETDM_NEMOTRON_ASR_PID", "/tmp/pocketdm-nemotron-asr.pid"))
LOG_FILE = Path(os.environ.get("POCKETDM_NEMOTRON_ASR_LOG", "/tmp/pocketdm-nemotron-asr.log"))
DEFAULT_HOST = os.environ.get("POCKETDM_NEMOTRON_ASR_HOST", "127.0.0.1")
DEFAULT_PORT = os.environ.get("POCKETDM_NEMOTRON_ASR_PORT", "7863")
DEFAULT_URL = f"http://{DEFAULT_HOST}:{DEFAULT_PORT}/health"


def main() -> int:
    parser = argparse.ArgumentParser(description="Manage the opt-in Nemotron streaming ASR sidecar.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    start = subparsers.add_parser("start", help="Start the Nemotron ASR sidecar in the background.")
    start.add_argument("--backend", choices=("auto", "local-nemotron", "stub", "riva-nim", "pika-stt", "nemo-local"), default="auto")
    start.add_argument("--fallback-backend", choices=("pika-stt", "stub", "none"), default=os.environ.get("POCKETDM_NEMOTRON_ASR_FALLBACK_BACKEND", "pika-stt"))
    start.add_argument("--fallback-url", default=os.environ.get("POCKETDM_NEMOTRON_ASR_FALLBACK_URL", ""), help="Fallback Pika STT base URL, normally http://127.0.0.1:7862.")
    start.add_argument("--model", default=os.environ.get("POCKETDM_NEMOTRON_ASR_MODEL", ""), help="Nemotron ASR model id to report from /health.")
    start.add_argument("--chunk-ms", default=os.environ.get("POCKETDM_NEMOTRON_ASR_CHUNK_MS", ""), help="Streaming chunk size in milliseconds.")
    start.add_argument("--host", default=os.environ.get("POCKETDM_NEMOTRON_ASR_HOST", "127.0.0.1"))
    start.add_argument("--port", default=os.environ.get("POCKETDM_NEMOTRON_ASR_PORT", "7863"))
    start.add_argument("--warmup", action="store_true")
    start.add_argument("--timeout", type=float, default=45)

    subparsers.add_parser("stop", help="Stop the Nemotron ASR sidecar.")
    subparsers.add_parser("status", help="Print PID and health status.")
    subparsers.add_parser("log", help="Print the tail of the sidecar log.")

    args = parser.parse_args()
    if args.command == "start":
        return start_service(args)
    if args.command == "stop":
        return stop_service()
    if args.command == "status":
        return status_service()
    if args.command == "log":
        return log_service()
    return 64


def start_service(args: argparse.Namespace) -> int:
    pid = read_pid()
    if is_running(pid):
        health_url = f"http://{args.host}:{args.port}/health"
        if fetch_health(health_url):
            print(f"Nemotron ASR already running: pid {pid}")
            return 0
        print(
            f"Nemotron ASR pid {pid} is running but {health_url} is unhealthy; "
            "run stop before restarting.",
            file=sys.stderr,
        )
        return 1

    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    command = [
        str(START_SCRIPT),
        "--backend",
        args.backend,
        "--fallback-backend",
        args.fallback_backend,
        "--host",
        args.host,
        "--port",
        str(args.port),
    ]
    if args.fallback_url:
        command.extend(["--fallback-url", args.fallback_url])
    if args.warmup:
        command.append("--warmup")
    if args.model:
        command.extend(["--model", args.model])
    if args.chunk_ms:
        command.extend(["--chunk-ms", str(args.chunk_ms)])

    with LOG_FILE.open("ab", buffering=0) as log:
        process = subprocess.Popen(
            command,
            cwd=REPO_ROOT,
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=subprocess.STDOUT,
            start_new_session=True,
            env=os.environ.copy(),
        )
    PID_FILE.write_text(f"{process.pid}\n")
    print(f"Started Nemotron ASR pid {process.pid}; log {LOG_FILE}")

    health_url = f"http://{args.host}:{args.port}/health"
    if wait_for_health(health_url, process=process, timeout=args.timeout):
        print(health_url)
        return 0
    if process.poll() is not None:
        print(f"Nemotron ASR exited before becoming healthy; see {LOG_FILE}", file=sys.stderr)
        return 1
    print(f"Nemotron ASR did not become healthy before {args.timeout:.0f}s; see {LOG_FILE}", file=sys.stderr)
    return 1


def stop_service() -> int:
    pid = read_pid()
    if not is_running(pid):
        if PID_FILE.exists():
            PID_FILE.unlink()
        print("Nemotron ASR is not running")
        return 0

    assert pid is not None
    os.kill(pid, signal.SIGTERM)
    deadline = time.monotonic() + 15
    while time.monotonic() < deadline:
        if not is_running(pid):
            break
        time.sleep(0.25)
    if is_running(pid):
        os.kill(pid, signal.SIGKILL)

    if PID_FILE.exists():
        PID_FILE.unlink()
    print(f"Stopped Nemotron ASR pid {pid}")
    return 0


def status_service() -> int:
    pid = read_pid()
    running = is_running(pid)
    health = fetch_health(DEFAULT_URL) if running else None
    healthy = bool(running and health)
    print(
        f"pid={pid or '-'} running={str(running).lower()} "
        f"healthy={str(healthy).lower()} health={health or '-'}"
    )
    return 0 if healthy else 1


def log_service() -> int:
    if not LOG_FILE.exists():
        print(f"No log at {LOG_FILE}")
        return 1
    lines = LOG_FILE.read_text(errors="replace").splitlines()[-80:]
    print("\n".join(lines))
    return 0


def wait_for_health(url: str, *, process: subprocess.Popen[bytes] | None, timeout: float) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if fetch_health(url):
            return True
        if process is not None and process.poll() is not None:
            return False
        time.sleep(0.8)
    return False


def fetch_health(url: str) -> str | None:
    try:
        with urlopen(url, timeout=2) as response:
            return response.read().decode("utf-8", errors="replace")
    except URLError:
        return None
    except TimeoutError:
        return None


def read_pid() -> int | None:
    try:
        return int(PID_FILE.read_text().strip())
    except (FileNotFoundError, ValueError):
        return None


def is_running(pid: int | None) -> bool:
    if pid is None:
        return False
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False
    except PermissionError:
        return True


if __name__ == "__main__":
    raise SystemExit(main())
