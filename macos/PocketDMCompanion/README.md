# PocketDM Companion

Native macOS overlay shell for Ember. The Python/Gradio app still owns the game,
model, and TTS runtime; this companion owns the OS-level floating dragon panel.

## Attach To A Running PocketDM App

From the repo root:

```bash
uv run --group eval --group tts python app.py
swift run --package-path macos/PocketDMCompanion PocketDMCompanion --attach http://127.0.0.1:7860
```

The companion opens a floating, minimizable `NSPanel`, can open the web game, and
can call the local `/api/assistant` seam after starting a lightweight companion
session.

## Launch The Server From The Companion

```bash
cd /Users/amal/listenowl/experiments/build-small/macos/PocketDMCompanion
POCKETDM_REPO=/Users/amal/listenowl/experiments/build-small swift run PocketDMCompanion --launch-server
```

This mode inherits the shell environment. For Gemma MTP, start the server from
the repo command in `/Users/amal/listenowl/experiments/build-small/docs/mtp-runtime-runbook.md`
until the companion grows a settings screen for model paths.

## Build

```bash
swift build --package-path macos/PocketDMCompanion
```

Package a local unsigned app bundle:

```bash
macos/PocketDMCompanion/scripts/package_app.sh
```
