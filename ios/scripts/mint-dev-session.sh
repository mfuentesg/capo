#!/usr/bin/env bash
# DEBUG/LOCAL ONLY. Mints a real Supabase session for an existing user of the LOCAL stack and writes
# it to ios/Capo/Capo/DevSession.plist (git-ignored). Debug builds that bundle that file sign in with
# it at launch, so the simulator and devices can show local data without the Google browser step.
#
#   ios/scripts/mint-dev-session.sh [email]   # default: the only user, or fails if there are several
#   ios/scripts/mint-dev-session.sh --remove  # deletes DevSession.plist
#
# Uses the local service-role key from `supabase status -o env` in memory only; it is never written
# anywhere. Tokens are never printed. Refuses to run against anything but 127.0.0.1 / localhost.
set -euo pipefail

IOS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
REPO_DIR="$(cd "$IOS_DIR/.." && pwd)"
PLIST="$IOS_DIR/Capo/Capo/DevSession.plist"

if [[ "${1:-}" == "--remove" ]]; then
  rm -f "$PLIST"
  echo "Removed $PLIST"
  exit 0
fi

command -v supabase >/dev/null || { echo "supabase CLI not found" >&2; exit 1; }
status="$(cd "$REPO_DIR" && supabase status -o env 2>/dev/null)" || {
  echo "Local Supabase is not running" >&2
  exit 1
}
value() { grep -E "^$1=" <<<"$status" | head -n1 | cut -d= -f2- | sed -e 's/^"//' -e 's/"$//'; }
api="$(value API_URL)"
case "$api" in
  http://127.0.0.1:*|http://localhost:*) ;;
  *) echo "Refusing: API_URL is not local ($api)" >&2; exit 1 ;;
esac

CAPO_SERVICE_ROLE_KEY="$(value SERVICE_ROLE_KEY)" python3 -I - "$api" "$PLIST" "${1:-}" <<'EOF'
import json, os, plistlib, sys, urllib.error, urllib.request

base, out, wanted = sys.argv[1], sys.argv[2], sys.argv[3]
key = os.environ["CAPO_SERVICE_ROLE_KEY"]

def call(method, path, body=None):
    req = urllib.request.Request(
        base + path, method=method, data=json.dumps(body).encode() if body is not None else None)
    req.add_header("apikey", key)
    req.add_header("Authorization", "Bearer " + key)
    req.add_header("Content-Type", "application/json")
    try:
        with urllib.request.urlopen(req) as response:
            return json.loads(response.read() or b"null")
    except urllib.error.HTTPError as error:
        sys.exit(f"{method} {path.split('?')[0]} failed with HTTP {error.code}")

users = [u["email"] for u in call("GET", "/auth/v1/admin/users?per_page=200")["users"] if u.get("email")]
if wanted:
    if wanted not in users:
        sys.exit("No local user with that email")
    email = wanted
elif len(users) == 1:
    email = users[0]
else:
    sys.exit(f"{len(users)} local users; pass the email to use")

link = call("POST", "/auth/v1/admin/generate_link", {"type": "magiclink", "email": email})
token_hash = link.get("hashed_token") or link.get("properties", {}).get("hashed_token")
session = call("POST", "/auth/v1/verify", {"type": "magiclink", "token_hash": token_hash})

with open(out, "wb") as f:
    plistlib.dump({
        "ACCESS_TOKEN": session["access_token"],
        "REFRESH_TOKEN": session["refresh_token"],
        "USER_EMAIL": email,
    }, f)
print(f"Wrote {out} for {email} (expires in {session['expires_in']}s; refreshed by the app)")
EOF

git -C "$REPO_DIR" check-ignore -q "$PLIST" || { echo "WARNING: $PLIST is not git-ignored" >&2; exit 1; }
