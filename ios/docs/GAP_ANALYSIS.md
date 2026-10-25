# Capo web vs native iOS: gap analysis

Date: 2026-10-24. Branch `main` (HEAD `eca3d8e`). Read-only audit; every row was checked against code, not against the older docs (`WEB_PARITY_ANALYSIS.md`, `STATUS.md`, `PLAN.md`), which were used only as a map.

Path shorthands (all relative to `/Users/mfuentesg/code/capo`):

- `UI/` = `ios/Packages/CapoUI/Sources/`
- `DATA/` = `ios/Packages/CapoData/Sources/`
- `SB/` = `ios/Packages/CapoSupabase/Sources/CapoSupabase/`
- `CORE/` = `ios/Packages/CapoCore/Sources/`
- `KIT/` = `ios/Packages/CapoAppKit/Sources/CapoAppKit/`
- `MIG/` = `supabase/migrations/`
- Web paths are written from the repo root (`features/...`, `app/...`, `lib/...`).

Status legend: DONE, PARTIAL, MISSING, DIVERGENT (by design or neutral difference), BUG (iOS does the wrong thing, or a web defect that hits iOS data), N/A (not applicable). Size: S under 1 day, M 1-3 days, L over 3 days.

Scope notes: `features/api-tokens` and `/api/v1/songs` are out of scope (local-only work). Web `features/activity` (feed, realtime on `activity_log`) and the presence/collaboration hooks are not rendered anywhere in the web UI (no consumer of `ActivityFeed` or `usePlaylistPresence`; `use-playlist-presence.ts` and `use-team-realtime.ts` are commented-out stubs), so they are N/A rather than gaps. Product decision recorded in `ios/docs/WAVE_PARITY_RULES.md:4`: guitar only, no ukulele.

---

## 1. Executive summary

### 1.1 Counts

Counts are of matrix rows in section 2 (see the last line of this file for the command that reproduces them).

| Status | Rows |
|---|---|
| DONE | 64 |
| PARTIAL | 14 |
| MISSING | 8 |
| DIVERGENT | 23 |
| BUG | 17 |
| N/A | 2 |
| Total | 128 |

Backlog (section 4): 28 work items = P0 8, P1 11, P2 9 (IDs GAP-011 and GAP-027 are merged into other items and kept only as pointers).

### 1.2 Top 10 priorities

1. GAP-001 (P0, BUG): rejected or silently dropped outbox operations are never surfaced and are rolled back by the next pull. Playlist, tag, delete and archive writes use `returning: .minimal` and treat "0 rows affected by RLS" as success (`SB/Remote/SupabaseRemoteWriter.swift:28,33,48,53,61,212`). Failed ops are not protected from pull overwrite (`DATA/CapoStore/Database/GRDBSyncStore.swift:128-137`) and have no UI to review, retry or discard.
2. GAP-002 (P0, BUG): wrong write-permission model. Role comes from the view filter, not from the item (`UI/CapoShellUI/ContextStore.swift:54-57`, `ShellEnvironment.swift:16`), so in "All" every team item looks editable, and `member` is offered delete although RLS needs `admin` for team songs and playlists (`MIG/20260213023343_consolidate_permissive_rls_policies.sql:147-160,266-279`).
3. GAP-003 (P0, BUG, web): the web column toggle overwrites the whole `profiles.preferences` JSON (`features/songs/api/user-preferences-api.ts:93-113`), wiping `chordHand`, `palette`, `uiFont`, `theme`, `locale`, which iOS also reads. Fix on the web side.
4. GAP-004 (P0, BUG): the song picker used by the playlist detail ignores the playlist's bucket, so personal songs can be added to team playlists (`UI/CapoLibraryUI/SongPickerView.swift:11`; the web filters, `features/playlists/components/playlist-detail/add-songs-sheet.tsx:54-65`). Teammates cannot read those songs.
5. GAP-005 (P0, MISSING): Sign in with Apple (App Store 4.8) and shipping account deletion (5.1.1v). Both are release blockers (`ios/HUMAN_TODO.md` items 4 and 5, `UI/CapoShellUI/ShellSettings.swift:10`).
6. GAP-006 (WON'T DO, links stay web-only): no universal links and no in-app handler for `https://<host>/shared/<code>` or `/teams/accept-invitation?token=`. `Info.plist` has only the `capo://` scheme and no associated domains.
7. GAP-007 (P0, BUG): the share sheet depends on the `ensure_share_code` RPC, which now requires edit permission. Viewers and offline users cannot share a link that is already in the local row (`KIT/CapoComposition.swift:128-130`, `UI/CapoTeamsUI/PlaylistShareSheet.swift:79-96`). The fallback `ShareSheetView` has no private-playlist check (`UI/CapoPlaylistsUI/PlaylistDetailView.swift:725-731`).
8. GAP-008 (P0, BUG): decline invitation deletes the row, but RLS only lets owner or admin delete (`MIG/20251224171732_rls_policies.sql:241`), so decline silently does nothing. Pending invitations are also filtered by RLS to teams where the user is already a member (`MIG/20251224171732_rls_policies.sql:216-221`), so the invitee's list is probably empty on web and iOS (verify on production).
9. GAP-009 (P1, BUG): song tag filter uses OR semantics (`DATA/CapoStore/Repositories/SongRepository.swift:174-182`); the web uses AND (`features/songs/components/song-list/song-list.tsx:62-64`).
10. GAP-010 (P1, MISSING): no bucket selector when creating songs and playlists (web `song-draft-form.tsx:229`, `playlist-create-form.tsx:108`), and no viewer guard for the creation bucket. In "All", a user whose last bucket is a viewer team creates content that the server rejects and the next pull deletes.

### 1.3 Items already known

| Item | Status | Evidence |
|---|---|---|
| Share URL `/shared/<code>` | DONE | `KIT/CapoComposition.swift:132-134` |
| Creation context survives "All" | DONE | `UI/CapoShellUI/ContextStore.swift:18-22,64-76`; not role-checked (GAP-010) |
| Draft survives dialog close and is reorderable | DONE | `UI/CapoPlaylistsUI/AddToPlaylistView.swift:5-9,98` |
| Lyrics unicode normalization (iOS only) | DIVERGENT | `CORE/CapoChordPro/Engine/LyricsText.swift`; web `song-pipeline.ts` has none (GAP-021) |
| `ensure_share_code` permission check | DONE in repo, deployment unverified | `MIG/20261025015742_restrict_ensure_share_code_to_editors.sql` (commit `86592d7`; the working tree shows further edits). Side effect on iOS: GAP-007 |
| Private-playlist check in fallback `ShareSheetView` | BUG | `UI/CapoPlaylistsUI/PlaylistDetailView.swift:672-735`; the shell path `PlaylistShareSheet` has the check (`PlaylistShareSheet.swift:15-26,97-112`) |
| `share_expires_at` ignored | PARTIAL, low impact | The web only filters public reads on it (`features/playlists/api/playlistsApi.ts:252`) and never writes it. iOS stores it (`Rows.swift:100`) and never reads it (GAP-020) |
| Universal links | MISSING | GAP-006 |
| Editor uses Geist Mono | DONE | commit `810eee6` |
| Draggable floating single button for performance controls (request a) | DONE in commit `eca3d8e`, residual gaps | `UI/CapoPerformanceUI/FloatingControls.swift`, `SongPerformanceView.swift:241-242,296-345`. Missing: lyrics-visibility toggle in the dock and panel, per-orientation memory (GAP-017) |

---

## 2. Feature matrix

Columns: Item | Web (file:line) | iOS (file:line) | Status | Gap or notes | Size.

### 2.1 Songs library (`features/songs`, `UI/CapoLibraryUI`)

| Item | Web | iOS | Status | Gap or notes | Size |
|---|---|---|---|---|---|
| List query by context (personal/team/all) | `features/songs/api/songsApi.ts:153-217` | `DATA/CapoStore/Repositories/SongRepository.swift:148-203` (`ContextFilter`) | DONE | Local SQLite mirror of scoped rows | - |
| Default order | created_at desc `songsApi.ts:165` | `LibraryFilters.swift:53-65`; table sort `SongTableLogic.swift:5-84` | DIVERGENT | iOS adds column sorting and an A-Z scrubber (`SongTableLogic.swift:87-132`); web has no sort UI | - |
| Search | server FTS prefix `songsApi.ts:139-151`, debounce 300 ms `songs-client.tsx:188-193` | local FTS5 `SongRepository.swift:153-160`, debounce 150 ms `LibraryFilters.swift:121` | DONE | Both cover title, artist, notes, lyrics (`MIG/20260327190108_add_full_text_search_to_songs.sql:5-8`) | - |
| Status filter | none (all statuses shown) | default `[published, draft]` `LibraryFilters.swift:46` | DIVERGENT | `archived` songs hidden on iOS; the web UI cannot set `status` at all (GAP-029) | S |
| BPM filter | slow <100, medium 100-140, fast >140 `song-list.tsx:53-61` | same `LibraryFilters.swift:6-21` | DONE | Web badges use 90/120 (web inconsistency, GAP-022) | - |
| Tag filter semantics | AND (`every`) `song-list.tsx:62-64` | OR (`tag_id IN`) `SongRepository.swift:174-182` | BUG | GAP-009 | S |
| Group by | none/key/artist `songs-client.tsx:468-490` (`bucket` exists only in the type, `song-list.tsx:83-86`) | none/key/artist `LibraryFilters.swift:24-41` | DONE | iOS sorts groups with `localizedStandardCompare`, empty last | - |
| Active filter count, clear all | `songs-client.tsx:288-300` | `LibraryFilters.swift:73-87` | DONE | | - |
| Row badges: key, BPM tier icon and colour, tags, played-frequency, ownership chip | `song-item.tsx:100-140`, `lib/badge-colors.ts` | `UI/CapoLibraryUI/SongBadges.swift:5-70`, `SongRow.swift`, `SongTableRow.swift` | DONE | Icon tiers 90/120, colour tiers 90/130 ported | - |
| Played-frequency scope | per creation context (personal or one team) `playlistsApi.ts:757-781`, `use-song-frequencies.ts:11-19` | all playlists in local DB `SongRepository.swift:115-117` | DIVERGENT | iOS counts every visible playlist, including archived; numbers differ (GAP-027) | S |
| Add-to-draft toggle on rows | `song-list.tsx:44` | Select mode `LibraryView.swift:30-40` | DIVERGENT | iOS-style selection bar, equivalent | - |
| Create song validation | form: title, artist, key required, BPM 40-300 `song-draft-form.tsx:55-110`; zod `actions.ts:41-52` | title only, BPM 1-400 `UI/CapoEditorUI/EditorLogic.swift:36-45` | DIVERGENT | Looser on iOS; no length caps (title 200, key 12, notes 10k, lyrics 100k). GAP-018 | S |
| Creation bucket picker | `BucketSelector` `song-draft-form.tsx:229`, `features/app-context/components/bucket-selector.tsx` | none; uses `creationContext` `SongEditorView.swift:13,180` | MISSING | GAP-010 | M |
| Creation bucket default, kept when view = All | `app-context/context.tsx:219-245` | `ContextStore.swift:18-22,64-83` | DONE | Persisted separately (`capo.creation.<uid>`) | - |
| Edit details (title, artist, key, BPM) | `song-detail.tsx:211-260`, `song-edit-dialog.tsx:57-96` | `SongEditorView.swift:241-262` | DONE | Web inline BPM clamp 20-500 but zod max 400 (web bug, GAP-022) | - |
| Song-level transpose/capo defaults | read-only on web (`songsApi.ts:69-80` omits them) | writable `Rows.swift:78-79`, `SongEditorView.swift:254` | DIVERGENT | iOS can author them; web only consumes | - |
| Per-user transpose/capo/font | `use-user-song-settings.ts:33-58`, ranges `use-lyrics-settings.ts:24-98` | `CORE/CapoCore/Models/Preferences.swift:154-176`, `PerformanceLogic.swift:6-44`, upsert `SupabaseRemoteWriter.swift:36-43` | DONE | Debounced 500 ms `SongPerformanceModel.swift:144-150` | - |
| Display-settings reset | per field to 0 / 1 `use-lyrics-settings.ts:46-48,66-69` | to song's authored values `SongPerformanceModel.swift:89-104` | DIVERGENT | Reasonable | - |
| Tags: create (name + colour), delete, assign | `tag-selector.tsx`, `actions.ts:107-129` | `UI/CapoLibraryUI/TagSheets.swift:18-100`, ops `.createTag/.deleteTag/.setSongTags` | DONE | Unique names by index (`MIG/20260527000000_add_song_tags.sql:17-19`) | - |
| Tag assignment write | delete then insert `tags-api.ts` | delete then insert `SupabaseRemoteWriter.swift:106-116` | BUG | If the insert is rejected the delete has already happened (server tags lost). GAP-001 | S |
| Tag delete via RLS | `deleteTagAction` | `SupabaseRemoteWriter.swift:32-35` (`.minimal`) | BUG | Zero rows treated as applied. GAP-001 | S |
| Transfer personal song to team | `songsApi.ts:327-339` (guard `team_id is null`), `transfer-to-team-dialog.tsx:20-101` | patch `teamID` `Rows.swift:81-84`, `UI/CapoTeamsUI/TransferSongToTeamSheet.swift:85` | DONE | Both leave personal tags behind (open question 14) | - |
| Delete song | `song-detail.tsx:417-450`; RLS admin for team songs | editor delete `SongEditorModel.swift:85`, gating `role?.canEditContent` | BUG | Member offered delete; server needs admin; result is a silent restore at next pull. GAP-002 | S |
| CifraClub import | server action, 10/min limit `actions.ts:259-317`, `utils/cifraclub/parse-html.ts` | client-side `UI/CapoEditorUI/CifraClub/*` | PARTIAL | Golden fixtures pass; not verified live (STATUS.md: 403 from dev machine); no throttle (GAP-029) | S |
| Song status draft/archived | column `MIG/20251224171705_core_schema.sql:7` | enum `CORE/CapoCore/Models/Songs.swift:3-5` | DIVERGENT | No UI to set it on either side | - |

### 2.2 Lyrics view, performance, editor (`features/lyrics-editor`, `UI/CapoPerformanceUI`, `UI/CapoEditorUI`, `UI/CapoRendering`, `CORE/CapoChordPro`)

| Item | Web | iOS | Status | Gap or notes | Size |
|---|---|---|---|---|---|
| ChordPro parse and render | `utils/song-pipeline.ts:1-640` | `CORE/CapoChordPro/*`, golden fixtures `ios/Fixtures` | DONE | Golden tests | - |
| Unicode normalization (U+00B4, decomposed accents) | absent | `CORE/CapoChordPro/Engine/LyricsText.swift` | DIVERGENT | Same song renders differently on web. GAP-021 | S |
| Transpose ±6, capo 0-12, font 0.5-3 step 0.25 | `use-lyrics-settings.ts` | `PerformanceLogic.swift:21-38` | DONE | | - |
| Columns 1/2 persisted | `lyrics-view.tsx:166-171` | `SongPerformanceModel.swift:127-132` | DONE | iOS merge-safe; web overwrites (GAP-003) | - |
| Chords / lyrics visibility (not persisted, never both off) | `lyrics-view.tsx:152-153,504-518` | `SongPerformanceModel.swift:115-125`, `DisplaySettingsLogic.swift:57-61`, `LyricsHeader.swift:506` | DONE | | - |
| Modified dot and chips | `lyrics-view.tsx:843-848` | `DisplaySettingsLogic.swift:5-47` | DONE | | - |
| Auto-scroll 10-300 step 10, default 30, BPM-inferred, stops at bottom | `lyrics-view.tsx:56-60,319-351`, `hooks/use-auto-scroll.ts` | `PerformanceLogic.swift:47-76`, `PerformanceScrollView.swift` | DONE | Web runs it in page mode only; iOS everywhere, plus Reduce Motion stepping (`PerformanceLogic.swift:92-98`) | - |
| Prev/next with n/total, swipe | `lyrics-view.tsx:781-810,300-306` | `SetlistPerformanceView.swift`, `SongQueueViews.swift` | DONE | iOS adds queue overlay | - |
| Floating controls | fixed bars, not movable `lyrics-view.tsx:778-860` | dock `SongPerformanceView.swift:296-326`; draggable button `FloatingControls.swift:1-68`; math `StageLogic.swift:35-80` | DONE | Request (a). Residual: GAP-017 | - |
| Dock and floating panel content | popover `lyrics-view.tsx:360-500` | `StageComponents.swift:240-470` (steppers, font, columns, chords, play, speed) | PARTIAL | No lyrics-visibility toggle in dock, panel or fullscreen (only `LyricsHeader.swift:506`). GAP-017 | S |
| Fullscreen stage, hardware keys, page turner | none | `SongPerformanceView.swift`, `PerformanceLogic.swift:109-141` | DIVERGENT | iOS-only | - |
| Share lyrics text | `buildShareText` `lyrics-view.tsx:62-90,249-269` | `ShareLink` in `LyricsHeader.swift` | DONE | Add parity test (GAP-021) | S |
| Edit lyrics | autosave `lyrics-view.tsx:178-190`, preview, wand, import | explicit Save `SongEditorView.swift:178-186`, wand `:204`, import `:210`, reference `:214`, split preview `:121-123` | DIVERGENT | Explicit save with dirty tracking and discard confirm | - |
| Section wrap toolbar, paste conversion | `section-wrap-toolbar.tsx`, `paste-convert-extension.ts` | `SectionWrapToolbar.swift`, `SectionWrap.swift`, `LyricsEditorController.swift` | DONE | | - |
| Editor font and highlighting | `chordpro-lang.ts` | `LyricsTextView.swift` | DONE | Geist Mono (commit `810eee6`) | - |
| ChordPro reference | `chordpro-reference.tsx` | `UI/CapoEditorUI/Reference/*` | DONE | | - |
| Chord tap diagram and pager | `chord-diagram.tsx:215-298` | `UI/CapoRendering/Diagrams/ChordDiagramView.swift:99-319` | DONE | | - |
| Diagram fallbacks | `chord-diagram.tsx:280-301` | `ChordFingering.swift`, `ChordDatabase.swift` | DONE | Check "Generated" subtitle parity | S |
| Chord audio | `features/chord-audio/*` | none | MISSING | GAP-019 | M |
| Section collapse, repeat/extend | `rendered-song.tsx` | `RenderParts.swift`, `ChordProContentView.swift:6` | DONE | | - |
| Edit permission in lyrics view | `readOnly` only on shared page `playlist-share-view.tsx:176-178` | `SongPerformanceView.swift:231` (`?? true`) | BUG | View-context role. GAP-002 | S |
| Setlist performance | none | `SetlistPerformanceView.swift:1-332` | DIVERGENT | iOS-only | - |

### 2.3 Playlists and draft (`features/playlists`, `features/playlist-draft`, `UI/CapoPlaylistsUI`)

| Item | Web | iOS | Status | Gap or notes | Size |
|---|---|---|---|---|---|
| Playlist list by context | `playlistsApi.ts:116-175` created_at desc | `PlaylistRepository.swift:10-33` date desc then created_at desc | DIVERGENT | Dated setlists first on iOS | - |
| Search, visibility filter | `playlist-list.tsx:56-68` | `PlaylistLogic.swift:8-30`, `PlaylistsView.swift:155-165` | DONE | | - |
| Archived display | inline, dimmed, badge `playlist-item.tsx:44,106` | Active/Archived tabs `PlaylistsView.swift:76,161` | DIVERGENT | Tabs | - |
| Archive / unarchive | `playlistsApi.ts:571-596` | `PlaylistRepository.swift:119-129`, op `SupabaseRemoteWriter.swift:51-57` | DONE | RLS silent drop (GAP-001) | - |
| Create (name, date, bucket, suggest name) | `playlist-create-form.tsx:45-64,108` | `PlaylistFormView.swift:14-92` | PARTIAL | No bucket picker (GAP-010), no suggest name (GAP-023) | S |
| Create defaults | private, pre-generated share_code `playlistsApi.ts:386-398` | `PlaylistRepository.swift:66-70`, code at push `SupabaseRemoteWriter.swift:157` | DONE | Same alphabet `:148` | - |
| Name and description caps | zod 200 / 2000 `actions.ts:54-61` | trimmed non-empty `PlaylistRepository.swift:57-58` | PARTIAL | GAP-018 | S |
| Inline edit name and description | `playlist-detail.tsx:159-256,398-417` | `PlaylistDetailView.swift:378-429` | DONE | | - |
| Date picker | `playlist-detail.tsx:425-457` | `PlaylistDetailView.swift:433-467` | DONE | | - |
| Public, guest-edit, URL copy/open | `playlist-detail.tsx:471-540` | `PlaylistDetailView.swift:472-553` | DONE | Public off clears guest editing on both | - |
| Share code ensured when public | client check `playlistsApi.ts:480-495`, RPC `:732-744` | `SupabaseRemoteWriter.swift:204-210`, `PlaylistDetailView.swift:502-505` | DONE | | - |
| Guest editing enforcement | UI flag only; no RLS reference (`MIG/20260216000100_fix_playlist_share_code_and_guest_editing.sql:4` is the only mention) | stored `Rows.swift:90` | DIVERGENT | Dead feature on web (open question 5) | - |
| Add songs picker | bucket-filtered `add-songs-sheet.tsx:54-65`, filters `:72-93` | `SongPickerView.swift:11` uses view context | BUG | GAP-004 | S |
| Add songs persistence | bulk insert at max+1 `playlistsApi.ts:628-655` | one op per song, RPC `add_song_to_playlist` `SupabaseRemoteWriter.swift:217-227` | DONE | RPC checks `member` (`MIG/20260610120000_harden_add_song_to_playlist_authorization.sql`) | - |
| Remove song | `playlist-detail.tsx:312-338` | `PlaylistRepository.swift:151-168` | DONE | RLS silent drop (GAP-001) | - |
| Reorder | dnd, two-phase `playlistsApi.ts:684-720` | `PlaylistDetailView.swift:314-320,353-359`; `SupabaseRemoteWriter.swift:230-247` | DONE | Concurrent add can hit unique `(playlist_id, position)`; unclassified error retries forever (GAP-001) | - |
| Count and date pills | `playlist-detail.tsx:462-467` | `PlaylistDetailView.swift:165-176` | DONE | | - |
| Open song from playlist | lyrics sheet with prev/next and "edit details" `playlist-detail.tsx:340-371,682-745` | `actions.performSetlist` `PlaylistDetailView.swift:202,311` | PARTIAL | No "edit song details" from the playlist (only via header edit) | S |
| Delete playlist | `playlist-detail.tsx:635-680` | `PlaylistDetailView.swift:327-349` | BUG | Members offered delete; RLS needs admin. GAP-002 | S |
| Share button | link in privacy block | `PlaylistDetailView.swift:213-236` → `PlaylistShareSheet` | PARTIAL | GAP-007 | S |
| Pin for offline | none | `PlaylistRepository.swift:184-195` | DIVERGENT | iOS-only marker | - |
| Draft cart (toggle, reorder, remove, clear, new vs existing, name, duplicate toast) | `draft.context.tsx:1-85`, `components/layout/draft-indicator.tsx:27-60` | `AddToPlaylistView.swift:1-235` | DONE | In-memory on both; cross-bucket songs unchecked on both (GAP-004) | - |
| Realtime | `use-playlist-realtime.ts:32-68` | one channel, 9 tables, debounce 1 s `SyncEngine.swift:134-145` | DONE | | - |

### 2.4 Playlist sharing (`features/playlist-sharing`, `app/(app)/shared/[shareCode]`)

| Item | Web | iOS | Status | Gap or notes | Size |
|---|---|---|---|---|---|
| Public page `/shared/<code>`, anonymous allowed | `app/(app)/shared/[shareCode]/page.tsx`, `playlistsApi.ts:243-252` | none (Safari) | MISSING | GAP-024 | L |
| Link format | `playlist-share-view.tsx:198` | `KIT/CapoComposition.swift:132-134` | DONE | | - |
| Universal links, URL router | n/a | `Info.plist` only `capo://`; `onOpenURL` only for auth `KIT/CapoAppScene.swift:17-19` | MISSING | GAP-006 | M |
| Share sheet needs online RPC | code already on row | `PlaylistShareSheet.swift:79-96` | BUG | GAP-007 | S |
| Private-playlist guard | n/a | shell sheet yes `PlaylistShareSheet.swift:15-26`; fallback no `PlaylistDetailView.swift:672-735` | BUG | Fallback is unreachable today (`ShellNavigation.swift:112`) | S |
| `share_expires_at` | read filter `playlistsApi.ts:252`; policy `MIG/20260213023343_consolidate_permissive_rls_policies.sql:175-190` | parsed, never evaluated | PARTIAL | GAP-020 | S |
| Realtime on shared page | `use-public-playlist-realtime.ts:63-89` | n/a | MISSING | In GAP-024 | - |
| Reorder and owner toggles on shared page | `playlist-share-view.tsx:122-144,207-221` | detail page only | PARTIAL | In GAP-024 | - |

### 2.5 Teams (`features/teams`, `UI/CapoTeamsUI`)

| Item | Web | iOS | Status | Gap or notes | Size |
|---|---|---|---|---|---|
| List, search, counts | `teams-client.tsx`, `team-card.tsx` | `TeamsView.swift`, `TeamCard.swift` | DONE | Web order joined_at desc `teamsApi.ts:58`; iOS by name `ContextStore.swift:90` | - |
| Create (RPC `create_team_with_owner`) | `teamsApi.ts:116-130` | `SB/Teams/SupabaseTeamsRemote.swift:52-65`, `TeamIconPicker.swift` (80 icons) | DONE | Online-only on both | - |
| Edit name / icon | `team-detail-header.tsx` | `SupabaseTeamsRemote.swift:67-78` | DONE | | - |
| Role matrix | `constants.ts:28-100` | `TeamPermissions.swift:1-27` | DONE | Identical rules | - |
| Invite (RPC `invite_team_member`) | `teamsApi.ts:279-294` | `SupabaseTeamsRemote.swift:94-110`, `TeamDetailView.swift:515-528` | PARTIAL | Email check is `contains("@")`, web uses `emailSchema` | S |
| Invitations list, copy link, cancel | `team-members-section.tsx:162-173,304-347` | `TeamDetailView.swift:240-285,433` | DONE | | - |
| Resend invitation | delete then invite `use-teams.ts:566-584` | `TeamsModel.swift:174-180` | DIVERGENT | Non-atomic on both (GAP-008) | S |
| Remove member, leave, transfer, delete team | `teamsApi.ts:149-160,266-308`, `team-danger-zone.tsx` | `SupabaseTeamsRemote.swift:80-156`, `TeamDetailView.swift:313-369` | DONE | iOS has transfer-and-leave | - |
| My pending invitations | `teamsApi.ts:320-351` | `SupabaseTeamsRemote.swift:40-50`, `PendingInvitationsView.swift` | BUG | RLS select limited to team members (`MIG/20251224171732_rls_policies.sql:216-221`); invitee outside the team sees none. Verify on production. GAP-008 | M |
| Accept via RPC | `acceptTeamInvitation` | `SupabaseTeamsRemote.swift:119-127` | DONE | | - |
| Decline | not on web | `TeamsModel.swift:219-226` | BUG | RLS delete admin-only (`rls_policies.sql:241`); returns success with 0 rows. GAP-008 | S |
| Accept link, signed-out cookie flow | `accept-invitation-client.tsx:35-71,138-142` | none | MISSING | GAP-006 | M |
| Team context pill and switcher | `app-context/context.tsx` | `ContextPicker.swift`, `ContextStore.swift` | DONE | | - |
| Account deletion cascades to created teams | `MIG/20260311185040_add_delete_user_account_function.sql:1-6` | same RPC | DIVERGENT | Open question 6 | S |

### 2.6 Settings (`features/settings`, `UI/CapoSettingsUI`)

| Item | Web | iOS | Status | Gap or notes | Size |
|---|---|---|---|---|---|
| Profile card | `profile-settings.tsx:15-52` | `SettingsView.swift:186-200` | DONE | | - |
| Theme | `theme-settings.tsx` (RPC per key) | `SettingsView.swift:323-340` | DONE | iOS read-merge-write (GAP-012) | - |
| Palette (12), Surprise me, UI font (12) | `palette-settings.tsx`, `font-context.tsx` | `AppearanceCards.swift`, `ShellModel.swift:49-61` | DONE | | - |
| Language en/es | `language-settings.tsx` | `SettingsView.swift:341-356` | PARTIAL | Restart needed (GAP-025) | M |
| Chord hand | `chord-hand-settings.tsx` | `SettingsView.swift:357-370` | DONE | | - |
| Default columns | lyrics view only | `SettingsView.swift:206` | DIVERGENT | iOS convenience | - |
| Delete account | `account-danger-zone.tsx:8-53` | `SettingsView.swift:410-420`, Debug only `ShellSettings.swift:10` | PARTIAL | GAP-005 | S |
| Sign out | menu | keep or erase local data `MainShellView.swift:71-83` | DIVERGENT | iOS-only choice | - |
| Sync section, conflicts, environment rows | none | `SettingsView.swift:236-262,398-408` | DIVERGENT | iOS-only | - |
| Preferences JSON storage | `profiles.preferences` | `Preferences.swift:49` | BUG | Web overwrite. GAP-003 | S |
| API tokens | `features/api-tokens` | n/a | N/A | Out of scope | - |
| Feedback (landing page only) | `features/feedback/api/actions.ts:20-87` | none | MISSING | GAP-026 | S |

### 2.7 Auth, shell, routes (`features/auth`, `features/app-context`, `app/`)

| Item | Web | iOS | Status | Gap or notes | Size |
|---|---|---|---|---|---|
| Google OAuth PKCE | `login-form.tsx:46-119` | `SB/Auth/SupabaseAuthService.swift:49-60` | DONE | Callback `capo://auth/callback` | - |
| Sign in with Apple | n/a | none | MISSING | GAP-005 | M |
| Email/password | disabled `login-form.tsx:128-170` | Debug only `AuthView.swift:71` | DIVERGENT | Dev fallback | - |
| Offline session restore | n/a | `SupabaseAuthService.swift:21-45` | DONE | | - |
| Shell tabs, context pill, avatar menu | navbar and drawer | `MainShellView.swift:105-252`, `AvatarMenu.swift` | DONE | Cmd-1..4 `:160-170` | - |
| Context change recreates shell | `router.refresh()` | `.id(model.context)` `MainShellView.swift:23` | DIVERGENT | Drops navigation state (GAP-016) | S |
| View filter persistence | cookie + localStorage `context.tsx:99-107,237-244` | `ContextStore.swift:33-43,78-83` | DONE | | - |
| Chords glossary and analyzer | `features/chords/*` | `UI/CapoChordsUI/*` | DONE | | - |
| Dashboard redirect, landing, login pages | `app/(app)/dashboard/page.tsx`, `app/(public)/*` | n/a | N/A | | - |

### 2.8 Data layer, offline and sync (iOS correctness)

| Item | Web | iOS | Status | Gap or notes | Size |
|---|---|---|---|---|---|
| Optimistic write + outbox, per-entity FIFO | React Query | `DATA/CapoStore/Outbox/Outbox.swift`, `DATA/CapoSync/SyncEngine.swift:231-267` | DONE | Compaction and add/remove cancel-out | - |
| Song update concurrency | last write wins | `updated_at` compare-and-set `SupabaseRemoteWriter.swift:82-98`, `ConflictsView.swift` | DONE | iOS ahead; only songs have conflicts | - |
| Rejected op handling | toast | state `failed`, no UI, overwritten by pull `GRDBSyncStore.swift:75-78,128-137` | BUG | GAP-001 | M |
| RLS zero-row writes | n/a | `returning: .minimal` `SupabaseRemoteWriter.swift:28,33,48,53,61,212` | BUG | GAP-001 | M |
| Unclassified permanent errors | n/a | `SB/Remote/RemoteSupport.swift:54-63` maps only 42501, PGRST30x, 23514, 22P02, 23502, 23503, 401/403 | BUG | e.g. 23505 on reorder loops with backoff to 300 s and blocks that entity. GAP-001 | S |
| Local rows missing remotely are purged | n/a | `SyncEngine.swift:323-334`, skip only pending/inflight/conflict | BUG | Failed creates vanish. GAP-001 | - |
| Preferences write | RPC per key, atomic `MIG/20260311185041_add_merge_user_preference_function.sql` | read then update `SupabaseRemoteWriter.swift:133-144` | PARTIAL | Lost-update window; RPC takes TEXT only, so numeric `lyricsColumns` needs a new RPC (GAP-012) | S |
| Pull strategy | n/a | id+updated_at diff for songs/playlists; full refetch of entries, tags, assignments, settings, profile `SyncEngine.swift:275-321` | PARTIAL | O(n) per tick (GAP-014) | M |
| Realtime reconnect | per hook | one-shot subscribe `SupabaseRealtimeNotifier.swift:25-43` | PARTIAL | No resubscribe on drop (GAP-015) | S |
| Sync triggers | n/a | foreground `MainShellView.swift:30-32`, reachability, outbox growth, realtime | DONE | | - |
| Offline create idempotent replays | n/a | `SupabaseRemoteWriter.swift:70-80,154-191` | DONE | | - |
| Offline share link | n/a | RPC required | BUG | GAP-007 | S |
| Per-user DB, erase on sign-out | n/a | `KIT/CapoComposition.swift:71-110` | DONE | | - |
| Server timestamps as raw strings | n/a | `ServerTimestamp`, `RowsDriftTests` | DONE | Keep `LocalE2ETests` in CI | - |
| Types drift guard | `lib/supabase/database.types.ts` | `Rows.swift` + drift tests | DONE | Re-run after migrations | - |

### 2.9 iOS-only features (keep)

| Feature | Where |
|---|---|
| Fullscreen stage, title pill, progress rail | `SongPerformanceView.swift`, `StageComponents.swift` |
| Setlist performance paging | `SetlistPerformanceView.swift` |
| Hardware keyboard and Bluetooth page-turner keys | `PerformanceLogic.swift:109-141` |
| Floating draggable controls and dock collapse | `FloatingControls.swift`, `StageLogic.swift` |
| Reduce Motion stepped auto-scroll | `PerformanceLogic.swift:92-98` |
| External display scene | `KIT/ExternalDisplay.swift`, `Info.plist` |
| Idle timer disabled while performing | `SongPerformanceView.swift` |
| Song conflict resolution (keep mine, theirs, both) | `UI/CapoEditorUI/ConflictsView.swift` |
| Offline pins, sync status button, erase-on-sign-out, demo mode | `PlaylistRepository.swift:184`, `UI/CapoDesign/Components.swift:111-150`, `KIT/CapoComposition.swift:13-19` |
| Column-sortable songs table, A-Z scrubber, select mode | `SongTableLogic.swift` |

---

## 3. Feature sections: logic and actions

### 3.1 Songs

Screens (web): library list (search, filters popover, group-by, tag chips, cart, create, CifraClub import), detail panel or drawer (inline edit, transpose, capo, tags, transfer, delete), lyrics view.

Actions and iOS counterpart:

- Create: web `handleCreateNewSong` (`songs-client.tsx:226-237`), bucket from `creationBucket`. iOS `actions.openEditor(.create)` then `SongRepository.create` (`SongRepository.swift:35-56`). Bucket picker missing.
- Edit fields: web saves each field on commit; iOS saves the form diff (`EditorLogic.swift:72-85`).
- Delete: confirm dialog on both.
- Transfer personal song to team: both.
- Tag create, delete, assign: both.
- Cart: per-row on web, Select mode on iOS.

Rules to preserve:

- Ownership is exclusive (`songs_owner_xor`); `created_by` always set.
- RLS: insert and update need `member`; delete needs `admin` for team songs; own songs always.
- Update mapping clears a column when the value is empty (`value || null`); BPM 0 clears.
- Server zod limits: title 1-200, artist ≤200, key ≤12, bpm int 0-400, lyrics ≤100k, notes ≤10k, transpose ±11, capo 0-24 (`actions.ts:41-52`). UI ranges are tighter (transpose ±6, capo 0-12).
- Per-user settings override song defaults; `fontSize` is a scale factor, default 1.
- Search is prefix match over title, artist, notes, lyrics.

Data operations (web): `songs` select with `song_tag_assignments(song_tags(...))` embed, `user_song_settings` upsert, realtime on `songs` and `user_song_settings` (`use-song-realtime.ts`). iOS replaces them with the sync engine and the same tables.

### 3.2 Lyrics view

Controls on web and iOS: font, transpose, capo, columns, chords/lyrics visibility, auto-scroll (speed inferred as `scrollableHeight / (lines * 4 / (bpm / 60))`, clamped 10-300), prev/next, share text, edit, section collapse, chord diagram. All exist on iOS; deltas: lyrics toggle missing from the dock, chord audio missing.

Floating controls (request a, already shipped): 60 pt circular button, draggable inside the lyrics area, stored as fractions in `AppStorage` (`ios.stage.floatingControls.x/.y`), panel opens above or below depending on the half. Switch between dock and floating with the arrows button (`SongPerformanceView.swift:296-326`) and the "Dock controls" button. Residual list in GAP-017.

### 3.3 Playlists and draft

- Share code is pre-generated at creation (12 chars `A-Z0-9`). Public requires a code (DB check `playlists_public_requires_share_code`, `MIG/20251224171705_core_schema.sql:144`).
- Public off also turns guest editing off.
- Reorder is two-phase (+10000 offset) because of unique `(playlist_id, position)`.
- Add uses RPC `add_song_to_playlist` (appends at max+1, ignores duplicates, requires `member`).
- Songs of a playlist should belong to the playlist's bucket (enforced only by the web picker).
- RLS: insert and update `member`; delete `admin` for team playlists; public read until `share_expires_at`.
- Frequency badge: count and last played use playlist `date` else `created_at`; recent window 14 days (`song-frequency.ts:19-72`).

### 3.4 Sharing

The web page works signed-out, has Open Graph metadata, lets owners or team members edit lyrics (`playlist-share-view.tsx:176-178`) and reorder when logged in or when guests are allowed. iOS has no counterpart. Minimum viable iOS: universal link opens the app; if the playlist is already synced, open it; else show a read-only view fetched by code (anonymous read works through `getPublicPlaylistByShareCode`).

### 3.5 Teams and invitations

Role matrix is identical. Gaps: invitation discovery (RLS), decline, links, atomic resend.

### 3.6 Settings

`profiles.preferences` keys: `lyricsColumns` (1|2), `locale`, `theme`, `chordHand`, `palette`, `uiFont`. All string keys can use `merge_user_preference`; numeric `lyricsColumns` cannot.

### 3.7 i18n

Web strings: `lib/i18n/locales/{en,es}.json`. iOS: generated `L10n` from the same files plus `ios/i18n/ios.{en,es}.json` (`ios/scripts/gen-i18n.mjs`, `--check` must stay clean). Language switch needs a restart on iOS.

---

## 4. Prioritized backlog

Format: ID, title, size, acceptance criteria (AC), files, tests.

### P0 (data loss, wrong ownership, security, broken links, release blockers)

**GAP-001. Make the outbox honest (M)**

- AC:
  1. Writes that RLS can silently reject (`deleteSong`, `deleteTag`, `deletePlaylist`, `setPlaylistArchived`, `updatePlaylist`, `removeSongFromPlaylist`, `setSongTags`, `reorder`) use `returning: .representation` or a count check and return `.rejected(.permissionDenied)` when zero rows are affected.
  2. `setSongTags` is atomic (RPC, or insert the missing then delete the removed) so a rejected insert never deletes server tags.
  3. Add `23505` and other 4xx PostgREST errors to permanent failures where replay cannot succeed, or cap attempts (for example 8) and move to `failed`.
  4. `pendingEntityKeys` includes `failed` so a pull cannot overwrite or delete locally failed work until the user resolves it.
  5. New "Sync problems" screen (from the sync button and Settings > Sync): list failed ops with entity name and error; actions Retry, Discard (re-pull that entity to roll back), Copy details.
  6. The red sync badge stays until the list is empty.
- Files: `SB/Remote/SupabaseRemoteWriter.swift`, `SB/Remote/RemoteSupport.swift`, `DATA/CapoStore/Database/GRDBSyncStore.swift`, `GRDBSyncStore+Apply.swift`, `DATA/CapoStore/Outbox/Outbox.swift`, `CORE/CapoCore/Contracts/LocalContracts.swift`, new view next to `UI/CapoEditorUI/ConflictsView.swift`, `UI/CapoShellUI/MainShellView.swift`.
- Tests: `CapoSupabaseTests/WriterTests.swift` (zero-row, atomic tags), `CapoStoreTests` (failed keys skipped by pull), `CapoSyncTests/SyncEngineTests.swift` (retry cap, FIFO released), logic test in `CapoEditorUITests`.

**GAP-002. Per-item permissions (M)**

- AC:
  1. Edit and create affordances use the item's own bucket (team role for `song.teamID` / `playlist.teamID`; personal always allowed), not the view filter.
  2. Delete of team songs and playlists requires `admin` or `owner`; `member` sees no delete.
  3. In "All", create is disabled or redirects to personal with a toast when the stored creation bucket is a viewer team.
  4. Remove the `?? true` defaults.
  5. (Former GAP-011) Rows in "All" hide edit actions for viewer teams.
- Files: `UI/CapoShellUI/ContextStore.swift`, `ShellEnvironment.swift`, `UI/CapoDesign/Environment.swift:49`, `CORE/CapoCore/Models/Teams.swift:6-7` (add `canDeleteContent`), `UI/CapoLibraryUI/LibraryView.swift:22`, `UI/CapoPlaylistsUI/PlaylistsView.swift:28`, `PlaylistDetailView.swift:36,327-349`, `UI/CapoPerformanceUI/SongPerformanceView.swift:231`, `UI/CapoEditorUI/SongEditorView.swift:14`.
- Tests: `CapoShellUITests` (role by team id), `CapoCoreTests` (matrix), `CapoPlaylistsUITests`, `CapoLibraryUITests`.

**GAP-003. Stop the web from wiping preferences (S, web)**

- AC: changing `lyricsColumns` on the web keeps `chordHand`, `palette`, `uiFont`, `theme`, `locale`. Use a JSONB merge (new RPC `merge_user_preferences(p_user_id, p_patch jsonb)` or extend the existing function) in `upsertUserPreferences`.
- Files: `features/songs/api/user-preferences-api.ts:93-113`, `features/songs/hooks/use-user-preferences.ts:41-46`, new migration through `pnpm supabase migration new`, regenerate `lib/supabase/database.types.ts`.
- Tests: jest in `features/songs/__tests__/api/` (payload preserves other keys); SQL test of the RPC.

**GAP-004. Restrict the song picker to the playlist bucket (S)**

- AC: `SongPickerView` receives the playlist's owner (team or personal) and lists only that bucket; the draft dialog warns or blocks cross-bucket targets; `PlaylistRepository.addSongs` rejects cross-bucket songs.
- Files: `UI/CapoLibraryUI/SongPickerView.swift`, `LibraryModel.swift`, `UI/CapoPlaylistsUI/PlaylistDetailView.swift:62`, `AddToPlaylistView.swift:196-205`, `DATA/CapoStore/Repositories/PlaylistRepository.swift:131`.
- Tests: `CapoLibraryUITests`, `CapoStoreTests`.

**GAP-005. Sign in with Apple and shippable account deletion (M)**

- AC: Apple button using `ASAuthorizationController` with nonce into `signInWithIdToken(.apple)`; entitlement and Supabase provider enabled; account deletion visible in Release with a warning when the user owns teams that have other members (question 6); `allowsAccountDeletion = true`.
- Files: `SB/Auth/SupabaseAuthService.swift`, `CORE/CapoCore/Contracts/LocalContracts.swift:102-109`, `UI/CapoAuthUI/AuthView.swift`, `UI/CapoShellUI/ShellSettings.swift:10`, Xcode entitlements, `ios/HUMAN_TODO.md`.
- Tests: `CapoAuthUITests`, `CapoSupabaseTests` (request shape), `CapoShellUITests` (Release flag).

**GAP-006. Universal links and URL router (M) — WON'T DO (product decision 2026-10-25: shared and invitation links stay web-only)**

- AC: AASA file on the web domain (`public/.well-known/apple-app-site-association`), Associated Domains entitlement, router for `/shared/<code>` (open the playlist if synced, else GAP-024 viewer, else Safari) and `/teams/accept-invitation?token=` (signed in: call `accept_team_invitation`, switch to the team; signed out: keep the token and resume after login, like the `_invitation_token` cookie).
- Files: web `public/.well-known/*`, `ios/Capo/**` entitlements, `KIT/CapoAppScene.swift:17-19`, new `UI/CapoShellUI/DeepLinkRouter.swift`, `ShellNavigation.swift`.
- Tests: `CapoShellUITests` (router per URL shape), `CapoAppKitTests`.

**GAP-007. Share sheet from the local row (S)**

- AC: if the local playlist has `shareCode`, build the link with no RPC (offline, viewers of public playlists); call `ensure_share_code` only when null and the user can edit; the make-public switch is editor-only; remove or fix `ShareSheetView` fallback so it never shows a link for a private playlist; map `permissionDenied` to a clear message. Deploy migration `20261025015742` first.
- Files: `UI/CapoTeamsUI/PlaylistShareSheet.swift:79-112`, `UI/CapoPlaylistsUI/PlaylistDetailView.swift:66,672-735`, `KIT/CapoComposition.swift:124-135`.
- Tests: `CapoTeamsUITests` (code present, offline, viewer).

**GAP-008. Invitations: discovery, decline, atomic resend (M, backend plus iOS)**

- AC: first confirm on production that an invitee outside the team cannot select their invitations; add an RLS select policy (`lower(email) = lower(auth.jwt()->>'email')`) or RPC `get_my_pending_invitations`; add RPC `decline_team_invitation(token)` deleting only the caller's row; resend as one RPC; use them on web and iOS.
- Files: new migration, `features/teams/api/teamsApi.ts:320-351`, `app/api/invitations/pending/route.ts`, `SB/Teams/SupabaseTeamsRemote.swift:40-50,112-117`, `CORE/CapoCore/Contracts/RemoteContracts.swift`, `UI/CapoTeamsUI/TeamsModel.swift:174-180,219-226`.
- Tests: SQL/RLS test, `CapoSupabaseTests`, `CapoTeamsUITests`, jest `features/teams/__tests__/`.

### P1 (parity of core flows)

**GAP-009. Tag filter AND semantics (S)**

- AC: selecting several tags returns only songs that have all of them (`GROUP BY song_id HAVING COUNT(DISTINCT tag_id) = n`).
- Files: `DATA/CapoStore/Repositories/SongRepository.swift:174-182`, `UI/CapoLibraryUI/LibraryFilters.swift:89-91`.
- Tests: `CapoStoreTests` (two tags), `CapoLibraryUITests/CapoLibraryUITests.swift`.

**GAP-010. Bucket picker on create (M)**

- AC: song editor (create mode) and playlist form get a bucket selector listing Personal and teams with role ≥ member, default `creationContext`; the choice applies to that creation only.
- Files: `UI/CapoEditorUI/SongEditorView.swift`, `SongEditorModel.swift:62-77`, `UI/CapoPlaylistsUI/PlaylistFormView.swift:13,87`, new shared `BucketPicker` view in `UI/CapoDesign` or `UI/CapoShellUI`.
- Tests: `CapoEditorUITests`, `CapoPlaylistsUITests`.

**GAP-011. Merged into GAP-002 item 5.**

**GAP-012. Atomic preference writes (S)**

- AC: `updatePreferences` uses the server-side JSONB merge RPC from GAP-003 instead of read-merge-write.
- Files: `SB/Remote/SupabaseRemoteWriter.swift:133-144`, migration.
- Tests: `CapoSupabaseTests/WriterTests.swift`.

**GAP-013. Membership change cleanup (S)**

- AC: leaving or being removed from a team removes that team's rows, tags, settings and queued ops locally within one pull and resets selections.
- Files: `DATA/CapoStore/Database/GRDBSyncStore+Apply.swift`, `UI/CapoShellUI/ContextStore.swift:89-105`.
- Tests: `CapoSyncTests`, `CapoStoreTests`.

**GAP-014. Incremental pull (M)**

- AC: playlist entries, tag assignments and settings fetched only for changed entities or by `updated_at`; realtime payload narrows the pull.
- Files: `DATA/CapoSync/SyncEngine.swift:275-321`, `SB/Remote/SupabaseRemoteSyncSource.swift`.
- Tests: `CapoSyncTests`.

**GAP-015. Realtime resilience (S)**

- AC: channel status changes trigger resubscribe with backoff and a full sync.
- Files: `SB/Realtime/SupabaseRealtimeNotifier.swift`.
- Tests: `CapoSupabaseTests` with a fake channel.

**GAP-016. Context switch keeps navigation (S)**

- AC: `.id(model.context)` (`MainShellView.swift:23`) no longer discards per-tab navigation or an open draft; only queries reload.
- Tests: `CapoShellUITests`.

**GAP-017. Floating controls residuals (S)**

- AC: lyrics visibility toggle in `StageDock` (so dock, panel and fullscreen have it); position remembered per size class and orientation; keyboard shortcut to switch dock and floating; VoiceOver order; clamping after Stage Manager resize; button can reach the area under the hidden header in fullscreen.
- Files: `UI/CapoPerformanceUI/StageComponents.swift:240-470`, `FloatingControls.swift`, `StageLogic.swift:35-80`, `SongPerformanceModel.swift:115-125`.
- Tests: `FloatingControlsMathTests`, `CapoPerformanceUITests`.

**GAP-018. Mirror server validation (S)**

- AC: title 1-200, artist ≤200, key ≤12, notes ≤10k, lyrics ≤100k, playlist name ≤200, description ≤2000, team name ≤120, inline errors on iOS (a rejected create is otherwise rolled back by the next pull). Decide on required artist and key (question 3).
- Files: `UI/CapoEditorUI/EditorLogic.swift:36-45`, `DATA/CapoStore/Repositories/SongRepository.swift:35-69`, `PlaylistRepository.swift:56-95`, `UI/CapoPlaylistsUI/PlaylistFormView.swift`.
- Tests: `CapoEditorUITests/CapoEditorUITests.swift`, `CapoStoreTests`.

**GAP-019. Chord audio (M)**

- AC: play button next to the chord title, bundled guitar samples (offline), same MIDI voicing as `features/chord-audio/hooks/use-chord-audio.ts`, 1.5 s note, playing indicator.
- Files: new `UI/CapoRendering/Diagrams/ChordAudio.swift`, `ChordDiagramView.swift`.
- Tests: `CapoRenderingTests` (note mapping parity with `features/chord-audio/utils/midi-to-note.ts`).

**GAP-020. Share expiry semantics (S)**

- AC: document that `share_expires_at` is read-only from clients; if surfaced later, hide expired links.
- Files: `UI/CapoTeamsUI/PlaylistShareSheet.swift`, docs.

### P2 (polish and hardening)

**GAP-021. Lyrics normalization on web, share-text parity (S, web)**

- AC: port `LyricsText` rules to `song-pipeline.ts`; add golden fixtures; test `buildShareText` against iOS share text.
- Files: `features/lyrics-editor/utils/song-pipeline.ts`, `ios/scripts/gen-converter-golden.ts`.
- Tests: jest `features/lyrics-editor`, `CapoChordProTests/LyricsTextTests.swift`.

**GAP-022. Web defects found (S, web)**

- AC: web BPM inline clamp 20-500 vs zod max 400 (`song-detail.tsx:164-166` vs `actions.ts:45`); BPM thresholds 90/120/130 (badges) vs 100/140 (filter) vs 90/120 (help text); one ticket for the web owner.

**GAP-023. Suggest playlist name (S)**

- AC: sparkles button fills a random "Adjective Noun" (lists in `playlist-create-form.tsx:45-62`), localized.
- Files: `UI/CapoPlaylistsUI/PlaylistFormView.swift`, `PlaylistLogic.swift`.

**GAP-024. In-app shared playlist viewer (L) — WON'T DO (shared pages stay web-only)**

- AC: read-only view by code with lyrics and prev/next, owner and team toggles, realtime; signed-out access only if the product wants it (question 2).
- Files: `UI/CapoPlaylistsUI` (new view), `CORE/CapoCore/Contracts/RemoteContracts.swift` (`getPublicPlaylist(code:)`), `SB/Remote/SupabaseRemoteSyncSource.swift`.
- Tests: `CapoSupabaseTests`, `CapoPlaylistsUITests`.

**GAP-025. Live language switch (M)**

- AC: language change updates strings without a restart.
- Files: `UI/CapoSettingsUI/SettingsView.swift:341-356`, `L10n` consumers.
- Tests: `CapoDesignTests`.

**GAP-026. In-app feedback (S)**

- AC: Settings row opens the web's form (5-5000 chars, optional newsletter opt-in) and inserts into `feedback`.
- Files: new `UI/CapoSettingsUI/FeedbackView.swift`, `SB/Remote/` insert.
- Tests: `CapoSupabaseTests`.

**GAP-027. Merged into GAP-008 (resend) and GAP-028 (frequency).**

**GAP-028. Played-frequency scope (S)**

- AC: decide whether counts match the web's per-context numbers; if so restrict `play_count` to the current context and exclude archived playlists.
- Files: `DATA/CapoStore/Repositories/SongRepository.swift:115-117`.
- Tests: `CapoStoreTests`.

**GAP-029. Status filter and CifraClub verification (S)**

- AC: drop the status chips or add UI to set draft/archived; test CifraClub on device and throttle to 10/min like the web.
- Files: `UI/CapoLibraryUI/LibraryFilters.swift:46`, `UI/CapoEditorUI/CifraClub/*`.

**GAP-030. Release checks (S)**

- AC: re-run `RowsDriftTests` after migrations; confirm Realtime publication for `team_invitations` if live invitations are wanted; AASA hosting verified; `PrivacyInfo.xcprivacy` reviewed for new APIs.

---

## 5. Work packages for parallel agents

Each package owns a disjoint set of files.

| WP | Scope | Owns (files) | Depends on |
|---|---|---|---|
| WP-DB (web and SQL) | GAP-003, SQL for GAP-008 and GAP-012, GAP-021, GAP-022, deploy of `20261025015742` | `supabase/migrations/*`, `features/songs/api/user-preferences-api.ts`, `features/songs/hooks/use-user-preferences.ts`, `features/teams/api/*`, `app/api/invitations/*`, `features/lyrics-editor/utils/song-pipeline.ts`, `lib/supabase/database.types.ts`, `public/.well-known/*` | none; must land before WP-A (RPC), WP-D, WP-E |
| WP-A Sync honesty | GAP-001, GAP-012 (iOS), GAP-013, GAP-014, GAP-015, GAP-030 | `SB/Remote/*`, `SB/Realtime/*`, `DATA/CapoSync/*`, `DATA/CapoStore/Database/*`, `DATA/CapoStore/Outbox/*`, new sync-problems view in `UI/CapoEditorUI/` | WP-DB for the RPCs |
| WP-B Permissions | GAP-002, GAP-016 | `UI/CapoShellUI/ContextStore.swift`, `ShellEnvironment.swift`, `MainShellView.swift`, `UI/CapoDesign/Environment.swift`, `CORE/CapoCore/Models/Teams.swift`, role lines in `LibraryView.swift`, `PlaylistsView.swift`, `PlaylistDetailView.swift`, `SongPerformanceView.swift`, `SongEditorView.swift` | none |
| WP-C Library and playlists | GAP-004, GAP-009, GAP-010, GAP-018, GAP-023, GAP-028, GAP-029 | `UI/CapoLibraryUI/*` (except role lines), `UI/CapoPlaylistsUI/PlaylistFormView.swift`, `AddToPlaylistView.swift`, `PlaylistLogic.swift`, `UI/CapoEditorUI/EditorLogic.swift`, `SongEditorModel.swift`, `DATA/CapoStore/Repositories/*` | WP-B first for shared view files |
| WP-D Sharing and links | GAP-006, GAP-007, GAP-020, GAP-024 | `UI/CapoTeamsUI/PlaylistShareSheet.swift`, `KIT/*`, `ios/Capo/**`, new `DeepLinkRouter.swift` | WP-DB for the deployed RPC |
| WP-E Teams and invitations | GAP-008 (iOS) | `UI/CapoTeamsUI/TeamsModel.swift`, `PendingInvitationsView.swift`, `TeamDetailView.swift`, `SB/Teams/*`, `CORE/CapoCore/Contracts/RemoteContracts.swift` | WP-DB |
| WP-F Auth and release | GAP-005, GAP-025, GAP-026 | `SB/Auth/*`, `UI/CapoAuthUI/*`, `UI/CapoShellUI/ShellSettings.swift`, `UI/CapoSettingsUI/*`, `ios/HUMAN_TODO.md` | Apple developer setup (human) |
| WP-G Performance | GAP-017, GAP-019 | `UI/CapoPerformanceUI/*`, `UI/CapoRendering/Diagrams/*` | none |

Conflict notes: WP-B and WP-C both touch `LibraryView.swift`, `PlaylistDetailView.swift` and `SongEditorView.swift` in different regions; run WP-B first or give both to one agent. `Rows.swift` and `SupabaseRemoteWriter.swift` are WP-A only; WP-DB never edits Swift. WP-D edits `PlaylistDetailView.swift` lines 66 and 672-735 only; coordinate with WP-B (lines 36, 327-349).

Suggested order: WP-DB and WP-A in parallel (data safety), then WP-B, then WP-C, WP-D, WP-E and WP-G in parallel, and WP-F last (needs Apple console work).

---

## 6. Open questions for the product owner

1. Should a rejected offline change be undone silently (today) or stay visible until the user picks Retry or Discard (proposed in GAP-001)?
2. Should the iOS app serve a shared playlist to signed-out people (guest viewer, GAP-024), or only open shared links in Safari?
3. Required fields: the web form forces artist and key and BPM 40-300; iOS requires only a title and allows BPM 1-400. Which rule wins?
4. Members can delete their own personal items but only admins can delete team songs and playlists (RLS). Keep it, or relax RLS so members can delete what they created?
5. `allow_guest_editing` has no RLS effect (anonymous reorder fails). Remove the toggle, or add a real policy and a reorder RPC?
6. Deleting an account cascades to teams created by that user, deleting other members' team content. Require ownership transfer first? What should the iOS confirmation say?
7. Should invitees see pending invitations in the app (needs a policy or RPC), or only through the emailed link?
8. Played-frequency badge: per current creation context (web) or across everything the user can see (iOS today)?
9. Song `status` (draft, archived) is invisible on the web. Keep the iOS filter, hide it, or add set-status UI on both?
10. Playlist order: web is created-at only; iOS puts dated setlists first. Keep the iOS order?
11. Is a restart acceptable for language change at release, or must it be live?
12. Ukulele stays out (decision in `WAVE_PARITY_RULES.md`); confirm, since the older parity doc proposed an instrument setting.
13. Should viewers of a public playlist see and share its link (the web shows it on the shared page to anyone)?
14. Tag handling on transfer: personal tags on a song moved to a team stay personal. Re-create them as team tags or drop them?

---

Counts reproduction: `awk '/^## 2\./,/^## 3\./' ios/docs/GAP_ANALYSIS.md | grep -oE '\| (DONE|PARTIAL|MISSING|DIVERGENT|BUG|N/A)[^|]* \|' | sort | uniq -c`
