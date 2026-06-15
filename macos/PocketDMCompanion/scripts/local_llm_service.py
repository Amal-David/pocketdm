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
START_SCRIPT = SCRIPT_DIR / "start_local_llm.sh"
PID_FILE = Path(os.environ.get("POCKETDM_LOCAL_LLM_PID", "/tmp/pocketdm-local-llm.pid"))
LOG_FILE = Path(os.environ.get("POCKETDM_LOCAL_LLM_LOG", "/tmp/pocketdm-local-llm.log"))
DEFAULT_HOST = os.environ.get("POCKETDM_LLAMA_SERVER_HOST", "127.0.0.1")
DEFAULT_PORT = os.environ.get("POCKETDM_LLAMA_SERVER_PORT", "8081")
DEFAULT_MODELS_URL = f"http://{DEFAULT_HOST}:{DEFAULT_PORT}/v1/models"


def main() -> int:
    parser = argparse.ArgumentParser(description="Manage the local companion LLM server.")
    subparsers = parser.add_subparsers(dest="command", required=True)

    start = subparsers.add_parser("start", help="Start the local LLM server in the background.")
    start.add_argument("--model", default=os.environ.get("POCKETDM_GGUF", ""), help="GGUF path to serve.")
    start.add_argument("--model-alias", default=os.environ.get("POCKETDM_LLAMA_SERVER_MODEL", ""), help="OpenAI-compatible model id to advertise.")
    start.add_argument("--host", default=os.environ.get("POCKETDM_LLAMA_SERVER_HOST", "127.0.0.1"))
    start.add_argument("--port", default=os.environ.get("POCKETDM_LLAMA_SERVER_PORT", "8081"))
    start.add_argument("--download-minicpm5", action="store_true", help="Download the MiniCPM5-1B Q4_K_M GGUF before starting.")
    start.add_argument("--download-qwen35-2b", action="store_true", help="Download the Qwen3.5-2B Q4_K_M fallback before starting.")
    start.add_argument("--download-qwen35-0.8b", action="store_true", help="Download the Qwen3.5-0.8B Q4_K_M speed fallback before starting.")
    start.add_argument("--download-phi4-mini", action="store_true", help="Download the Phi-4-mini Q4_K_M optional fallback before starting.")
    start.add_argument("--timeout", type=float, default=90)

    subparsers.add_parser("stop", help="Stop the local LLM server.")
    subparsers.add_parser("status", help="Print PID and model endpoint status.")
    subparsers.add_parser("log", help="Print the tail of the local LLM log.")

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
        models_url = f"http://{args.host}:{args.port}/v1/models"
        if fetch_text(models_url):
            print(f"Local LLM already running: pid {pid}")
            return 0
        print(
            f"Local LLM pid {pid} is running but {models_url} is unhealthy; "
            "run stop before restarting.",
            file=sys.stderr,
        )
        return 1

    LOG_FILE.parent.mkdir(parents=True, exist_ok=True)
    command = [
        str(START_SCRIPT),
        "--host",
        args.host,
        "--port",
        str(args.port),
    ]
    if args.model:
        command.extend(["--model", args.model])
    if args.model_alias:
        command.extend(["--model-alias", args.model_alias])
    if args.download_minicpm5:
        command.append("--download-minicpm5")
    if args.download_qwen35_2b:
        command.append("--download-qwen35-2b")
    if getattr(args, "download_qwen35_0_8b", False):
        command.append("--download-qwen35-0.8b")
    if args.download_phi4_mini:
        command.append("--download-phi4-mini")

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
    print(f"Started local LLM pid {process.pid}; log {LOG_FILE}")

    models_url = f"http://{args.host}:{args.port}/v1/models"
    if wait_for_models(models_url, process=process, timeout=args.timeout):
        print(models_url)
        return 0
    if process.poll() is not None:
        print(f"Local LLM exited before becoming ready; see {LOG_FILE}", file=sys.stderr)
        return 1
    print(f"Local LLM did not become ready before {args.timeout:.0f}s; see {LOG_FILE}", file=sys.stderr)
    return 1


def stop_service() -> int:
    pid = read_pid()
    if not is_running(pid):
        if PID_FILE.exists():
            PID_FILE.unlink()
        print("Local LLM is not running")
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
    print(f"Stopped local LLM pid {pid}")
    return 0


def status_service() -> int:
    pid = read_pid()
    running = is_running(pid)
    models = fetch_text(DEFAULT_MODELS_URL) if running else None
    healthy = bool(running and models)
    print(
        f"pid={pid or '-'} running={str(running).lower()} "
        f"healthy={str(healthy).lower()} models={models or '-'}"
    )
    return 0 if healthy else 1


def log_service() -> int:
    if not LOG_FILE.exists():
        print(f"No log at {LOG_FILE}")
        return 1
    lines = LOG_FILE.read_text(errors="replace").splitlines()[-80:]
    print("\n".join(lines))
    return 0


def wait_for_models(url: str, *, process: subprocess.Popen[bytes] | None, timeout: float) -> bool:
    deadline = time.monotonic() + timeout
    while time.monotonic() < deadline:
        if fetch_text(url):
            return True
        if process is not None and process.poll() is not None:
            return False
        time.sleep(0.8)
    return False


def fetch_text(url: str) -> str | None:
    try:
        with urlopen(url, timeout=2) as response:
            if 200 <= int(response.status) < 300:
                return response.read().decode("utf-8", errors="replace")
    except URLError:
        return None
    except TimeoutError:
        return None
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
