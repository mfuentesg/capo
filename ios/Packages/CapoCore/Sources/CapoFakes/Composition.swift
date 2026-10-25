import CapoCore
import Foundation

extension UserServices {
  /// Every service backed by one seeded InMemoryBackend.
  public static func fake(
    backend: InMemoryBackend = InMemoryBackend(), sync: any SyncService = FakeSyncService()
  ) -> UserServices {
    UserServices(
      userID: backend.userID,
      songs: FakeSongRepository(backend: backend),
      tags: FakeTagRepository(backend: backend),
      playlists: FakePlaylistRepository(backend: backend),
      settings: FakeSettingsRepository(backend: backend),
      teams: FakeTeamRepository(backend: backend),
      sharing: FakeSharingService(backend: backend),
      conflicts: FakeConflictRepository(backend: backend),
      sync: sync,
      tearDown: { _ in }
    )
  }

  /// Shared demo data for SwiftUI previews and the environment default.
  public static let preview = UserServices.fake()
}

extension AppDependencies {
  /// Demo mode: signed in as the demo user, everything in memory, nothing leaves the device.
  public static var demo: AppDependencies {
    AppDependencies(
      config: nil, isDemo: true, auth: FakeAuthService(),
      makeUserServices: { session in
        UserServices.fake(backend: InMemoryBackend(userID: session.userID))
      })
  }
}
