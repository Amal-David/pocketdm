#!/usr/bin/env bash
# Build a distributable .dmg of the Pocket Pikachu macOS companion app.
#
# Honest caveats:
#  * The app is dev-signed, NOT notarized. On another Mac the first launch needs
#    right-click -> Open (or: xattr -dr com.apple.quarantine "<app>").
#  * It is NOT a standalone app — it attaches to the local model sidecars. Pair the
#    .dmg with scripts/setup-and-launch.sh (downloads models, starts the stack).
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
repo_root="$(cd -- "$script_dir/../../.." >/dev/null 2>&1 && pwd -P)"
cd "$repo_root"

app_name="PocketDM Companion"
app_path="macos/PocketDMCompanion/.build/release/$app_name.app"
dist_dir="$repo_root/dist"
dmg_path="$dist_dir/PocketDM-Companion.dmg"

echo "==> Building + signing the app bundle"
"$script_dir/package_app.sh" >/dev/null
[[ -d "$app_path" ]] || { echo "error: app bundle missing at $app_path" >&2; exit 1; }

mkdir -p "$dist_dir"
rm -f "$dmg_path"

echo "==> Staging .app + /Applications shortcut"
staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp -R "$app_path" "$staging/"
ln -s /Applications "$staging/Applications"

echo "==> Creating compressed DMG (hdiutil)"
hdiutil create \
  -volname "$app_name" \
  -srcfolder "$staging" \
  -ov -format UDZO \
  "$dmg_path" >/dev/null

echo "==> DMG ready: $dmg_path ($(du -h "$dmg_path" | awk '{print $1}'))"
