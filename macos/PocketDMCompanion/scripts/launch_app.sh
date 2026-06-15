#!/usr/bin/env bash
set -euo pipefail

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" >/dev/null 2>&1 && pwd -P)"
repo_root="$(cd -- "$script_dir/../../.." >/dev/null 2>&1 && pwd -P)"
attach_url="${POCKETDM_COMPANION_ATTACH_URL:-http://127.0.0.1:7860}"
character="${POCKETDM_COMPANION_CHARACTER:-}"
pika_tts_url="${POCKETDM_PIKA_TTS_URL:-}"
pika_stt_url="${POCKETDM_PIKA_STT_URL:-}"
realtime_stt_url="${POCKETDM_REALTIME_STT_URL:-}"
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
    --pika-tts-url)
      if [[ $# -lt 2 ]]; then
        echo "--pika-tts-url requires a URL" >&2
        exit 64
      fi
      pika_tts_url="$2"
      shift 2
      ;;
    --pika-stt-url)
      if [[ $# -lt 2 ]]; then
        echo "--pika-stt-url requires a URL" >&2
        exit 64
      fi
      pika_stt_url="$2"
      shift 2
      ;;
    --realtime-stt-url)
      if [[ $# -lt 2 ]]; then
        echo "--realtime-stt-url requires a URL" >&2
        exit 64
      fi
      realtime_stt_url="$2"
      shift 2
      ;;
    --character|--pet)
      if [[ $# -lt 2 ]]; then
        echo "$1 requires pika" >&2
        exit 64
      fi
      if [[ "$2" != "pika" && "$2" != "pikachu" ]]; then
        echo "Only Pikachu is active for this demo; use --character pika" >&2
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
Usage: scripts/launch_app.sh [--attach URL] [--character pika] [--pika-tts-url URL] [--pika-stt-url URL] [--realtime-stt-url URL] [--launch-server] [--dry-run]

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

if [[ -n "$pika_tts_url" ]]; then
  export POCKETDM_PIKA_TTS_URL="$pika_tts_url"
  args+=(--pika-tts-url "$pika_tts_url")
fi

if [[ -n "$pika_stt_url" ]]; then
  export POCKETDM_PIKA_STT_URL="$pika_stt_url"
  args+=(--pika-stt-url "$pika_stt_url")
fi

if [[ -n "$realtime_stt_url" ]]; then
  export POCKETDM_REALTIME_STT_URL="$realtime_stt_url"
  args+=(--realtime-stt-url "$realtime_stt_url")
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
