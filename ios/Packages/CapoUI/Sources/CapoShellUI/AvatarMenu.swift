import CapoDesign
import SwiftUI

/// Avatar trigger plus the account popover (web `user-profile-menu.tsx`): profile header,
/// Settings, Invitations, Theme with Surprise me, Logout.
struct AvatarMenu: View {
  enum Style { case compact, sidebar, rail }

  let model: ShellModel
  var style: Style = .compact
  @State private var open = false

  var body: some View {
    Button { open = true } label: { label }
      .buttonStyle(.plain)
      .accessibilityLabel(L10n.Ios.Shell.accountMenu)
      .popover(isPresented: $open) {
        AvatarMenuContent(model: model) { open = false }
          .presentationCompactAdaptation(.popover)
      }
  }

  private var avatar: some View {
    InitialAvatar(
      url: model.session.avatarURL, text: model.session.fullName ?? model.session.email ?? "?",
      size: style == .compact ? 32 : 36, tinted: true
    )
    .overlay(alignment: .topTrailing) {
      if model.conflictCount > 0 {
        Circle().fill(CapoTheme.destructive).frame(width: 10, height: 10).offset(x: 2, y: -2)
      }
    }
  }

  @ViewBuilder
  private var label: some View {
    switch style {
    case .compact:
      avatar.frame(width: CapoMetrics.minTouchTarget, height: CapoMetrics.minTouchTarget).contentShape(Rectangle())
    case .rail:
      avatar.frame(width: 56, height: 56).contentShape(Rectangle())
    case .sidebar:
      HStack(spacing: 10) {
        avatar
        VStack(alignment: .leading, spacing: 1) {
          Text(model.session.fullName ?? model.session.email ?? "")
            .font(CapoFont.style(.subheadline, weight: .semibold)).lineLimit(1)
          if model.session.fullName != nil, let email = model.session.email {
            Text(email).font(CapoFont.style(.caption)).foregroundStyle(CapoTheme.subtext).lineLimit(1)
          }
        }
        Spacer(minLength: 0)
        Image(systemName: "chevron.up").font(CapoFont.style(.caption)).foregroundStyle(CapoTheme.subtext)
      }
      .foregroundStyle(CapoTheme.text)
      .padding(.horizontal, 8)
      .frame(minHeight: CapoMetrics.minTouchTarget + 4)
      .contentShape(Rectangle())
    }
  }
}

private struct AvatarMenuContent: View {
  let model: ShellModel
  let dismiss: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      header
      CapoTheme.border.frame(height: 1)
      VStack(spacing: 0) {
        item("gearshape", ContextStrings.settings) { model.navigation.showSettings = true }
        item("envelope", ContextStrings.invitations) { model.navigation.showInvitations = true }
        if model.conflictCount > 0 {
          item("exclamationmark.triangle", "\(ContextStrings.conflicts) (\(model.conflictCount))") {
            model.navigation.showConflicts = true
          }
        }
      }
      .padding(.vertical, 4)
      CapoTheme.border.frame(height: 1)
      themeRow
      CapoTheme.border.frame(height: 1)
      item("rectangle.portrait.and.arrow.right", ContextStrings.signOut, destructive: true) {
        model.navigation.showSignOut = true
      }
      .padding(.vertical, 4)
    }
    .frame(width: 288)
    .background(CapoTheme.card)
  }

  private var header: some View {
    HStack(spacing: 12) {
      InitialAvatar(
        url: model.session.avatarURL, text: model.session.fullName ?? model.session.email ?? "?",
        size: 40, tinted: true)
      VStack(alignment: .leading, spacing: 1) {
        Text(model.session.fullName ?? model.session.email ?? "")
          .font(CapoFont.style(.subheadline, weight: .semibold)).lineLimit(1)
        if model.session.fullName != nil, let email = model.session.email {
          Text(email).font(CapoFont.style(.caption)).foregroundStyle(CapoTheme.subtext).lineLimit(1)
        }
      }
      Spacer(minLength: 0)
    }
    .foregroundStyle(CapoTheme.text)
    .padding(12)
  }

  private func item(
    _ symbol: String, _ title: String, destructive: Bool = false, action: @escaping () -> Void
  ) -> some View {
    Button {
      dismiss()
      // Let the popover finish dismissing before presenting a sheet or dialog.
      Task {
        try? await Task.sleep(for: .milliseconds(300))
        action()
      }
    } label: {
      HStack(spacing: 12) {
        Image(systemName: symbol).frame(width: 22)
        Text(title).font(CapoFont.style(.subheadline, weight: .medium))
        Spacer(minLength: 0)
      }
      .foregroundStyle(destructive ? CapoTheme.destructive : CapoTheme.text)
      .padding(.horizontal, 16)
      .frame(minHeight: CapoMetrics.minTouchTarget)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private var themeRow: some View {
    HStack(spacing: 4) {
      Text(L10n.Settings.theme)
        .font(CapoFont.style(.subheadline)).foregroundStyle(CapoTheme.subtext)
      Spacer(minLength: 0)
      ForEach(ThemeChoice.all, id: \.theme) { choice in
        let selected = (model.theme ?? .system) == choice.theme
        Button { model.setTheme(choice.theme) } label: {
          Image(systemName: choice.symbol)
            .frame(width: 36, height: 36)
            .foregroundStyle(selected ? CapoTheme.primary : CapoTheme.subtext)
            .background(selected ? CapoTheme.selection : Color.clear, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .frame(width: CapoMetrics.minTouchTarget, height: CapoMetrics.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(choice.title)
        .accessibilityAddTraits(selected ? .isSelected : [])
      }
      if model.hasPalettes {
        CapoTheme.border.frame(width: 1, height: 20)
        Button { model.surpriseMe() } label: {
          Image(systemName: "sparkles")
            .foregroundStyle(CapoTheme.subtext)
            .frame(width: CapoMetrics.minTouchTarget, height: CapoMetrics.minTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(L10n.Settings.surpriseMe)
      }
    }
    .padding(.horizontal, 16)
  }
}

struct ThemeChoice {
  let theme: AppTheme
  let symbol: String
  let title: String

  /// Web order: Sun, Moon, Monitor.
  static var all: [ThemeChoice] {
    [
      ThemeChoice(theme: .light, symbol: "sun.max", title: L10n.Settings.themeLight),
      ThemeChoice(theme: .dark, symbol: "moon", title: L10n.Settings.themeDark),
      ThemeChoice(theme: .system, symbol: "display", title: L10n.Settings.themeSystem)
    ]
  }
}
