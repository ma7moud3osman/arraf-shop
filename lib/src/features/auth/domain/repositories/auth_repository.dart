import 'package:arraf_shop/src/utils/utils.dart';
import 'package:arraf_shop/src/features/auth/domain/entities/auth_result.dart';
import 'package:arraf_shop/src/features/auth/domain/entities/user.dart';

abstract class AuthRepository {
  /// Stream of auth state changes. Emits AppUser when authenticated, null when not.
  Stream<AppUser?> get onAuthStateChanged;

  /// Unified sign-in. The server decides whether the mobile number belongs
  /// to a shop owner or a shop employee and returns the corresponding
  /// actor resource + token. The repo persists the token to the right
  /// secure-storage slot before resolving.
  FutureEither<AuthResult> login({
    required String mobile,
    required String password,
  });

  /// Create a new account. Mobile is required (unique per user on the
  /// backend); gender is optional (`male` | `female`).
  FutureEither<AppUser> signUp({
    required String name,
    required String email,
    required String mobile,
    required String password,
    String? gender,
  });

  /// Send a password reset code to the user's mobile number.
  FutureEither<void> forgotPassword({required String mobile});

  /// Sign out the current user
  FutureEither<void> logout();

  /// Check if the user is currently authenticated natively
  FutureEither<AppUser?> checkAuthState();
}
