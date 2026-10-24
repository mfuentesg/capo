import CapoDesign
import CapoIcons
import SwiftUI

/// Filters popover (web `songs-client.tsx`): BPM range, Group by, Tags, plus the iOS-only Sort and
/// Status choices and a Manage tags shortcut.
struct FiltersPopover: View {
  @Bindable var model: LibraryModel
  let onManageTags: () -> Void

  var body: some View {
    let filters = model.filters
    ScrollView {
      VStack(alignment: .leading, spacing: 16) {
        HStack(alignment: .top) {
          VStack(alignment: .leading, spacing: 4) {
            Text(LibraryStrings.filtersTitle).capoText(.base, weight: .medium)
            Text(LibraryStrings.filtersDescription).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground)
          }
          Spacer(minLength: 8)
          if filters.activeFilterCount > 0 {
            Button(LibraryStrings.clearAll) { model.filters.resetFilters() }
              .buttonStyle(.plain)
              .capoText(.xs, weight: .medium)
              .padding(.horizontal, 8)
              .frame(minHeight: CapoMetrics.minHitTarget)
          }
        }
        divider
        section(icon: .music2, title: LibraryStrings.bpmRange) {
          HStack(spacing: 8) {
            chip(LibraryStrings.all, selected: filters.bpm == nil) { model.filters.bpm = nil }
            ForEach(BPMBucket.allCases, id: \.self) { bucket in
              chip(LibraryStrings.webBucketName(bucket), icon: Self.icon(bucket), selected: filters.bpm == bucket) {
                model.filters.bpm = bucket
              }
            }
          }
          Text(LibraryStrings.bpmHelp).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground)
        }
        divider
        section(icon: .layoutList, title: LibraryStrings.groupBy) {
          HStack(spacing: 8) {
            ForEach(SongGrouping.allCases, id: \.self) { grouping in
              chip(LibraryStrings.groupName(grouping), selected: filters.grouping == grouping) {
                model.filters.grouping = grouping
              }
            }
          }
        }
        if !model.tags.isEmpty {
          divider
          section(icon: nil, title: LibraryStrings.tags) {
            FlowLayout(spacing: 6) {
              ForEach(model.tags) { tag in
                Button { model.filters.toggle(tag: tag.id) } label: {
                  SongRowTag(name: tag.name, colorHex: tag.color)
                    .padding(2)
                    .overlay(
                      Capsule().strokeBorder(
                        filters.tagIDs.contains(tag.id) ? CapoTheme.ring : Color.clear, lineWidth: 2))
                    .frame(minHeight: CapoMetrics.minHitTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
              }
            }
          }
        }
        divider
        section(icon: nil, title: LibraryStrings.status) {
          FlowLayout(spacing: 8) {
            ForEach(SongStatus.allCases, id: \.self) { status in
              chip(LibraryStrings.statusName(status), selected: filters.statuses.contains(status), expands: false) {
                model.filters.toggle(status: status)
              }
            }
          }
        }
        Button(action: onManageTags) {
          PillLabel(icon: .tag, title: LibraryStrings.manageTags)
        }
        .buttonStyle(.plain)
      }
      .padding(16)
    }
    .frame(width: 320)
    .frame(maxHeight: 500)
    .background(CapoTheme.popover)
  }

  private var divider: some View { CapoTheme.border.frame(height: 1) }

  private static func icon(_ bucket: BPMBucket) -> CapoIconName {
    switch bucket {
    case .slow: .turtle
    case .medium: .rabbit
    case .fast: .zap
    }
  }

  private func section<Content: View>(
    icon: CapoIconName?, title: String, @ViewBuilder content: () -> Content
  ) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack(spacing: 8) {
        if let icon { CapoIcon(icon, size: 16) }
        Text(title).capoText(.sm, weight: .medium)
      }
      content()
    }
  }

  /// `Button size="sm"`: default variant when selected, outline otherwise.
  private func chip(
    _ title: String, icon: CapoIconName? = nil, selected: Bool, expands: Bool = true, action: @escaping () -> Void
  ) -> some View {
    Button(action: action) {
      HStack(spacing: 6) {
        if let icon { CapoIcon(icon, size: 14) }
        Text(title).capoText(.sm, weight: .medium).lineLimit(1).minimumScaleFactor(0.8)
      }
      .foregroundStyle(selected ? CapoTheme.primaryForeground : CapoTheme.foreground)
      .padding(.horizontal, 8)
      .frame(maxWidth: expands ? .infinity : nil, minHeight: 32)
      .background(selected ? CapoTheme.primary : CapoTheme.background, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous)
          .strokeBorder(selected ? Color.clear : CapoTheme.input, lineWidth: 1))
      .frame(minHeight: CapoMetrics.minHitTarget)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(selected ? .isSelected : [])
  }
}
