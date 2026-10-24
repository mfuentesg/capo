import CapoDesign
import CapoIcons
import SwiftUI

/// Songs header block (design A): "Songs · N" with Select and Add song on the right, then the
/// search field, the Sort and Group menus and the Filters button. Lives outside the scrolling
/// list, so the search field never scrolls away. Compact width collapses the buttons to icons.
struct LibraryHeader: View {
  @Bindable var model: LibraryModel
  let canEdit: Bool
  let isRegular: Bool
  let onAdd: () -> Void
  let onManageTags: () -> Void

  @State private var showFilters = false
  @FocusState private var searchFocused: Bool

  private static let sortColumns: [SongColumn] = [.title, .artist, .key, .bpm, .played, .recent]

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      titleRow
      HStack(spacing: 8) {
        searchField
        sortMenu
        if isRegular { groupMenu }
        filterButton
      }
    }
    .padding(.horizontal, isRegular ? 24 : 16)
    .padding(.top, isRegular ? 16 : 8)
    .padding(.bottom, 12)
    .frame(maxWidth: .infinity, alignment: .leading)
  }

  // MARK: Title row

  private var titleRow: some View {
    HStack(alignment: .firstTextBaseline, spacing: 8) {
      Text(LibraryStrings.songsTitle).capoText(isRegular ? .xl2 : .xl, weight: .bold, tracking: -0.025)
      Text("· \(model.songs.count)")
        .capoText(.sm).monospacedDigit().foregroundStyle(CapoTheme.mutedForeground)
      Spacer(minLength: 0)
      selectButton
      if canEdit { addButton }
    }
  }

  private var selectButton: some View {
    Button {
      withAnimation(.snappy(duration: 0.2)) {
        if model.selecting { model.finishSelecting() } else { model.selecting = true }
      }
    } label: {
      if isRegular {
        HStack(spacing: 8) {
          TableGlyphView(.listChecks, size: 16)
          Text(model.selecting ? L10n.Ios.Table.done : L10n.Ios.Table.select).capoText(.sm, weight: .medium)
        }
        .foregroundStyle(CapoTheme.foreground)
        .padding(.horizontal, 12)
        .frame(minHeight: 36)
        .background(model.selecting ? CapoTheme.secondary : Color.clear, in: Capsule())
        .contentShape(Capsule())
      } else {
        TableGlyphView(.listChecks, size: 20)
          .foregroundStyle(model.selecting ? CapoTheme.primary : CapoTheme.foreground)
          .frame(width: CapoMetrics.minHitTarget, height: CapoMetrics.minHitTarget)
          .contentShape(Rectangle())
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(model.selecting ? L10n.Ios.Table.done : L10n.Ios.Table.select)
    .accessibilityAddTraits(model.selecting ? .isSelected : [])
  }

  private var addButton: some View {
    Button(action: onAdd) {
      if isRegular {
        PillLabel(icon: .plus, title: LibraryStrings.addSong, filled: true)
      } else {
        CapoIcon(.plus, size: 20)
          .foregroundStyle(CapoTheme.primaryForeground)
          .frame(width: 40, height: 40)
          .background(CapoTheme.primary, in: Circle())
          .frame(width: CapoMetrics.minHitTarget, height: CapoMetrics.minHitTarget)
          .contentShape(Rectangle())
      }
    }
    .buttonStyle(.plain)
    .accessibilityLabel(LibraryStrings.addSong)
  }

  // MARK: Search

  private var searchField: some View {
    HStack(spacing: 8) {
      CapoIcon(.search, size: 16).foregroundStyle(CapoTheme.mutedForeground)
      TextField(LibraryStrings.searchSongs, text: $model.searchInput)
        .capoText(.sm)
        .focused($searchFocused)
        .submitLabel(.search)
        .autocorrectionDisabled()
      if !model.searchInput.isEmpty {
        Button { model.searchInput = "" } label: {
          CapoIcon(.x, size: 16)
            .foregroundStyle(CapoTheme.mutedForeground)
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

  // MARK: Sort and group

  private var sortMenu: some View {
    Menu {
      ForEach(Self.sortColumns, id: \.self) { column in
        Button {
          model.setSort(
            model.tableSort.column == column ? model.tableSort.tapped(column) : SongTableSort(column))
        } label: {
          if model.tableSort.column == column {
            Label(LibraryStrings.columnName(column), systemImage: model.tableSort.ascending ? "chevron.up" : "chevron.down")
          } else {
            Text(LibraryStrings.columnName(column))
          }
        }
      }
    } label: {
      HStack(spacing: 8) {
        TableGlyphView(.arrowUpDown, size: 16)
        if isRegular {
          Text(LibraryStrings.columnName(model.tableSort.column)).capoText(.sm, weight: .medium).lineLimit(1)
          CapoIcon(.chevronDown, size: 12).foregroundStyle(CapoTheme.mutedForeground)
        }
      }
      .controlChrome(isRegular: isRegular)
    }
    .accessibilityLabel(L10n.Ios.Table.sortBy)
  }

  private var groupMenu: some View {
    Menu {
      Picker(LibraryStrings.groupBy, selection: $model.filters.grouping) {
        ForEach(SongGrouping.allCases, id: \.self) { Text(LibraryStrings.groupName($0)).tag($0) }
      }
    } label: {
      HStack(spacing: 8) {
        CapoIcon(.layoutList, size: 16)
        Text(L10n.Ios.Table.groupValue(value: LibraryStrings.groupName(model.filters.grouping)))
          .capoText(.sm, weight: .medium).lineLimit(1)
        CapoIcon(.chevronDown, size: 12).foregroundStyle(CapoTheme.mutedForeground)
      }
      .controlChrome(isRegular: true)
    }
    .accessibilityLabel(LibraryStrings.groupBy)
  }

  private var filterButton: some View {
    let count = model.filters.activeFilterCount
    return Button { showFilters = true } label: {
      HStack(spacing: 8) {
        CapoIcon(.settings2, size: 16)
        if isRegular { Text(LibraryStrings.filtersTitle).capoText(.sm, weight: .medium) }
        if count > 0 {
          Text("\(count)")
            .capoText(.xs, weight: .medium)
            .foregroundStyle(CapoTheme.primaryForeground)
            .frame(width: 20, height: 20)
            .background(CapoTheme.primary, in: Circle())
        }
      }
      .controlChrome(isRegular: isRegular)
    }
    .buttonStyle(.plain)
    .accessibilityLabel(LibraryStrings.filtersTitle)
    .popover(isPresented: $showFilters) {
      FiltersPopover(model: model, onManageTags: {
        showFilters = false
        Task {
          try? await Task.sleep(for: .milliseconds(300))
          onManageTags()
        }
      })
      .presentationCompactAdaptation(.popover)
    }
  }
}

private extension View {
  /// Outlined 40 pt control of the header row (`Button variant="outline"`).
  func controlChrome(isRegular: Bool) -> some View {
    self
      .foregroundStyle(CapoTheme.foreground)
      .padding(.horizontal, isRegular ? 12 : 10)
      .frame(minWidth: 40, minHeight: 40)
      .background(CapoTheme.background, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous).strokeBorder(CapoTheme.input, lineWidth: 1))
      .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
      .contentShape(RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
  }
}

/// Pill button (`rounded-full`, h-8, text-sm medium, icon 16): filled = default variant, else outline.
struct PillLabel: View {
  let icon: CapoIconName
  let title: String
  var filled = false
  var fillsWidth = false

  var body: some View {
    HStack(spacing: 8) {
      CapoIcon(icon, size: 16)
      Text(title).capoText(.sm, weight: .medium).lineLimit(1)
    }
    .foregroundStyle(filled ? CapoTheme.primaryForeground : CapoTheme.foreground)
    .padding(.horizontal, 12)
    .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 36)
    .background(filled ? CapoTheme.primary : CapoTheme.background, in: Capsule())
    .overlay(Capsule().strokeBorder(filled ? Color.clear : CapoTheme.input, lineWidth: 1))
    .contentShape(Capsule())
  }
}
