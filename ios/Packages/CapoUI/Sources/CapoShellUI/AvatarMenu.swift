import CapoDesign
import CapoIcons
import SwiftUI

/// Avatar trigger plus the account popover (web `user-profile-menu.tsx`): profile header,
/// Settings, Invitations, Theme with Surprise me, Logout.
struct AvatarMenu: View {
  let model: ShellModel
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
    ProfileAvatar(url: model.session.avatarURL, teamIcon: nil, size: 36, ringed: true)
    .overlay(alignment: .topTrailing) {
      if model.conflictCount > 0 {
        Circle().fill(CapoTheme.destructive).frame(width: 10, height: 10).offset(x: 2, y: -2)
      }
    }
  }

  private var label: some View {
    avatar.frame(width: CapoMetrics.minTouchTarget, height: CapoMetrics.minTouchTarget).contentShape(Rectangle())
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
        item(.settings, ContextStrings.settings) { model.navigation.showSettings = true }
        item(.mail, ContextStrings.invitations) { model.navigation.showInvitations = true }
        if model.conflictCount > 0 {
          item(.alertCircle, "\(ContextStrings.conflicts) (\(model.conflictCount))") {
            model.navigation.showConflicts = true
          }
        }
      }
      .padding(.vertical, 4)
      CapoTheme.border.frame(height: 1)
      themeRow
      CapoTheme.border.frame(height: 1)
      item(.logOut, ContextStrings.signOut, destructive: true) {
        model.navigation.showSignOut = true
      }
      .padding(.vertical, 4)
    }
    .frame(width: 288)
    .background(CapoTheme.popover)
  }

  private var header: some View {
    HStack(spacing: 12) {
      ProfileAvatar(url: model.session.avatarURL, teamIcon: nil, size: 40)
      VStack(alignment: .leading, spacing: 1) {
        Text(model.session.fullName ?? model.session.email ?? "")
          .capoText(.sm, weight: .semibold).lineLimit(1)
        if model.session.fullName != nil, let email = model.session.email {
          Text(email).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground).lineLimit(1)
        }
      }
      Spacer(minLength: 0)
    }
    .foregroundStyle(CapoTheme.text)
    .padding(12)
  }

  private func item(
    _ icon: CapoIconName, _ title: String, destructive: Bool = false, action: @escaping () -> Void
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
        CapoIcon(icon, size: 16).frame(width: 22)
        Text(title).capoText(.sm, weight: .medium)
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
        .capoText(.sm).foregroundStyle(CapoTheme.mutedForeground)
      Spacer(minLength: 0)
      ForEach(ThemeChoice.all, id: \.theme) { choice in
        let selected = (model.theme ?? .system) == choice.theme
        Button { model.setTheme(choice.theme) } label: {
          CapoIcon(choice.icon, size: 16)
            .frame(width: 28, height: 28)
            .foregroundStyle(selected ? CapoTheme.primary : CapoTheme.mutedForeground)
            .background(selected ? CapoTheme.primary.opacity(0.10) : Color.clear, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
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
          CapoIcon(.sparkles, size: 16)
            .foregroundStyle(CapoTheme.mutedForeground)
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
  let icon: CapoIconName
  let title: String

  /// Web order: Sun, Moon, Monitor.
  static var all: [ThemeChoice] {
    [
      ThemeChoice(theme: .light, icon: .sun, title: L10n.Settings.themeLight),
      ThemeChoice(theme: .dark, icon: .moon, title: L10n.Settings.themeDark),
      ThemeChoice(theme: .system, icon: .monitor, title: L10n.Settings.themeSystem)
    ]
  }
}
