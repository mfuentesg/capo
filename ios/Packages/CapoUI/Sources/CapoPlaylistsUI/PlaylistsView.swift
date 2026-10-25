import CapoDesign
import CapoIcons
import CapoLibraryUI
import SwiftUI

/// Playlists table (design A): "Playlists · N" with a Create pill, search, All/Public/Private and
/// Active/Archived toggles, a sortable Name / Date / Songs / Sharing strip and one-line rows.
/// Compact width drops the strip and stacks name and meta. Rows call `onOpen` to push the detail.
public struct PlaylistsView: View {
  let onOpen: (PlaylistID) -> Void
  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var context
  @Environment(\.teamRoles) private var teamRoles
  @Environment(\.creationContext) private var creationContext
  @Environment(\.horizontalSizeClass) private var sizeClass
  @State private var all: [PlaylistSummary] = []
  @State private var loaded = false
  @State private var query = ""
  @State private var visibility = PlaylistLogic.Visibility.all
  @State private var showArchived = false
  @State private var sort = PlaylistTableSort.default
  @State private var showCreate = false
  @State private var pendingDelete: PlaylistSummary?
  @State private var width: CGFloat = 0
  @FocusState private var searchFocused: Bool

  public init(onOpen: @escaping (PlaylistID) -> Void) { self.onOpen = onOpen }

  private var canCreate: Bool { teamRoles.canEdit(in: creationContext) }
  private var isRegular: Bool { sizeClass == .regular && width >= 600 }
  private var visible: [PlaylistSummary] {
    PlaylistTableLogic.rows(all, query: query, visibility: visibility, archived: showArchived, sort: sort)
  }
  private var activeCount: Int { all.filter { $0.playlist.archivedAt == nil }.count }

  public var body: some View {
    VStack(spacing: 0) {
      header
      if isRegular { columnStrip } else { CapoTheme.border.frame(height: 1) }
      list
    }
    .background(CapoTheme.background)
    .background {
      GeometryReader { proxy in
        Color.clear
          .onAppear { width = proxy.size.width }
          .onChange(of: proxy.size.width) { _, value in width = value }
      }
    }
    .overlay {
      if loaded && visible.isEmpty {
        EmptyStateView(
          title: all.isEmpty ? PlaylistStrings.emptyTitle : L10n.Playlists.noPlaylists,
          message: all.isEmpty ? PlaylistStrings.emptyMessage : nil,
          systemImage: "music.note.list")
      }
    }
    .navigationTitle("")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar(.hidden, for: .navigationBar)
    .sheet(isPresented: $showCreate) {
      PlaylistFormView(mode: .create) { if let p = $0 { onOpen(p.id) } }
    }
    .confirmationDialog(
      pendingDelete.map { PlaylistStrings.deleteConfirm($0.playlist.name) } ?? "",
      isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
      titleVisibility: .visible
    ) {
      Button(PlaylistStrings.delete, role: .destructive) {
        if let target = pendingDelete {
          Task { try? await services.playlists.delete(id: target.id) }
        }
        pendingDelete = nil
      }
    }
    .task(id: context) {
      for await items in services.playlists.playlists(in: context, includeArchived: true) {
        all = items
        loaded = true
      }
    }
  }

  // MARK: Header

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(PlaylistStrings.title).capoText(isRegular ? .xl2 : .xl, weight: .bold, tracking: -0.025)
        Text("· \(loaded ? visible.count : activeCount)")
          .capoText(.sm).monospacedDigit().foregroundStyle(CapoTheme.mutedForeground)
        Spacer(minLength: 0)
        if canCreate { createButton }
      }
      HStack(spacing: 8) {
        searchField
        if isRegular { toggles }
      }
      if !isRegular { HStack(spacing: 8) { toggles }.frame(maxWidth: .infinity, alignment: .leading) }
    }
    .padding(.horizontal, isRegular ? 24 : 16)
    .padding(.top, isRegular ? 16 : 8)
    .padding(.bottom, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  private var createButton: some View {
    Button { showCreate = true } label: {
      if isRegular {
        HStack(spacing: 8) {
          CapoIcon(.plus, size: 16)
          Text(L10n.Playlists.createPlaylist).capoText(.sm, weight: .medium).lineLimit(1)
        }
        .foregroundStyle(CapoTheme.primaryForeground)
        .padding(.horizontal, 14)
        .frame(minHeight: 36)
        .background(CapoTheme.primary, in: Capsule())
      } else {
        CapoIcon(.plus, size: 20)
          .foregroundStyle(CapoTheme.primaryForeground)
          .frame(width: 40, height: 40)
          .background(CapoTheme.primary, in: Circle())
          .frame(width: CapoMetrics.minHitTarget, height: CapoMetrics.minHitTarget)
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(L10n.Playlists.createPlaylist)
  }

  private var searchField: some View {
    HStack(spacing: 8) {
      CapoIcon(.search, size: 16).foregroundStyle(CapoTheme.mutedForeground)
      TextField(L10n.Playlists.searchPlaceholder, text: $query)
        .capoText(.sm)
        .focused($searchFocused)
        .autocorrectionDisabled()
      if !query.isEmpty {
        Button { query = "" } label: {
          CapoIcon(.x, size: 16).foregroundStyle(CapoTheme.mutedForeground)
            .frame(width: CapoMetrics.minHitTarget, height: CapoMetrics.minHitTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.trailing, -12)
      }
    }
    .padding(.horizontal, 12)
    .frame(height: 40)
    .background(CapoTheme.muted.opacity(0.5), in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous).strokeBorder(CapoTheme.input, lineWidth: 1))
    .contentShape(Rectangle())
    .onTapGesture { searchFocused = true }
  }

  @ViewBuilder private var toggles: some View {
    SegmentedPills(
      options: [
        (PlaylistLogic.Visibility.all, L10n.Songs.all), (.public, L10n.Filters.public),
        (.private, L10n.Filters.private)
      ], selection: $visibility)
    SegmentedPills(
      options: [(false, L10n.Ios.Table.active), (true, L10n.Ios.Table.archived)], selection: $showArchived)
  }

  // MARK: Column strip

  private var columnStrip: some View {
    func header(_ column: PlaylistColumn, _ title: String, width: CGFloat? = nil) -> some View {
      let state: TableSortState =
        sort.column == column ? (sort.ascending ? .ascending : .descending) : .unsorted
      return TableColumnHeader(title, state: state) { sort = sort.tapped(column) }
        .frame(width: width, alignment: .leading)
        .frame(maxWidth: width == nil ? .infinity : nil, alignment: .leading)
    }
    return HStack(spacing: 0) {
      header(.name, L10n.Ios.Table.colName)
      header(.date, L10n.Ios.Table.colDate, width: Col.date)
      header(.songs, L10n.Ios.Table.colSongs, width: Col.songs)
      header(.sharing, L10n.Ios.Table.colSharing, width: Col.sharing)
      Color.clear.frame(width: Col.action, height: 1)
    }
    .tableHeaderStrip()
  }

  fileprivate enum Col {
    static let date: CGFloat = 150
    static let songs: CGFloat = 80
    static let sharing: CGFloat = 130
    static let action: CGFloat = 44
  }

  // MARK: Rows

  private var list: some View {
    List {
      ForEach(visible) { summary in
        Group {
          if isRegular {
            PlaylistTableRow(summary: summary, onArchive: teamRoles.canEdit(teamID: summary.playlist.teamID) ? { toggleArchive(summary) } : nil)
          } else {
            PlaylistCompactRow(summary: summary, onArchive: teamRoles.canEdit(teamID: summary.playlist.teamID) ? { toggleArchive(summary) } : nil)
          }
        }
        .onTapGesture { onOpen(summary.id) }
        .accessibilityAddTraits(.isButton)
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
        .listRowInsets(EdgeInsets())
        .swipeActions(edge: .trailing) {
          if teamRoles.canDelete(teamID: summary.playlist.teamID) {
            Button(PlaylistStrings.delete, role: .destructive) { pendingDelete = summary }
          }
        }
      }
    }
    .listStyle(.plain)
    .scrollContentBackground(.hidden)
    .environment(\.defaultMinListRowHeight, 1)
    .refreshable { await services.sync.syncNow(reason: .manual) }
  }

  private func toggleArchive(_ summary: PlaylistSummary) {
    let archive = summary.playlist.archivedAt == nil
    Task { try? await services.playlists.setArchived(id: summary.id, archive) }
  }
}

/// Small capsule segmented control (`All | Public | Private`).
private struct SegmentedPills<Value: Hashable>: View {
  let options: [(Value, String)]
  @Binding var selection: Value

  var body: some View {
    HStack(spacing: 2) {
      ForEach(Array(options.enumerated()), id: \.offset) { _, option in
        let selected = option.0 == selection
        Button { withAnimation(.snappy(duration: 0.18)) { selection = option.0 } } label: {
          Text(option.1)
            .capoText(.sm, weight: .medium)
            .foregroundStyle(selected ? CapoTheme.foreground : CapoTheme.mutedForeground)
            .padding(.horizontal, 12)
            .frame(minHeight: 32)
            .background(selected ? CapoTheme.card : Color.clear, in: Capsule())
            .shadow(color: .black.opacity(selected ? 0.08 : 0), radius: 1, y: 1)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
      }
    }
    .padding(3)
    .background(CapoTheme.muted, in: Capsule())
    .overlay(Capsule().strokeBorder(CapoTheme.border, lineWidth: 1))
    .fixedSize()
  }
}

/// Stable accent for a playlist tile, cycling orange, blue, green, purple like the design.
private func tileColor(_ id: PlaylistID) -> Color {
  let byte = Int(id.uuid.15)
  return [CapoTheme.primary, CapoTheme.accentSongs, CapoTheme.accentActivity, CapoTheme.accentPlaylists][byte % 4]
}

private struct PlaylistTile: View {
  let id: PlaylistID
  var size: CGFloat = 32

  var body: some View {
    let color = tileColor(id)
    CapoIcon(.music3, size: size * 0.55)
      .foregroundStyle(color)
      .frame(width: size, height: size)
      .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
  }
}

private struct ArchiveButton: View {
  let archived: Bool
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      CapoIcon(archived ? .archiveRestore : .archive, size: 18)
        .foregroundStyle(CapoTheme.mutedForeground)
        .frame(width: 44, height: 44)
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(archived ? L10n.Playlists.unarchive : L10n.Playlists.archive)
  }
}

private struct SharingLabel: View {
  let playlist: Playlist

  var body: some View {
    HStack(spacing: 6) {
      CapoIcon(playlist.isPublic ? .globe : .lock, size: 13)
      Text(playlist.isPublic ? L10n.Ios.Table.public : L10n.Ios.Table.private).capoText(.xs)
      if playlist.isPublic && playlist.allowGuestEditing { CapoIcon(.users, size: 13) }
    }
    .foregroundStyle(CapoTheme.mutedForeground)
    .lineLimit(1)
    .accessibilityElement(children: .combine)
  }
}

private struct PlaylistTableRow: View {
  let summary: PlaylistSummary
  let onArchive: (() -> Void)?

  private var playlist: Playlist { summary.playlist }
  private var archived: Bool { playlist.archivedAt != nil }

  var body: some View {
    HStack(spacing: 0) {
      HStack(spacing: 12) {
        PlaylistTile(id: summary.id)
        Text(playlist.name).capoText(.sm, weight: .bold).lineLimit(1)
        if summary.isPinned { PinMark(offline: summary.isFullyAvailableOffline) }
      }
      .frame(maxWidth: .infinity, alignment: .leading)
      HStack(spacing: 6) {
        if let date = PlaylistDate.display(playlist.date) {
          CapoIcon(.calendar, size: 13)
          Text(date).capoText(.xs).lineLimit(1)
        } else {
          Text("—").capoText(.xs)
        }
      }
      .foregroundStyle(CapoTheme.mutedForeground)
      .frame(width: PlaylistsView.Col.date, alignment: .leading)
      Text("\(summary.songCount)").capoText(.base).monospacedDigit()
        .frame(width: PlaylistsView.Col.songs, alignment: .leading)
      SharingLabel(playlist: playlist).frame(width: PlaylistsView.Col.sharing, alignment: .leading)
      Group {
        if let onArchive { ArchiveButton(archived: archived, action: onArchive) } else { Color.clear }
      }
      .frame(width: PlaylistsView.Col.action)
    }
    .foregroundStyle(CapoTheme.foreground)
    .padding(.leading, 16)
    .padding(.trailing, 16)
    .frame(minHeight: 52)
    .background(CapoTheme.card)
    .overlay(alignment: .bottom) { CapoTheme.border.opacity(0.6).frame(height: 1) }
    .opacity(archived ? 0.6 : 1)
    .contentShape(Rectangle())
  }
}

private struct PlaylistCompactRow: View {
  let summary: PlaylistSummary
  let onArchive: (() -> Void)?

  private var playlist: Playlist { summary.playlist }
  private var archived: Bool { playlist.archivedAt != nil }

  var body: some View {
    HStack(spacing: 12) {
      PlaylistTile(id: summary.id, size: 40)
      VStack(alignment: .leading, spacing: 3) {
        Text(playlist.name).capoText(.base, weight: .bold).lineLimit(1)
        HStack(spacing: 8) {
          if let date = PlaylistDate.display(playlist.date) {
            HStack(spacing: 4) { CapoIcon(.calendar, size: 12); Text(date) }
          }
          Text(PlaylistStrings.songCount(summary.songCount))
          SharingLabel(playlist: playlist)
        }
        .capoText(.xs)
        .foregroundStyle(CapoTheme.mutedForeground)
        .lineLimit(1)
      }
      Spacer(minLength: 0)
      if summary.isPinned { PinMark(offline: summary.isFullyAvailableOffline) }
      if let onArchive { ArchiveButton(archived: archived, action: onArchive) }
    }
    .foregroundStyle(CapoTheme.foreground)
    .padding(.leading, 16)
    .padding(.trailing, 8)
    .padding(.vertical, 8)
    .frame(minHeight: 64)
    .background(CapoTheme.card)
    .overlay(alignment: .bottom) { CapoTheme.border.opacity(0.6).frame(height: 1) }
    .opacity(archived ? 0.6 : 1)
    .contentShape(Rectangle())
  }
}

/// iOS-only: the setlist is kept for offline use.
private struct PinMark: View {
  let offline: Bool

  var body: some View {
    if offline {
      CapoIcon(.checkCircle2, size: 14).foregroundStyle(CapoTheme.success)
        .accessibilityLabel(PlaylistStrings.offlineReady)
    } else {
      Image(systemName: "pin.fill").font(.system(size: 11)).foregroundStyle(CapoTheme.mutedForeground)
        .accessibilityLabel(PlaylistStrings.pinned)
    }
  }
}
