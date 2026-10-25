import CapoDesign
import CapoIcons
import CapoLibraryUI
import SwiftUI
import UniformTypeIdentifiers

/// Web `playlist-detail.tsx` as a pushed, full-width page (design A): header with inline-editable
/// name and Details pills, numbered draggable songs on the left, and on wide panes a 300 pt
/// column on the right with Privacy & sharing, Archive and the Danger zone. Narrow panes (and the
/// iPhone) stack the same sections under the songs.
public struct PlaylistDetailView: View {
  let playlistID: PlaylistID
  let backLabel: String?
  @Environment(\.userServices) private var services
  @Environment(\.currentTeamRole) private var role
  @Environment(\.capoActions) private var actions
  @Environment(\.capoUIScale) private var scale
  @Environment(\.isPresented) private var isPresented
  @Environment(\.dismiss) private var dismiss
  @State private var detail: PlaylistDetail?
  @State private var songs: [SongListItem] = []
  @State private var loaded = false
  @State private var isOffline = false
  @State private var showPicker = false
  @State private var showShare = false
  @State private var confirmDelete = false
  @State private var toast: String?
  @State private var paneWidth: CGFloat = 1000

  /// `backLabel` names the screen the back button returns to ("Playlists").
  public init(playlistID: PlaylistID, backLabel: String? = nil) {
    self.playlistID = playlistID
    self.backLabel = backLabel
  }

  private var canEdit: Bool { role?.canEditContent ?? true }
  /// Songs left, sharing column right; below this the sections stack.
  private var wide: Bool { PlaylistDetailLayout.isWide(paneWidth: Double(paneWidth)) }

  public var body: some View {
    Group {
      if let detail {
        page(detail)
      } else if loaded {
        EmptyStateView(title: PlaylistStrings.notFound, message: nil, systemImage: "questionmark.folder")
      } else {
        ProgressView()
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(CapoTheme.background.ignoresSafeArea())
    .toolbar(.hidden, for: .navigationBar)
    .background {
      GeometryReader { proxy in
        Color.clear
          .onAppear { paneWidth = proxy.size.width }
          .onChange(of: proxy.size.width) { _, width in paneWidth = width }
      }
    }
    .capoToast($toast)
    .sheet(isPresented: $showPicker) {
      SongPickerView(excluding: Set(songs.map(\.id))) { ids in
        Task { try? await services.playlists.addSongs(ids, to: playlistID) }
      }
    }
    .sheet(isPresented: $showShare) { ShareSheetView(playlistID: playlistID) }
    .confirmationDialog(
      L10n.PlaylistDetail.deletePlaylistConfirmTitle,
      isPresented: $confirmDelete, titleVisibility: .visible
    ) {
      Button(L10n.PlaylistDetail.deletePlaylist, role: .destructive) {
        Task { try? await services.playlists.delete(id: playlistID) }
      }
    } message: {
      Text(L10n.PlaylistDetail.deletePlaylistConfirmDescription(name: detail?.playlist.name ?? ""))
    }
    .task(id: playlistID) {
      for await value in services.playlists.playlist(id: playlistID) {
        detail = value
        songs = value?.songs ?? []
        loaded = true
      }
    }
    .task {
      for await status in services.sync.status() { isOffline = status.phase == .offline }
    }
  }

  // MARK: Layout

  private func page(_ detail: PlaylistDetail) -> some View {
    VStack(spacing: 0) {
      headerCard(detail)
      if wide {
        HStack(spacing: 0) {
          ScrollView { songsSection.frame(maxWidth: .infinity, alignment: .leading) }
            .background(CapoTheme.card)
          Rectangle().fill(CapoTheme.border).frame(width: 1)
          ScrollView { sideColumn(detail.playlist) }
            .frame(width: PlaylistDetailLayout.sideColumnWidth * scale)
        }
      } else {
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            songsSection.background(CapoTheme.card)
            sideColumn(detail.playlist)
          }
        }
      }
    }
    .overlay(alignment: .top) {
      Rectangle().fill(CapoTheme.accentPlaylists).frame(height: 2).ignoresSafeArea(edges: .top)
    }
  }

  /// Privacy & sharing, Archive and the Danger zone.
  private func sideColumn(_ playlist: Playlist) -> some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(L10n.PlaylistDetail.privacySharing.uppercased())
        .capoText(.xs, weight: .semibold, tracking: 0.1)
        .foregroundStyle(CapoTheme.mutedForeground)
        .accessibilityAddTraits(.isHeader)
      PlaylistPrivacyCard(
        playlist: playlist, canEdit: canEdit, isOffline: isOffline,
        onChange: { patch in
          Task { try? await services.playlists.update(id: playlistID, patch) }
        }, onCopied: { toast = L10n.PlaylistDetail.copied })
      archiveCard(playlist)
      if canEdit { dangerZone(playlist) }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: Header

  /// `bg-card`: back button, name and description (inline editable), actions, Details pills.
  private func headerCard(_ detail: PlaylistDetail) -> some View {
    let playlist = detail.playlist
    return VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 4) {
        if isPresented { backButton }
        Spacer(minLength: 0)
        if !wide {
          shareButton(labeled: false)
          moreMenu(detail)
        }
      }
      .frame(minHeight: 36)
      if wide {
        HStack(alignment: .top, spacing: 12) {
          PlaylistHeaderFields(playlist: playlist, canEdit: canEdit) { patch in
            Task { try? await services.playlists.update(id: playlistID, patch) }
          }
          shareButton(labeled: true)
          performButton(fullWidth: false)
          moreMenu(detail)
        }
      } else {
        PlaylistHeaderFields(playlist: playlist, canEdit: canEdit) { patch in
          Task { try? await services.playlists.update(id: playlistID, patch) }
        }
        performButton(fullWidth: true)
      }
      PillFlow(spacing: 8) {
        PlaylistDatePill(playlist: playlist, canEdit: canEdit) { patch in
          Task { try? await services.playlists.update(id: playlistID, patch) }
        }
        PlaylistPill(
          icon: .listMusic,
          text: PlaylistLogic.countLabel(
            songs.count, singular: L10n.PlaylistDetail.song, plural: L10n.PlaylistDetail.songsPlural))
        PlaylistPill(
          icon: playlist.isPublic ? .globe : .lock,
          text: playlist.isPublic ? L10n.Filters.public : L10n.Filters.private)
      }
    }
    .padding(.horizontal, wide ? 24 : 16)
    .padding(.top, 8)
    .padding(.bottom, 16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(CapoTheme.card.ignoresSafeArea(edges: .top))
    .overlay(alignment: .bottom) { Rectangle().fill(CapoTheme.border).frame(height: 1) }
  }

  private var backButton: some View {
    Button { dismiss() } label: {
      HStack(spacing: 4) {
        CapoIcon(.arrowLeft, size: 16)
        if let backLabel { Text(backLabel).capoText(.sm, weight: .medium).lineLimit(1) }
      }
      .foregroundStyle(CapoTheme.primary)
      .padding(.horizontal, 8)
      .frame(minWidth: 36, minHeight: 36)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(backLabel ?? PlaylistStrings.close)
  }

  private func performButton(fullWidth: Bool) -> some View {
    Button { actions.performSetlist(playlistID, 0) } label: {
      HStack(spacing: 6) {
        CapoIcon(.play, size: 14)
        Text(PlaylistStrings.perform)
      }
      .frame(maxWidth: fullWidth ? .infinity : nil)
    }
    .buttonStyle(CapoPrimaryButtonStyle(size: fullWidth ? .regular : .small))
    .disabled(songs.isEmpty)
  }

  @ViewBuilder private func shareButton(labeled: Bool) -> some View {
    let action = {
      if let share = actions.sharePlaylist { share(playlistID) } else { showShare = true }
    }
    if labeled {
      Button(action: action) {
        HStack(spacing: 6) {
          CapoIcon(.share2, size: 14)
          Text(PlaylistStrings.share)
        }
      }
      .buttonStyle(CapoSecondaryButtonStyle(size: .small))
      .disabled(isOffline)
    } else {
      Button(action: action) {
        CapoIcon(.share2, size: 16).foregroundStyle(CapoTheme.foreground)
          .frame(width: 36, height: 36)
          .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .disabled(isOffline)
      .accessibilityLabel(PlaylistStrings.share)
    }
  }

  private func moreMenu(_ detail: PlaylistDetail) -> some View {
    Menu {
      Button(
        detail.isPinned ? PlaylistStrings.unpin : PlaylistStrings.pin,
        systemImage: detail.isPinned ? "pin.slash" : "pin"
      ) {
        Task { try? await services.playlists.setPinned(!detail.isPinned, playlistID: playlistID) }
      }
    } label: {
      CapoIcon(.moreVertical, size: 16).foregroundStyle(CapoTheme.foreground)
        .frame(width: 36, height: 36)
        .contentShape(Rectangle())
    }
    .accessibilityLabel(PlaylistStrings.title)
  }

  // MARK: Sections

  private func archiveCard(_ playlist: Playlist) -> some View {
    let archived = playlist.archivedAt != nil
    return HStack(alignment: .center, spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(archived ? L10n.Playlists.unarchive : L10n.Playlists.archive)
          .capoText(.sm, weight: .semibold)
        Text(archived ? L10n.PlaylistDetail.unarchiveDescription : L10n.PlaylistDetail.archiveDescription)
          .capoText(.xs).foregroundStyle(CapoTheme.mutedForeground)
      }
      Spacer(minLength: 8)
      if canEdit {
        Button {
          Task { try? await services.playlists.setArchived(id: playlistID, !archived) }
        } label: { CapoIcon(archived ? .archiveRestore : .archive, size: 14) }
          .buttonStyle(CapoSecondaryButtonStyle(size: .small))
          .accessibilityLabel(archived ? L10n.Playlists.unarchive : L10n.Playlists.archive)
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .playlistCard()
  }

  private var songsSection: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Text(L10n.PlaylistDetail.songs.uppercased())
          .capoText(.xs, weight: .semibold, tracking: 0.1)
          .foregroundStyle(CapoTheme.mutedForeground)
          .accessibilityAddTraits(.isHeader)
        Spacer()
        if canEdit {
          Button { showPicker = true } label: {
            HStack(spacing: 6) {
              CapoIcon(.plus, size: 14)
              Text(PlaylistStrings.addSongs)
            }
          }
          .buttonStyle(CapoSecondaryButtonStyle(size: .small))
        }
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      .overlay(alignment: .bottom) { Rectangle().fill(CapoTheme.border).frame(height: 1) }
      if songs.isEmpty {
        EmptyStateView(
          title: L10n.PlaylistDetail.noSongsInPlaylist,
          message: L10n.PlaylistDetail.addSongsDescription, systemImage: "music.note.list",
          tint: CapoTheme.accentPlaylists, bordered: true)
          .padding(16)
      } else {
        VStack(spacing: 0) {
          ForEach(Array(songs.enumerated()), id: \.element.id) { index, song in
            PlaylistSongRow(
              index: index, song: song, canEdit: canEdit, wide: wide,
              onOpen: { actions.performSetlist(playlistID, index) },
              onRemove: { remove(song) }
            )
            .dropDestination(for: String.self) { items, _ in
              guard canEdit, let raw = items.first, let dragged = UUID(uuidString: raw) else {
                return false
              }
              reorder(dragged: dragged, onto: song.id)
              return true
            }
          }
        }
      }
    }
  }

  private func dangerZone(_ playlist: Playlist) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(L10n.PlaylistDetail.dangerZone)
        .capoText(.sm, weight: .semibold).foregroundStyle(CapoTheme.destructive)
      VStack(alignment: .leading, spacing: 12) {
        Text(L10n.PlaylistDetail.deletePlaylistDescription)
          .capoText(.xs).foregroundStyle(CapoTheme.mutedForeground)
        Button { confirmDelete = true } label: {
          HStack(spacing: 6) {
            CapoIcon(.trash2, size: 14)
            Text(L10n.PlaylistDetail.deletePlaylist)
          }
        }
        .buttonStyle(CapoDestructiveButtonStyle(size: .small))
      }
      .padding(16)
      .frame(maxWidth: .infinity, alignment: .leading)
      .playlistCard()
      .overlay(
        RoundedRectangle(cornerRadius: CapoRadius.xl * scale, style: .continuous)
          .strokeBorder(CapoTheme.destructive.opacity(0.3), lineWidth: 1))
    }
  }

  // MARK: Mutations

  private func reorder(dragged: SongID, onto target: SongID) {
    let next = PlaylistLogic.move(songs, dragged: dragged, onto: target)
    guard next.map(\.id) != songs.map(\.id) else { return }
    songs = next
    let ids = next.map(\.id)
    Task { try? await services.playlists.reorder(playlistID: playlistID, songIDs: ids) }
  }

  private func remove(_ song: SongListItem) {
    songs.removeAll { $0.id == song.id }
    Task { try? await services.playlists.removeSong(song.id, from: playlistID) }
  }
}

/// Pane-width rule of the playlist page: songs and sharing side by side, or stacked.
nonisolated enum PlaylistDetailLayout {
  static let sideColumnWidth: CGFloat = 300
  static let wideBreakpoint = 720.0

  static func isWide(paneWidth: Double) -> Bool { paneWidth >= wideBreakpoint }
}

// MARK: - Header fields

/// Inline-editable name (lg bold) and multiline description ("Add description").
private struct PlaylistHeaderFields: View {
  let playlist: Playlist
  let canEdit: Bool
  let onChange: (PlaylistPatch) -> Void
  @State private var name = ""
  @State private var details = ""
  @FocusState private var focus: Field?
  private enum Field { case name, details }

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      TextField(PlaylistStrings.name, text: $name)
        .focused($focus, equals: .name)
        .capoText(.lg, weight: .bold, tracking: -0.025)
        .disabled(!canEdit)
        .submitLabel(.done)
        .onSubmit(commitName)
      TextField(L10n.PlaylistDetail.addDescription, text: $details, axis: .vertical)
        .focused($focus, equals: .details)
        .capoText(.sm)
        .foregroundStyle(CapoTheme.mutedForeground)
        .lineLimit(1...4)
        .disabled(!canEdit)
        .onSubmit(commitDetails)
    }
    .onAppear(perform: seed)
    .onChange(of: playlist.name) { _, _ in if focus != .name { seed() } }
    .onChange(of: playlist.description) { _, _ in if focus != .details { seed() } }
    .onChange(of: focus) { old, _ in
      if old == .name { commitName() }
      if old == .details { commitDetails() }
    }
  }

  private func seed() {
    name = playlist.name
    details = playlist.description ?? ""
  }

  private func commitName() {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return name = playlist.name }
    guard trimmed != playlist.name else { return }
    onChange(PlaylistPatch(name: trimmed))
  }

  private func commitDetails() {
    let trimmed = details.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed != (playlist.description ?? "") else { return }
    onChange(PlaylistPatch(description: trimmed))
  }
}

// MARK: - Date pill

private struct PlaylistDatePill: View {
  let playlist: Playlist
  let canEdit: Bool
  let onChange: (PlaylistPatch) -> Void
  @State private var open = false
  @State private var date = Date()

  var body: some View {
    Button { open = canEdit } label: {
      PlaylistPill(
        icon: .calendar, text: PlaylistDate.display(playlist.date) ?? L10n.PlaylistDetail.pickDate)
    }
    .buttonStyle(.plain)
    .popover(isPresented: $open) {
      VStack(spacing: 8) {
        DatePicker("", selection: $date, displayedComponents: .date)
          .datePickerStyle(.graphical).labelsHidden()
          .onChange(of: date) { _, value in
            onChange(PlaylistPatch(date: PlaylistDate.format(value)))
          }
        if playlist.date != nil {
          Button(L10n.Songs.reset) {
            onChange(PlaylistPatch(date: ""))
            open = false
          }
          .buttonStyle(CapoSecondaryButtonStyle(size: .small))
        }
      }
      .padding(12)
      .frame(width: 320)
      .presentationCompactAdaptation(.popover)
    }
    .onAppear { date = PlaylistDate.parse(playlist.date) ?? Date() }
  }
}

// MARK: - Privacy & sharing

/// Public visibility switch, public URL with Copy / Open, guest-editing switch.
private struct PlaylistPrivacyCard: View {
  let playlist: Playlist
  let canEdit: Bool
  let isOffline: Bool
  let onChange: (PlaylistPatch) -> Void
  let onCopied: () -> Void
  @Environment(\.userServices) private var services
  @Environment(\.openURL) private var openURL
  @State private var ensuredCode: String?

  private var code: String? { playlist.shareCode ?? ensuredCode }
  private var url: URL? { code.map { services.sharing.shareURL(forCode: $0) } }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      toggleRow(
        title: L10n.PlaylistDetail.publicVisibility, detail: L10n.PlaylistDetail.anyoneWithLink,
        isOn: playlist.isPublic, enabled: canEdit
      ) { onChange(PlaylistPatch(isPublic: $0, allowGuestEditing: $0 ? nil : false)) }
      if playlist.isPublic { urlRow }
      toggleRow(
        title: L10n.PlaylistDetail.guestEditing,
        detail: playlist.isPublic
          ? L10n.PlaylistDetail.guestsCanReorder : L10n.PlaylistDetail.guestEditingDisabledHint,
        isOn: playlist.allowGuestEditing, enabled: canEdit && playlist.isPublic
      ) { onChange(PlaylistPatch(allowGuestEditing: $0)) }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .playlistCard()
    .task(id: playlist.isPublic) {
      guard playlist.isPublic, playlist.shareCode == nil, !isOffline else { return }
      ensuredCode = try? await services.sharing.ensureShareCode(playlistID: playlist.id)
    }
  }

  private func toggleRow(
    title: String, detail: String, isOn: Bool, enabled: Bool, set: @escaping (Bool) -> Void
  ) -> some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: 2) {
        Text(title).capoText(.sm, weight: .medium)
        Text(detail).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground)
      }
      Spacer(minLength: 8)
      Toggle("", isOn: Binding(get: { isOn }, set: set))
        .labelsHidden()
        .tint(CapoTheme.primary)
        .disabled(!enabled)
        .accessibilityLabel(title)
    }
    .opacity(enabled ? 1 : 0.6)
  }

  private var urlRow: some View {
    VStack(alignment: .leading, spacing: 6) {
      Text(L10n.PlaylistDetail.publicUrl).capoText(.xs, weight: .medium)
        .foregroundStyle(CapoTheme.mutedForeground)
      HStack(spacing: 8) {
        Text(url?.absoluteString ?? "…")
          .font(CapoFont.mono(12))
          .lineLimit(1)
          .truncationMode(.middle)
          .padding(.horizontal, 10)
          .frame(maxWidth: .infinity, minHeight: 32, alignment: .leading)
          .background(CapoTheme.muted, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
        Button {
          if let url { UIPasteboard.general.url = url; onCopied() }
        } label: { CapoIcon(.copy, size: 14) }
          .buttonStyle(CapoSecondaryButtonStyle(size: .small))
          .disabled(url == nil)
          .accessibilityLabel(L10n.PlaylistDetail.copy)
        Button {
          if let url { openURL(url) }
        } label: { CapoIcon(.externalLink, size: 14) }
          .buttonStyle(CapoSecondaryButtonStyle(size: .small))
          .disabled(url == nil)
          .accessibilityLabel(L10n.Playlists.openPlaylist)
      }
    }
  }
}

// MARK: - Song row

/// Flat row of the songs list: grip, 28 pt numbered circle, title with artist, key and BPM
/// badges, remove button. Wide panes keep everything on one line; narrow ones stack the artist
/// and tempo under the title.
struct PlaylistSongRow: View {
  let index: Int
  let song: SongListItem
  var canEdit = true
  var wide = true
  var onOpen: () -> Void = {}
  var onRemove: () -> Void = {}

  var body: some View {
    HStack(spacing: 8) {
      if canEdit { grip }
      Button(action: onOpen) {
        HStack(spacing: 12) {
          Text("\(index + 1)")
            .capoText(.xs, weight: .bold).monospacedDigit()
            .foregroundStyle(CapoTheme.primary)
            .frame(width: 28, height: 28)
            .background(CapoTheme.primary.opacity(0.10), in: Circle())
          if wide { wideContent } else { narrowContent }
        }
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      if canEdit {
        Button(action: onRemove) {
          CapoIcon(.x, size: 16)
            .foregroundStyle(CapoTheme.mutedForeground)
            .frame(width: 36, height: 36)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(PlaylistStrings.remove)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, wide ? 8 : 10)
    .frame(minHeight: wide ? 52 : 0)
    .overlay(alignment: .bottom) { Rectangle().fill(CapoTheme.border.opacity(0.5)).frame(height: 1) }
  }

  private var wideContent: some View {
    HStack(spacing: 12) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(song.title).capoText(.sm, weight: .bold).lineLimit(1)
          .foregroundStyle(CapoTheme.foreground)
        if let artist = song.artist, !artist.isEmpty {
          Text(artist).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground).lineLimit(1)
        }
      }
      Spacer(minLength: 0)
      HStack { if let key = song.key, !key.isEmpty { KeyBadge(key) } }
        .frame(width: 64, alignment: .leading)
      HStack { if let bpm = song.bpm, bpm > 0 { bpmBadge(bpm) } }
        .frame(width: 104, alignment: .leading)
    }
  }

  private var narrowContent: some View {
    HStack(spacing: 8) {
      VStack(alignment: .leading, spacing: 2) {
        Text(song.title).capoText(.sm, weight: .bold).lineLimit(1)
          .foregroundStyle(CapoTheme.foreground)
        HStack(spacing: 6) {
          if let artist = song.artist, !artist.isEmpty { Text(artist).lineLimit(1) }
          if let bpm = song.bpm, bpm > 0 {
            if song.artist?.isEmpty == false { Text("·") }
            CapoIcon(Self.tempoIcon(bpm), size: 12)
            Text("\(bpm)").monospacedDigit()
          }
        }
        .capoText(.xs).foregroundStyle(CapoTheme.mutedForeground)
      }
      Spacer(minLength: 0)
      if let key = song.key, !key.isEmpty { KeyBadge(key) }
    }
  }

  private var grip: some View {
    CapoIcon(.gripVertical, size: 16)
      .foregroundStyle(CapoTheme.mutedForeground.opacity(0.6))
      .frame(width: 28, height: 36)
      .contentShape(Rectangle())
      .draggable(song.id.uuidString) {
        Text(song.title).capoText(.sm, weight: .bold)
          .padding(12).background(CapoTheme.card, in: Capsule())
      }
      .accessibilityHidden(true)
  }

  private static func tempoIcon(_ bpm: Int) -> CapoIconName {
    bpm < 90 ? .turtle : (bpm <= 120 ? .rabbit : .zap)
  }

  /// Tempo badge: green from 90 BPM up, muted below (the canvas Setlist board).
  private func bpmBadge(_ bpm: Int) -> some View {
    let slow = bpm < 90
    let tint = slow ? CapoTheme.mutedForeground : CapoTheme.success
    return HStack(spacing: 6) {
      CapoIcon(Self.tempoIcon(bpm), size: 12)
      Text("\(bpm) \(L10n.Songs.bpm)").font(CapoFont.ui(12, weight: .medium))
    }
    .foregroundStyle(tint)
    .padding(.horizontal, 8)
    .frame(height: 22)
    .background(slow ? CapoTheme.secondary : CapoTheme.success.opacity(0.10), in: Capsule())
    .overlay(Capsule().strokeBorder(slow ? CapoTheme.border : CapoTheme.success.opacity(0.3), lineWidth: 1))
  }
}

// MARK: - Share sheet

/// Online only: ensures a share code, then offers the public link.
struct ShareSheetView: View {
  let playlistID: PlaylistID
  @Environment(\.userServices) private var services
  @Environment(\.dismiss) private var dismiss
  @State private var url: URL?
  @State private var errorText: String?
  @State private var toast: String?

  var body: some View {
    NavigationStack {
      VStack(spacing: 20) {
        if let url {
          VStack(spacing: 8) {
            CapoIcon(.link, size: 20).foregroundStyle(CapoTheme.accentPlaylists)
            Text(url.absoluteString)
              .font(CapoFont.mono(13)).textSelection(.enabled).multilineTextAlignment(.center)
          }
          .padding(16)
          .frame(maxWidth: .infinity)
          .playlistCard()
          ShareLink(item: url) {
            HStack(spacing: 8) {
              CapoIcon(.share2, size: 16)
              Text(PlaylistStrings.share)
            }
          }
          .buttonStyle(CapoPrimaryButtonStyle())
          Button {
            UIPasteboard.general.url = url
            toast = L10n.PlaylistDetail.copied
          } label: {
            HStack(spacing: 8) {
              CapoIcon(.copy, size: 16)
              Text(PlaylistStrings.copyLink)
            }
          }
          .buttonStyle(CapoSecondaryButtonStyle())
        } else if let errorText {
          Text(errorText).foregroundStyle(CapoTheme.destructive)
        } else {
          ProgressView()
        }
      }
      .padding()
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .background(CapoTheme.background)
      .tint(CapoTheme.primary)
      .capoToast($toast)
      .navigationTitle(L10n.PlaylistShare.sharedPlaylist)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) { Button(PlaylistStrings.done) { dismiss() } }
      }
      .task {
        do {
          let code = try await services.sharing.ensureShareCode(playlistID: playlistID)
          url = services.sharing.shareURL(forCode: code)
        } catch CapoError.offlineUnavailable {
          errorText = PlaylistStrings.shareOffline
        } catch { errorText = String(describing: error) }
      }
    }
  }
}
