import CapoDesign
import CapoIcons
import SwiftUI

/// Songs header block (web `songs-client.tsx`): "Songs · N", the Add song pill, then the search
/// field and the Filters button.
struct LibraryHeader: View {
  @Bindable var model: LibraryModel
  let canEdit: Bool
  let isRegular: Bool
  let onAdd: () -> Void
  let onManageTags: () -> Void

  @State private var showFilters = false
  @FocusState private var searchFocused: Bool

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        Text(LibraryStrings.songsTitle).capoText(isRegular ? .xl2 : .xl, weight: .bold, tracking: -0.025)
        Text("· \(model.songs.count)")
          .capoText(.sm).monospacedDigit().foregroundStyle(CapoTheme.mutedForeground)
        Spacer(minLength: 0)
      }
      if canEdit {
        HStack(spacing: 8) {
          Button(action: onAdd) {
            PillLabel(icon: .plus, title: LibraryStrings.addSong, filled: true, fillsWidth: !isRegular)
          }
          .buttonStyle(.plain)
          if isRegular { Spacer(minLength: 0) }
        }
      }
      HStack(spacing: 8) {
        searchField
        filterButton
      }
    }
    .padding(16)
    .frame(maxWidth: .infinity, alignment: .leading)
    .overlay(alignment: .bottom) { CapoTheme.border.frame(height: 1) }
  }

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
    .frame(height: 36)
    .background(CapoTheme.muted.opacity(0.5), in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
    .overlay(RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous).strokeBorder(CapoTheme.input, lineWidth: 1))
    .contentShape(Rectangle())
    .onTapGesture { searchFocused = true }
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
      .foregroundStyle(CapoTheme.foreground)
      .padding(.horizontal, isRegular ? 12 : 9)
      .frame(minWidth: 36, minHeight: 36)
      .background(CapoTheme.background, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
      .overlay(RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous).strokeBorder(CapoTheme.input, lineWidth: 1))
      .shadow(color: .black.opacity(0.05), radius: 1, y: 1)
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
    .frame(maxWidth: fillsWidth ? .infinity : nil, minHeight: 32)
    .background(filled ? CapoTheme.primary : CapoTheme.background, in: Capsule())
    .overlay(Capsule().strokeBorder(filled ? Color.clear : CapoTheme.input, lineWidth: 1))
    .contentShape(Capsule())
  }
}
