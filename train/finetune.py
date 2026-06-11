from __future__ import annotations

import argparse
import json
import time
from pathlib import Path
from typing import Any

import modal

from train.data import parse_training_jsonl

APP_NAME = "pocketdm-wp4-training"
MODEL_VOLUME_NAME = "pocketdm-models"
MODEL_DIR = "/models"
A100_40GB_RATE_PER_HOUR = 1.10

app = modal.App(APP_NAME)
model_volume = modal.Volume.from_name(MODEL_VOLUME_NAME, create_if_missing=True)

train_image = (
    modal.Image.from_registry(
        "nvidia/cuda:12.8.1-devel-ubuntu22.04",
        add_python="3.12",
    )
    .entrypoint([])
    .pip_install(
        "unsloth>=2026.2.0",
        "transformers>=4.51.0",
        "trl>=0.25.0,<1.0.0",
        "datasets>=3.2.0",
        "accelerate>=1.2.0",
        "bitsandbytes>=0.45.0",
        "sentencepiece>=0.2.0",
    )
    .add_local_python_source("train")
)


@app.function(
    image=train_image,
    gpu="A100-40GB",
    timeout=60 * 60 * 8,
    volumes={MODEL_DIR: model_volume},
    secrets=[modal.Secret.from_name("huggingface")],
)
def fine_tune_remote(
    *,
    base: str,
    data_jsonl: str,
    run_name: str,
    epochs: float,
    max_steps: int | None,
    lora: bool,
    max_seq_length: int,
    learning_rate: float | None,
    seed: int,
) -> dict[str, Any]:
    import torch
    from datasets import Dataset
    from train.data import parse_training_jsonl, prompt_completion_pair, split_train_eval
    from trl import SFTConfig, SFTTrainer
    from unsloth import FastLanguageModel

    started = time.monotonic()
    rows = parse_training_jsonl(data_jsonl)
    if len(rows) < 10:
        raise ValueError("training data must contain at least 10 rows")

    model, tokenizer = FastLanguageModel.from_pretrained(
        model_name=base,
        max_seq_length=max_seq_length,
        load_in_4bit=False,
        load_in_16bit=True,
        full_finetuning=not lora,
    )
    if lora:
        model = FastLanguageModel.get_peft_model(
            model,
            r=16,
            target_modules=[
                "q_proj",
                "k_proj",
                "v_proj",
                "o_proj",
                "gate_proj",
                "up_proj",
                "down_proj",
            ],
            lora_alpha=16,
            lora_dropout=0,
            bias="none",
            use_gradient_checkpointing="unsloth",
            random_state=seed,
            max_seq_length=max_seq_length,
        )

    if tokenizer.pad_token is None:
        tokenizer.pad_token = tokenizer.eos_token

    train_rows, eval_rows = split_train_eval(rows, eval_fraction=0.02, seed=seed)
    train_dataset = Dataset.from_list(
        [prompt_completion_pair(row, tokenizer) for row in train_rows]
    )
    eval_dataset = Dataset.from_list(
        [prompt_completion_pair(row, tokenizer) for row in eval_rows]
    )
    lr = learning_rate if learning_rate is not None else (2e-4 if lora else 2e-5)
    args = SFTConfig(
        output_dir=f"{MODEL_DIR}/{run_name}/checkpoints",
        per_device_train_batch_size=1,
        gradient_accumulation_steps=4,
        num_train_epochs=epochs,
        max_steps=max_steps if max_steps and max_steps > 0 else -1,
        learning_rate=lr,
        warmup_ratio=0.03,
        lr_scheduler_type="cosine",
        logging_steps=5,
        eval_strategy="steps" if eval_rows else "no",
        eval_steps=50,
        save_strategy="epoch",
        optim="adamw_8bit",
        seed=seed,
        bf16=torch.cuda.is_available() and torch.cuda.is_bf16_supported(),
        fp16=torch.cuda.is_available() and not torch.cuda.is_bf16_supported(),
        report_to=[],
        max_length=max_seq_length,
        packing=True,
        completion_only_loss=True,
    )
    trainer = SFTTrainer(
        model=model,
        processing_class=tokenizer,
        train_dataset=train_dataset,
        eval_dataset=eval_dataset if eval_rows else None,
        args=args,
    )
    train_result = trainer.train()
    eval_metrics = trainer.evaluate() if eval_rows else {}

    merged_dir = f"{MODEL_DIR}/{run_name}/merged"
    lora_dir = f"{MODEL_DIR}/{run_name}/lora"
    model.save_pretrained(lora_dir)
    tokenizer.save_pretrained(lora_dir)
    if hasattr(model, "save_pretrained_merged"):
        model.save_pretrained_merged(merged_dir, tokenizer, save_method="merged_16bit")
    else:
        trainer.save_model(merged_dir)
        tokenizer.save_pretrained(merged_dir)
    model_volume.commit()

    duration = time.monotonic() - started
    cost = duration / 3600 * A100_40GB_RATE_PER_HOUR
    return {
        "base": base,
        "run_name": run_name,
        "rows": len(rows),
        "train_rows": len(train_rows),
        "eval_rows": len(eval_rows),
        "lora": lora,
        "max_steps": max_steps,
        "duration_seconds": round(duration, 1),
        "estimated_cost_usd": round(cost, 2),
        "train_metrics": train_result.metrics,
        "eval_metrics": eval_metrics,
        "merged_dir": merged_dir,
        "lora_dir": lora_dir,
    }


@app.local_entrypoint()
def main(
    base: str = "Qwen/Qwen3.5-2B",
    data: str = "data/clean/train.jsonl",
    run_name: str = "2b-v1",
    epochs: float = 2.0,
    max_steps: int = 0,
    lora: bool = False,
    max_seq_length: int = 2048,
    learning_rate: float = 0.0,
    seed: int = 3407,
    dry_run: bool = False,
) -> None:
    data_path = Path(data)
    rows = parse_training_jsonl(data_path.read_text())
    print(f"loaded {len(rows)} training rows from {data_path}")
    if dry_run:
        print("dry_run=true; remote Modal training was not launched")
        return

    result = fine_tune_remote.remote(
        base=base,
        data_jsonl=data_path.read_text(),
        run_name=run_name,
        epochs=epochs,
        max_steps=max_steps or None,
        lora=lora,
        max_seq_length=max_seq_length,
        learning_rate=learning_rate or None,
        seed=seed,
    )
    print(json.dumps(result, indent=2, sort_keys=True))
    print(
        "| 2026-06-11 | WP-4 fine-tune "
        f"({run_name}) | Modal A100-40GB | "
        f"{result['duration_seconds'] / 60:.1f} min | "
        f"{result['estimated_cost_usd']:.2f} | "
        f"{result['train_rows']} train rows; {result['eval_rows']} eval rows; "
        f"base={base}; lora={lora} |"
    )


def cli() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--base", default="Qwen/Qwen3.5-2B")
    parser.add_argument("--data", default="data/clean/train.jsonl")
    parser.add_argument("--run-name", default="2b-v1")
    parser.add_argument("--epochs", type=float, default=2.0)
    parser.add_argument("--max-steps", type=int, default=0)
    parser.add_argument("--lora", action="store_true")
    parser.add_argument("--max-seq-length", type=int, default=2048)
    parser.add_argument("--learning-rate", type=float, default=0.0)
    parser.add_argument("--seed", type=int, default=3407)
    parser.add_argument("--dry-run", action="store_true")
    args = parser.parse_args()
    main(
        base=args.base,
        data=args.data,
        run_name=args.run_name,
        epochs=args.epochs,
        max_steps=args.max_steps,
        lora=args.lora,
        max_seq_length=args.max_seq_length,
        learning_rate=args.learning_rate,
        seed=args.seed,
        dry_run=args.dry_run,
    )


if __name__ == "__main__":
    cli()
