import 'package:arraf_shop/src/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_status.dart';
import 'package:arraf_shop/src/features/audits/domain/realtime/audit_realtime.dart';
import 'package:arraf_shop/src/features/audits/domain/repositories/audit_repository.dart';
import 'package:arraf_shop/src/features/audits/presentation/providers/audit_session_provider.dart';
import 'package:arraf_shop/src/features/audits/presentation/providers/audits_list_provider.dart';
import 'package:arraf_shop/src/features/audits/presentation/screens/audit_session_screen.dart';
import 'package:arraf_shop/src/features/audits/presentation/screens/audit_summary_screen.dart';
import 'package:arraf_shop/src/features/audits/presentation/screens/audits_list_screen.dart';
import 'package:arraf_shop/src/features/gold_price/presentation/screens/gold_price_screen.dart';
import 'package:arraf_shop/src/features/purchase_invoices/domain/repositories/purchase_invoice_repository.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/create_purchase_invoice_provider.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/purchase_invoice_detail_provider.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/screens/create_purchase_invoice_screen.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/screens/purchase_invoice_detail_screen.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/screens/purchase_invoices_list_screen.dart';
import 'package:arraf_shop/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:arraf_shop/src/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:arraf_shop/src/features/auth/presentation/screens/login_screen.dart';
import 'package:arraf_shop/src/features/employees/presentation/screens/employees_screen.dart';
import 'package:arraf_shop/src/features/home/presentation/screens/home_page.dart';
import 'package:arraf_shop/src/features/onboarding/presentation/screens/onboarding_page.dart';
import 'package:arraf_shop/src/features/payroll/presentation/screens/payslips_screen.dart';
import 'package:arraf_shop/src/features/settings/presentation/screens/settings_screen.dart';
import 'package:arraf_shop/src/features/splash/presentation/screens/animated_splash_screen.dart';
import 'package:arraf_shop/src/routing/app_routes.dart';
import 'package:arraf_shop/src/routing/global_navigator.dart';
import 'package:arraf_shop/src/services/storage_service.dart';
import 'package:easy_localization/easy_localization.dart';
import 'package:arraf_shop/src/shared/widgets/app_shell_scaffold.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

/// Route names used with `context.goNamed` / `pushNamed`. Centralized to keep
/// the router file as the single source of truth.
abstract final class AppRouteNames {
  AppRouteNames._();
  static const splash = 'splash';
  static const onboarding = 'onboarding';
  static const login = 'login';
  static const employeeLogin = 'employeeLogin';
  static const signup = 'signup';
  static const forgotPassword = 'forgotPassword';
  static const home = 'home';
  static const audits = 'audits';
  static const auditsView = 'auditsView';
  static const auditSession = 'auditSession';
  static const auditSummary = 'auditSummary';
  static const settings = 'settings';
  static const attendance = 'attendance';
  static const payslips = 'payslips';
  static const employees = 'employees';
  static const goldPrice = 'goldPrice';
  static const createPurchaseInvoice = 'createPurchaseInvoice';
  static const purchaseInvoices = 'purchaseInvoices';
  static const purchaseInvoiceDetail = 'purchaseInvoiceDetail';
}

/// Auth-gated paths. Anyone visiting these without a live session (owner
/// OR employee) is bounced to `/onboarding`.
const Set<String> _authGatedPrefixes = {
  AppRoutes.audits,
  AppRoutes.auditsView,
  AppRoutes.home,
  AppRoutes.settings,
  AppRoutes.attendance,
  AppRoutes.payslips,
  AppRoutes.employees,
  AppRoutes.goldPrice,
  AppRoutes.purchaseInvoices,
  AppRoutes.createPurchaseInvoice,
};

bool _isAuthGated(String location) {
  return _authGatedPrefixes.any(
    (prefix) => location == prefix || location.startsWith('$prefix/'),
  );
}

String? _authRedirect(BuildContext context, GoRouterState state) {
  final location = state.matchedLocation;

  if (location == AppRoutes.onboarding &&
      (StorageService.instance.getBool(onboardingCompletedStorageKey) ??
          false)) {
    return AppRoutes.login;
  }

  if (!_isAuthGated(location)) return null;

  final session = context.read<AuthProvider>();
  // Don't bounce while we're still resolving cold-start state — the
  // provider flips to authenticated/unauthenticated the moment the
  // cached actor is read, and the redirect runs again on notifyListeners.
  if (session.isHydrating || session.status == SessionStatus.unknown) {
    return null;
  }
  if (session.isAuthenticated) return null;

  return AppRoutes.login;
}

// Dedicated navigator keys for each shell branch so that go_router can
// preserve per-tab stacks (e.g. audits list → audit session → summary
// doesn't reset when switching tabs).
final _homeNavKey = GlobalKey<NavigatorState>(debugLabel: 'home');
final _attendanceNavKey = GlobalKey<NavigatorState>(debugLabel: 'attendance');
final _employeesNavKey = GlobalKey<NavigatorState>(debugLabel: 'employees');
final _auditsNavKey = GlobalKey<NavigatorState>(debugLabel: 'audits');
final _invoicesNavKey = GlobalKey<NavigatorState>(debugLabel: 'invoices');
final _settingsNavKey = GlobalKey<NavigatorState>(debugLabel: 'settings');

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.splash,
  redirect: _authRedirect,
  routes: <RouteBase>[
    // ── Outside the shell: splash, onboarding, auth ────────────────────
    GoRoute(
      path: AppRoutes.splash,
      name: AppRouteNames.splash,
      builder:
          (context, state) => AnimatedSplashScreen(
            onComplete: () async {
              // Wait for the auth provider's cold-start rehydrate before
              // routing — otherwise we race secure-storage reads and
              // bounce the user to login despite a valid persisted token.
              final session = context.read<AuthProvider>();
              while (session.isHydrating) {
                await Future<void>.delayed(const Duration(milliseconds: 50));
              }

              final onboardingDone =
                  StorageService.instance.getBool(
                    onboardingCompletedStorageKey,
                  ) ??
                  false;

              if (session.isAuthenticated) {
                appRouter.go(AppRoutes.home);
              } else if (onboardingDone) {
                appRouter.go(AppRoutes.login);
              } else {
                appRouter.go(AppRoutes.onboarding);
              }
            },
          ),
    ),
    GoRoute(
      path: AppRoutes.onboarding,
      name: AppRouteNames.onboarding,
      builder: (context, state) => const OnboardingPage(),
    ),
    GoRoute(
      path: AppRoutes.login,
      name: AppRouteNames.login,
      builder: (context, state) => const LoginScreen(),
    ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      name: AppRouteNames.forgotPassword,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),

    // ── Payslips: employee-only detail, lives outside the shell so the
    // bottom bar is hidden while viewing the list ────────────────────
    GoRoute(
      path: AppRoutes.payslips,
      name: AppRouteNames.payslips,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const PayslipsScreen(),
    ),

    // ── Gold price (everyone reads, admin edits) ─────────────────────
    GoRoute(
      path: AppRoutes.goldPrice,
      name: AppRouteNames.goldPrice,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => const GoldPriceScreen(),
    ),

    // ── Create Purchase Invoice (admin-only) ─────────────────────────
    // Uses a route-scoped provider so each entry into the wizard starts
    // with a fresh draft (otherwise re-opening would inherit the last
    // submission's items list).
    GoRoute(
      path: AppRoutes.createPurchaseInvoice,
      name: AppRouteNames.createPurchaseInvoice,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final draftIdRaw = state.uri.queryParameters['draftId'];
        final draftId = draftIdRaw == null ? null : int.tryParse(draftIdRaw);
        return ChangeNotifierProvider(
          create:
              (ctx) => CreatePurchaseInvoiceProvider(
                repository: ctx.read<PurchaseInvoiceRepository>(),
              ),
          child: CreatePurchaseInvoiceScreen(draftId: draftId),
        );
      },
    ),

    // ── Purchase invoice detail (draft or completed) ─────────────────
    // Lives outside the shell so it pushes over the bottom bar. The path
    // is `/purchase-invoices/:id` — note it shares the `purchase-invoices`
    // prefix with the list route inside the shell, but go_router routes
    // the more-specific `:id` segment here.
    GoRoute(
      path: '${AppRoutes.purchaseInvoices}/:id',
      name: AppRouteNames.purchaseInvoiceDetail,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final id = int.parse(state.pathParameters['id']!);
        return ChangeNotifierProvider<PurchaseInvoiceDetailProvider>(
          create: (ctx) => PurchaseInvoiceDetailProvider(
            repository: ctx.read<PurchaseInvoiceRepository>(),
            invoiceId: id,
          ),
          child: PurchaseInvoiceDetailScreen(invoiceId: id),
        );
      },
    ),

    // ── Standalone audits list: pushed from the home screen so it opens
    // full-screen over the shell (no bottom nav). The `/audits` shell
    // branch is still used by the employee bottom-nav tab.
    GoRoute(
      path: AppRoutes.auditsView,
      name: AppRouteNames.auditsView,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => AuditsListScreen(
        isAdmin: context.read<AuthProvider>().isAdmin,
        onOpen: (session) async {
          final target = session.status == AuditStatus.completed
              ? AppRoutes.auditSummary(session.uuid)
              : AppRoutes.auditSession(session.uuid);
          await context.push(target);
          if (context.mounted) {
            await context.read<AuditsListProvider>().refresh();
          }
        },
      ),
    ),

    // ── Audit session + summary: push over the shell so the scanner
    // gets a full-screen experience without the bottom nav ───────────
    GoRoute(
      path: '${AppRoutes.audits}/:uuid',
      name: AppRouteNames.auditSession,
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) {
        final uuid = state.pathParameters['uuid']!;
        return _AuditSessionRoute(uuid: uuid);
      },
      routes: [
        GoRoute(
          path: 'summary',
          name: AppRouteNames.auditSummary,
          parentNavigatorKey: rootNavigatorKey,
          builder: (context, state) {
            final uuid = state.pathParameters['uuid']!;
            return AuditSummaryScreen(uuid: uuid);
          },
        ),
      ],
    ),

    // ── Bottom-nav shell with 5 branches (the nav bar filters which
    // 4 are visible per role) ─────────────────────────────────────────
    StatefulShellRoute.indexedStack(
      builder:
          (context, state, navShell) => AppShellScaffold(navShell: navShell),
      branches: [
        // 0 — Home
        StatefulShellBranch(
          navigatorKey: _homeNavKey,
          routes: [
            GoRoute(
              path: AppRoutes.home,
              name: AppRouteNames.home,
              builder: (context, state) => const HomePage(),
            ),
          ],
        ),
        // 1 — Attendance (employee tab)
        StatefulShellBranch(
          navigatorKey: _attendanceNavKey,
          routes: [
            GoRoute(
              path: AppRoutes.attendance,
              name: AppRouteNames.attendance,
              builder: (context, state) => const AttendanceScreen(),
            ),
          ],
        ),
        // 2 — Employees (admin tab)
        StatefulShellBranch(
          navigatorKey: _employeesNavKey,
          routes: [
            GoRoute(
              path: AppRoutes.employees,
              name: AppRouteNames.employees,
              builder: (context, state) => const EmployeesScreen(),
            ),
          ],
        ),
        // 3 — Audits (list only; session/summary push over the shell)
        StatefulShellBranch(
          navigatorKey: _auditsNavKey,
          routes: [
            GoRoute(
              path: AppRoutes.audits,
              name: AppRouteNames.audits,
              builder:
                  (context, state) => AuditsListScreen(
                    isAdmin: context.read<AuthProvider>().isAdmin,
                    onOpen: (session) async {
                      final target =
                          session.status == AuditStatus.completed
                              ? AppRoutes.auditSummary(session.uuid)
                              : AppRoutes.auditSession(session.uuid);
                      await context.push(target);
                      if (context.mounted) {
                        await context.read<AuditsListProvider>().refresh();
                      }
                    },
                  ),
            ),
          ],
        ),
        // 4 — Settings
        StatefulShellBranch(
          navigatorKey: _settingsNavKey,
          routes: [
            GoRoute(
              path: AppRoutes.settings,
              name: AppRouteNames.settings,
              builder: (context, state) => const SettingsScreen(),
            ),
          ],
        ),
        // 5 — Purchase invoices (owner-only tab; replaces Audits in the
        // owner's bottom nav). Appended at the end so the existing
        // branch indices (home/attendance/employees/audits/settings)
        // stay stable.
        StatefulShellBranch(
          navigatorKey: _invoicesNavKey,
          routes: [
            GoRoute(
              path: AppRoutes.purchaseInvoices,
              name: AppRouteNames.purchaseInvoices,
              builder: (context, state) => const PurchaseInvoicesListScreen(),
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Wraps [AuditSessionScreen] with a route-scoped [AuditSessionProvider].
class _AuditSessionRoute extends StatelessWidget {
  const _AuditSessionRoute({required this.uuid});
  final String uuid;

  @override
  Widget build(BuildContext context) {
    final session = context.read<AuthProvider>();
    final isOwner = session.isOwner;
    final employee = session.employee;

    return ChangeNotifierProvider<AuditSessionProvider>(
      create:
          (ctx) => AuditSessionProvider(
            repository: ctx.read<AuditRepository>(),
            realtime: ctx.read<AuditRealtime>(),
            deviceLabel: _resolveDeviceLabel(
              isOwner: isOwner,
              employeeName: employee?.name,
            ),
            shopEmployeeId: isOwner ? null : employee?.id,
          ),
      child: AuditSessionScreen(
        uuid: uuid,
        isOwner: isOwner,
        onCompleted: (_) => context.replace(AppRoutes.auditSummary(uuid)),
      ),
    );
  }

  String _resolveDeviceLabel({required bool isOwner, String? employeeName}) {
    if (isOwner) return 'device.owner'.tr();
    if (employeeName != null && employeeName.isNotEmpty) return employeeName;
    return 'device.mobile'.tr();
  }
}
