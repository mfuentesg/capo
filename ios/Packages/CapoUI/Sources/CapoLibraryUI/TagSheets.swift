import CapoDesign
import SwiftUI

let tagPalette = [
  "#6b7280", "#ef4444", "#f97316", "#eab308", "#22c55e", "#14b8a6", "#3b82f6", "#8b5cf6", "#ec4899"
]

func color(fromHex hex: String) -> Color {
  var s = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
  if s.count == 3 { s = s.map { "\($0)\($0)" }.joined() }
  guard s.count == 6, let v = UInt32(s, radix: 16) else { return .gray }
  return Color(
    red: Double((v >> 16) & 0xFF) / 255, green: Double((v >> 8) & 0xFF) / 255,
    blue: Double(v & 0xFF) / 255)
}

/// Create (name + colour) and delete tags for the current context.
struct TagManagementView: View {
  let tags: [SongTag]
  @Environment(\.userServices) private var services
  @Environment(\.appContext) private var context
  @Environment(\.dismiss) private var dismiss
  @State private var name = ""
  @State private var colorHex = tagPalette[0]
  @State private var errorText: String?

  var body: some View {
    NavigationStack {
      List {
        Section(LibraryStrings.newTag) {
          TextField(LibraryStrings.tagName, text: $name)
            .submitLabel(.done)
            .onSubmit(create)
          ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
              ForEach(tagPalette, id: \.self) { hex in
                Button { colorHex = hex } label: {
                  Circle().fill(color(fromHex: hex)).frame(width: 32, height: 32)
                    .overlay {
                      if hex == colorHex {
                        Image(systemName: "checkmark").font(.caption.bold()).foregroundStyle(.white)
                      }
                    }
                    .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(hex)
              }
            }
          }
          Button(LibraryStrings.create, action: create)
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
          if let errorText { Text(errorText).font(.footnote).foregroundStyle(.red) }
        }
        Section(LibraryStrings.tags) {
          if tags.isEmpty {
            EmptyStateView(
              title: LibraryStrings.noTags, message: LibraryStrings.noTagsHint,
              systemImage: "tag")
          }
          ForEach(tags) { tag in
            HStack {
              TagChip(name: tag.name, colorHex: tag.color)
              Spacer()
            }
            .frame(minHeight: 44)
            .swipeActions {
              Button(LibraryStrings.delete, role: .destructive) { delete(tag) }
            }
          }
        }
      }
      .navigationTitle(LibraryStrings.manageTags)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(LibraryStrings.done) { dismiss() }
        }
      }
    }
  }

  private func create() {
    let trimmed = name.trimmingCharacters(in: .whitespaces)
    guard !trimmed.isEmpty else { return }
    Task {
      do {
        _ = try await services.tags.create(name: trimmed, color: colorHex, in: context)
        name = ""
        errorText = nil
      } catch { errorText = String(describing: error) }
    }
  }

  private func delete(_ tag: SongTag) {
    Task {
      do { try await services.tags.delete(id: tag.id) } catch { errorText = String(describing: error) }
    }
  }
}

/// Toggle which tags a song has; each toggle is saved immediately through the repository.
struct AssignTagsView: View {
  let songID: SongID
  let allTags: [SongTag]
  @Environment(\.userServices) private var services
  @Environment(\.dismiss) private var dismiss
  @State private var assigned: Set<TagID> = []
  @State private var loaded = false

  var body: some View {
    NavigationStack {
      List {
        if allTags.isEmpty {
          EmptyStateView(
            title: LibraryStrings.noTags, message: LibraryStrings.noTagsHint, systemImage: "tag")
        }
        ForEach(allTags) { tag in
          Button { toggle(tag) } label: {
            HStack {
              TagChip(name: tag.name, colorHex: tag.color, isSelected: assigned.contains(tag.id))
              Spacer()
              if assigned.contains(tag.id) { Image(systemName: "checkmark").foregroundStyle(.tint) }
            }
            .frame(minHeight: 44)
            .contentShape(Rectangle())
          }
          .buttonStyle(.plain)
        }
      }
      .navigationTitle(LibraryStrings.assignTags)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button(LibraryStrings.done) { dismiss() }
        }
      }
      .task {
        for await tags in services.songs.tags(forSong: songID) {
          if !loaded { assigned = Set(tags.map(\.id)); loaded = true }
        }
      }
    }
  }

  private func toggle(_ tag: SongTag) {
    if !assigned.insert(tag.id).inserted { assigned.remove(tag.id) }
    let ids = allTags.map(\.id).filter(assigned.contains)
    Task { try? await services.songs.setTags(songID: songID, tagIDs: ids) }
  }
}
