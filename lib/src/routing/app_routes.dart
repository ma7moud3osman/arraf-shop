/// Centralized route path constants for GoRouter.
///
/// Use these variables instead of raw strings throughout the app.
/// Example: `context.go(AppRoutes.onboarding)` instead of `context.go('/')`.
abstract final class AppRoutes {
  AppRoutes._();

  static const String splash = '/splash';
  static const String home = '/';
  static const String onboarding = '/onboarding';
  static const String login = '/login';
  static const String employeeLogin = '/employee-login';
  static const String signup = '/signup';
  static const String forgotPassword = '/forgot-password';

  // ── Settings ─────────────────────────────────────────────
  static const String settings = '/settings';

  // ── Employee-only ────────────────────────────────────────
  static const String attendance = '/attendance';
  static const String payslips = '/payslips';

  // ── Audits ───────────────────────────────────────────────
  static const String audits = '/audits';

  /// `/audits/:uuid` — audit session detail. Use instead of string-concat
  /// so a UUID containing unusual chars can't break the path.
  static String auditSession(String uuid) =>
      '/audits/${Uri.encodeComponent(uuid)}';

  /// `/audits/:uuid/summary` — completed session report.
  static String auditSummary(String uuid) =>
      '/audits/${Uri.encodeComponent(uuid)}/summary';
}
