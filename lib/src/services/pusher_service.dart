import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:pusher_channels_flutter/pusher_channels_flutter.dart';

import '../features/audits/domain/realtime/audit_realtime.dart';
import '../utils/utils.dart';
import 'auth_endpoint_signer.dart';
import 'session_expired_handler.dart';

/// Pusher-backed implementation of the [AuditRealtime] contract.
///
/// Responsibilities
/// ----------------
///  * Owns a single [PusherChannelsFlutter] connection, lazily initialized on
///    first [subscribe].
///  * Multiplexes subscribers per `sessionId` via a [StreamController]
///    broadcast map. Multiple callers for the same session share one private
///    channel; the channel is torn down only when the last subscriber leaves
///    (reference counting).
///  * Routes incoming `scan.recorded` events to the right per-session
///    controller by parsing the channel name.
///  * Signs private-channel auth via [AuthEndpointSigner], using whichever
///    bearer token is currently active in [SecureStorageService].
///  * Exposes connection-state transitions on [connectionState].
///
/// Reconnect policy is delegated to the native Pusher SDK; we expose the
/// state transitions so UI can react (banner, retry CTA).
class PusherService implements AuditRealtime {
  PusherService._({
    PusherChannelsFlutter? pusher,
    AuthEndpointSigner? signer,
    String? apiKey,
    String? cluster,
  }) : _pusher = pusher ?? PusherChannelsFlutter.getInstance(),
       _signer = signer ?? AuthEndpointSigner(),
       _apiKey = apiKey ?? dotenv.maybeGet('PUSHER_APP_KEY') ?? '',
       _cluster = cluster ?? dotenv.maybeGet('PUSHER_APP_CLUSTER') ?? 'mt1';

  static PusherService? _testOverride;
  static PusherService? _singleton;

  /// Access the shared service. Tests can inject a fake via
  /// [debugOverrideInstance].
  static PusherService get instance {
    if (_testOverride != null) return _testOverride!;
    return _singleton ??= PusherService._();
  }

  /// For tests only — swaps the singleton. Pass `null` to restore.
  // ignore: use_setters_to_change_properties
  static void debugOverrideInstance(PusherService? override) {
    _testOverride = override;
  }

  final PusherChannelsFlutter _pusher;
  final AuthEndpointSigner _signer;
  final String _apiKey;
  final String _cluster;

  /// Per-session fan-out streams.
  final Map<int, StreamController<AuditScanEvent>> _sessionControllers = {};

  /// Number of live subscribers per session. When a session's count hits 0 we
  /// leave the Pusher channel and close the stream controller.
  final Map<int, int> _sessionRefCount = {};

  /// Per-shop fan-out streams for the audits list realtime feed.
  final Map<int, StreamController<AuditSessionEvent>> _shopControllers = {};

  /// Per-shop subscriber refcount, mirror of [_sessionRefCount].
  final Map<int, int> _shopRefCount = {};

  final StreamController<RealtimeConnectionState> _connectionController =
      StreamController<RealtimeConnectionState>.broadcast();

  bool _initialized = false;
  Future<void>? _initFuture;
  RealtimeConnectionState _currentState = RealtimeConnectionState.disconnected;

  @override
  Stream<RealtimeConnectionState> get connectionState async* {
    // Replay the last known state to late subscribers so banners render
    // immediately instead of waiting for the next transition.
    yield _currentState;
    yield* _connectionController.stream;
  }

  @override
  Stream<AuditScanEvent> subscribe(int sessionId) {
    final controller = _sessionControllers.putIfAbsent(
      sessionId,
      () => StreamController<AuditScanEvent>.broadcast(),
    );
    final firstSubscriber = (_sessionRefCount[sessionId] ?? 0) == 0;
    _sessionRefCount[sessionId] = (_sessionRefCount[sessionId] ?? 0) + 1;

    if (firstSubscriber) {
      // Fire-and-forget the init+subscribe. Errors are surfaced via
      // [connectionState] and per-session errors via the stream itself.
      unawaited(_joinSession(sessionId));
    }

    return controller.stream;
  }

  @override
  Future<void> unsubscribe(int sessionId) async {
    final remaining = (_sessionRefCount[sessionId] ?? 0) - 1;
    if (remaining > 0) {
      _sessionRefCount[sessionId] = remaining;
      return;
    }

    _sessionRefCount.remove(sessionId);
    final controller = _sessionControllers.remove(sessionId);
    final channelName = channelFor(sessionId);

    // Only reach into the native plugin if we actually finished init + connect.
    // Calling unsubscribe/disconnect on an uninitialized plugin force-unwraps
    // nil inside the iOS Swift plugin and crashes the app.
    if (_initialized) {
      try {
        await _pusher.unsubscribe(channelName: channelName);
      } catch (error, stack) {
        AppLogger.error('Pusher unsubscribe failed for $channelName', [
          error,
          stack,
        ]);
      }
    }

    await controller?.close();

    // When nothing is left, drop the connection so we're not holding an
    // open socket during idle periods.
    if (_initialized && _sessionControllers.isEmpty) {
      try {
        await _pusher.disconnect();
      } catch (error, stack) {
        AppLogger.error('Pusher disconnect failed', [error, stack]);
      }
    }
  }

  /// Exposed for tests / channel-name sanity checks.
  static String channelFor(int sessionId) => 'private-shop-audit.$sessionId';

  /// Exposed for tests / channel-name sanity checks.
  static String shopChannelFor(int shopId) => 'private-shop-audits.$shopId';

  /// Parse `private-shop-audit.17` back to `17`. Returns `null` on mismatch.
  /// `private-shop-audits.5` (note the trailing `s`) is explicitly rejected
  /// so the two channel spaces can't be confused by the event router.
  static int? sessionIdFromChannel(String channelName) {
    const prefix = 'private-shop-audit.';
    if (!channelName.startsWith(prefix)) return null;
    if (channelName.startsWith('private-shop-audits.')) return null;
    return int.tryParse(channelName.substring(prefix.length));
  }

  /// Parse `private-shop-audits.5` back to `5`.
  static int? shopIdFromChannel(String channelName) {
    const prefix = 'private-shop-audits.';
    if (!channelName.startsWith(prefix)) return null;
    return int.tryParse(channelName.substring(prefix.length));
  }

  Future<void> _joinSession(int sessionId) async {
    try {
      await _ensureInitialized();
      await _pusher.subscribe(channelName: channelFor(sessionId));
    } catch (error, stack) {
      AppLogger.error('Pusher subscribe failed for session $sessionId', [
        error,
        stack,
      ]);
      _sessionControllers[sessionId]?.addError(error, stack);
    }
  }

  @override
  Stream<AuditSessionEvent> subscribeShop(int shopId) {
    final controller = _shopControllers.putIfAbsent(
      shopId,
      () => StreamController<AuditSessionEvent>.broadcast(),
    );
    final firstSubscriber = (_shopRefCount[shopId] ?? 0) == 0;
    _shopRefCount[shopId] = (_shopRefCount[shopId] ?? 0) + 1;

    if (firstSubscriber) {
      unawaited(_joinShop(shopId));
    }

    return controller.stream;
  }

  @override
  Future<void> unsubscribeShop(int shopId) async {
    final remaining = (_shopRefCount[shopId] ?? 0) - 1;
    if (remaining > 0) {
      _shopRefCount[shopId] = remaining;
      return;
    }

    _shopRefCount.remove(shopId);
    final controller = _shopControllers.remove(shopId);
    final channelName = shopChannelFor(shopId);

    if (_initialized) {
      try {
        await _pusher.unsubscribe(channelName: channelName);
      } catch (error, stack) {
        AppLogger.error('Pusher unsubscribe failed for $channelName', [
          error,
          stack,
        ]);
      }
    }

    await controller?.close();

    if (_initialized &&
        _sessionControllers.isEmpty &&
        _shopControllers.isEmpty) {
      try {
        await _pusher.disconnect();
      } catch (error, stack) {
        AppLogger.error('Pusher disconnect failed', [error, stack]);
      }
    }
  }

  Future<void> _joinShop(int shopId) async {
    try {
      await _ensureInitialized();
      await _pusher.subscribe(channelName: shopChannelFor(shopId));
    } catch (error, stack) {
      AppLogger.error('Pusher subscribe failed for shop $shopId', [
        error,
        stack,
      ]);
      _shopControllers[shopId]?.addError(error, stack);
    }
  }

  Future<void> _ensureInitialized() {
    if (_initialized) return Future.value();
    return _initFuture ??= _performInit();
  }

  Future<void> _performInit() async {
    if (_apiKey.isEmpty) {
      throw StateError(
        'PUSHER_APP_KEY is empty — cannot initialize realtime. '
        'Set PUSHER_APP_KEY + PUSHER_APP_CLUSTER in .env.',
      );
    }

    await _pusher.init(
      apiKey: _apiKey,
      cluster: _cluster,
      onConnectionStateChange: _handleConnectionStateChange,
      onAuthorizer: _handleAuthorizer,
      onEvent: _handleEvent,
      onError: (message, code, error) {
        AppLogger.error('Pusher error [$code]: $message', [error]);
      },
      onSubscriptionError: (message, error) {
        AppLogger.error('Pusher subscription error: $message', [error]);
      },
    );
    await _pusher.connect();
    _initialized = true;
  }

  void _handleConnectionStateChange(String current, String previous) {
    final next = _mapConnectionState(current);
    if (next == _currentState) return;
    _currentState = next;
    if (!_connectionController.isClosed) {
      _connectionController.add(next);
    }
    AppLogger.info('Pusher state: $previous → $current');
  }

  void _handleEvent(PusherEvent event) {
    switch (event.eventName) {
      case 'scan.recorded':
        _dispatchScanEvent(event);
      case 'session.updated':
        _dispatchShopSessionEvent(event);
    }
  }

  void _dispatchScanEvent(PusherEvent event) {
    final sessionId = sessionIdFromChannel(event.channelName);
    if (sessionId == null) return;

    final controller = _sessionControllers[sessionId];
    if (controller == null || controller.isClosed) return;

    final payload = _decodePayload(event.data, 'scan.recorded $sessionId');
    if (payload == null) return;

    try {
      controller.add(AuditScanEvent.fromMap(payload));
    } on FormatException catch (error, stack) {
      AppLogger.error('Failed to parse AuditScanEvent for $sessionId', [
        error,
        stack,
      ]);
      controller.addError(error, stack);
    }
  }

  void _dispatchShopSessionEvent(PusherEvent event) {
    final shopId = shopIdFromChannel(event.channelName);
    if (shopId == null) return;

    final controller = _shopControllers[shopId];
    if (controller == null || controller.isClosed) return;

    final payload = _decodePayload(event.data, 'session.updated shop $shopId');
    if (payload == null) return;

    try {
      controller.add(AuditSessionEvent.fromMap(payload));
    } on FormatException catch (error, stack) {
      AppLogger.error('Failed to parse AuditSessionEvent for $shopId', [
        error,
        stack,
      ]);
      controller.addError(error, stack);
    }
  }

  Map<String, dynamic>? _decodePayload(dynamic raw, String context) {
    try {
      return raw is Map
          ? Map<String, dynamic>.from(raw)
          : Map<String, dynamic>.from(jsonDecode(raw as String) as Map);
    } catch (error, stack) {
      AppLogger.error('Malformed payload [$context]', [error, stack]);
      return null;
    }
  }

  Future<Map<String, dynamic>> _handleAuthorizer(
    String channelName,
    String socketId,
    dynamic options,
  ) async {
    try {
      return await _signer.sign(socketId: socketId, channelName: channelName);
    } on DioException catch (error, stack) {
      AppLogger.error('Broadcasting auth failed for $channelName', [
        error,
        stack,
      ]);
      // When the token was revoked from another device, the Sanctum
      // `broadcasting/auth` call returns 401. Trigger the normal
      // session-expired flow — it's idempotent so it's safe to call from
      // the authorizer alongside any concurrent API 401.
      if (error.response?.statusCode == 401) {
        unawaited(SessionExpiredHandler.handle());
      }
      // Never rethrow — the native Pusher plugin force-casts the
      // authorizer's result to `[String: Any]` and crashes the app on any
      // Dart exception. Returning an empty well-shaped map lets Pusher
      // fail the subscription gracefully (and we're logging out anyway).
      return const <String, dynamic>{'auth': ''};
    } catch (error, stack) {
      AppLogger.error('Broadcasting auth failed for $channelName', [
        error,
        stack,
      ]);
      return const <String, dynamic>{'auth': ''};
    }
  }

  RealtimeConnectionState _mapConnectionState(String raw) {
    switch (raw.toUpperCase()) {
      case 'CONNECTING':
        return RealtimeConnectionState.connecting;
      case 'CONNECTED':
        return RealtimeConnectionState.connected;
      case 'RECONNECTING':
        return RealtimeConnectionState.reconnecting;
      case 'DISCONNECTED':
      case 'DISCONNECTING':
      case 'UNAVAILABLE':
      case 'FAILED':
      default:
        return RealtimeConnectionState.disconnected;
    }
  }

  /// Tests / hot-restart helper: tears down everything.
  Future<void> dispose() async {
    for (final controller in _sessionControllers.values) {
      await controller.close();
    }
    _sessionControllers.clear();
    _sessionRefCount.clear();
    for (final controller in _shopControllers.values) {
      await controller.close();
    }
    _shopControllers.clear();
    _shopRefCount.clear();
    if (!_connectionController.isClosed) {
      await _connectionController.close();
    }
    if (_initialized) {
      try {
        await _pusher.disconnect();
      } catch (_) {}
      _initialized = false;
    }
  }
}
