// `rootContext` is a fresh getter on every access — there is no captured
// BuildContext being carried across an await. The analyzer can't see that,
// so silence the false positive file-wide.
// ignore_for_file: use_build_context_synchronously

import 'package:easy_localization/easy_localization.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../features/auth/presentation/providers/auth_provider.dart';
import '../routing/app_routes.dart';
import '../routing/global_navigator.dart';
import '../shared/helpers/show_toast.dart';
import '../utils/logger.dart';
import 'auth_service.dart';
import 'secure_storage_service.dart';
import 'storage_service.dart';

/// Central "the server rejected our bearer token" handler.
///
/// Wipes every shred of persisted and in-memory auth state, surfaces a
/// toast so the user knows why they're back at the login screen, and
/// routes to `/login`. Safe to call from anywhere — including a Dio
/// interceptor with no [BuildContext] — because it drives everything
/// through the global navigator key.
class SessionExpiredHandler {
  SessionExpiredHandler._();

  static bool _firing = false;

  /// Invoke on a definitive 401 (after the Dio interceptor's retry fails).
  /// Idempotent — concurrent 401s from parallel requests only trigger one
  /// logout + toast.
  static Future<void> handle() async {
    if (_firing) return;
    _firing = true;
    try {
      AppLogger.warning('Session expired — clearing cached auth state.');

      // Persisted state.
      await SecureStorageService.instance.clearAllAuth();
      await StorageService.instance.remove(StorageService.cachedOwnerUserKey);
      await StorageService.instance.remove(StorageService.cachedEmployeeKey);

      // In-memory state. The AuthProvider subscribes to this stream and
      // flips itself to unauthenticated.
      AuthService.instance.emitOwnerAuthState(null);

      final ctx = rootContext;
      if (ctx != null) {
        try {
          ctx.read<AuthProvider>().clear();
        } catch (_) {
          // Provider tree may not include the provider during
          // early cold-start; nothing to reset in that case.
        }

        showToast(ctx, message: 'auth.session_expired'.tr(), status: 'error');

        if (ctx.mounted) {
          ctx.go(AppRoutes.login);
        }
      }
    } finally {
      // Small grace period so near-simultaneous 401s from unrelated
      // requests don't each try to fire their own logout.
      await Future<void>.delayed(const Duration(milliseconds: 500));
      _firing = false;
    }
  }
}
