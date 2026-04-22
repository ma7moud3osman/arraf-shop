import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

import 'package:arraf_shop/src/features/auth/domain/entities/shop_employee.dart';
import 'package:arraf_shop/src/features/auth/domain/repositories/employee_auth_repository.dart';

/// Holds the authenticated [ShopEmployee] for the current session.
///
/// Login itself flows through [AuthProvider.login] + the unified
/// `/api/login` endpoint; this provider owns
///  * the in-memory cache of the current employee,
///  * cold-start rehydration via `GET /shop-employees/me` when the
///    active token slot is the employee one, and
///  * the employee-side logout call.
class EmployeeAuthProvider extends ChangeNotifier {
  EmployeeAuthProvider({
    required EmployeeAuthRepository repository,
    SecureStorageService? storage,
  })  : _repository = repository,
        _storage = storage ?? SecureStorageService.instance {
    _rehydrate();
  }

  final EmployeeAuthRepository _repository;
  final SecureStorageService _storage;

  ShopEmployee? _employee;
  bool _hydrating = true;

  ShopEmployee? get employee => _employee;

  /// True only during the initial `me()` call on cold start — gives the
  /// auth-redirect guard a chance to not bounce the user to onboarding
  /// before we know whether a saved employee session is still valid.
  bool get isHydrating => _hydrating;

  /// Called by [AuthProvider] after a successful employee branch of the
  /// unified login. Exposed publicly so the orchestrator can populate the
  /// slot without reaching into private fields.
  void setAuthenticated(ShopEmployee employee) {
    _employee = employee;
    _hydrating = false;
    notifyListeners();
  }

  /// On cold start, restore the current employee if the saved auth mode is
  /// `employee`. Fails silently (clears the token) when the server rejects —
  /// the SessionListenerWrapper will route to login.
  Future<void> _rehydrate() async {
    final mode = await _storage.readAuthMode();
    if (mode != 'employee') {
      _hydrating = false;
      notifyListeners();
      return;
    }

    final result = await _repository.me();
    result.fold(
      (failure) async {
        // Token expired or revoked server-side — drop it so future requests
        // don't carry a stale employee token.
        await _storage.clearActiveToken();
        _employee = null;
      },
      (employee) {
        _employee = employee;
      },
    );
    _hydrating = false;
    notifyListeners();
  }

  Future<void> logout({BuildContext? context}) async {
    final result = await _repository.logout();
    _employee = null;
    notifyListeners();
    result.fold(
      (failure) {
        if (context != null && context.mounted) {
          showToast(context, message: failure.message, status: 'error');
        }
      },
      (_) {
        if (context != null && context.mounted) {
          context.go(AppRoutes.login);
        }
      },
    );
  }
}
