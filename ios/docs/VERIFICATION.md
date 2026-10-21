# Verification report and rerun guide

Scope: what was machine-verified for the native app, how to rerun it, and what still needs a human on a device. Plan references: `PLAN.md` §6 and §9.

## Automated checks

| Check | Command | Result |
|---|---|---|
| CapoCore (ChordPro engine, music theory, goldens, perf) | `cd ios/Packages/CapoCore && swift test` | 29 tests (16 + 13 across two runs), pass |
| CapoData (CapoStore + CapoSync) | `cd ios/Packages/CapoData && swift test` | 48 tests (26 sync + 22 store), pass |
| CapoSupabase (rows, writer, sync source, teams, auth, local E2E) | `cd ios/Packages/CapoSupabase && swift test` | 42 tests, pass (E2E suites are no-ops without env, see below) |
| CapoAppKit (composition, DevSession, privacy manifest) | `cd ios/Packages/CapoAppKit && xcodebuild -scheme CapoAppKit -destination 'platform=iOS Simulator,id=<iPhone>' -derivedDataPath ../../build/dd-shared test` 9 tests in 3 suites, pass (includes B2 privacy-manifest tests) |
| All host suites + CapoUI | `ios/scripts/test-packages.sh` | wrapper for the above plus CapoUI-Package |
| Secrets in history | `git log -p -- ios \| grep 'eyJ'` | only matches the sentence in PLAN.md §9 that quotes the command; no token |

## Local Supabase E2E

Runs against the already-running local stack (127.0.0.1:54321). It never resets or stops the stack and the read path writes nothing.

```bash
KEY=$(supabase status -o env | grep '^PUBLISHABLE_KEY=' | cut -d= -f2- | tr -d '"')   # env only, never to a file
ios/scripts/mint-dev-session.sh                                                          # refresh ios/Capo/Capo/DevSession.plist (git-ignored)
cd ios/Packages/CapoSupabase
CAPO_LOCAL_SUPABASE=1 CAPO_LOCAL_SUPABASE_KEY="$KEY" swift test --filter LocalE2E
```

- `LocalE2E.songRoundTripWithConflict` (write path: create, update, stale-base conflict, delete) needs a throwaway user. The local stack has `enable_signup = false`, so it logs "skipped: signup unavailable" and returns. It runs for real on a stack that allows signup.
- `LocalE2EReadPath.libraryPullReturnsSongs` signs in with the dev session and pulls through the real `SupabaseRemoteSyncSource`. Last run: 48 song versions returned for the dev user, songs and profile decode. It skips when `DevSession.plist` is missing or its access token is expired (it never refreshes, so the app's refresh token is not rotated); re-run `mint-dev-session.sh`.

## Release-build safety (dev session must not ship)

Built `Release` for the simulator from a clean `git archive` of HEAD with `Secrets.plist` and `DevSession.plist` copied into the source folder (worst case), then inspected the `.app`:

- `strings` on the executable for `CapoDevSession`, `DevSession`, `dev-session`: 0 hits. `DevSession.swift` and its call site are `#if DEBUG`.
- Finding: the file-system-synchronized group bundled `DevSession.plist` (a local-stack access and refresh token) into the Release `.app`. Only the local stack's token, but it should never ship.
- Fix (commit "strip DevSession.plist from non-Debug app bundles"): a run-script build phase in `Capo.xcodeproj` removes `DevSession.plist` from the bundle unless `CONFIGURATION == Debug`. Re-verified: Release bundle contains only `Secrets.plist` (public anon key and URLs, intended); Debug bundle still contains `DevSession.plist`.

Rerun:

```bash
xcodebuild -project ios/Capo/Capo.xcodeproj -scheme Capo -configuration Release \
  -destination 'generic/platform=iOS Simulator' -derivedDataPath ios/build/dd-release CODE_SIGNING_ALLOWED=NO build
APP=ios/build/dd-release/Build/Products/Release-iphonesimulator/Capo.app
ls "$APP" | grep -i devsession                                  # expect no output
strings -a "$APP/Capo" | grep -E 'CapoDevSession|DevSession|dev-session'   # expect no output
rm -rf ios/build/dd-release
```

## Manual checklist (needs a physical iPhone 13 Pro and iPad Pro 11, PLAN.md §9)

Not machine-verifiable; none of these were run:

1. Sign in with real Google OAuth (production, human's choice) and confirm the library count per context matches the web.
2. Airplane mode, force quit, cold start: session restored; library, search, song view and a 20-song setlist work offline.
3. Bluetooth page-turner pedals: next/previous in the setlist performance view.
4. External display / AirPlay mirroring of the performance view.
5. Spanish device language: no raw keys, accented search ("cancion" finds "Canción").
6. Two-device conflict test: edit the same song offline on the app and on the web, reconnect, check the conflict UI and each of the three resolutions; transpose changed offline appears on the web after reconnect.
7. Auto-scroll at BPM 70 and 140 stops at the bottom; screen does not lock for 5 minutes.
8. iPad: rotation, two columns, Stage Manager resize, hardware keyboard shortcuts.
9. Sign out with "erase" deletes the database; a different account sees no earlier data.
10. Chords at transpose +/-2 and capo 3 match the web for three real songs.
