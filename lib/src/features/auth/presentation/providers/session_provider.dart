import 'dart:async';

import 'package:arraf_shop/src/features/auth/domain/entities/user.dart';
import 'package:arraf_shop/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:arraf_shop/src/services/secure_storage_service.dart';
import 'package:flutter/foundation.dart';

enum SessionStatus { unknown, authenticated, unauthenticated }

class SessionProvider extends ChangeNotifier {
  SessionProvider({
    required AuthRepository repository,
    SecureStorageService? storage,
  }) : _repository = repository,
       _storage = storage ?? SecureStorageService.instance {
    _init();
  }

  final AuthRepository _repository;
  final SecureStorageService _storage;
  StreamSubscription<AppUser?>? _authSub;

  SessionStatus _status = SessionStatus.unknown;
  AppUser? _user;
  bool _loggingOut = false;

  SessionStatus get status => _status;
  AppUser? get user => _user;
  bool get isAuthenticated => _status == SessionStatus.authenticated;
  bool get isLoggingOut => _loggingOut;

  Future<void> _init() async {
    // If the saved auth mode is `employee`, `/profile` will 401 because it
    // only accepts User Sanctum tokens. Short-circuit to unauthenticated on
    // the owner side — the EmployeeAuthProvider handles its own rehydrate.
    final mode = await _storage.readAuthMode();
    if (mode == 'employee') {
      _status = SessionStatus.unauthenticated;
      notifyListeners();
      _listenToAuthChanges();
      return;
    }

    final result = await _repository.checkAuthState();
    result.fold(
      (_) {
        _status = SessionStatus.unauthenticated;
        notifyListeners();
      },
      (user) {
        if (user != null) {
          _user = user;
          _status = SessionStatus.authenticated;
        } else {
          _status = SessionStatus.unauthenticated;
        }
        notifyListeners();
      },
    );

    _listenToAuthChanges();
  }

  void _listenToAuthChanges() {
    _authSub = _repository.onAuthStateChanged.listen((user) {
      if (user != null) {
        _user = user;
        _status = SessionStatus.authenticated;
      } else {
        _user = null;
        _status = SessionStatus.unauthenticated;
      }
      notifyListeners();
    });
  }

  Future<void> logout() async {
    if (_loggingOut) return;
    _loggingOut = true;
    notifyListeners();
    try {
      await _repository.logout();
      _user = null;
      _status = SessionStatus.unauthenticated;
    } finally {
      _loggingOut = false;
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}
