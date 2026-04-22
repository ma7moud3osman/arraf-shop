import 'package:arraf_shop/src/features/auth/domain/entities/shop_employee.dart';
import 'package:arraf_shop/src/utils/utils.dart';

/// Contract for the employee-side auth lifecycle.
///
/// Login itself now flows through the unified [AuthRepository.login] +
/// `POST /api/login`. This repo only owns the two employee-specific
/// touchpoints that the owner flow doesn't share:
///
///  * rehydrating the current employee from the server on cold start
///    (so a saved employee token survives app restart), and
///  * logging out (invalidates the Sanctum token + clears storage).
abstract class EmployeeAuthRepository {
  /// `GET /api/shop-employees/me` — fetches the currently-authenticated
  /// employee using whichever token is in the employee slot.
  FutureEither<ShopEmployee> me();

  /// Clear the employee token + flip the Dio interceptor away from
  /// employee mode. Safe to call whether or not we were signed in.
  FutureEither<void> logout();
}
