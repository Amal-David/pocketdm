from __future__ import annotations

import atexit
import json
import os
import subprocess
import time
from dataclasses import dataclass
from functools import lru_cache
from pathlib import Path
from urllib import error as urlerror
from urllib import request as urlrequest

from engine.generate import TurnBackend

DEFAULT_GRAMMAR_PATH = Path(__file__).resolve().parents[1] / "engine" / "grammar.gbnf"


@dataclass(frozen=True)
class LlamaBackendConfig:
    model_path: Path
    grammar_path: Path = DEFAULT_GRAMMAR_PATH
    n_ctx: int = 2048
    n_threads: int = 2
    max_tokens: int = 340
    use_chat_template: bool = False


@dataclass(frozen=True)
class LlamaServerConfig:
    base_url: str
    grammar_path: Path = DEFAULT_GRAMMAR_PATH
    model: str = "pocketdm"
    max_tokens: int = 340
    timeout_seconds: float = 120.0


@dataclass(frozen=True)
class ManagedLlamaServerConfig:
    binary_path: Path
    model_path: Path
    base_url: str
    host: str
    port: int
    draft_model_path: Path | None = None
    grammar_path: Path = DEFAULT_GRAMMAR_PATH
    model: str = "pocketdm"
    n_ctx: int = 2048
    n_threads: int = 8
    n_gpu_layers: int = 999
    flash_attention: bool = True
    spec_draft_n_max: int = 1
    spec_draft_gpu_layers: int = 999
    reasoning: str | None = None
    start_timeout_seconds: float = 120.0
    request_timeout_seconds: float = 120.0
    log_path: Path = Path("/tmp/pocketdm-llama-server.log")


class LlamaCppBackend:
    def __init__(self, config: LlamaBackendConfig) -> None:
        self.config = config
        self.model_label = _model_label(config.model_path)

    def complete(self, messages: list[dict[str, str]], *, temperature: float) -> str:
        llm, grammar = _load_llama(
            str(self.config.model_path),
            str(self.config.grammar_path),
            self.config.n_ctx,
            self.config.n_threads,
        )
        if self.config.use_chat_template:
            response = llm.create_chat_completion(
                messages=messages,
                max_tokens=self.config.max_tokens,
                temperature=temperature,
                grammar=grammar,
                stop=["<turn|>", "<|im_end|>"],
            )
            return str(response["choices"][0]["message"]["content"]).strip()

        response = llm(
            render_prompt(messages),
            max_tokens=self.config.max_tokens,
            temperature=temperature,
            grammar=grammar,
            stop=["<|im_end|>"],
        )
        return str(response["choices"][0]["text"]).strip()


class LlamaServerBackend:
    def __init__(self, config: LlamaServerConfig) -> None:
        self.config = config
        self.model_label = os.environ.get("POCKETDM_LLAMA_SERVER_LABEL", "llama.cpp server")
        self._grammar = config.grammar_path.read_text()

    def complete(self, messages: list[dict[str, str]], *, temperature: float) -> str:
        payload = {
            "model": self.config.model,
            "messages": messages,
            "max_tokens": self.config.max_tokens,
            "temperature": temperature,
            "grammar": self._grammar,
            "stop": ["<turn|>", "<|im_end|>"],
        }
        request = urlrequest.Request(
            f"{self.config.base_url.rstrip('/')}/v1/chat/completions",
            data=json.dumps(payload).encode("utf-8"),
            headers={"content-type": "application/json"},
        )
        try:
            with urlrequest.urlopen(request, timeout=self.config.timeout_seconds) as response:
                result = json.loads(response.read().decode("utf-8"))
        except urlerror.HTTPError as exc:
            detail = exc.read().decode("utf-8", errors="replace")
            raise RuntimeError(f"llama.cpp server error {exc.code}: {detail}") from exc
        except urlerror.URLError as exc:
            raise RuntimeError(f"llama.cpp server unavailable: {exc.reason}") from exc

        return str(result["choices"][0]["message"]["content"]).strip()


class ManagedLlamaServerBackend(LlamaServerBackend):
    def __init__(self, config: ManagedLlamaServerConfig) -> None:
        self.managed_config = config
        self.process = _ensure_llama_server(config)
        super().__init__(
            LlamaServerConfig(
                base_url=config.base_url,
                grammar_path=config.grammar_path,
                model=config.model,
                timeout_seconds=config.request_timeout_seconds,
            )
        )
        self.model_label = os.environ.get(
            "POCKETDM_LLAMA_SERVER_LABEL",
            _managed_model_label(config),
        )


def configured_backend() -> TurnBackend | None:
    raw_server_bin = os.environ.get("POCKETDM_LLAMA_SERVER_BIN")
    raw_server_url = os.environ.get("POCKETDM_LLAMA_SERVER_URL")
    if raw_server_bin:
        return ManagedLlamaServerBackend(_managed_server_config(raw_server_bin, raw_server_url))

    if raw_server_url:
        grammar_path = Path(os.environ.get("POCKETDM_GRAMMAR", str(DEFAULT_GRAMMAR_PATH)))
        return LlamaServerBackend(
            LlamaServerConfig(
                base_url=raw_server_url,
                grammar_path=grammar_path,
                model=os.environ.get("POCKETDM_LLAMA_SERVER_MODEL", "pocketdm"),
            )
        )

    raw_model_path = os.environ.get("POCKETDM_GGUF") or os.environ.get("POCKETDM_GGUF_MODEL")
    if not raw_model_path:
        return None
    model_path = Path(raw_model_path)
    if not model_path.exists():
        return None
    grammar_path = Path(os.environ.get("POCKETDM_GRAMMAR", str(DEFAULT_GRAMMAR_PATH)))
    n_threads = int(os.environ.get("POCKETDM_LLAMA_THREADS", "2"))
    chat_template = _use_chat_template(model_path)
    return LlamaCppBackend(
        LlamaBackendConfig(
            model_path=model_path,
            grammar_path=grammar_path,
            n_threads=n_threads,
            use_chat_template=chat_template,
        )
    )


def _managed_server_config(
    raw_server_bin: str,
    raw_server_url: str | None,
) -> ManagedLlamaServerConfig:
    binary_path = Path(raw_server_bin).expanduser()
    if not binary_path.exists():
        raise RuntimeError(f"llama.cpp server binary not found: {binary_path}")

    raw_model_path = os.environ.get("POCKETDM_GGUF") or os.environ.get("POCKETDM_GGUF_MODEL")
    if not raw_model_path:
        raise RuntimeError("POCKETDM_GGUF is required when POCKETDM_LLAMA_SERVER_BIN is set")
    model_path = Path(raw_model_path).expanduser()
    if not model_path.exists():
        raise RuntimeError(f"GGUF model not found: {model_path}")

    draft_model_path = None
    raw_draft_path = os.environ.get("POCKETDM_LLAMA_DRAFT_GGUF")
    if raw_draft_path:
        draft_model_path = Path(raw_draft_path).expanduser()
        if not draft_model_path.exists():
            raise RuntimeError(f"llama.cpp draft model not found: {draft_model_path}")

    host = os.environ.get("POCKETDM_LLAMA_SERVER_HOST", "127.0.0.1")
    port = int(os.environ.get("POCKETDM_LLAMA_SERVER_PORT", "8081"))
    base_url = raw_server_url or f"http://{host}:{port}"

    return ManagedLlamaServerConfig(
        binary_path=binary_path,
        model_path=model_path,
        base_url=base_url,
        host=host,
        port=port,
        draft_model_path=draft_model_path,
        grammar_path=Path(os.environ.get("POCKETDM_GRAMMAR", str(DEFAULT_GRAMMAR_PATH))),
        model=os.environ.get("POCKETDM_LLAMA_SERVER_MODEL", "pocketdm"),
        n_ctx=int(os.environ.get("POCKETDM_LLAMA_CTX", "2048")),
        n_threads=int(os.environ.get("POCKETDM_LLAMA_THREADS", "8")),
        n_gpu_layers=int(os.environ.get("POCKETDM_LLAMA_GPU_LAYERS", "999")),
        flash_attention=_env_flag("POCKETDM_LLAMA_FLASH_ATTN", default=True),
        spec_draft_n_max=int(os.environ.get("POCKETDM_LLAMA_SPEC_DRAFT_N", "1")),
        spec_draft_gpu_layers=int(os.environ.get("POCKETDM_LLAMA_SPEC_DRAFT_GPU_LAYERS", "999")),
        reasoning=os.environ.get("POCKETDM_LLAMA_REASONING"),
        start_timeout_seconds=float(os.environ.get("POCKETDM_LLAMA_SERVER_START_TIMEOUT", "120")),
        request_timeout_seconds=float(os.environ.get("POCKETDM_LLAMA_SERVER_TIMEOUT", "120")),
        log_path=Path(
            os.environ.get("POCKETDM_LLAMA_SERVER_LOG", "/tmp/pocketdm-llama-server.log")
        ),
    )


def _ensure_llama_server(config: ManagedLlamaServerConfig) -> subprocess.Popen[bytes] | None:
    if _llama_server_ready(config.base_url):
        _assert_existing_llama_server_compatible(config)
        return None

    config.log_path.parent.mkdir(parents=True, exist_ok=True)
    log_handle = config.log_path.open("ab")
    process = subprocess.Popen(
        _llama_server_command(config),
        stdout=log_handle,
        stderr=subprocess.STDOUT,
    )
    _register_process_cleanup(process, log_handle)

    deadline = time.monotonic() + config.start_timeout_seconds
    while time.monotonic() < deadline:
        if _llama_server_ready(config.base_url):
            return process
        if process.poll() is not None:
            raise RuntimeError(
                "llama.cpp server exited before becoming ready; "
                f"see {config.log_path}"
            )
        time.sleep(0.5)

    process.terminate()
    raise RuntimeError(
        "llama.cpp server did not become ready before timeout; "
        f"see {config.log_path}"
    )


def _llama_server_command(config: ManagedLlamaServerConfig) -> list[str]:
    command = [
        str(config.binary_path),
        "--model",
        str(config.model_path),
        "--ctx-size",
        str(config.n_ctx),
        "--threads",
        str(config.n_threads),
        "-ngl",
        str(config.n_gpu_layers),
        "-fa",
        "on" if config.flash_attention else "off",
        "--host",
        config.host,
        "--port",
        str(config.port),
        "--no-ui",
    ]
    if config.reasoning:
        command.extend(["--reasoning", config.reasoning])
    if config.draft_model_path is not None:
        command.extend(
            [
                "--model-draft",
                str(config.draft_model_path),
                "--spec-type",
                "draft-mtp",
                "--spec-draft-n-max",
                str(config.spec_draft_n_max),
                "--spec-draft-ngl",
                str(config.spec_draft_gpu_layers),
            ]
        )
    return command


def _llama_server_ready(base_url: str) -> bool:
    try:
        with urlrequest.urlopen(f"{base_url.rstrip('/')}/health", timeout=1.0) as response:
            return 200 <= int(response.status) < 300
    except (OSError, urlerror.URLError):
        return False


def _assert_existing_llama_server_compatible(config: ManagedLlamaServerConfig) -> None:
    model_ids = _llama_server_model_ids(config.base_url)
    if not model_ids:
        raise RuntimeError(
            "llama.cpp server is already running at "
            f"{config.base_url}, but PocketDM could not confirm its model via /v1/models. "
            "Stop the server or choose a different POCKETDM_LLAMA_SERVER_PORT."
        )

    if not any(_model_id_matches(model_id, config.model_path) for model_id in model_ids):
        raise RuntimeError(
            "llama.cpp server is already running at "
            f"{config.base_url}, but it is not serving {config.model_path.name}. "
            f"Reported models: {', '.join(model_ids)}. Stop the server or choose a "
            "different POCKETDM_LLAMA_SERVER_PORT."
        )

    if config.draft_model_path is None or _env_flag(
        "POCKETDM_LLAMA_SERVER_ALLOW_EXISTING",
        default=False,
    ):
        return

    commands = _llama_server_process_commands()
    if any(_llama_server_process_command_matches(command, config) for command in commands):
        return

    raise RuntimeError(
        "llama.cpp server is already running at "
        f"{config.base_url} with the target model, but PocketDM cannot verify that "
        f"it was started with MTP drafter {config.draft_model_path.name}. Stop the "
        "server so PocketDM can start a managed MTP process, or set "
        "POCKETDM_LLAMA_SERVER_ALLOW_EXISTING=1 after verifying the server command."
    )


def _llama_server_model_ids(base_url: str) -> list[str]:
    try:
        with urlrequest.urlopen(f"{base_url.rstrip('/')}/v1/models", timeout=2.0) as response:
            payload = json.loads(response.read().decode("utf-8"))
    except (OSError, json.JSONDecodeError, urlerror.URLError):
        return []

    data = payload.get("data") if isinstance(payload, dict) else None
    if not isinstance(data, list):
        return []
    model_ids: list[str] = []
    for item in data:
        if isinstance(item, dict) and isinstance(item.get("id"), str):
            model_ids.append(item["id"])
    return model_ids


def _model_id_matches(model_id: str, model_path: Path) -> bool:
    return model_id == model_path.name or model_id == str(model_path) or model_id.endswith(
        f"/{model_path.name}"
    )


def _llama_server_process_commands() -> list[str]:
    try:
        completed = subprocess.run(
            ["ps", "-axo", "command="],
            check=False,
            capture_output=True,
            text=True,
            timeout=2.0,
        )
    except (OSError, subprocess.TimeoutExpired):
        return []
    if completed.returncode != 0:
        return []
    return [line for line in completed.stdout.splitlines() if "llama-server" in line]


def _llama_server_process_command_matches(
    command: str,
    config: ManagedLlamaServerConfig,
) -> bool:
    if config.draft_model_path is None:
        return True
    port_matches = f"--port {config.port}" in command or f"--port={config.port}" in command
    model_matches = str(config.model_path) in command or config.model_path.name in command
    draft_matches = (
        str(config.draft_model_path) in command or config.draft_model_path.name in command
    )
    return (
        "llama-server" in command
        and port_matches
        and model_matches
        and "--model-draft" in command
        and draft_matches
        and "draft-mtp" in command
    )


def _register_process_cleanup(
    process: subprocess.Popen[bytes],
    log_handle: object,
) -> None:
    def cleanup() -> None:
        if process.poll() is None:
            process.terminate()
        close = getattr(log_handle, "close", None)
        if close is not None:
            close()

    atexit.register(cleanup)


def _managed_model_label(config: ManagedLlamaServerConfig) -> str:
    label = _model_label(config.model_path)
    if config.draft_model_path is None:
        return f"{label} llama.cpp server"
    return f"{label} MTP llama.cpp server"


def _env_flag(name: str, *, default: bool) -> bool:
    raw = os.environ.get(name)
    if raw is None:
        return default
    return raw.casefold() in {"1", "true", "yes", "on"}


def render_prompt(messages: list[dict[str, str]]) -> str:
    rendered = "\n".join(
        f"<|im_start|>{message['role']}\n{message['content']}<|im_end|>"
        for message in messages
    )
    return f"{rendered}\n<|im_start|>assistant\n"


def _use_chat_template(model_path: Path) -> bool:
    raw = os.environ.get("POCKETDM_CHAT_TEMPLATE", "auto").casefold()
    if raw in {"1", "true", "yes", "on"}:
        return True
    if raw in {"0", "false", "no", "off"}:
        return False
    name = model_path.name.casefold()
    return "gemma" in name


def _model_label(model_path: Path) -> str:
    name = model_path.name.casefold()
    if "gemma-4-e2b" in name and "bf16" in name:
        return "Gemma 4 E2B BF16 GGUF"
    if "gemma-4-e2b" in name and "q6_k" in name:
        return "Gemma 4 E2B Q6_K GGUF"
    if "gemma-4-e2b" in name and "q5_k_m" in name:
        return "Gemma 4 E2B Q5_K_M GGUF"
    if "gemma-4-e2b" in name and "q4_k_m" in name:
        return "Gemma 4 E2B Q4_K_M GGUF"
    if "gemma-4-e2b" in name:
        return "Gemma 4 E2B GGUF"
    if "gemma" in name:
        return "Gemma GGUF"
    if "2b-v1-lora" in str(model_path).casefold() or "qwen" in name:
        return "2B Q4_K_M GGUF"
    return model_path.stem


@lru_cache(maxsize=2)
def _load_llama(
    model_path: str,
    grammar_path: str,
    n_ctx: int,
    n_threads: int,
) -> tuple[object, object]:
    from llama_cpp import Llama, LlamaGrammar

    return (
        Llama(
            model_path=model_path,
            n_ctx=n_ctx,
            n_threads=n_threads,
            verbose=False,
        ),
        LlamaGrammar.from_file(grammar_path),
    )
