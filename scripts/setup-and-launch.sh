#!/usr/bin/env bash
# One-command local setup for the Pocket Pikachu macOS companion.
#
# Starts the 100%-local model stack (brain + voice + ears + web) and launches the
# floating desktop pet. First run downloads ~4 GB of model weights and builds
# isolated Python venvs, so it can take a few minutes. Everything runs on your
# machine — no cloud, no API keys.
#
# Requirements: macOS 14+, Python 3.11+, `uv`, ~5 GB free disk.
set -euo pipefail

repo_root="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." >/dev/null 2>&1 && pwd -P)"
cd "$repo_root"

cat <<'BANNER'
⚡ Pocket Pikachu — local setup
   Starts the on-device model stack and launches the desktop pet.
   First run downloads ~4 GB of weights + builds Python venvs (a few minutes).
BANNER

echo "==> Starting the local model stack (brain 8081 · voice 7861 · ears 7862/7863 · web 7860)"
macos/PocketDMCompanion/scripts/pika_demo_stack.sh start

echo "==> Launching the desktop pet"
macos/PocketDMCompanion/scripts/pika_demo_stack.sh launch

cat <<'DONE'
✅ Done. The floating Pikachu should be on your desktop — click it and talk!
   Stop the stack later with:
     macos/PocketDMCompanion/scripts/pika_demo_stack.sh stop
DONE
