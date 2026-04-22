import 'package:arraf_shop/src/utils/failure.dart';

/// HTTP-status-aware failure subtypes.
///
/// Defined here for now to keep Track B inside the audit feature scope; once
/// other features need them they should be promoted to `lib/src/utils/failure.dart`.

class AuthFailure extends Failure {
  const AuthFailure(super.message, {super.error});
}

class ForbiddenFailure extends Failure {
  const ForbiddenFailure(super.message, {super.error});
}

class NotFoundFailure extends Failure {
  const NotFoundFailure(super.message, {super.error});
}

class ConflictFailure extends Failure {
  const ConflictFailure(super.message, {super.error});
}

class ValidationFailure extends Failure {
  /// Field → list of error messages, keyed by request-body field name.
  final Map<String, List<String>> errors;

  const ValidationFailure(super.message, {this.errors = const {}, super.error});

  /// First message for a given field, if any.
  String? firstFor(String field) {
    final list = errors[field];
    if (list == null || list.isEmpty) return null;
    return list.first;
  }

  @override
  List<Object?> get props => [...super.props, errors];
}
