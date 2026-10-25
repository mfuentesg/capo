import CapoDesign
import CapoIcons
import CapoRendering
import SwiftUI

private let zinc950 = Color(.sRGB, red: 9 / 255, green: 9 / 255, blue: 11 / 255)

/// Chords section (web `features/chords/*`): Chord Library glossary and Chord Finder analyzer.
public struct ChordsView: View {
  enum Tab: Hashable { case glossary, analyzer }

  @Environment(\.userServices) private var services
  @Environment(\.horizontalSizeClass) private var sizeClass
  @State private var tab: Tab = .glossary
  @State private var hand = ChordHand.default

  public init() {}

  public var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 24) {
        header
        tabs
        switch tab {
        case .glossary: GlossaryView(hand: hand)
        case .analyzer: AnalyzerView(hand: hand)
        }
      }
      .frame(maxWidth: 1024, alignment: .leading)
      .padding(.horizontal, sizeClass == .regular ? 32 : 16)
      .padding(.vertical, 24)
      .frame(maxWidth: .infinity)
    }
    .scrollDismissesKeyboard(.interactively)
    .background(CapoTheme.background)
    .navigationTitle(L10n.Nav.chords)
    .navigationBarTitleDisplayMode(.inline)
    .task {
      for await preferences in services.settings.preferences() { hand = preferences.resolvedChordHand }
    }
  }

  private var header: some View {
    ViewThatFits(in: .horizontal) {
      HStack(alignment: .top) {
        titles
        Spacer(minLength: 16)
        handControl
      }
      VStack(alignment: .leading, spacing: 12) {
        titles
        handControl
      }
    }
  }

  private var titles: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text(L10n.Chords.Page.title).capoText(.xl3, weight: .bold, tracking: -0.025)
        .foregroundStyle(CapoTheme.foreground)
        .accessibilityAddTraits(.isHeader)
      Text(L10n.Chords.Page.subtitle).capoText(.sm).foregroundStyle(CapoTheme.mutedForeground)
    }
  }

  private var handControl: some View {
    HStack(spacing: 4) {
      ForEach(ChordHand.allCases, id: \.self) { option in
        Button {
          guard hand != option else { return }
          hand = option
          Task { try? await services.settings.updatePreferences(PreferencesPatch(chordHand: option)) }
        } label: {
          HStack(spacing: 6) {
            CapoIcon(.guitar, size: 14).scaleEffect(x: option == .left ? -1 : 1)
            Text(option == .left ? L10n.Settings.leftHand : L10n.Settings.rightHand)
              .capoText(.xs, weight: .semibold)
          }
          .padding(.horizontal, 12).frame(minHeight: 44)
          .foregroundStyle(hand == option ? CapoTheme.foreground : CapoTheme.mutedForeground)
          .background(hand == option ? CapoTheme.card : Color.clear, in: Capsule())
          .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(hand == option ? .isSelected : [])
      }
    }
    .padding(4)
    .background(CapoTheme.muted, in: Capsule())
    .accessibilityElement(children: .contain)
    .accessibilityLabel(L10n.Settings.chordHand)
  }

  private var tabs: some View {
    HStack(spacing: 4) {
      tabButton(.glossary, icon: .bookOpen, title: L10n.Chords.Page.glossaryTab, beta: nil)
      tabButton(.analyzer, icon: .scanSearch, title: L10n.Chords.Page.analyzerTab, beta: L10n.Chords.Page.betaBadge)
    }
    .padding(4)
    .background(CapoTheme.muted, in: RoundedRectangle(cornerRadius: CapoRadius.xl, style: .continuous))
    .fixedSize(horizontal: true, vertical: false)
  }

  private func tabButton(_ value: Tab, icon: CapoIconName, title: String, beta: String?) -> some View {
    Button { tab = value } label: {
      HStack(spacing: 8) {
        CapoIcon(icon, size: 16)
        Text(title).capoText(.sm, weight: .medium)
        if let beta {
          Text(beta).capoText(.px10, weight: .medium)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(CapoTheme.primary.opacity(0.15), in: Capsule())
            .foregroundStyle(CapoTheme.primary)
        }
      }
      .padding(.horizontal, 12).frame(minHeight: 44)
      .foregroundStyle(tab == value ? CapoTheme.foreground : CapoTheme.mutedForeground)
      .background(
        tab == value ? CapoTheme.card : Color.clear,
        in: RoundedRectangle(cornerRadius: CapoRadius.md + 2, style: .continuous)
      )
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityAddTraits(tab == value ? .isSelected : [])
  }
}

/// White (zinc-950 in dark) tile holding a diagram, as in the web cards.
struct DiagramTile: View {
  let position: ChordPosition
  let hand: ChordHand
  var padding: CGFloat = 8
  @Environment(\.colorScheme) private var scheme

  var body: some View {
    FretboardView(position: position, mirror: hand == .left)
      .padding(padding)
      .frame(maxWidth: .infinity)
      .background(
        scheme == .dark ? zinc950 : Color.white,
        in: RoundedRectangle(cornerRadius: CapoRadius.base, style: .continuous))
  }
}

struct GlossaryView: View {
  let hand: ChordHand
  @State private var query = ""
  @State private var selectedKey: String?
  @State private var selected: ChordEntry?
  @Environment(\.userServices) private var services

  private var chords: [ChordEntry] { ChordGlossary.filter(query: query, key: selectedKey) }

  var body: some View {
    VStack(alignment: .leading, spacing: 16) {
      search
      keyChips
      let chords = chords
      if chords.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          Capsule().fill(CapoTheme.mutedForeground.opacity(0.3)).frame(width: 32, height: 2)
            .padding(.bottom, 12)
          Text(L10n.Chords.Glossary.noResults).capoText(.base, weight: .bold, tracking: -0.025)
          Text(L10n.Common.tryDifferentSearch).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground)
        }
        .padding(.vertical, 40).padding(.horizontal, 8)
      } else {
        Text(L10n.Chords.Glossary.chordsFound(count: String(chords.count)))
          .capoText(.xs).foregroundStyle(CapoTheme.mutedForeground)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
          ForEach(chords) { chord in card(chord) }
        }
      }
    }
    .sheet(item: $selected) { chord in
      ScrollView {
        ChordDiagramView(
          chordName: chord.displayName, hand: hand,
          onHandChange: { option in
            Task { try? await services.settings.updatePreferences(PreferencesPatch(chordHand: option)) }
          }
        )
        .padding(20)
      }
      .capoTheme()
      .presentationDetents([.large])
      .presentationDragIndicator(.visible)
    }
  }

  private var search: some View {
    HStack(spacing: 8) {
      CapoIcon(.search, size: 16).foregroundStyle(CapoTheme.mutedForeground)
      TextField(L10n.Chords.Glossary.searchPlaceholder, text: $query)
        .textInputAutocapitalization(.never).autocorrectionDisabled()
        .capoText(.sm)
      if !query.isEmpty {
        Button { query = "" } label: {
          CapoIcon(.x, size: 16).foregroundStyle(CapoTheme.mutedForeground).frame(width: 44, height: 44)
        }
        .buttonStyle(.plain).accessibilityLabel(L10n.Common.clearSearch)
      }
    }
    .padding(.leading, 12).frame(minHeight: 44)
    .background(CapoTheme.card, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
    .overlay(
      RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous).strokeBorder(CapoTheme.input))
    .frame(maxWidth: 320)
  }

  private var keyChips: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 8) {
        ForEach(ChordGlossary.keys, id: \.self) { key in
          let isOn = selectedKey == key
          Button { selectedKey = isOn ? nil : key } label: {
            Text(ChordEntry.keyLabel(key)).capoText(.sm, weight: .semibold)
              .padding(.horizontal, 16).frame(minWidth: 44, minHeight: 44)
              .foregroundStyle(isOn ? CapoTheme.primaryForeground : CapoTheme.foreground)
              .background(isOn ? CapoTheme.primary : Color.clear, in: Capsule())
              .contentShape(Capsule())
          }
          .buttonStyle(.plain)
          .accessibilityAddTraits(isOn ? .isSelected : [])
        }
      }
    }
  }

  private func card(_ chord: ChordEntry) -> some View {
    Button { selected = chord } label: {
      VStack(spacing: 8) {
        if let position = ChordGlossary.firstPosition(chord) {
          DiagramTile(position: position, hand: hand)
        }
        Text(chord.displayName).capoText(.sm, weight: .semibold).foregroundStyle(CapoTheme.foreground)
      }
      .padding(12)
      .background(CapoTheme.card, in: RoundedRectangle(cornerRadius: CapoRadius.xl, style: .continuous))
      .overlay(
        RoundedRectangle(cornerRadius: CapoRadius.xl, style: .continuous)
          .strokeBorder(CapoTheme.border.opacity(0.6)))
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .accessibilityLabel(chord.displayName)
  }
}

struct AnalyzerView: View {
  let hand: ChordHand
  @State private var model = ChordAnalyzerModel()

  var body: some View {
    VStack(alignment: .leading, spacing: 24) {
      HStack(alignment: .center) {
        Text(L10n.Chords.Analyzer.instructionsDiagram).capoText(.sm)
          .foregroundStyle(CapoTheme.mutedForeground)
        Spacer(minLength: 12)
        Button { model.reset() } label: {
          HStack(spacing: 8) {
            CapoIcon(.rotateCcw, size: 14)
            Text(L10n.Chords.Analyzer.reset).capoText(.sm, weight: .medium)
          }
          .padding(.horizontal, 12).frame(minHeight: 44)
          .overlay(
            RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous).strokeBorder(CapoTheme.input))
          .contentShape(Rectangle())
        }
        .buttonStyle(.plain).foregroundStyle(CapoTheme.foreground)
      }
      FretboardInput(model: model).foregroundStyle(CapoTheme.foreground)
      if !model.notes.isEmpty { notes }
      results
    }
  }

  private var notes: some View {
    HStack(spacing: 8) {
      Text("\(L10n.Chords.Analyzer.notes):").capoText(.xs, weight: .medium).textCase(.uppercase)
        .foregroundStyle(CapoTheme.mutedForeground)
      ForEach(model.notes, id: \.self) { note in
        Text(note).capoText(.xs, weight: .semibold)
          .padding(.horizontal, 8).padding(.vertical, 2)
          .background(CapoTheme.muted, in: Capsule())
      }
    }
  }

  @ViewBuilder private var results: some View {
    let results = model.results
    if !model.hasInput {
      message(L10n.Chords.Analyzer.emptyStateTitle, L10n.Chords.Analyzer.emptyState)
    } else if results.isEmpty {
      message(L10n.Chords.Analyzer.noMatchTitle, L10n.Chords.Analyzer.noMatch)
    } else {
      VStack(alignment: .leading, spacing: 12) {
        Text(L10n.Chords.Analyzer.matches).capoText(.sm, weight: .semibold)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 8)], spacing: 8) {
          ForEach(results.prefix(8), id: \.name) { match in resultCard(match) }
        }
      }
    }
  }

  private func message(_ title: String, _ detail: String) -> some View {
    VStack(spacing: 4) {
      Text(title).capoText(.sm, weight: .semibold)
      Text(detail).capoText(.xs).foregroundStyle(CapoTheme.mutedForeground)
    }
    .frame(maxWidth: .infinity).padding(.vertical, 24)
  }

  private func resultCard(_ match: ChordIdentifier.Identified) -> some View {
    VStack(spacing: 8) {
      HStack(alignment: .top) {
        Text(match.name).capoText(.base, weight: .bold, tracking: -0.025)
        Spacer(minLength: 4)
        if match.isExact {
          Text(L10n.Chords.Analyzer.exact).capoText(.px10, weight: .semibold).textCase(.uppercase)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .foregroundStyle(CapoTheme.primary)
            .background(CapoTheme.primary.opacity(0.1), in: Capsule())
        }
      }
      if let key = ChordIdentifier.dbKey[match.root],
        let position = ChordDatabase.shared.positions(key: key, suffix: match.suffix).first
      {
        DiagramTile(position: position, hand: hand, padding: 4)
      }
      if match.missingNotes > 0 {
        Text(L10n.Chords.Analyzer.missingNotes(count: String(match.missingNotes)))
          .capoText(.px10).foregroundStyle(CapoTheme.mutedForeground)
      }
    }
    .padding(12)
    .background(
      match.isExact ? CapoTheme.primary.opacity(0.05) : CapoTheme.card,
      in: RoundedRectangle(cornerRadius: CapoRadius.xl, style: .continuous)
    )
    .overlay(
      RoundedRectangle(cornerRadius: CapoRadius.xl, style: .continuous)
        .strokeBorder(match.isExact ? CapoTheme.primary.opacity(0.3) : CapoTheme.border))
  }
}
