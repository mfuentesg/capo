import CapoFakes

/// Lets targets that do not link CapoFakes (CapoShellUI) offer the demo dependencies.
public enum DemoSupport {
  public static var dependencies: AppDependencies { .demo }
}
