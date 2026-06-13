#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
repo_root="$(cd -- "$script_dir/../../.." >/dev/null 2>&1 && pwd -P)"
attach_url="${POCKETDM_COMPANION_ATTACH_URL:-http://127.0.0.1:7860}"
character="${POCKETDM_COMPANION_CHARACTER:-}"
launch_server=0
dry_run=0

while [[ $# -gt 0 ]]; do
  case "$1" in
    --attach)
      if [[ $# -lt 2 ]]; then
        echo "--attach requires a URL" >&2
        exit 64
      fi
      attach_url="$2"
      shift 2
      ;;
    --launch-server)
      launch_server=1
      shift
      ;;
    --character|--pet)
      if [[ $# -lt 2 ]]; then
        echo "$1 requires pika or golden" >&2
        exit 64
      fi
      character="$2"
      shift 2
      ;;
    --dry-run)
      dry_run=1
      shift
      ;;
    -h|--help)
      cat <<'USAGE'
Usage: scripts/launch_app.sh [--attach URL] [--character pika|golden] [--launch-server] [--dry-run]

Builds the unsigned local PocketDM Companion.app, then launches it attached to
the running PocketDM web app. The default attach URL is http://127.0.0.1:7860.
USAGE
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      exit 64
      ;;
  esac
done

if [[ "$dry_run" -eq 1 ]]; then
  app_path="$("$script_dir/package_app.sh" --dry-run)"
else
  app_path="$("$script_dir/package_app.sh")"
fi
args=(--attach "$attach_url")

if [[ -n "$character" ]]; then
  args+=(--character "$character")
fi

if [[ "$launch_server" -eq 1 ]]; then
  args+=(--launch-server)
fi

if [[ "$dry_run" -eq 1 ]]; then
  printf '/usr/bin/open %q --args' "$app_path"
  printf ' %q' "${args[@]}"
  printf '\n'
  exit 0
fi

export POCKETDM_REPO="$repo_root"
binary_name="PocketDMCompanion"
if pgrep -x "$binary_name" >/dev/null 2>&1; then
  pkill -9 -x "$binary_name" >/dev/null 2>&1 || true
  sleep 0.2
fi
/usr/bin/open "$app_path" --args "${args[@]}"
