import 'package:arraf_shop/src/features/auth/domain/entities/auth_result.dart';
import 'package:arraf_shop/src/features/auth/domain/repositories/auth_repository.dart';
import 'package:arraf_shop/src/features/auth/presentation/providers/employee_auth_provider.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

class AuthProvider extends ChangeNotifier {
  final AuthRepository _repository;

  AuthProvider({required AuthRepository repository}) : _repository = repository;

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  /// Unified login. Returns `null` on success, or a user-facing error
  /// message on failure. On an employee-role result it forwards the
  /// authenticated employee onto [EmployeeAuthProvider] so downstream
  /// screens (home, sign-out menu) light up the right cards.
  Future<String?> login({
    required BuildContext context,
    required String mobile,
    required String password,
  }) async {
    _setLoading(true);

    final result = await _repository.login(mobile: mobile, password: password);

    _setLoading(false);

    return result.fold<String?>((failure) => failure.message, (authResult) {
      switch (authResult) {
        case OwnerAuthResult():
          // SessionProvider picks this up via the auth-state stream.
          break;
        case EmployeeAuthResult(:final employee):
          if (context.mounted) {
            context.read<EmployeeAuthProvider>().setAuthenticated(employee);
          }
      }
      return null;
    });
  }

  void signUp({
    required BuildContext context,
    required String name,
    required String email,
    required String mobile,
    required String password,
    String? gender,
  }) async {
    _setLoading(true);

    final result = await _repository.signUp(
      name: name,
      email: email,
      mobile: mobile,
      password: password,
      gender: gender ?? 'male',
    );

    _setLoading(false);
    result.fold(
      (failure) {
        showToast(context, message: failure.message, status: 'error');
      },
      (user) {
        if (context.mounted) {
          context.go(AppRoutes.home);
        }
      },
    );
  }

  void forgotPassword({
    required BuildContext context,
    required String mobile,
  }) async {
    _setLoading(true);

    final result = await _repository.forgotPassword(mobile: mobile);

    _setLoading(false);
    result.fold(
      (failure) {
        showToast(context, message: failure.message, status: 'error');
      },
      (success) {
        showToast(
          context,
          message: 'auth.reset_code_sent'.tr(),
          status: 'success',
        );
        if (context.mounted) {
          context.go(AppRoutes.login);
        }
      },
    );
  }
}
