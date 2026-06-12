#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

swift build -c release

bundle=".build/release/PocketDM Companion.app"
rm -rf "$bundle"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp .build/release/PocketDMCompanion "$bundle/Contents/MacOS/PocketDMCompanion"
cp Info.plist "$bundle/Contents/Info.plist"

echo "$PWD/$bundle"
