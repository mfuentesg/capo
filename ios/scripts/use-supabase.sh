#!/usr/bin/env bash
# Points the iOS app at a Supabase backend by writing ios/Capo/Capo/Secrets.plist (git-ignored).
#
#   ios/scripts/use-supabase.sh local            # simulator -> http://127.0.0.1:54321
#   ios/scripts/use-supabase.sh local --device   # physical device -> http://<Mac LAN IP>:54321
#   ios/scripts/use-supabase.sh production       # copies ios/Capo/Secrets.production.plist
#   ios/scripts/use-supabase.sh demo             # removes Secrets.plist (app runs in demo mode)
#
# `local` reads the running stack with `supabase status -o env` (read-only). Keys are never printed.
set -euo pipefail

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "$IOS_DIR/.." && pwd)"
PLIST="$IOS_DIR/Capo/Capo/Secrets.plist"

env_value() {
  # Prints the value of KEY from `supabase status -o env` output on stdin, without quotes.
  grep -E "^$1=" | head -n1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//'
}

write_local() {
  local device="${1:-}"
  command -v supabase >/dev/null || { echo "supabase CLI not found" >&2; exit 1; }
  local status
  status="$(cd "$REPO_DIR" && supabase status -o env 2>/dev/null)" || {
    echo "Local Supabase is not running (supabase status failed). Start it with: pnpm supabase start" >&2
    exit 1
  }
  local api key host web
  api="$(env_value API_URL <<<"$status")"
  key="$(env_value PUBLISHABLE_KEY <<<"$status")"
  [[ -n "$key" ]] || key="$(env_value ANON_KEY <<<"$status")"
  [[ -n "$api" && -n "$key" ]] || { echo "Could not read API_URL / key from supabase status" >&2; exit 1; }

  web="http://localhost:3000"
  if [[ "$device" == "--device" ]]; then
    host="$(ipconfig getifaddr en0 || true)"
    [[ -n "$host" ]] || { echo "No LAN IP on en0; is Wi-Fi connected?" >&2; exit 1; }
    api="$(sed -E "s#//(127\.0\.0\.1|localhost)#//$host#" <<<"$api")"
    web="http://$host:3000"
  fi

  rm -f "$PLIST"
  plutil -create xml1 "$PLIST"
  plutil -insert SUPABASE_URL -string "$api" "$PLIST"
  plutil -insert SUPABASE_PUBLISHABLE_KEY -string "$key" "$PLIST"
  plutil -insert CAPO_WEB_URL -string "$web" "$PLIST"
  plutil -insert CAPO_ENV_NAME -string "local" "$PLIST"
  echo "Wrote $PLIST for $api"
}

case "${1:-}" in
  local) write_local "${2:-}" ;;
  production)
    src="$IOS_DIR/Capo/Secrets.production.plist"
    [[ -f "$src" ]] || { echo "Missing $src (create it; it is git-ignored)" >&2; exit 1; }
    cp "$src" "$PLIST"
    echo "Wrote $PLIST from Secrets.production.plist"
    ;;
  demo)
    rm -f "$PLIST"
    echo "Removed $PLIST; the app will start in demo mode"
    ;;
  *)
    sed -n '2,9p' "${BASH_SOURCE[0]}" | sed 's/^# \{0,1\}//'
    exit 1
    ;;
esac
