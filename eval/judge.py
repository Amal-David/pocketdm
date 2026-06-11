from __future__ import annotations

import argparse
import json
import re
from pathlib import Path
from typing import Any

import modal

APP_NAME = "pocketdm-wp5-judge"
MODEL_ID = "Qwen/Qwen3-32B"
CACHE_DIR = "/cache"

app = modal.App(APP_NAME)
hf_cache = modal.Volume.from_name("pocketdm-hf-cache", create_if_missing=True)

judge_image = (
    modal.Image.from_registry(
        "nvidia/cuda:12.8.1-devel-ubuntu22.04",
        add_python="3.12",
    )
    .entrypoint([])
    .pip_install(
        "vllm==0.11.2",
        "pydantic>=2",
        "transformers>=4.51.0",
        "xgrammar>=0.1.18",
        "sentencepiece>=0.2.0",
        "huggingface-hub[hf_transfer]>=0.30.0",
    )
    .env({"HF_HOME": f"{CACHE_DIR}/huggingface", "HF_HUB_ENABLE_HF_TRANSFER": "1"})
)


@app.function(
    image=judge_image,
    gpu="H100",
    timeout=60 * 60,
    volumes={CACHE_DIR: hf_cache},
)
def judge_remote(transcripts_json: str) -> dict[str, Any]:
    from pydantic import BaseModel, Field
    from vllm import LLM, SamplingParams
    from vllm.sampling_params import StructuredOutputsParams

    class Verdict(BaseModel):
        coherence: int = Field(ge=1, le=5)
        choice_meaningfulness: int = Field(ge=1, le=5)
        ending_satisfaction: int = Field(ge=1, le=5)
        rationale: str = Field(max_length=300)

    transcripts = json.loads(transcripts_json)
    llm = LLM(
        model=MODEL_ID,
        dtype="bfloat16",
        max_model_len=4096,
        gpu_memory_utilization=0.92,
    )
    sampling = SamplingParams(
        temperature=0.0,
        max_tokens=400,
        structured_outputs=StructuredOutputsParams(
            json=Verdict.model_json_schema(),
            disable_any_whitespace=True,
        ),
    )
    prompts = [_judge_prompt(transcript) for transcript in transcripts]
    outputs = llm.generate(prompts, sampling)
    verdicts = []
    parse_fallbacks = []
    for index, output in enumerate(outputs):
        text = output.outputs[0].text
        try:
            verdict = Verdict.model_validate_json(text)
        except Exception as error:
            verdict = _partial_verdict(Verdict, text)
            parse_fallbacks.append(
                {
                    "index": index,
                    "error": error.__class__.__name__,
                    "text_prefix": text[:500],
                }
            )
        verdicts.append(verdict.model_dump())
    return {"verdicts": verdicts, "parse_fallbacks": parse_fallbacks}


def _partial_verdict(verdict_cls: type[Any], text: str) -> Any:
    fields = {}
    for field in ("coherence", "choice_meaningfulness", "ending_satisfaction"):
        match = re.search(rf'"{field}"\s*:\s*([1-5])', text)
        fields[field] = int(match.group(1)) if match else 1
    rationale = "Judge output was partial; numeric scores were recovered when present."
    match = re.search(r'"rationale"\s*:\s*"([^"]{1,300})', text)
    if match:
        rationale = match.group(1)
    return verdict_cls(**fields, rationale=rationale)


def _judge_prompt(transcript: dict[str, Any]) -> str:
    sample_bad = (
        "Bad anchor: repeated room text, choices all mean open door, no ending. "
        "Scores: coherence=1, choice_meaningfulness=1, ending_satisfaction=1."
    )
    sample_good = (
        "Good anchor: state changes matter, choices differ, final turn resolves the quest. "
        "Scores: coherence=5, choice_meaningfulness=5, ending_satisfaction=5."
    )
    compact = json.dumps(_compact_transcript(transcript), ensure_ascii=True)
    return (
        "You are judging a tiny-model interactive fiction transcript for a hackathon. "
        "Return JSON only with integer scores 1-5 and a short rationale. "
        f"{sample_bad}\n{sample_good}\nTranscript={compact}"
    )


def _compact_transcript(transcript: dict[str, Any]) -> dict[str, Any]:
    turns = []
    for index, record in enumerate(transcript.get("turns", []), start=1):
        turn = record.get("turn_json") or {}
        delta = turn.get("state_delta") or {}
        turns.append(
            {
                "i": index,
                "n": str(turn.get("narration") or "")[:180],
                "choices": turn.get("choices") or [],
                "loc": delta.get("location"),
                "hp": delta.get("hp"),
                "items": {
                    "add": delta.get("add_items") or [],
                    "remove": delta.get("remove_items") or [],
                },
                "flags": delta.get("add_flags") or [],
                "bridge": bool(record.get("used_bridge")),
                "ending": bool(turn.get("is_ending")),
                "ending_type": turn.get("ending_type"),
            }
        )
    return {
        "adventure_id": transcript.get("adventure_id"),
        "genre": transcript.get("genre"),
        "premise": transcript.get("premise"),
        "turns": turns,
    }


@app.local_entrypoint()
def main(results: str, out: str = "eval/results/judge.json") -> None:
    data = json.loads(Path(results).read_text())
    transcripts = data.get("sessions", data)
    result = judge_remote.remote(json.dumps(transcripts))
    out_path = Path(out)
    out_path.parent.mkdir(parents=True, exist_ok=True)
    out_path.write_text(json.dumps(result, indent=2))
    print(json.dumps(result, indent=2))


def cli() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--results", required=True)
    parser.add_argument("--out", default="eval/results/judge.json")
    args = parser.parse_args()
    main(results=args.results, out=args.out)


if __name__ == "__main__":
    cli()
