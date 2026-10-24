import CapoDesign
import CapoIcons
import SwiftUI

/// The 80 lucide names the web icon picker offers (`components/ui/icon-picker.tsx`), stored verbatim
/// in `teams.icon`.
nonisolated enum TeamIconCatalog {
  static let names: [String] = [
    // Music & audio
    "Music", "Music2", "Music3", "Music4", "Mic", "Mic2", "Guitar", "Drum", "Piano", "Headphones",
    "Radio", "Disc", "Disc3", "Album",
    // People
    "Users", "Users2", "User", "UserCircle",
    // Achievement
    "Star", "Trophy", "Award", "Medal", "Crown", "Target", "CheckCircle2",
    // Energy
    "Heart", "Zap", "Flame", "Sparkles", "Sparkle", "Rocket", "Lightbulb",
    // Protection, precious
    "Shield", "ShieldCheck", "Sword", "Gem", "Diamond", "Gift",
    // Organization
    "LayoutGrid", "Settings", "Settings2", "Briefcase", "Book", "BookOpen", "Calendar", "Clock", "Bell",
    // Places
    "Globe", "Globe2", "MapPin", "Compass", "Mountain", "Home", "Building", "Building2",
    // Nature
    "Sun", "Moon", "Cloud", "CloudRain", "Leaf", "Flower2", "Waves",
    // Hobbies
    "Coffee", "Palette", "Camera", "Film", "Gamepad2", "Puzzle",
    // Maritime, fun, status
    "Anchor", "Ship", "Umbrella", "Smile", "Ghost", "Cat", "Dog", "Bird", "Fish", "Lock", "Flag",
    "AlertCircle"
  ]

  /// Stored value for new teams and the fallback for unknown names.
  static let defaultName = "Users"
}

/// Grid of every selectable team icon; the current one is highlighted.
struct TeamIconPicker: View {
  @Binding var selection: String?
  var onPick: (() -> Void)?

  private let columns = [GridItem(.adaptive(minimum: 48, maximum: 56), spacing: 8)]

  var body: some View {
    let current = selection ?? TeamIconCatalog.defaultName
    ScrollView {
      LazyVGrid(columns: columns, spacing: 8) {
        ForEach(TeamIconCatalog.names, id: \.self) { name in
          Button {
            selection = name
            onPick?()
          } label: {
            CapoIcon.named(name, size: 24)
              .foregroundStyle(CapoTheme.text)
              .frame(width: 48, height: 48)
              .background(
                name == current ? CapoTheme.accent : Color.clear,
                in: RoundedRectangle(cornerRadius: CapoRadius.md, style: .continuous))
          }
          .buttonStyle(.plain)
          .accessibilityLabel(name)
          .accessibilityAddTraits(name == current ? .isSelected : [])
        }
      }
      .padding(16)
    }
  }
}

/// Round trigger (`bg-primary/10 border p-2`) that opens the picker in a sheet.
struct TeamIconPickerButton: View {
  @Binding var icon: String?
  @State private var open = false

  var body: some View {
    Button { open = true } label: {
      CapoIcon.named(icon, size: 24)
        .foregroundStyle(CapoTheme.text)
        .frame(width: 44, height: 44)
        .background(CapoTheme.primary.opacity(0.1), in: Circle())
        .overlay(Circle().strokeBorder(CapoTheme.border, lineWidth: 1))
    }
    .buttonStyle(.plain)
    .accessibilityLabel(TeamsStrings.iconPickerTitle)
    .sheet(isPresented: $open) { TeamIconPickerSheet(icon: $icon) }
  }
}

struct TeamIconPickerSheet: View {
  @Binding var icon: String?
  @Environment(\.dismiss) private var dismiss

  var body: some View {
    NavigationStack {
      TeamIconPicker(selection: $icon) { dismiss() }
        .background(CapoTheme.background)
        .navigationTitle(TeamsStrings.iconPickerTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
          ToolbarItem(placement: .cancellationAction) { Button(TeamsStrings.cancel) { dismiss() } }
        }
    }
    .presentationDetents([.medium, .large])
  }
}
