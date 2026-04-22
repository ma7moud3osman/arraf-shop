import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

import 'package:arraf_shop/src/features/auth/presentation/providers/employee_auth_provider.dart';
import 'package:arraf_shop/src/features/auth/presentation/providers/session_provider.dart';

/// Watches both auth providers and performs the one-shot post-resolve
/// navigation (splash → home / onboarding) once the app knows who's
/// signed in.
///
///  * Owner session resolved → `/home`.
///  * Employee session resolved (rehydrated from saved token) → `/home`.
///  * Both resolved as logged-out → `/onboarding`.
///  * Either still hydrating → wait.
class SessionListenerWrapper extends StatefulWidget {
  final Widget child;
  const SessionListenerWrapper({super.key, required this.child});

  @override
  State<SessionListenerWrapper> createState() => _SessionListenerWrapperState();
}

class _SessionListenerWrapperState extends State<SessionListenerWrapper> {
  bool _initialRoutePushed = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final session = Provider.of<SessionProvider>(context);
    final employeeAuth = Provider.of<EmployeeAuthProvider>(context);

    // Still probing — either the owner-side /profile call hasn't landed yet
    // or the employee rehydrate is mid-flight.
    if (session.status == SessionStatus.unknown || employeeAuth.isHydrating) {
      return;
    }

    // The initial splash-to-route handoff runs exactly once; after the user
    // logs in/out we rely on the provider's own navigation calls and the
    // router's auth guard.
    if (_initialRoutePushed) return;
    _initialRoutePushed = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      FlutterNativeSplash.remove();

      final loggedIn = session.isAuthenticated || employeeAuth.employee != null;

      // Use the global router instance — this widget lives in
      // `MaterialApp.router`'s `builder`, which is above the GoRouter
      // InheritedWidget, so `context.go` cannot find it.
      if (loggedIn) {
        appRouter.go(AppRoutes.home);
      } else {
        appRouter.go(AppRoutes.onboarding);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
