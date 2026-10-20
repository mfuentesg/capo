import CapoDesign
import SwiftUI

/// Account, appearance, lyrics defaults, sync, environment and danger zone.
public struct SettingsView: View {
  @Environment(\.userServices) private var services
  @Environment(\.settingsContext) private var context
  @Environment(\.capoActions) private var actions
  @Environment(\.openURL) private var openURL

  @State private var model = SettingsModel()
  @State private var confirmSignOut = false
  @State private var confirmErase = false
  @State private var confirmDelete = false
  @State private var toast: String?

  public init() {}

  public var body: some View {
    Form {
      accountSection
      appearanceSection
      lyricsSection
      languageSection
      syncSection
      environmentSection
      dataSection
      if context.deleteAccount != nil { dangerSection }
      aboutSection
    }
    .navigationTitle(L10n.Settings.title)
    .capoToast($toast)
    .task(id: services.userID) { await model.observePreferences(services.settings) }
    .task(id: services.userID) { await model.observeStatus(services.sync) }
    .confirmationDialog(SettingsStrings.signOutTitle, isPresented: $confirmSignOut, titleVisibility: .visible) {
      Button(SettingsStrings.signOut, role: .destructive) { context.signOut(false) }
      Button(L10n.Common.cancel, role: .cancel) {}
    } message: {
      Text(SettingsStrings.signOutMessage)
    }
    .confirmationDialog(L10n.Ios.EraseData.title, isPresented: $confirmErase, titleVisibility: .visible) {
      Button(L10n.Ios.EraseData.confirm, role: .destructive) { context.signOut(true) }
      Button(L10n.Common.cancel, role: .cancel) {}
    } message: {
      Text(eraseMessage)
    }
    .confirmationDialog(L10n.Settings.deleteAccount, isPresented: $confirmDelete, titleVisibility: .visible) {
      Button(L10n.Settings.deleteAccountConfirmButton, role: .destructive) {
        Task { await deleteAccount() }
      }
      Button(L10n.Common.cancel, role: .cancel) {}
    } message: {
      Text(L10n.Settings.deleteAccountConfirm)
    }
  }

  // MARK: Sections

  private var accountSection: some View {
    Section(SettingsStrings.account) {
      HStack(spacing: 12) {
        avatar
        VStack(alignment: .leading, spacing: 2) {
          Text(context.fullName ?? context.email ?? "—").font(.headline)
          if context.fullName != nil, let email = context.email {
            Text(email).font(.subheadline).foregroundStyle(.secondary)
          }
          if let provider = context.provider {
            Text(L10n.Settings.connectedVia(provider: provider.capitalized))
              .font(.caption).foregroundStyle(.secondary)
          }
        }
      }
      .accessibilityElement(children: .combine)
      Button(SettingsStrings.signOut, role: .destructive) { confirmSignOut = true }
    }
  }

  @ViewBuilder
  private var avatar: some View {
    if let url = context.avatarURL {
      AsyncImage(url: url) { image in
        image.resizable().scaledToFill()
      } placeholder: {
        Image(systemName: "person.crop.circle.fill").resizable().foregroundStyle(.secondary)
      }
      .frame(width: 48, height: 48)
      .clipShape(Circle())
    } else {
      Image(systemName: "person.crop.circle.fill")
        .resizable().frame(width: 48, height: 48).foregroundStyle(.secondary)
    }
  }

  private var appearanceSection: some View {
    Section(L10n.Settings.appearance) {
      Picker(L10n.Settings.theme, selection: themeBinding) {
        Text(L10n.Settings.themeSystem).tag(AppTheme.system)
        Text(L10n.Settings.themeLight).tag(AppTheme.light)
        Text(L10n.Settings.themeDark).tag(AppTheme.dark)
      }
    }
  }

  private var lyricsSection: some View {
    Section(SettingsStrings.lyrics) {
      Picker(SettingsStrings.defaultColumns, selection: columnsBinding) {
        Text(L10n.Songs.Lyrics.oneColumn).tag(1)
        Text(L10n.Songs.Lyrics.twoColumns).tag(2)
      }
    }
  }

  private var languageSection: some View {
    Section(L10n.Settings.language) {
      LabeledContent(L10n.Settings.language, value: SettingsModel.currentLanguageName())
      Button(SettingsStrings.openLanguageSettings) {
        if let url = URL(string: UIApplication.openSettingsURLString) { openURL(url) }
      }
    }
  }

  private var syncSection: some View {
    Section(SettingsStrings.sync) {
      LabeledContent(SettingsStrings.status) {
        Label(SyncStatusBadge.label(for: model.status), systemImage: "arrow.triangle.2.circlepath")
          .labelStyle(.titleOnly)
      }
      LabeledContent(SettingsStrings.lastSync) {
        if let date = model.status.lastSuccessAt {
          Text(date, style: .relative)
        } else {
          Text(L10n.Ios.Sync.never)
        }
      }
      LabeledContent(SettingsStrings.pendingChanges, value: String(model.status.pendingOperations))
      Button(L10n.Ios.Sync.syncNow) {
        Task { await services.sync.syncNow(reason: .manual) }
      }
      .disabled(model.isSyncing)
      if model.status.conflicts > 0 {
        Button {
          actions.showConflicts()
        } label: {
          Label(
            "\(SettingsStrings.viewConflicts) (\(model.status.conflicts))",
            systemImage: "exclamationmark.arrow.triangle.2.circlepath")
        }
      }
    }
  }

  private var environmentSection: some View {
    Section(L10n.Ios.Server.environment) {
      if context.isDemo {
        LabeledContent(L10n.Ios.Server.environment, value: L10n.Ios.Demo.badge)
      } else {
        if let name = context.environmentName {
          LabeledContent(L10n.Ios.Server.environment, value: name)
        }
        if let url = context.serverURL {
          LabeledContent(L10n.Ios.Server.url) {
            Text(url.absoluteString).font(.footnote).foregroundStyle(.secondary).textSelection(.enabled)
          }
        }
      }
    }
  }

  private var dataSection: some View {
    Section(SettingsStrings.data) {
      Button(SettingsStrings.eraseAndSignOut, role: .destructive) { confirmErase = true }
    }
  }

  private var dangerSection: some View {
    Section {
      Button(model.isDeleting ? L10n.Settings.deleteAccountPending : L10n.Settings.deleteAccount, role: .destructive) {
        confirmDelete = true
      }
      .disabled(model.isDeleting)
    } header: {
      Text(L10n.Settings.dangerZone)
    } footer: {
      Text(L10n.Settings.dangerZoneDescription)
    }
  }

  private var aboutSection: some View {
    Section(SettingsStrings.about) {
      LabeledContent(SettingsStrings.version, value: SettingsModel.appVersion())
    }
  }

  // MARK: Bindings and actions

  private var themeBinding: Binding<AppTheme> {
    Binding(
      get: { model.preferences.theme ?? .system },
      set: { newValue in
        model.preferences.theme = newValue
        let settings = services.settings
        Task { try? await settings.updatePreferences(PreferencesPatch(theme: newValue)) }
      })
  }

  private var columnsBinding: Binding<Int> {
    Binding(
      get: { model.preferences.lyricsColumns },
      set: { newValue in
        model.preferences.lyricsColumns = newValue
        let settings = services.settings
        Task { try? await settings.updatePreferences(PreferencesPatch(lyricsColumns: newValue)) }
      })
  }

  private var eraseMessage: String {
    let base = L10n.Ios.EraseData.message
    let pending = model.status.pendingOperations
    return pending > 0 ? base + "\n" + L10n.Ios.EraseData.pendingWarning(count: String(pending)) : base
  }

  private func deleteAccount() async {
    guard let delete = context.deleteAccount else { return }
    model.isDeleting = true
    defer { model.isDeleting = false }
    do {
      try await delete()
      context.signOut(true)
    } catch {
      toast = SettingsStrings.deleteFailed
    }
  }
}

#Preview {
  NavigationStack {
    SettingsView()
      .environment(
        \.settingsContext,
        SettingsContext(
          email: "ana@example.com", fullName: "Ana", provider: "google",
          environmentName: "local", serverURL: URL(string: "http://localhost:54321"),
          deleteAccount: {}))
  }
}
