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
START_SCRIPT = SCRIPT_DIR / "start_pika_stt.sh"
PID_FILE = Path(os.environ.get("POCKETDM_PIKA_STT_PID", "/tmp/pocketdm-pika-stt.pid"))
LOG_FILE = Path(os.environ.get("POCKETDM_PIKA_STT_LOG", "/tmp/pocketdm-pika-stt.log"))
DEFAULT_HOST = os.environ.get("POCKETDM_PIKA_STT_HOST", "127.0.0.1")
DEFAULT_PORT = os.environ.get("POCKETDM_PIKA_STT_PORT", "7862")
DEFAULT_URL = f"http://{DEFAULT_HOST}:{DEFAULT_PORT}/health"


def main() -> int:
    parser = argparse.ArgumentParser(description="Manage the local Pika STT sidecar.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    start = subparsers.add_parser("start", help="Start the Pika STT sidecar in the background.")
    start.add_argument("--backend", choices=("faster-whisper", "stub"), default="faster-whisper")
    start.add_argument("--host", default=os.environ.get("POCKETDM_PIKA_STT_HOST", "127.0.0.1"))
    start.add_argument("--port", default=os.environ.get("POCKETDM_PIKA_STT_PORT", "7862"))
    start.add_argument("--warmup", action="store_true")
    start.add_argument("--timeout", type=float, default=90)

    subparsers.add_parser("stop", help="Stop the Pika STT sidecar.")
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
            print(f"Pika STT already running: pid {pid}")
            return 0
        print(
            f"Pika STT pid {pid} is running but {health_url} is unhealthy; "
            "run stop before restarting.",
            file=sys.stderr,
        )
        return 1

    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    command = [
        str(START_SCRIPT),
        "--backend",
        args.backend,
        "--host",
        args.host,
        "--port",
        str(args.port),
    ]
    if args.warmup:
        command.append("--warmup")

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
    print(f"Started Pika STT pid {process.pid}; log {LOG_FILE}")

    health_url = f"http://{args.host}:{args.port}/health"
    if wait_for_health(health_url, process=process, timeout=args.timeout):
        print(health_url)
        return 0
    if process.poll() is not None:
        print(f"Pika STT exited before becoming healthy; see {LOG_FILE}", file=sys.stderr)
        return 1
    print(f"Pika STT did not become healthy before {args.timeout:.0f}s; see {LOG_FILE}", file=sys.stderr)
    return 1


def stop_service() -> int:
    pid = read_pid()
    if not is_running(pid):
        if PID_FILE.exists():
            PID_FILE.unlink()
        print("Pika STT is not running")
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
    print(f"Stopped Pika STT pid {pid}")
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
