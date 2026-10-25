import CapoIcons
import SwiftUI

/// The web's `BucketSelector` ("Save to"): Personal plus the teams where the user can create
/// content. Hidden when the user has no team that allows creating, as on the web.
public struct BucketPicker: View {
  @Binding var selection: AppContext
  var label: String?

  @Environment(\.userServices) private var services
  @State private var teams: [TeamWithRole] = []

  public init(selection: Binding<AppContext>, label: String? = L10n.Songs.bucket) {
    _selection = selection
    self.label = label
  }

  /// Teams where `canEditContent` holds, sorted by name.
  static func creatable(_ teams: [TeamWithRole]) -> [Team] {
    teams.filter { $0.role.canEditContent }.map(\.team)
      .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
  }

  private var options: [Team] { Self.creatable(teams) }

  private var selectedTeam: Team? {
    selection.teamID.flatMap { id in options.first { $0.id == id } }
  }

  public var body: some View {
    Group {
      if !options.isEmpty { picker }
    }
    .task {
      for await list in services.teams.teams() { teams = list }
    }
  }

  private var picker: some View {
    VStack(alignment: .leading, spacing: 6) {
      if let label { Text(label).capoText(.sm, weight: .medium) }
      Menu {
        Button { selection = .personal(userID: services.userID) } label: {
          Text(L10n.Nav.personal)
        }
        ForEach(options) { team in
          Button { selection = .team(teamID: team.id) } label: { Text(team.name) }
        }
      } label: {
        HStack(spacing: 8) {
          if let team = selectedTeam {
            CapoIcon.named(team.icon, size: 16).foregroundStyle(CapoTheme.mutedForeground)
            Text(team.name).capoText(.sm).foregroundStyle(CapoTheme.foreground).lineLimit(1)
          } else {
            CapoIcon(.user, size: 16).foregroundStyle(CapoTheme.mutedForeground)
            Text(L10n.Nav.personal).capoText(.sm).foregroundStyle(CapoTheme.foreground)
          }
          Spacer(minLength: 8)
          CapoIcon(.chevronDown, size: 16).foregroundStyle(CapoTheme.mutedForeground)
        }
        .padding(.horizontal, 12)
        .frame(minHeight: 44)
        .background(
          CapoTheme.background, in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous)
        )
        .overlay(
          RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous)
            .strokeBorder(CapoTheme.input, lineWidth: 1))
      }
      .accessibilityLabel(label ?? L10n.Songs.bucket)
    }
  }
}
