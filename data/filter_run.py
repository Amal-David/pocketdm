from __future__ import annotations

import argparse
import glob
import json
from pathlib import Path

from data.filters import (
    BetterProfanityChecker,
    SentenceTransformerEncoder,
    filter_many,
    load_jsonl,
    render_report,
)


def expand_inputs(patterns: list[str]) -> list[Path]:
    paths: list[Path] = []
    for pattern in patterns:
        matches = sorted(glob.glob(pattern))
        if matches:
            paths.extend(Path(match) for match in matches)
        else:
            paths.append(Path(pattern))
    return paths


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("inputs", nargs="+")
    parser.add_argument("--out", default="data/clean/")
    args = parser.parse_args()

    adventures = []
    for path in expand_inputs(args.inputs):
        adventures.extend(load_jsonl(path))

    clean, report = filter_many(
        adventures,
        encoder=SentenceTransformerEncoder(),
        profanity_checker=BetterProfanityChecker(),
    )

    out_dir = Path(args.out)
    out_dir.mkdir(parents=True, exist_ok=True)
    clean_path = out_dir / "adventures.jsonl"
    with clean_path.open("w") as handle:
        for adventure in clean:
            handle.write(json.dumps(adventure, ensure_ascii=True, separators=(",", ":")) + "\n")

    report_path = out_dir / "REPORT.md"
    report_path.write_text(render_report(report))
    print(f"wrote {len(clean)} clean adventures to {clean_path}")
    print(f"wrote filter report to {report_path}")


if __name__ == "__main__":
    main()
