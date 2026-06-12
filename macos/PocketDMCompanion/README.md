# PocketDM Companion

Native macOS overlay shell for Spark. The Python/Gradio app still owns the game,
model, and TTS runtime; this companion owns the OS-level floating electric
familiar panel.

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

The script prints the bundle path on stdout and writes the unsigned app to:

```text
/Users/amal/listenowl/experiments/build-small/macos/PocketDMCompanion/.build/release/PocketDM Companion.app
```

Launch the packaged app attached to a running local PocketDM server:

```bash
macos/PocketDMCompanion/scripts/launch_app.sh --attach http://127.0.0.1:7860
```

Preview the launch command without opening the app:

```bash
macos/PocketDMCompanion/scripts/launch_app.sh --attach http://127.0.0.1:7860 --dry-run
```

Preview the bundle path without rebuilding it:

```bash
macos/PocketDMCompanion/scripts/package_app.sh --dry-run
```

Useful packaging environment variables:

```bash
POCKETDM_COMPANION_CONFIGURATION=debug macos/PocketDMCompanion/scripts/package_app.sh
POCKETDM_COMPANION_BUNDLE_PATH=/tmp/PocketDMCompanion.app macos/PocketDMCompanion/scripts/package_app.sh
POCKETDM_COMPANION_ATTACH_URL=http://127.0.0.1:7860 macos/PocketDMCompanion/scripts/launch_app.sh
```

This local bundle is intentionally unsigned and not notarized. It is meant for
the hackathon demo path on the same Mac, not for distribution.
