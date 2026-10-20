## WP5 notes

### Delivered
- CapoDesign: oklch-based section accents (light/dark), FlagBadge (FLAG_CONFIG), TagChip, SyncStatusBadge,
  EmptyStateView, CapoFont, toast modifier, `CapoMetrics`.
- CapoShellUI: `CapoRootView`, `SessionStore`, `ContextStore` (per-user UserDefaults), `ShellModel`,
  adaptive shell (3-column split on regular, TabView on compact), sheets/covers, add-to-setlist chooser.
- CapoAuthUI: `AuthView` + `AuthFormModel` (Google, email/password, sign-up only when env != production).
- Tests: CapoDesignTests, CapoAuthUITests, CapoShellUITests (20 tests, pass on iPhone 15 Pro).

### Deviations
- `AuthView()` has a frozen no-arg init, so the shell injects `AuthActions` via a new `\.authActions`
  environment value (CapoDesign/AuthEnvironment.swift).
- Auth/Shell targets have no resources, so there is no `Bundle.module`; fallback strings use
  `Bundle.capoDesign` (keys `ios.shell.*`, `ios.auth.*`, `ios.sync.*`, marked `// TODO(i18n)`). WP12 harvests them.
- `DemoSupport.dependencies` (CapoDesign) exposes `AppDependencies.demo` to CapoShellUI, which does not link CapoFakes.
- The shell starts sync (`start()` + `syncNow(.appLaunch)`) and runs `syncNow(.foreground)` on scenePhase active.
  The integrator should not duplicate these. Theme preference is applied via `preferredColorScheme` in the shell.

### TODO / open
- Sign-out outside the shell's confirm flow (e.g. from Settings calling `auth.signOut()`) tears down without erasing.
- App build and demo screenshots (iPhone + iPad) pending: disk was full.
- Regular-width layout only verified by build; needs visual review once screenshots exist.
