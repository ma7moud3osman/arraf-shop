import 'package:fpdart/fpdart.dart';

import '../imports/core_imports.dart';

/// A reusable generic function to handle potential exceptions in async tasks
/// and map them to the [Either] type matching [FutureEither<T>].
///
/// Network-related failures (connection refused, DNS failure, timeouts) are
/// mapped to a user-facing message by [AppErrorHandler.format], so callers
/// don't need to pre-flight a connectivity check — the request itself is
/// the source of truth.
FutureEither<T> runTask<T>(Future<T> Function() action) async {
  try {
    final result = await action();
    return right(result);
  } catch (error, stackTrace) {
    AppLogger.error('Task execution failed $error', [error, stackTrace]);
    final errorMessage = AppErrorHandler.format(error);

    // Depending on logic, map error strings/types to specific Failure variants
    return left(ServerFailure(errorMessage, error: error));
  }
}
