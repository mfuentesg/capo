import CapoDesign
import CapoIcons
import SwiftUI

/// CifraClub import dialog (web `cifraclub-import-dialog.tsx`). `create` starts a new song from the
/// page; `replaceLyrics` swaps the lyrics of the song being edited, asking first when it has any.
public struct CifraClubImportView: View {
  public enum Mode: Equatable {
    case create
    case replaceLyrics(hasExistingLyrics: Bool)
  }

  enum Step: Equatable { case input, loading, confirmReplace, failed(CifraClubError) }

  let mode: Mode
  let importer: CifraClubImporter
  let onImported: (CifraClubSong) -> Void
  let onClose: () -> Void

  @State private var url = ""
  @State private var step: Step = .input
  @State private var pending: CifraClubSong?
  @FocusState private var focused: Bool

  public init(
    mode: Mode, importer: CifraClubImporter = CifraClubImporter(),
    onImported: @escaping (CifraClubSong) -> Void, onClose: @escaping () -> Void
  ) {
    self.mode = mode
    self.importer = importer
    self.onImported = onImported
    self.onClose = onClose
  }

  /// Error copy as the web dialog maps it.
  static func message(for error: CifraClubError) -> String {
    switch error {
    case .invalidURL: L10n.Songs.CifraImport.Errors.invalidUrl
    case .wrongHost: L10n.Songs.CifraImport.Errors.unsupportedHost
    case .network, .httpStatus: L10n.Songs.CifraImport.Errors.network
    case .noChordBlock: L10n.Songs.CifraImport.Errors.parseFailed
    case .rateLimited: L10n.Songs.CifraImport.Errors.rateLimited
    case .unexpected: L10n.Songs.CifraImport.Errors.unknown
    }
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text(mode == .create ? L10n.Songs.CifraImport.dialogTitleCreate : L10n.Songs.CifraImport.dialogTitleReplace)
        .capoText(.lg, weight: .semibold, tracking: -0.025)
        .accessibilityAddTraits(.isHeader)
      if step == .confirmReplace {
        alert(L10n.Songs.CifraImport.confirmReplaceDescription)
        footer {
          button(L10n.Common.cancel, primary: false) { step = .input }
          button(L10n.Songs.CifraImport.confirmReplaceTitle, primary: true) {
            if let pending { onImported(pending) }
            onClose()
          }
        }
      } else {
        VStack(alignment: .leading, spacing: 8) {
          Text(L10n.Songs.CifraImport.urlLabel).capoText(.sm, weight: .medium)
          TextField(L10n.Songs.CifraImport.urlPlaceholder, text: $url)
            .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
            .focused($focused).disabled(step == .loading)
            .capoText(.sm)
            .padding(.horizontal, 12).frame(minHeight: 44)
            .background(CapoTheme.card, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
            .overlay(
              RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous).strokeBorder(CapoTheme.input)
            )
            .accessibilityIdentifier("cifra.url")
        }
        if case .failed(let error) = step { alert(Self.message(for: error)) }
        footer {
          button(L10n.Common.cancel, primary: false, action: onClose)
          importButton
        }
      }
    }
    .padding(20)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(CapoTheme.background)
    .onAppear { focused = true }
  }

  private var importButton: some View {
    let disabled = url.trimmingCharacters(in: .whitespaces).isEmpty || step == .loading
    return Button { Task { await run() } } label: {
      HStack(spacing: 8) {
        if step == .loading {
          ProgressView().controlSize(.small).tint(CapoTheme.primaryForeground)
          Text(L10n.Songs.CifraImport.importing)
        } else {
          CapoIcon(.music4, size: 16)
          Text(L10n.Songs.CifraImport.importButton)
        }
      }
      .capoText(.sm, weight: .medium)
      .foregroundStyle(CapoTheme.primaryForeground)
      .padding(.horizontal, 16).frame(minHeight: 44)
      .background(CapoTheme.primary, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
      .opacity(disabled ? 0.5 : 1)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain).disabled(disabled)
    .accessibilityIdentifier("cifra.import")
  }

  private func button(_ title: String, primary: Bool, action: @escaping () -> Void) -> some View {
    Button(action: action) {
      Text(title).capoText(.sm, weight: .medium)
        .foregroundStyle(primary ? CapoTheme.primaryForeground : CapoTheme.foreground)
        .padding(.horizontal, 16).frame(minHeight: 44)
        .background(primary ? CapoTheme.primary : Color.clear, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
        .overlay(
          RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous)
            .strokeBorder(primary ? Color.clear : CapoTheme.input)
        )
        .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }

  private func footer<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
    HStack(spacing: 8) {
      Spacer(minLength: 0)
      content()
    }
  }

  private func alert(_ text: String) -> some View {
    Text(text).capoText(.sm).foregroundStyle(CapoTheme.destructive)
      .frame(maxWidth: .infinity, alignment: .leading).padding(12)
      .background(CapoTheme.destructive.opacity(0.08), in: RoundedRectangle(cornerRadius: CapoRadius.base, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: CapoRadius.base, style: .continuous)
          .strokeBorder(CapoTheme.destructive.opacity(0.4)))
      .accessibilityIdentifier("cifra.error")
  }

  private func run() async {
    step = .loading
    switch await importer.importSong(from: url) {
    case .failure(let error): step = .failed(error)
    case .success(let song):
      if case .replaceLyrics(hasExistingLyrics: true) = mode {
        pending = song
        step = .confirmReplace
      } else {
        onImported(song)
        onClose()
      }
    }
  }
}
