import CapoCore
import CapoDesign
import CapoIcons
import SwiftUI

/// Design A "set nav": Previous and Next with the neighbouring titles around the position, a
/// bordered pill that sits in the bottom-left thumb zone.
public struct SongSetNav: View {
  let previousTitle: String?
  let nextTitle: String?
  let positionLabel: String?
  var showsTitles = true
  let onPrevious: (() -> Void)?
  let onNext: (() -> Void)?
  @Environment(\.capoUIScale) private var scale

  public init(
    previousTitle: String?, nextTitle: String?, positionLabel: String?, showsTitles: Bool = true,
    onPrevious: (() -> Void)?, onNext: (() -> Void)?
  ) {
    self.previousTitle = previousTitle
    self.nextTitle = nextTitle
    self.positionLabel = positionLabel
    self.showsTitles = showsTitles
    self.onPrevious = onPrevious
    self.onNext = onNext
  }

  public var body: some View {
    HStack(spacing: 0) {
      half(
        icon: .chevronLeft, caption: L10n.Ios.Queue.previous, title: previousTitle,
        action: onPrevious, trailing: false)
      if let positionLabel {
        Text(positionLabel)
          .capoText(.xs).monospacedDigit().foregroundStyle(CapoTheme.mutedForeground)
          .padding(.horizontal, 6)
      }
      half(
        icon: .chevronRight, caption: L10n.Ios.Queue.next, title: nextTitle, action: onNext,
        trailing: true)
    }
    .background(CapoTheme.background, in: RoundedRectangle(cornerRadius: CapoRadius.xxl, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: CapoRadius.xxl, style: .continuous)
        .strokeBorder(CapoTheme.border, lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.12), radius: 8, y: 3)
    .accessibilityElement(children: .contain)
  }

  private func half(
    icon: CapoIconName, caption: String, title: String?, action: (() -> Void)?, trailing: Bool
  ) -> some View {
    Button {
      action?()
    } label: {
      HStack(spacing: 8) {
        if !trailing { CapoIcon(icon, size: 20).foregroundStyle(CapoTheme.mutedForeground) }
        if showsTitles {
          VStack(alignment: trailing ? .trailing : .leading, spacing: 0) {
            Text(caption.uppercased())
              .font(CapoFont.ui(10, weight: .semibold)).tracking(1)
              .foregroundStyle(CapoTheme.mutedForeground)
            Text(title ?? "–")
              .capoText(.sm, weight: .semibold).lineLimit(1)
              .frame(maxWidth: 170 * scale, alignment: trailing ? .trailing : .leading)
          }
          .fixedSize(horizontal: true, vertical: false)
        }
        if trailing { CapoIcon(icon, size: 20).foregroundStyle(CapoTheme.mutedForeground) }
      }
      .foregroundStyle(CapoTheme.foreground)
      .padding(.horizontal, 14)
      .frame(minWidth: 52, minHeight: 52)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .disabled(action == nil)
    .opacity(action == nil ? 0.4 : 1)
    .sensoryFeedback(.impact(weight: .light), trigger: positionLabel)
    .accessibilityLabel(title.map { "\(caption): \($0)" } ?? caption)
  }
}

/// Leading-edge slide-over listing the songs of the current context so a musician can jump
/// without going back. Hosts place it in a `ZStack` with `.leading` alignment and fade a scrim
/// behind it.
public struct SongQueueDrawer: View {
  let queue: SongQueue
  let current: SongID?
  let onSelect: (SongID) -> Void
  let onClose: () -> Void
  @State private var query = ""
  @Environment(\.capoUIScale) private var scale

  public init(
    queue: SongQueue, current: SongID?, onSelect: @escaping (SongID) -> Void,
    onClose: @escaping () -> Void
  ) {
    self.queue = queue
    self.current = current
    self.onSelect = onSelect
    self.onClose = onClose
  }

  public var body: some View {
    VStack(spacing: 0) {
      header
      ScrollViewReader { proxy in
        ScrollView {
          LazyVStack(spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.element.item.id) { _, row in
              rowView(row).id(row.item.id)
            }
          }
        }
        .onAppear { if let current { proxy.scrollTo(current, anchor: .center) } }
      }
    }
    .frame(width: 320 * min(scale, 1.2))
    .frame(maxHeight: .infinity)
    .background(CapoTheme.background.ignoresSafeArea())
    .overlay(alignment: .trailing) { Rectangle().fill(CapoTheme.border).frame(width: 1) }
    .shadow(color: .black.opacity(0.25), radius: 16, x: 4)
    .accessibilityElement(children: .contain)
    .accessibilityLabel(L10n.Ios.Queue.songListTitle)
  }

  private struct Row {
    let item: SongQueueItem
    let number: Int
  }

  private var rows: [Row] {
    let numbers = Dictionary(uniqueKeysWithValues: queue.items.enumerated().map { ($1.id, $0 + 1) })
    return queue.filtered(by: query).map { Row(item: $0, number: numbers[$0.id] ?? 0) }
  }

  private var header: some View {
    VStack(alignment: .leading, spacing: 12) {
      HStack(spacing: 8) {
        Text((queue.title ?? L10n.Ios.Queue.songListTitle).uppercased())
          .capoText(.xs, weight: .semibold, tracking: 0.05)
          .foregroundStyle(CapoTheme.mutedForeground)
          .lineLimit(1)
          .accessibilityAddTraits(.isHeader)
        Spacer(minLength: 0)
        Button(action: onClose) {
          Image(systemName: "sidebar.left").font(.system(size: 15, weight: .medium))
            .foregroundStyle(CapoTheme.mutedForeground)
            .frame(width: 32, height: 32)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Ios.Queue.hideList)
      }
      HStack(spacing: 8) {
        CapoIcon(.search, size: 14).foregroundStyle(CapoTheme.mutedForeground)
        TextField(L10n.Ios.Queue.jumpToSong, text: $query)
          .capoText(.sm)
          .textInputAutocapitalization(.never)
          .autocorrectionDisabled()
      }
      .padding(.horizontal, 10)
      .frame(height: 36)
      .background(CapoTheme.card, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous)
          .strokeBorder(CapoTheme.input, lineWidth: 1))
    }
    .padding(16)
    .overlay(alignment: .bottom) { Rectangle().fill(CapoTheme.border).frame(height: 1) }
  }

  private func rowView(_ row: Row) -> some View {
    let isCurrent = row.item.id == current
    return Button {
      onSelect(row.item.id)
    } label: {
      HStack(spacing: 12) {
        if queue.isNumbered {
          Text("\(row.number)")
            .capoText(.xs, weight: .bold).monospacedDigit()
            .foregroundStyle(CapoTheme.primary)
            .frame(width: 26, height: 26)
            .background(CapoTheme.primary.opacity(0.10), in: Circle())
        }
        VStack(alignment: .leading, spacing: 1) {
          Text(row.item.title)
            .capoText(.sm, weight: isCurrent ? .bold : .semibold).lineLimit(1)
          if let artist = row.item.artist, !artist.isEmpty {
            Text(artist).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground).lineLimit(1)
          }
        }
        Spacer(minLength: 0)
        if let key = row.item.key, !key.isEmpty { HeaderBadge(text: key, style: .secondary, mono: true) }
      }
      .foregroundStyle(CapoTheme.foreground)
      .padding(.horizontal, 16)
      .padding(.vertical, 10)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(isCurrent ? CapoTheme.accentSongs.opacity(0.12) : .clear)
      .overlay(alignment: .leading) {
        if isCurrent { Rectangle().fill(CapoTheme.accentSongs).frame(width: 3) }
      }
      .overlay(alignment: .bottom) {
        Rectangle().fill(CapoTheme.border.opacity(0.5)).frame(height: 1)
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(isCurrent ? .isSelected : [])
  }
}

/// Dimmed backdrop plus the drawer, sliding from the leading edge. Content under it stays
/// non-interactive while it is open.
public struct SongQueueOverlay: View {
  @Binding var isPresented: Bool
  let queue: SongQueue
  let current: SongID?
  let onSelect: (SongID) -> Void
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  public init(
    isPresented: Binding<Bool>, queue: SongQueue, current: SongID?,
    onSelect: @escaping (SongID) -> Void
  ) {
    _isPresented = isPresented
    self.queue = queue
    self.current = current
    self.onSelect = onSelect
  }

  public var body: some View {
    ZStack(alignment: .leading) {
      if isPresented {
        Color.black.opacity(0.25)
          .ignoresSafeArea()
          .onTapGesture { close() }
          .transition(.opacity)
          .accessibilityHidden(true)
        SongQueueDrawer(
          queue: queue, current: current,
          onSelect: { id in
            onSelect(id)
            close()
          }, onClose: close
        )
        .transition(.move(edge: .leading))
      }
    }
    .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isPresented)
    .allowsHitTesting(isPresented)
  }

  private func close() { isPresented = false }
}

/// Header button that opens the slide-over ("Setlist" / "Songs").
public struct SongQueueButton: View {
  let label: String
  let isActive: Bool
  let action: () -> Void

  public init(label: String, isActive: Bool = false, action: @escaping () -> Void) {
    self.label = label
    self.isActive = isActive
    self.action = action
  }

  public var body: some View {
    Button(action: action) {
      HStack(spacing: 6) {
        Image(systemName: "sidebar.left").font(.system(size: 13, weight: .medium))
        Text(label).capoText(.sm, weight: .medium)
      }
      .foregroundStyle(CapoTheme.foreground)
      .padding(.horizontal, 10)
      .frame(minHeight: 36)
      .background(isActive ? CapoTheme.secondary : .clear, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(L10n.Ios.Queue.showList)
  }
}
