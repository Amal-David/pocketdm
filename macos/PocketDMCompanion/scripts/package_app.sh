#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
project_dir="$(cd -- "$script_dir/.." >/dev/null 2>&1 && pwd -P)"
configuration="${POCKETDM_COMPANION_CONFIGURATION:-release}"
app_name="${POCKETDM_COMPANION_APP_NAME:-PocketDM Companion}"
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: scripts/package_app.sh [--dry-run]

Builds an unsigned local PocketDM Companion.app bundle from the SwiftPM
executable. The generated app is intended for local demos, not distribution.

Environment:
  POCKETDM_COMPANION_CONFIGURATION  debug or release, default release
  POCKETDM_COMPANION_APP_NAME       default "PocketDM Companion"
  POCKETDM_COMPANION_BUNDLE_PATH    override output .app path
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 64
      ;;
  esac
done

case "$configuration" in
  debug|release) ;;
  *)
    echo "POCKETDM_COMPANION_CONFIGURATION must be debug or release, got: $configuration" >&2
    exit 64
    ;;
esac

if [[ -n "${POCKETDM_COMPANION_BUNDLE_PATH:-}" ]]; then
  bundle="$POCKETDM_COMPANION_BUNDLE_PATH"
else
  bundle="$project_dir/.build/$configuration/$app_name.app"
fi

if [[ "$bundle" != /* ]]; then
  bundle="$project_dir/$bundle"
fi

if [[ "$bundle" != *.app ]]; then
  echo "Bundle path must end in .app: $bundle" >&2
  exit 64
fi

case "$(basename "$bundle")" in
  "$app_name.app"|*PocketDM*Companion*.app|*PocketDMCompanion*.app) ;;
  *)
    echo "Refusing to replace an app bundle that is not named for PocketDM Companion: $bundle" >&2
    exit 64
    ;;
esac

executable="$project_dir/.build/$configuration/PocketDMCompanion"
resource_bundle_name="PocketDMCompanion_PocketDMCompanion.bundle"
resource_bundle="$project_dir/.build/$configuration/$resource_bundle_name"

if [[ "$dry_run" -eq 1 ]]; then
  echo "Would build PocketDMCompanion ($configuration) and create unsigned app bundle: $bundle" >&2
  printf '%s\n' "$bundle"
  exit 0
fi

cd "$project_dir"
swift build -c "$configuration" --product PocketDMCompanion >&2

if [[ ! -x "$executable" ]]; then
  echo "SwiftPM did not produce the expected executable: $executable" >&2
  exit 66
fi

rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp "$executable" "$bundle/Contents/MacOS/PocketDMCompanion"
cp "$project_dir/Info.plist" "$bundle/Contents/Info.plist"
# App icon (Pikachu). Info.plist sets CFBundleIconFile=AppIcon -> this file.
if [[ -f "$project_dir/Resources/AppIcon.icns" ]]; then
  cp "$project_dir/Resources/AppIcon.icns" "$bundle/Contents/Resources/AppIcon.icns"
else
  echo "WARN: Resources/AppIcon.icns missing — app will have no icon" >&2
fi
if [[ ! -d "$resource_bundle" ]]; then
  echo "SwiftPM did not produce the expected resource bundle: $resource_bundle" >&2
  exit 66
fi
cp -R "$resource_bundle" "$bundle/Contents/Resources/$resource_bundle_name"
chmod 755 "$bundle/Contents/MacOS/PocketDMCompanion"
printf 'APPL????' > "$bundle/Contents/PkgInfo"

if command -v plutil >/dev/null 2>&1; then
  plutil -lint "$bundle/Contents/Info.plist" >/dev/null
fi

if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$bundle/Contents/Info.plist")" != "PocketDMCompanion" ]]; then
  echo "Info.plist CFBundleExecutable does not match PocketDMCompanion" >&2
  exit 65
fi

# Bundle the torch-free Python runtime payload so the app can self-bootstrap the
# local stack on first launch (build venvs + download weights). Kept lean: app
# source + sidecar scripts + the bundled Kokoro voice weights; no tests/models/venvs.
repo_root="$(cd "$project_dir/../.." >/dev/null 2>&1 && pwd -P)"
runtime_payload="$bundle/Contents/Resources/pocketdm-runtime"
echo "Bundling Python runtime payload into Resources/pocketdm-runtime" >&2
mkdir -p "$runtime_payload/macos/PocketDMCompanion" "$runtime_payload/space"
payload_excludes=(--exclude '__pycache__' --exclude '*.pyc' --exclude '.venv' --exclude '.pika-*-venv' \
  --exclude 'voices/models' --exclude 'voices/auditions')
rsync -a "${payload_excludes[@]}" "$repo_root/app" "$runtime_payload/"
[[ -d "$repo_root/engine" ]] && rsync -a "${payload_excludes[@]}" "$repo_root/engine" "$runtime_payload/"
rsync -a "${payload_excludes[@]}" "$repo_root/macos/PocketDMCompanion/scripts" "$runtime_payload/macos/PocketDMCompanion/"
cp "$repo_root/app.py" "$runtime_payload/" 2>/dev/null || true
cp "$repo_root/pyproject.toml" "$runtime_payload/" 2>/dev/null || true
cp "$repo_root/uv.lock" "$runtime_payload/" 2>/dev/null || true
cp "$repo_root/space/kokoro-v1.0.onnx" "$runtime_payload/space/" 2>/dev/null || echo "WARN: kokoro-v1.0.onnx missing from payload" >&2
cp "$repo_root/space/voices-v1.0.bin" "$runtime_payload/space/" 2>/dev/null || echo "WARN: voices-v1.0.bin missing from payload" >&2

# Code-sign with a stable Apple Development identity so macOS (TCC) remembers the
# microphone/speech permission grant across rebuilds and relaunches. An ad-hoc
# signature changes every build, which is why the mic permission kept re-prompting.
# Falls back to ad-hoc if the stable identity isn't available on this machine.
sign_identity="${POCKETDM_CODESIGN_IDENTITY:-7D85F11EAF637E167025E747F0303E092EA3C781}"
if codesign --force --deep --sign "$sign_identity" "$bundle" >/dev/null 2>&1; then
  echo "Signed app bundle with stable identity ($sign_identity): $bundle" >&2
else
  codesign --force --deep --sign - "$bundle" >/dev/null 2>&1 || true
  echo "Created ad-hoc signed app bundle (stable identity unavailable): $bundle" >&2
fi
printf '%s\n' "$bundle"
