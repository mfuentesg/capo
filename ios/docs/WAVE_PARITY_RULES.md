# Parity implementation rules (all agents)

Source of truth: `ios/docs/WEB_PARITY_ANALYSIS.md` (spec, tokens, gaps) and the approved design canvas
(https://claude.ai/artifact/GTdX1n1Z8HJNz1C5P7TFxu; local sources in the session scratchpad `capo-design/project/*.dc.html`).
Decisions: guitar only (no ukulele anywhere); sidebar kept but with web items (Songs, Playlists, Chords, Teams) + context pill on top + avatar menu in footer;
2 lyric columns kept on narrow detail; EN/ES labels for language; keep iOS-only extras (fullscreen stage, chord-hand toggle in chord dialog).

Workflow rules:
- Worktree: /Users/mfuentesg/code/capo/.claude/worktrees/ios-p0 (branch feat/ios-p0-golden-fixtures). NEVER push, never open PRs, never touch web/prod config, never commit Secrets.plist/DevSession.plist.
- Only edit files in YOUR assigned area. If you must touch another area, keep the change minimal and mention it in your report.
- Commit with pathspec (`git commit -m ... -- <paths>`), message trailer `Co-Authored-By: Claude Sonnet 5.5 <noreply@anthropic.com>`.
- Builds: take lock dir `ios/build/.buildlock` (mkdir to acquire, rmdir to release; stale if >12 min old and no xcodebuild running -> rmdir), single derived data `ios/build/dd-shared`. Prefer package tests (`ios/scripts/test-packages.sh` / xcodebuild test on the relevant package scheme) over full app builds; do one app build at the end.
- Swift 6, packages default to MainActor isolation: any closure UIKit/SwiftUI may call off-main (UIColor providers, Shape paths, Layout) must be nonisolated/@Sendable (this caused a real crash).
- Keep i18n through `ios/i18n/ios.{en,es}.json` + `node ios/scripts/gen-i18n.mjs` (--check must stay clean).
- Add/adjust unit tests for logic. Report: files changed, tests run + results, anything left undone.
