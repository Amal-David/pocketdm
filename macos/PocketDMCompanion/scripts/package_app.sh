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
chmod 755 "$bundle/Contents/MacOS/PocketDMCompanion"
printf 'APPL????' > "$bundle/Contents/PkgInfo"

if command -v plutil >/dev/null 2>&1; then
  plutil -lint "$bundle/Contents/Info.plist" >/dev/null
fi

if [[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleExecutable' "$bundle/Contents/Info.plist")" != "PocketDMCompanion" ]]; then
  echo "Info.plist CFBundleExecutable does not match PocketDMCompanion" >&2
  exit 65
fi

echo "Created unsigned local app bundle: $bundle" >&2
printf '%s\n' "$bundle"
