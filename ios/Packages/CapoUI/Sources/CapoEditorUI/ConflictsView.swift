import CapoDesign
import SwiftUI

/// One row of the side-by-side comparison.
struct ConflictField: Identifiable, Equatable {
  var id: String { label }
  var label: String
  var mine: String
  var theirs: String?  // nil = song deleted on the server
  var differs: Bool { theirs != nil && mine != theirs }
}

enum ConflictComparison {
  static func fields(local: Song, server: Song?) -> [ConflictField] {
    func f(_ label: String, _ mine: String?, _ theirs: String??) -> ConflictField {
      ConflictField(label: label, mine: mine ?? "", theirs: server == nil ? nil : (theirs ?? nil) ?? "")
    }
    return [
      f(EditorStrings.title, local.title, server?.title),
      f(EditorStrings.artist, local.artist, server?.artist),
      f(EditorStrings.key, local.key, server?.key),
      f(EditorStrings.bpm, local.bpm.map(String.init), server?.bpm.map { String($0) }),
      f(EditorStrings.transpose, "\(local.transpose)", server.map { "\($0.transpose)" }),
      f(EditorStrings.capo, "\(local.capo)", server.map { "\($0.capo)" }),
      f(EditorStrings.notes, local.notes, server?.notes),
      f(EditorStrings.lyrics, local.lyrics, server?.lyrics)
    ]
  }
}

@Observable
final class ConflictsModel {
  var conflicts: [SongConflict] = []
  var failed: [FailedOperation] = []
  var errorText: String?
  private(set) var resolving: Set<UUID> = []

  func resolve(_ conflict: SongConflict, _ resolution: ConflictResolution, repo: any ConflictRepository)
    async
  {
    resolving.insert(conflict.id)
    defer { resolving.remove(conflict.id) }
    do { try await repo.resolve(conflict.id, with: resolution) } catch {
      errorText = EditorStrings.resolveFailed
    }
  }
}

public struct ConflictsView: View {
  @Environment(\.userServices) private var services
  @State private var model = ConflictsModel()

  public init() {}

  public var body: some View {
    Group {
      if model.conflicts.isEmpty && model.failed.isEmpty {
        EmptyStateView(
          title: EditorStrings.conflictsEmptyTitle, message: EditorStrings.conflictsEmptyMessage,
          systemImage: "checkmark.circle")
      } else {
        List {
          ForEach(model.conflicts) { conflict in
            ConflictCard(conflict: conflict, busy: model.resolving.contains(conflict.id)) { resolution in
              Task { await model.resolve(conflict, resolution, repo: services.conflicts) }
            }
            .listRowSeparator(.hidden)
          }
          if !model.failed.isEmpty {
            Section {
              ForEach(model.failed) { op in
                FailedOperationRow(
                  operation: op,
                  onRetry: {
                    Task {
                      try? await services.conflicts.retryFailed(op.id)
                      await services.sync.syncNow(reason: .manual)
                    }
                  },
                  onDiscard: {
                    Task {
                      try? await services.conflicts.discardFailed(op.id)
                      await services.sync.syncNow(reason: .manual)
                    }
                  })
              }
            } header: {
              VStack(alignment: .leading, spacing: 4) {
                Text(EditorStrings.failedTitle).font(CapoFont.style(.headline))
                Text(EditorStrings.failedHint).font(CapoFont.style(.footnote))
                  .foregroundStyle(CapoTheme.mutedForeground).textCase(nil)
              }
              .padding(.vertical, 4)
            }
          }
        }
        .listStyle(.plain)
      }
    }
    .navigationTitle(EditorStrings.conflictsTitle)
    .task {
      for await list in services.conflicts.conflicts() { model.conflicts = list }
    }
    .task {
      for await list in services.conflicts.failedOperations() { model.failed = list }
    }
    .alert(
      EditorStrings.resolveFailed,
      isPresented: Binding(
        get: { model.errorText != nil }, set: { if !$0 { model.errorText = nil } })
    ) {
      Button(L10n.Common.close, role: .cancel) {}
    }
  }
}

private struct FailedOperationRow: View {
  let operation: FailedOperation
  let onRetry: () -> Void
  let onDiscard: () -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text(operation.subject ?? EditorStrings.failedKind(operation.kind))
        .font(CapoFont.style(.headline))
      Text(EditorStrings.failedKind(operation.kind))
        .font(CapoFont.style(.subheadline)).foregroundStyle(CapoTheme.mutedForeground)
      if let error = operation.error {
        Text(error).font(CapoFont.style(.caption)).foregroundStyle(.orange).lineLimit(3)
      }
      HStack(spacing: 8) {
        Button(EditorStrings.retry, action: onRetry).buttonStyle(.borderedProminent)
        Button(EditorStrings.discardFailed, role: .destructive, action: onDiscard).buttonStyle(.bordered)
      }
    }
    .padding(.vertical, 4)
  }
}

private struct ConflictCard: View {
  let conflict: SongConflict
  let busy: Bool
  let onResolve: (ConflictResolution) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      Text(conflict.local.title).font(CapoFont.style(.headline))
      if conflict.server == nil {
        Label(EditorStrings.deletedRemotely, systemImage: "trash")
          .font(CapoFont.style(.subheadline)).foregroundStyle(.orange)
      }
      HStack(alignment: .top, spacing: 12) {
        Text(EditorStrings.mine).font(CapoFont.style(.caption, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading)
        Text(EditorStrings.theirs).font(CapoFont.style(.caption, weight: .semibold)).frame(maxWidth: .infinity, alignment: .leading)
      }
      .foregroundStyle(CapoTheme.mutedForeground)
      ForEach(ConflictComparison.fields(local: conflict.local, server: conflict.server)) { field in
        fieldRow(field)
      }
      VStack(spacing: 8) {
        Button(EditorStrings.keepMine) { onResolve(.keepMine) }
          .buttonStyle(.borderedProminent)
        Button(EditorStrings.keepTheirs) { onResolve(.keepTheirs) }
          .buttonStyle(.bordered)
        if conflict.server != nil {
          Button(EditorStrings.keepBoth) { onResolve(.keepBothAsCopy) }
            .buttonStyle(.bordered)
        }
      }
      .frame(maxWidth: .infinity)
      .disabled(busy)
    }
    .padding()
    .background(.quaternary.opacity(0.4), in: RoundedRectangle(cornerRadius: CapoMetrics.cornerRadius))
  }

  private func fieldRow(_ field: ConflictField) -> some View {
    VStack(alignment: .leading, spacing: 4) {
      HStack {
        Text(field.label).font(CapoFont.style(.caption)).foregroundStyle(CapoTheme.mutedForeground)
        if field.differs {
          Text(EditorStrings.differs).font(CapoFont.style(.caption2, weight: .bold)).foregroundStyle(.orange)
        }
      }
      HStack(alignment: .top, spacing: 12) {
        cell(field.mine, highlighted: field.differs)
        cell(field.theirs, highlighted: field.differs)
      }
    }
  }

  private func cell(_ value: String?, highlighted: Bool) -> some View {
    let isLyrics = (value ?? "").contains("\n")
    return Text(value.map { $0.isEmpty ? EditorStrings.empty : $0 } ?? "—")
      .font(isLyrics ? .system(.footnote, design: .monospaced) : .subheadline)
      .lineLimit(8)
      .frame(maxWidth: .infinity, alignment: .leading)
      .padding(6)
      .background(highlighted ? Color.orange.opacity(0.12) : .clear, in: RoundedRectangle(cornerRadius: 6))
  }
}
