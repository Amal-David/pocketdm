from __future__ import annotations

import importlib.util
import os
from pathlib import Path
from types import SimpleNamespace
from types import ModuleType


ROOT = Path(__file__).resolve().parents[1]
SCRIPTS = ROOT / "macos/PocketDMCompanion/scripts"


def _load_script(name: str) -> ModuleType:
    path = SCRIPTS / name
    spec = importlib.util.spec_from_file_location(path.stem, path)
    assert spec is not None
    assert spec.loader is not None
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def test_local_llm_status_fails_when_pid_is_alive_but_models_endpoint_is_dead(tmp_path, capsys) -> None:
    module = _load_script("local_llm_service.py")
    module.PID_FILE = tmp_path / "llm.pid"
    module.PID_FILE.write_text(f"{os.getpid()}\n")
    module.fetch_text = lambda _url: None

    assert module.status_service() == 1
    output = capsys.readouterr().out
    assert "running=true" in output
    assert "healthy=false" in output
    assert "models=-" in output


def test_health_sidecar_status_fails_when_pid_is_alive_but_health_endpoint_is_dead(tmp_path, capsys) -> None:
    for script_name in [
        "pika_stt_service.py",
        "nemotron_asr_service.py",
        "pika_tts_service.py",
    ]:
        module = _load_script(script_name)
        module.PID_FILE = tmp_path / f"{script_name}.pid"
        module.PID_FILE.write_text(f"{os.getpid()}\n")
        module.fetch_health = lambda _url: None

        assert module.status_service() == 1
        output = capsys.readouterr().out
        assert "running=true" in output
        assert "healthy=false" in output
        assert "health=-" in output


def test_sidecar_status_succeeds_only_when_endpoint_is_healthy(tmp_path, capsys) -> None:
    module = _load_script("pika_tts_service.py")
    module.PID_FILE = tmp_path / "tts.pid"
    module.PID_FILE.write_text(f"{os.getpid()}\n")
    module.fetch_health = lambda _url: '{"status":"ok"}'

    assert module.status_service() == 0
    output = capsys.readouterr().out
    assert "running=true" in output
    assert "healthy=true" in output


def test_local_llm_start_fails_loudly_for_alive_pid_with_dead_models_endpoint(tmp_path, capsys) -> None:
    module = _load_script("local_llm_service.py")
    module.PID_FILE = tmp_path / "llm.pid"
    module.PID_FILE.write_text(f"{os.getpid()}\n")
    module.fetch_text = lambda _url: None
    args = SimpleNamespace(
        host="127.0.0.1",
        port="8081",
        model="",
        model_alias="",
        download_minicpm5=False,
        download_qwen35_2b=False,
        download_qwen35_0_8b=False,
        download_phi4_mini=False,
        timeout=0.01,
    )

    assert module.start_service(args) == 1
    output = capsys.readouterr()
    assert "is running but http://127.0.0.1:8081/v1/models is unhealthy" in output.err


def test_health_sidecar_start_fails_loudly_for_alive_pid_with_dead_health_endpoint(tmp_path, capsys) -> None:
    for script_name in [
        "pika_stt_service.py",
        "nemotron_asr_service.py",
        "pika_tts_service.py",
    ]:
        module = _load_script(script_name)
        module.PID_FILE = tmp_path / f"{script_name}.pid"
        module.PID_FILE.write_text(f"{os.getpid()}\n")
        module.fetch_health = lambda _url: None
        args = SimpleNamespace(
            backend="stub",
            host="127.0.0.1",
            port="9999",
            warmup=False,
            model="",
            chunk_ms="",
            fallback_backend="pika-stt",
            fallback_url="",
            timeout=0.01,
        )

        assert module.start_service(args) == 1
        output = capsys.readouterr()
        assert "is running but http://127.0.0.1:9999/health is unhealthy" in output.err
