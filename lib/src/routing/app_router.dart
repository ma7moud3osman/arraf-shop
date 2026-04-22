import 'package:arraf_shop/src/routing/app_routes.dart';
import 'package:arraf_shop/src/routing/global_navigator.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'package:arraf_shop/src/features/auth/presentation/providers/employee_auth_provider.dart';
import 'package:arraf_shop/src/features/auth/presentation/providers/session_provider.dart';
// import 'package:arraf_shop/src/features/auth/presentation/screens/employee_login_screen.dart';
import 'package:arraf_shop/src/features/auth/presentation/screens/forgot_password_screen.dart';
import 'package:arraf_shop/src/features/auth/presentation/screens/login_screen.dart';
// import 'package:arraf_shop/src/features/auth/presentation/screens/signup_screen.dart';
import 'package:arraf_shop/src/features/audits/domain/entities/audit_status.dart';
import 'package:arraf_shop/src/features/audits/domain/realtime/audit_realtime.dart';
import 'package:arraf_shop/src/features/audits/domain/repositories/audit_repository.dart';
import 'package:arraf_shop/src/features/audits/presentation/providers/audit_session_provider.dart';
import 'package:arraf_shop/src/features/audits/presentation/providers/audits_list_provider.dart';
import 'package:arraf_shop/src/features/audits/presentation/screens/audit_session_screen.dart';
import 'package:arraf_shop/src/features/audits/presentation/screens/audit_summary_screen.dart';
import 'package:arraf_shop/src/features/audits/presentation/screens/audits_list_screen.dart';
import 'package:arraf_shop/src/features/attendance/presentation/screens/attendance_screen.dart';
import 'package:arraf_shop/src/features/home/presentation/screens/home_page.dart';
import 'package:arraf_shop/src/features/onboarding/presentation/screens/onboarding_page.dart';
import 'package:arraf_shop/src/features/payroll/presentation/screens/payslips_screen.dart';
import 'package:arraf_shop/src/features/settings/presentation/screens/settings_screen.dart';

/// Route names used with `context.goNamed` / `pushNamed`. Centralized to keep
/// the router file as the single source of truth.
abstract final class AppRouteNames {
  AppRouteNames._();
  static const onboarding = 'onboarding';
  static const login = 'login';
  static const employeeLogin = 'employeeLogin';
  static const signup = 'signup';
  static const forgotPassword = 'forgotPassword';
  static const home = 'home';
  static const audits = 'audits';
  static const auditSession = 'auditSession';
  static const auditSummary = 'auditSummary';
  static const settings = 'settings';
  static const attendance = 'attendance';
  static const payslips = 'payslips';
}

/// Auth-gated paths. Anyone visiting these without a live session (owner
/// OR employee) is bounced to `/onboarding`.
const Set<String> _authGatedPrefixes = {
  AppRoutes.audits,
  AppRoutes.home,
  AppRoutes.settings,
  AppRoutes.attendance,
  AppRoutes.payslips,
};

bool _isAuthGated(String location) {
  return _authGatedPrefixes.any(
    (prefix) => location == prefix || location.startsWith('$prefix/'),
  );
}

/// Returns a redirect target, or `null` to let the navigation proceed.
///
/// Guard policy:
///  * Owner session (SessionProvider.isAuthenticated) → allow everywhere.
///  * Employee session (EmployeeAuthProvider.employee != null) → allow audits.
///  * Neither → redirect any auth-gated path to /onboarding.
///
/// Auth state on cold-start is `unknown`; we don't redirect from /audits in
/// that case so the SessionProvider's initial check has a chance to resolve.
String? _authRedirect(BuildContext context, GoRouterState state) {
  final location = state.matchedLocation;
  if (!_isAuthGated(location)) return null;

  final session = context.read<SessionProvider>();
  if (session.status == SessionStatus.unknown) {
    // Still resolving — let the page render, SessionListenerWrapper will
    // kick the user out later if it turns out they're unauthenticated.
    return null;
  }
  if (session.isAuthenticated) return null;

  final employeeAuth = context.read<EmployeeAuthProvider>();
  if (employeeAuth.isHydrating) {
    // Employee rehydrate is in flight (cold start with a saved employee
    // token). Let the page render — the provider will notify once me()
    // resolves and the redirect runs again.
    return null;
  }
  if (employeeAuth.employee != null) return null;

  return AppRoutes.onboarding;
}

final GoRouter appRouter = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: AppRoutes.onboarding,
  redirect: _authRedirect,
  routes: <RouteBase>[
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
    // Employee login disabled — mobile now uses the unified `/api/login`
    // endpoint via LoginScreen for both owners and employees.
    // Signup disabled — mobile app is sign-in only for existing accounts.
    // Re-register this GoRoute to restore.
    // GoRoute(
    //   path: AppRoutes.signup,
    //   name: AppRouteNames.signup,
    //   builder: (context, state) => const SignupScreen(),
    // ),
    GoRoute(
      path: AppRoutes.forgotPassword,
      name: AppRouteNames.forgotPassword,
      builder: (context, state) => const ForgotPasswordScreen(),
    ),
    GoRoute(
      path: AppRoutes.home,
      name: AppRouteNames.home,
      builder: (context, state) => const HomePage(),
    ),
    GoRoute(
      path: AppRoutes.settings,
      name: AppRouteNames.settings,
      builder: (context, state) => const SettingsScreen(),
    ),

    // ── Employee: attendance + payslips ──────────────────────────────
    GoRoute(
      path: AppRoutes.attendance,
      name: AppRouteNames.attendance,
      builder: (context, state) => const AttendanceScreen(),
    ),
    GoRoute(
      path: AppRoutes.payslips,
      name: AppRouteNames.payslips,
      builder: (context, state) => const PayslipsScreen(),
    ),

    // ── Audits ────────────────────────────────────────────────────────
    GoRoute(
      path: AppRoutes.audits,
      name: AppRouteNames.audits,
      builder:
          (context, state) => AuditsListScreen(
            isOwner: context.read<SessionProvider>().isAuthenticated,
            onOpen: (session) async {
              // Completed sessions go straight to the summary; in-progress
              // sessions go to the live scanner. Using push keeps the list
              // screen in the stack so the back button returns there.
              final target =
                  session.status == AuditStatus.completed
                      ? AppRoutes.auditSummary(session.uuid)
                      : AppRoutes.auditSession(session.uuid);
              await context.push(target);
              // On return, refresh so scanned counts/progress reflect work
              // done inside the session (including updates from other
              // devices broadcasted via the session screen).
              if (context.mounted) {
                await context.read<AuditsListProvider>().refresh();
              }
            },
          ),
      routes: [
        GoRoute(
          path: ':uuid',
          name: AppRouteNames.auditSession,
          builder: (context, state) {
            final uuid = state.pathParameters['uuid']!;
            return _AuditSessionRoute(uuid: uuid);
          },
          routes: [
            GoRoute(
              path: 'summary',
              name: AppRouteNames.auditSummary,
              builder: (context, state) {
                final uuid = state.pathParameters['uuid']!;
                return AuditSummaryScreen(uuid: uuid);
              },
            ),
          ],
        ),
      ],
    ),
  ],
);

/// Wraps [AuditSessionScreen] with a route-scoped [AuditSessionProvider].
///
/// A fresh provider is built per route instance so that navigating between
/// two different sessions doesn't leak state from the previous session (the
/// provider owns a realtime subscription that must be torn down).
class _AuditSessionRoute extends StatelessWidget {
  const _AuditSessionRoute({required this.uuid});
  final String uuid;

  @override
  Widget build(BuildContext context) {
    final session = context.read<SessionProvider>();
    final employee = context.read<EmployeeAuthProvider>().employee;
    final isOwner = session.isAuthenticated;

    return ChangeNotifierProvider<AuditSessionProvider>(
      create:
          (ctx) => AuditSessionProvider(
            repository: ctx.read<AuditRepository>(),
            realtime: ctx.read<AuditRealtime>(),
            deviceLabel: _resolveDeviceLabel(
              isOwner: isOwner,
              employeeName: employee?.name,
            ),
            // When the caller is an employee the backend attributes the scan
            // automatically; pass null. Owners must supply an employee id.
            shopEmployeeId: isOwner ? null : employee?.id,
          ),
      child: AuditSessionScreen(
        uuid: uuid,
        isOwner: isOwner,
        // Replace (not push) so the completed session screen is popped off
        // the stack — otherwise back-from-summary would land on a session
        // screen that auto-navigates back to summary (loop).
        onCompleted: (_) => context.replace(AppRoutes.auditSummary(uuid)),
      ),
    );
  }

  /// Short, human-readable device label persisted with each scan.
  /// Refined devices/labels can be plumbed in later from DeviceInfoService.
  String _resolveDeviceLabel({required bool isOwner, String? employeeName}) {
    if (isOwner) return 'Owner device';
    if (employeeName != null && employeeName.isNotEmpty) return employeeName;
    return 'Mobile';
  }
}
