import CapoCore
import CapoDesign
import CapoIcons
import SwiftUI

enum SettingsTab: CaseIterable, Identifiable {
  case profile, appearance, account
  var id: Self { self }

  var icon: CapoIconName {
    switch self {
    case .profile: .user
    case .appearance: .palette
    case .account: .shieldAlert
    }
  }

  var title: String {
    switch self {
    case .profile: L10n.Settings.profile
    case .appearance: L10n.Settings.appearance
    case .account: SettingsStrings.account
    }
  }
}

/// Profile, Appearance and Account, laid out like the web's `settings-client.tsx`: a section nav (vertical on
/// wide containers, pills on narrow ones) beside one card. The iOS-only sync, lyrics-layout, server and data
/// rows live under Profile and Account.
public struct SettingsView: View {
  @Environment(\.userServices) private var services
  @Environment(\.settingsContext) private var context
  @Environment(\.capoActions) private var actions
  @Environment(\.capoUIScale) private var scale
  @Environment(\.openURL) private var openURL

  @State private var model = SettingsModel()
  @State private var tab: SettingsTab = {
    #if DEBUG
      switch UserDefaults.standard.string(forKey: "CapoSettingsTab")?.lowercased() {
      case "appearance": return .appearance
      case "account": return .account
      default: return .profile
      }
    #else
      return .profile
    #endif
  }()
  @State private var confirmSignOut = false
  @State private var confirmErase = false
  @State private var confirmDelete = false
  @State private var toast: String?
  @State private var languageChanged = false
  @State private var wide = false

  public init() {}

  public var body: some View {
    // Reading the revision re-runs this body on a palette or font change; the content is re-keyed on it
    // while the ScrollView (and its offset) stays put.
    let revision = CapoPaletteStore.shared.revision
    GeometryReader { proxy in
      ScrollView {
        VStack(alignment: .leading, spacing: 0) {
          Text(L10n.Settings.title)
            .capoText(.xl3, weight: .bold, tracking: -0.025)
            .padding(.bottom, 24 * scale)
          if wide {
            HStack(alignment: .top, spacing: 32 * scale) {
              VStack(spacing: 4 * scale) { ForEach(SettingsTab.allCases) { navItem($0, pill: false) } }
                .frame(width: 176 * scale)
              card
            }
          } else {
            ScrollView(.horizontal, showsIndicators: false) {
              HStack(spacing: 8 * scale) { ForEach(SettingsTab.allCases) { navItem($0, pill: true) } }
            }
            .padding(.bottom, 16 * scale)
            card
          }
        }
        .padding(.horizontal, 24 * scale)
        .padding(.vertical, 24 * scale)
        .frame(maxWidth: .infinity, alignment: .leading)
        .id(revision)
      }
      .onAppear { wide = proxy.size.width >= 640 }
      .onChange(of: proxy.size.width) { _, width in wide = width >= 640 }
    }
    .background { CapoTheme.background.ignoresSafeArea().id(revision) }
    .capoTheme(refreshOnChange: false)
    .navigationBarTitleDisplayMode(.inline)
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

  // MARK: Navigation and card

  private func navItem(_ item: SettingsTab, pill: Bool) -> some View {
    let active = tab == item
    return Button { tab = item } label: {
      HStack(spacing: 8 * scale) {
        CapoIcon(item.icon, size: 16 * scale)
        Text(item.title).capoText(.sm, weight: .medium)
        if !pill { Spacer(minLength: 0) }
      }
      .foregroundStyle(active ? CapoTheme.primary : CapoTheme.mutedForeground)
      .padding(.horizontal, (pill ? 16 : 12) * scale)
      .padding(.vertical, (pill ? 8 : 10) * scale)
      .frame(minHeight: CapoMetrics.minHitTarget)
      .background(
        active ? CapoTheme.primary.opacity(0.1) : Color.clear,
        in: pill
          ? AnyShape(Capsule()) : AnyShape(RoundedRectangle(cornerRadius: CapoRadius.xl * scale, style: .continuous))
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(active ? [.isButton, .isSelected] : .isButton)
  }

  private var card: some View {
    VStack(alignment: .leading, spacing: 24 * scale) {
      switch tab {
      case .profile: profileContent
      case .appearance: appearanceContent
      case .account: accountContent
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(24 * scale)
    .background(CapoTheme.card, in: RoundedRectangle(cornerRadius: CapoRadius.xxl * scale, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: CapoRadius.xxl * scale, style: .continuous)
        .strokeBorder(CapoTheme.border, lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.06), radius: 2, y: 1)
  }

  private func sectionHeader(_ title: String, _ description: String? = nil) -> some View {
    VStack(alignment: .leading, spacing: 2 * scale) {
      Text(title).capoText(.base, weight: .semibold, tracking: -0.025)
      if let description {
        Text(description).capoText(.sm).foregroundStyle(CapoTheme.mutedForeground)
      }
    }
  }

  private var divider: some View { CapoTheme.border.frame(height: 1) }

  private func infoRow(_ label: String, _ value: String) -> some View {
    HStack(alignment: .firstTextBaseline) {
      Text(label).capoText(.sm).foregroundStyle(CapoTheme.mutedForeground)
      Spacer(minLength: 12)
      Text(value).capoText(.sm).multilineTextAlignment(.trailing).textSelection(.enabled)
    }
    .frame(minHeight: 32)
  }

  // MARK: Profile

  private var profileContent: some View {
    VStack(alignment: .leading, spacing: 24 * scale) {
      HStack(spacing: 16 * scale) {
        avatar
        VStack(alignment: .leading, spacing: 4 * scale) {
          Text(context.fullName ?? context.email ?? "—").capoText(.lg, weight: .bold)
          if context.fullName != nil, let email = context.email {
            Text(email).capoText(.sm).foregroundStyle(CapoTheme.mutedForeground)
          }
          if let provider = context.provider {
            HStack(spacing: 4 * scale) {
              CapoIcon(.keyRound, size: 12)
              Text(L10n.Settings.connectedVia(provider: provider.capitalized)).capoText(.xs, weight: .medium)
            }
            .foregroundStyle(CapoTheme.mutedForeground)
            .padding(.horizontal, 8 * scale).padding(.vertical, 2 * scale)
            .background(CapoTheme.muted, in: Capsule())
          }
        }
        .accessibilityElement(children: .combine)
      }
      divider
      sectionHeader(SettingsStrings.lyrics)
      Picker(SettingsStrings.defaultColumns, selection: columnsBinding) {
        Text(L10n.Songs.Lyrics.oneColumn).tag(1)
        Text(L10n.Songs.Lyrics.twoColumns).tag(2)
      }
      .pickerStyle(.segmented)
      divider
      syncSection
    }
  }

  private var avatar: some View {
    let size = 64 * scale
    return ZStack {
      Circle().fill(CapoTheme.primary.opacity(0.1))
      Text(initials).capoText(.xl, weight: .bold).foregroundStyle(CapoTheme.primary)
      if let url = context.avatarURL {
        AsyncImage(url: url) { image in image.resizable().scaledToFill() } placeholder: { Color.clear }
      }
    }
    .frame(width: size, height: size)
    .clipShape(Circle())
    .accessibilityHidden(true)
  }

  private var initials: String {
    let source = context.fullName ?? context.email ?? "?"
    let letters = source.split(separator: " ").prefix(2).compactMap(\.first)
    return String(letters).uppercased()
  }

  private var syncSection: some View {
    VStack(alignment: .leading, spacing: 8 * scale) {
      sectionHeader(SettingsStrings.sync)
      infoRow(SettingsStrings.status, SyncStatusBadge.label(for: model.status))
      HStack {
        Text(SettingsStrings.lastSync).capoText(.sm).foregroundStyle(CapoTheme.mutedForeground)
        Spacer(minLength: 12)
        if let date = model.status.lastSuccessAt {
          Text(date, style: .relative).capoText(.sm)
        } else {
          Text(L10n.Ios.Sync.never).capoText(.sm)
        }
      }
      infoRow(SettingsStrings.pendingChanges, String(model.status.pendingOperations))
      HStack(spacing: 8 * scale) {
        Button {
          Task { await services.sync.syncNow(reason: .manual) }
        } label: {
          HStack(spacing: 6 * scale) {
            CapoIcon(.refreshCw, size: 14)
            Text(L10n.Ios.Sync.syncNow)
          }
        }
        .buttonStyle(CapoSecondaryButtonStyle(size: .small))
        .disabled(model.isSyncing)
        if model.status.conflicts + model.status.failedOperations > 0 {
          Button("\(SettingsStrings.viewConflicts) (\(model.status.conflicts + model.status.failedOperations))") { actions.showConflicts() }
            .buttonStyle(CapoSecondaryButtonStyle(size: .small))
        }
      }
    }
  }

  // MARK: Appearance

  private var appearanceContent: some View {
    VStack(alignment: .leading, spacing: 24 * scale) {
      paletteSection
      divider
      fontSection
      divider
      themeSection
      divider
      languageSection
      divider
      chordHandSection
    }
  }

  private var paletteSection: some View {
    VStack(alignment: .leading, spacing: 16 * scale) {
      HStack(alignment: .top, spacing: 16 * scale) {
        sectionHeader(L10n.Settings.palette, L10n.Settings.paletteDescription)
        Spacer(minLength: 0)
        Button { surpriseMe() } label: {
          HStack(spacing: 6 * scale) {
            CapoIcon(.sparkles, size: 14)
            Text(L10n.Settings.surpriseMe).capoText(.xs, weight: .medium)
          }
          .foregroundStyle(CapoTheme.mutedForeground)
          .padding(.horizontal, 12 * scale).padding(.vertical, 6 * scale)
          .frame(minHeight: CapoMetrics.minHitTarget)
          .background(CapoTheme.muted.opacity(0.6), in: Capsule())
          .overlay(Capsule().strokeBorder(CapoTheme.border, lineWidth: 1))
          .contentShape(Capsule())
        }
        .buttonStyle(.plain)
      }
      LazyVGrid(columns: columns(2), spacing: 8 * scale) {
        ForEach(CapoPalette.all) { palette in
          PaletteCard(palette: palette, selected: currentPalette.id == palette.id) { choose(palette: palette) }
        }
      }
    }
  }

  private var fontSection: some View {
    VStack(alignment: .leading, spacing: 16 * scale) {
      sectionHeader(L10n.Settings.font, L10n.Settings.fontDescription)
      LazyVGrid(columns: columns(wide ? 4 : 2), spacing: 8 * scale) {
        ForEach(CapoUIFont.all) { font in
          FontCard(font: font, selected: currentFont.id == font.id) { choose(font: font) }
        }
      }
    }
  }

  private var themeSection: some View {
    VStack(alignment: .leading, spacing: 16 * scale) {
      sectionHeader(L10n.Settings.theme, L10n.Settings.themeDescription)
      HStack(spacing: 12 * scale) {
        themeTile(.sun, L10n.Settings.themeLight, .light)
        themeTile(.moon, L10n.Settings.themeDark, .dark)
        themeTile(.monitor, L10n.Settings.themeSystem, .system)
      }
    }
  }

  private func themeTile(_ icon: CapoIconName, _ title: String, _ theme: AppTheme) -> some View {
    OptionTile(icon: icon, title: title, selected: (model.preferences.theme ?? .system) == theme) {
      model.preferences.theme = theme
      save(PreferencesPatch(theme: theme))
    }
  }

  private var languageSection: some View {
    VStack(alignment: .leading, spacing: 16 * scale) {
      sectionHeader(L10n.Settings.language, L10n.Settings.languageDescription)
      HStack(spacing: 8 * scale) {
        ForEach(SettingsModel.languages, id: \.code) { language in
          LanguageChip(
            flag: language.flag, name: language.name, selected: model.currentLanguageCode == language.code
          ) { chooseLanguage(language.code) }
        }
      }
      if languageChanged {
        Text(SettingsStrings.restartForLanguage).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground)
      }
    }
  }

  private var chordHandSection: some View {
    VStack(alignment: .leading, spacing: 16 * scale) {
      sectionHeader(L10n.Settings.chordHand, L10n.Settings.chordHandDescription)
      HStack(spacing: 8 * scale) {
        OptionTile(
          icon: .guitar, title: L10n.Settings.rightHand,
          selected: model.preferences.resolvedChordHand == .right
        ) { chooseHand(.right) }
        OptionTile(
          icon: .guitar, title: L10n.Settings.leftHand,
          selected: model.preferences.resolvedChordHand == .left, mirrored: true
        ) { chooseHand(.left) }
      }
    }
  }

  // MARK: Account

  private var accountContent: some View {
    VStack(alignment: .leading, spacing: 24 * scale) {
      sectionHeader(SettingsStrings.account)
      Button { confirmSignOut = true } label: {
        HStack(spacing: 6 * scale) {
          CapoIcon(.logOut, size: 14)
          Text(SettingsStrings.signOut)
        }
      }
      .buttonStyle(CapoSecondaryButtonStyle())
      divider
      sectionHeader(SettingsStrings.data)
      Button(SettingsStrings.eraseAndSignOut) { confirmErase = true }
        .buttonStyle(CapoSecondaryButtonStyle())
      divider
      environmentRows
      if context.deleteAccount != nil {
        dangerZone
      }
    }
  }

  @ViewBuilder
  private var environmentRows: some View {
    VStack(alignment: .leading, spacing: 8 * scale) {
      sectionHeader(L10n.Ios.Server.environment)
      if context.isDemo {
        infoRow(L10n.Ios.Server.environment, L10n.Ios.Demo.badge)
      } else {
        if let name = context.environmentName { infoRow(L10n.Ios.Server.environment, name) }
        if let url = context.serverURL { infoRow(L10n.Ios.Server.url, url.absoluteString) }
      }
      infoRow(SettingsStrings.version, SettingsModel.appVersion())
    }
  }

  private var dangerZone: some View {
    VStack(alignment: .leading, spacing: 12 * scale) {
      Text(L10n.Settings.dangerZone).capoText(.base, weight: .semibold).foregroundStyle(CapoTheme.destructive)
      Text(L10n.Settings.dangerZoneDescription).capoText(.sm).foregroundStyle(CapoTheme.mutedForeground)
      Button(model.isDeleting ? L10n.Settings.deleteAccountPending : L10n.Settings.deleteAccount) {
        confirmDelete = true
      }
      .buttonStyle(CapoDestructiveButtonStyle())
      .disabled(model.isDeleting)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(16 * scale)
    .overlay(
      RoundedRectangle(cornerRadius: CapoRadius.xl * scale, style: .continuous)
        .strokeBorder(CapoTheme.destructive.opacity(0.5), lineWidth: 1)
    )
  }

  // MARK: Bindings and actions

  private var currentPalette: CapoPalette { CapoPalette.named(model.preferences.palette) ?? .default }
  private var currentFont: CapoUIFont { CapoUIFont.named(model.preferences.uiFont) ?? .default }

  private func columns(_ count: Int) -> [GridItem] {
    Array(repeating: GridItem(.flexible(), spacing: 8 * scale), count: count)
  }

  private func choose(palette: CapoPalette) {
    model.preferences.palette = palette.id
    CapoPaletteStore.shared.current = palette
    save(PreferencesPatch(palette: palette.id))
  }

  private func choose(font: CapoUIFont) {
    model.preferences.uiFont = font.id
    CapoPaletteStore.shared.uiFont = font
    save(PreferencesPatch(uiFont: font.id))
  }

  /// Random palette and font, never the current ones (web `palette-settings.tsx:229`).
  private func surpriseMe() {
    var rng = SystemRandomNumberGenerator()
    let pick = CapoAppearance.surprise(
      palette: model.preferences.palette, font: model.preferences.uiFont, theme: nil, flipTheme: false,
      using: &rng)
    model.preferences.palette = pick.palette.id
    model.preferences.uiFont = pick.font.id
    CapoPaletteStore.shared.current = pick.palette
    CapoPaletteStore.shared.uiFont = pick.font
    save(CapoAppearance.patch(palette: pick.palette, font: pick.font))
  }

  private func chooseHand(_ hand: ChordHand) {
    model.preferences.chordHand = hand.rawValue
    save(PreferencesPatch(chordHand: hand))
  }

  private func chooseLanguage(_ code: String) {
    guard code != model.currentLanguageCode else { return }
    model.preferences.locale = code
    SettingsModel.storeLanguage(code)
    languageChanged = code != SettingsModel.runningLanguageCode
    save(PreferencesPatch(locale: code))
  }

  private func save(_ patch: PreferencesPatch) {
    let settings = services.settings
    Task { try? await settings.updatePreferences(patch) }
  }

  private var columnsBinding: Binding<Int> {
    Binding(
      get: { model.preferences.lyricsColumns },
      set: { newValue in
        model.preferences.lyricsColumns = newValue
        save(PreferencesPatch(lyricsColumns: newValue))
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
