/// Canonical responsive width tiers for KPMS (mobile / tablet / desktop).
abstract final class ResponsiveBreakpoints {
  /// Below this width: preserve exact mobile UI (bottom nav, sheets, spacing).
  static const double mobile = 700;

  /// Tablet range: [mobile, desktop).
  static const double tablet = 1100;

  /// At or above this width: enterprise desktop shell.
  static const double desktop = tablet;
}
