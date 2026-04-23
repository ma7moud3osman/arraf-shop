import 'package:equatable/equatable.dart';

import 'shop_employee.dart';
import 'user.dart';

/// The kind of actor currently signed in. The backend decides this at
/// `/api/login` time and returns one of two payload shapes.
enum ActorRole { owner, employee }

/// Unified identity for the signed-in user, whether they're a shop owner
/// or a shop employee. Consumers that only care about display info can use
/// [displayName]/[secondaryLabel]; consumers that care about the role
/// (e.g. the nav shell, the audit session provider) switch on [role].
///
/// Exactly one of [user]/[employee] is non-null, matched by [role].
class CurrentActor extends Equatable {
  const CurrentActor.owner(AppUser this.user)
    : role = ActorRole.owner,
      employee = null;

  const CurrentActor.employee(ShopEmployee this.employee)
    : role = ActorRole.employee,
      user = null;

  final ActorRole role;
  final AppUser? user;
  final ShopEmployee? employee;

  bool get isOwner => role == ActorRole.owner;
  bool get isEmployee => role == ActorRole.employee;

  /// Name shown in greetings and the account card.
  String? get displayName => user?.name ?? employee?.name;

  /// Secondary identifier (owner email / employee code).
  String? get secondaryLabel => user?.email ?? employee?.code;

  /// Employee primary key, only set when [isEmployee]. Used by the audits
  /// flow for scan attribution on shared devices.
  int? get employeeId => employee?.id;

  @override
  List<Object?> get props => [role, user, employee];
}
