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

  // ── Admin-only ───────────────────────────────────────────
  static const String employees = '/employees';

  // ── Gold price (read for everyone, edit for admin) ───────
  static const String goldPrice = '/gold-price';

  // ── Purchase invoices ────────────────────────────────────
  /// Owner-only Invoices tab — paginated list of purchase invoices.
  /// Replaces the Audits slot in the bottom nav for owners; employees
  /// keep Audits in their nav.
  static const String purchaseInvoices = '/purchase-invoices';

  /// Admin-only create-invoice wizard. Lives outside the shell so it
  /// pushes over the bottom nav. Optional `?draftId=` query param resumes
  /// an existing draft (skips Phase 1, locks the header + items).
  static const String createPurchaseInvoice = '/purchase-invoices/create';

  /// `/purchase-invoices/:id` — single invoice detail (draft or completed).
  /// Lives outside the shell so it pushes over the bottom bar.
  static String purchaseInvoiceDetail(int id) => '/purchase-invoices/$id';

  // ── Audits ───────────────────────────────────────────────
  static const String audits = '/audits';

  /// Standalone audits-list route that pushes over the shell. Used from
  /// the home screen so the list opens full-screen (no bottom nav).
  /// `/audits` (the shell branch) stays for the bottom-nav tab.
  static const String auditsView = '/audits-view';

  /// `/audits/:uuid` — audit session detail. Use instead of string-concat
  /// so a UUID containing unusual chars can't break the path.
  static String auditSession(String uuid) =>
      '/audits/${Uri.encodeComponent(uuid)}';

  /// `/audits/:uuid/summary` — completed session report.
  static String auditSummary(String uuid) =>
      '/audits/${Uri.encodeComponent(uuid)}/summary';
}
