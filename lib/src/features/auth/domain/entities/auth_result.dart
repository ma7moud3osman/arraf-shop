import 'package:equatable/equatable.dart';

import 'shop_employee.dart';
import 'user.dart';

/// Outcome of the unified login call — the server returns one of two actor
/// shapes depending on whether a User or ShopEmployee authenticated.
sealed class AuthResult extends Equatable {
  const AuthResult();
}

/// Shop owner (User Sanctum token).
final class OwnerAuthResult extends AuthResult {
  const OwnerAuthResult(this.user);
  final AppUser user;

  @override
  List<Object?> get props => [user];
}

/// Shop employee (ShopEmployee Sanctum token).
final class EmployeeAuthResult extends AuthResult {
  const EmployeeAuthResult(this.employee);
  final ShopEmployee employee;

  @override
  List<Object?> get props => [employee];
}
