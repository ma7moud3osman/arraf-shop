import '../../features/attendance/data/repositories/attendance_repository_impl.dart';
import '../../features/attendance/domain/repositories/attendance_repository.dart';
import '../../features/attendance/presentation/providers/attendance_history_provider.dart';
import '../../features/attendance/presentation/providers/attendance_provider.dart';
import '../../features/audits/data/repositories/audit_repository_impl.dart';
import '../../features/audits/domain/realtime/audit_realtime.dart';
import '../../features/audits/domain/repositories/audit_repository.dart';
import '../../features/audits/presentation/providers/audits_list_provider.dart';
import '../../features/auth/data/repositories/auth_repository_impl.dart';
import '../../features/auth/data/repositories/employee_auth_repository_impl.dart';
import '../../features/auth/presentation/providers/auth_provider.dart';
import '../../features/payroll/data/repositories/payroll_repository_impl.dart';
import '../../features/payroll/domain/repositories/payroll_repository.dart';
import '../../features/payroll/presentation/providers/payroll_list_provider.dart';
import '../../features/settings/presentation/providers/settings_provider.dart';
import '../../imports/imports.dart';

/// Composes the MultiProvider that wraps the app.
///
/// Layering:
///  * Bottom: singletons / interfaces (repositories + realtime) exposed as
///    plain [Provider]s. Downstream [ChangeNotifierProvider]s read them via
///    `context.read<T>()` in their `create` callbacks.
///  * Top: [ChangeNotifierProvider]s for session state (auth + audits list).
///
/// Session-scoped providers (e.g. `AuditSessionProvider` for a specific
/// uuid) are not registered here — they're instantiated per-route in
/// `app_router.dart` so each session screen instance gets a fresh provider.
class StateWrapper extends StatelessWidget {
  final Widget child;

  const StateWrapper({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // ── Domain dependencies (plain Providers, not ChangeNotifiers) ──
        Provider<AuditRepository>(create: (_) => AuditRepositoryImpl()),
        Provider<AuditRealtime>(create: (_) => PusherService.instance),
        Provider<AttendanceRepository>(
          create: (_) => AttendanceRepositoryImpl(),
        ),
        Provider<PayrollRepository>(create: (_) => PayrollRepositoryImpl()),

        // ── Auth (single source of truth for the signed-in actor) ──────
        ChangeNotifierProvider(
          create:
              (_) => AuthProvider(
                authRepository: AuthRepositoryImpl(),
                employeeRepository: EmployeeAuthRepositoryImpl(),
              ),
        ),

        // ── Audits ─────────────────────────────────────────────────────
        ChangeNotifierProvider(
          create:
              (ctx) => AuditsListProvider(
                repository: ctx.read<AuditRepository>(),
                realtime: ctx.read<AuditRealtime>(),
              ),
        ),

        // ── Attendance (employee-only) ─────────────────────────────────
        ChangeNotifierProvider(
          create:
              (ctx) => AttendanceProvider(
                repository: ctx.read<AttendanceRepository>(),
              ),
        ),
        ChangeNotifierProvider(
          create:
              (ctx) => AttendanceHistoryProvider(
                repository: ctx.read<AttendanceRepository>(),
              ),
        ),

        // ── Payroll (employee-only) ────────────────────────────────────
        ChangeNotifierProvider(
          create:
              (ctx) => PayrollListProvider(
                repository: ctx.read<PayrollRepository>(),
              ),
        ),

        // ── User preferences (theme + locale) ──────────────────────────
        ChangeNotifierProvider(create: (_) => SettingsProvider()),
      ],
      child: child,
    );
  }
}
