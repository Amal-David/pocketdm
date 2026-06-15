from __future__ import annotations

import argparse
import hashlib
import json
import shutil
import time
from pathlib import Path
from typing import Any

import modal

APP_NAME = "pocketdm-wp4-export"
MODEL_VOLUME_NAME = "pocketdm-models"
MODEL_DIR = "/models"

app = modal.App(APP_NAME)
model_volume = modal.Volume.from_name(MODEL_VOLUME_NAME, create_if_missing=True)

export_image = (
    modal.Image.from_registry(
        "nvidia/cuda:12.8.1-devel-ubuntu22.04",
        add_python="3.12",
    )
    .entrypoint([])
    .apt_install(
        "build-essential",
        "cmake",
        "curl",
        "git",
        "libcurl4-openssl-dev",
        "libssl-dev",
    )
    .pip_install(
        "unsloth>=2026.2.0",
        "transformers>=4.51.0",
        "sentencepiece>=0.2.0",
    )
)


@app.function(
    image=export_image,
    gpu="A10G",
    timeout=60 * 60 * 4,
    volumes={MODEL_DIR: model_volume},
    secrets=[modal.Secret.from_name("huggingface")],
)
def export_remote(*, run_name: str, quantizations: list[str]) -> dict[str, Any]:
    from unsloth import FastLanguageModel

    started = time.monotonic()
    merged_dir = f"{MODEL_DIR}/{run_name}/merged"
    output_dir = f"{MODEL_DIR}/{run_name}/gguf"
    config_patch = _disable_missing_mtp_layers(Path(merged_dir) / "config.json")
    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=merged_dir,
        max_seq_length=2048,
        load_in_4bit=False,
    )
    artifacts = []
    for quantization in quantizations:
        target = f"{output_dir}/{quantization}"
        model.save_pretrained_gguf(
            target,
            tokenizer,
            quantization_method=quantization.lower(),
        )
    artifacts.extend(
        _copy_gguf_artifacts(
            source=Path(f"{merged_dir}_gguf"),
            target=Path(output_dir),
        )
    )
    model_volume.commit()
    return {
        "run_name": run_name,
        "merged_dir": merged_dir,
        "output_dir": output_dir,
        "duration_seconds": round(time.monotonic() - started, 1),
        "artifacts": artifacts,
        "config_patch": config_patch,
        "download_hint": (
            f"modal volume get {MODEL_VOLUME_NAME} {run_name}/gguf "
            f"models/{run_name}/gguf"
        ),
    }


def _disable_missing_mtp_layers(config_path: Path) -> dict[str, Any]:
    config = json.loads(config_path.read_text())
    original = config.get("mtp_num_hidden_layers")
    if original:
        config["mtp_num_hidden_layers"] = 0
        config_path.write_text(json.dumps(config, indent=4, sort_keys=False) + "\n")
    return {
        "path": str(config_path),
        "mtp_num_hidden_layers_before": original,
        "mtp_num_hidden_layers_after": config.get("mtp_num_hidden_layers"),
    }


def _copy_gguf_artifacts(*, source: Path, target: Path) -> list[dict[str, Any]]:
    generated = sorted(source.rglob("*.gguf"))
    if not generated:
        raise RuntimeError(f"no GGUF artifacts found under {source}")
    target.mkdir(parents=True, exist_ok=True)
    for path in generated:
        shutil.copy2(path, target / path.name)
    return _artifact_info(target)


def _artifact_info(root: Path) -> list[dict[str, Any]]:
    rows: list[dict[str, Any]] = []
    for path in sorted(root.rglob("*.gguf")):
        rows.append(
            {
                "path": str(path),
                "size_bytes": path.stat().st_size,
                "sha256": _sha256(path),
            }
        )
    return rows


def _sha256(path: Path) -> str:
    digest = hashlib.sha256()
    with path.open("rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


@app.local_entrypoint()
def main(run_name: str = "2b-v1", quantizations: str = "q4_k_m,q8_0") -> None:
    result = export_remote.remote(
        run_name=run_name,
        quantizations=[item.strip() for item in quantizations.split(",") if item.strip()],
    )
    print(json.dumps(result, indent=2, sort_keys=True))


def cli() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--run-name", default="2b-v1")
    parser.add_argument("--quantizations", default="q4_k_m,q8_0")
    args = parser.parse_args()
    main(run_name=args.run_name, quantizations=args.quantizations)


if __name__ == "__main__":
    cli()
