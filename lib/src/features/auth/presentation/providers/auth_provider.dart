import 'package:arraf_shop/src/features/auth/domain/entities/auth_result.dart';
import 'package:arraf_shop/src/features/auth/domain/entities/current_actor.dart';
import 'package:arraf_shop/src/features/auth/domain/entities/shop_employee.dart';
import 'package:arraf_shop/src/features/auth/domain/entities/user.dart';
import 'package:arraf_shop/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:arraf_shop/src/features/auth/domain/repositories/employee_auth_repository.dart';
import 'package:arraf_shop/src/routing/app_routes.dart';
import 'package:arraf_shop/src/services/secure_storage_service.dart';
import 'package:arraf_shop/src/services/storage_service.dart';
import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Coarse-grained lifecycle state used by the router's redirect guard.
enum SessionStatus { unknown, authenticated, unauthenticated }

/// Single source of truth for the signed-in actor (owner OR employee),
/// the four auth-adjacent actions (login / signup / forgot-password /
/// logout), and cold-start rehydration.
///
/// All state transitions are **synchronous** so that `context.go` can
/// trigger a redirect in the same microtask and see the new state.
class AuthProvider extends ChangeNotifier {
  AuthProvider({
    required AuthRepository authRepository,
    required EmployeeAuthRepository employeeRepository,
    SecureStorageService? storage,
  }) : _authRepository = authRepository,
       _employeeRepository = employeeRepository,
       _storage = storage ?? SecureStorageService.instance {
    _hydrate();
  }

  final AuthRepository _authRepository;
  final EmployeeAuthRepository _employeeRepository;
  final SecureStorageService _storage;

  // ── State ───────────────────────────────────────────────────────────
  SessionStatus _status = SessionStatus.unknown;
  CurrentActor? _actor;
  bool _hydrating = true;
  bool _loggingIn = false;
  bool _signingUp = false;
  bool _sendingResetCode = false;
  bool _loggingOut = false;

  // ── Getters ─────────────────────────────────────────────────────────
  SessionStatus get status => _status;
  CurrentActor? get actor => _actor;

  bool get isAuthenticated => _status == SessionStatus.authenticated;
  bool get isOwner => _actor?.isOwner ?? false;
  bool get isEmployee => _actor?.isEmployee ?? false;

  /// True during the initial cold-start cache lookup. The router guard
  /// uses this to avoid bouncing the user to /login before we've had a
  /// chance to read the saved token slot.
  bool get isHydrating => _hydrating;

  bool get isLoggingIn => _loggingIn;
  bool get isSigningUp => _signingUp;
  bool get isSendingResetCode => _sendingResetCode;
  bool get isLoggingOut => _loggingOut;

  /// Back-compat conveniences so existing widgets can keep reading `.user`
  /// or `.employee` without switching on role everywhere.
  AppUser? get user => _actor?.user;
  ShopEmployee? get employee => _actor?.employee;

  // ── Cold-start rehydrate ────────────────────────────────────────────
  Future<void> _hydrate() async {
    final mode = await _storage.readAuthMode();
    switch (mode) {
      case 'owner':
        final cached = StorageService.instance.getJson(
          StorageService.cachedOwnerUserKey,
        );
        if (cached != null) {
          _actor = CurrentActor.owner(
            AppUser(
              id: cached['id']?.toString() ?? '',
              email: (cached['email'] as String?) ?? '',
              name: cached['name'] as String?,
              photoUrl:
                  (cached['photoUrl'] as String?) ??
                  (cached['image'] as String?),
            ),
          );
          _status = SessionStatus.authenticated;
        } else {
          _status = SessionStatus.unauthenticated;
        }
      case 'employee':
        final cached = StorageService.instance.getJson(
          StorageService.cachedEmployeeKey,
        );
        if (cached != null) {
          try {
            _actor = CurrentActor.employee(ShopEmployee.fromJson(cached));
            _status = SessionStatus.authenticated;
          } catch (_) {
            // Schema drift in the cache — drop it and fall through to
            // unauthenticated so we render /login, not a stale identity.
            _actor = null;
            _status = SessionStatus.unauthenticated;
          }
        } else {
          _status = SessionStatus.unauthenticated;
        }
      default:
        _status = SessionStatus.unauthenticated;
    }
    _hydrating = false;
    notifyListeners();
  }

  // ── Login ───────────────────────────────────────────────────────────
  /// Returns `null` on success, or a user-facing error message on
  /// failure. On success, session state is already flipped to
  /// authenticated — the caller can `context.go(home)` immediately.
  Future<String?> login({
    required String mobile,
    required String password,
  }) async {
    if (_loggingIn) return null;
    _loggingIn = true;
    notifyListeners();

    try {
      final result = await _authRepository.login(
        mobile: mobile,
        password: password,
      );
      return result.fold<String?>((failure) => failure.message, (authResult) {
        switch (authResult) {
          case OwnerAuthResult(:final user):
            _setAuthenticated(CurrentActor.owner(user));
          case EmployeeAuthResult(:final employee):
            _setAuthenticated(CurrentActor.employee(employee));
        }
        return null;
      });
    } finally {
      _loggingIn = false;
      notifyListeners();
    }
  }

  // ── Signup (owner-only) ─────────────────────────────────────────────
  Future<String?> signUp({
    required String name,
    required String email,
    required String mobile,
    required String password,
    String? gender,
  }) async {
    if (_signingUp) return null;
    _signingUp = true;
    notifyListeners();

    try {
      final result = await _authRepository.signUp(
        name: name,
        email: email,
        mobile: mobile,
        password: password,
        gender: gender ?? 'male',
      );
      return result.fold<String?>((failure) => failure.message, (user) {
        _setAuthenticated(CurrentActor.owner(user));
        return null;
      });
    } finally {
      _signingUp = false;
      notifyListeners();
    }
  }

  // ── Forgot password ────────────────────────────────────────────────
  Future<String?> forgotPassword({required String mobile}) async {
    if (_sendingResetCode) return null;
    _sendingResetCode = true;
    notifyListeners();

    try {
      final result = await _authRepository.forgotPassword(mobile: mobile);
      return result.fold<String?>((failure) => failure.message, (_) => null);
    } finally {
      _sendingResetCode = false;
      notifyListeners();
    }
  }

  // ── Logout ──────────────────────────────────────────────────────────
  /// Calls the correct endpoint for the current actor, clears state, and
  /// (when a [context] is supplied) navigates to /login.
  Future<void> logout({BuildContext? context}) async {
    if (_loggingOut) return;
    _loggingOut = true;
    notifyListeners();

    try {
      // Route the logout call to the actor-specific endpoint.
      if (isEmployee) {
        await _employeeRepository.logout();
      } else {
        // Owner logout also covers the "no actor" case (idempotent
        // server clear; never throws for a missing token).
        await _authRepository.logout();
      }
      _setUnauthenticated();
      if (context != null && context.mounted) {
        context.go(AppRoutes.login);
      }
    } finally {
      _loggingOut = false;
      notifyListeners();
    }
  }

  // ── 401 handler entry point ─────────────────────────────────────────
  /// Wipe in-memory state without calling the server (the bearer token is
  /// already dead). Called by [SessionExpiredHandler] — which also clears
  /// persisted tokens and navigates to /login.
  void clear() {
    if (_actor == null && _status == SessionStatus.unauthenticated) return;
    _setUnauthenticated();
  }

  // ── Internal helpers ────────────────────────────────────────────────
  void _setAuthenticated(CurrentActor actor) {
    _actor = actor;
    _status = SessionStatus.authenticated;
    _hydrating = false;
    notifyListeners();
  }

  void _setUnauthenticated() {
    _actor = null;
    _status = SessionStatus.unauthenticated;
    _hydrating = false;
    notifyListeners();
  }
}
