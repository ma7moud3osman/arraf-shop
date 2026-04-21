import 'dart:async';
import 'package:arraf_shop/src/imports/packages_imports.dart';
import 'package:arraf_shop/src/features/auth/domain/entities/user.dart';
import 'package:arraf_shop/src/features/auth/domain/repositories/auth_repository.dart';

enum SessionStatus { unknown, authenticated, unauthenticated }

class SessionProvider extends ChangeNotifier {
  final AuthRepository _repository;
  StreamSubscription<AppUser?>? _authSub;

  SessionStatus _status = SessionStatus.unknown;
  AppUser? _user;

  SessionStatus get status => _status;
  AppUser? get user => _user;
  bool get isAuthenticated => _status == SessionStatus.authenticated;

  SessionProvider({required AuthRepository repository}) : _repository = repository {
    _init();
  }

  Future<void> _init() async {
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
    await _repository.logout();
    _user = null;
    _status = SessionStatus.unauthenticated;
    notifyListeners();
  }

  @override
  void dispose() {
    _authSub?.cancel();
    super.dispose();
  }
}

