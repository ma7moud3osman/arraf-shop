import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/failure.dart';
import '../../domain/entities/gold_price_snapshot.dart';
import '../../domain/realtime/gold_price_realtime.dart';
import '../../domain/repositories/gold_price_repository.dart';

/// Holds the current per-shop gold-price snapshot + realtime-patched
/// updates.
///
/// * [status]   — lifecycle of the last [load] call
/// * [updateStatus] — lifecycle of the last admin write
/// * [snapshot] — the latest snapshot (HTTP-loaded OR realtime-patched)
///
/// Subscription lifecycle: [load] lazily subscribes to the per-shop
/// private channel on first success, using the `shop_id` returned in the
/// HTTP response. [dispose] releases the channel refcount.
class GoldPriceProvider extends ChangeNotifier {
  GoldPriceProvider({
    required GoldPriceRepository repository,
    required GoldPriceRealtime realtime,
  }) : _repository = repository,
       _realtime = realtime;

  final GoldPriceRepository _repository;
  final GoldPriceRealtime _realtime;

  StreamSubscription<GoldPriceUpdatedEvent>? _realtimeSub;
  int? _subscribedShopId;

  AppStatus _status = AppStatus.initial;
  AppStatus get status => _status;

  AppStatus _updateStatus = AppStatus.initial;
  AppStatus get updateStatus => _updateStatus;

  GoldPriceSnapshot? _snapshot;
  GoldPriceSnapshot? get snapshot => _snapshot;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _disposed = false;

  Future<void> load() async {
    _status = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.today();
    result.fold(
      (Failure f) {
        _status = AppStatus.failure;
        _errorMessage = f.message;
      },
      (GoldPriceSnapshot snapshot) {
        _snapshot = snapshot;
        _status = AppStatus.success;
        _ensureSubscribed(snapshot.shopId);
      },
    );
    _safeNotify();
  }

  Future<void> refresh() => load();

  /// Owner / admin patch. Returns `null` on success, or a user-facing
  /// error message so the caller can display it in a snackbar / dialog.
  Future<String?> update(Map<String, double> updates) async {
    _updateStatus = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.update(updates: updates);

    String? outcome;
    result.fold(
      (Failure f) {
        _updateStatus = AppStatus.failure;
        _errorMessage = f.message;
        outcome = f.message;
      },
      (GoldPriceSnapshot snapshot) {
        _snapshot = snapshot;
        _updateStatus = AppStatus.success;
        _ensureSubscribed(snapshot.shopId);
      },
    );
    _safeNotify();
    return outcome;
  }

  /// Reset [updateStatus] back to [AppStatus.initial] — used by the UI
  /// after consuming a one-shot snackbar so re-opening the dialog doesn't
  /// immediately render a stale error.
  void clearUpdateStatus() {
    if (_updateStatus == AppStatus.initial) return;
    _updateStatus = AppStatus.initial;
    _safeNotify();
  }

  void _ensureSubscribed(int? shopId) {
    if (shopId == null) return;
    if (_subscribedShopId == shopId && _realtimeSub != null) return;

    // If we were previously subscribed to a different shop (e.g. user
    // logged out and back in as another owner), tear that down first.
    if (_subscribedShopId != null && _subscribedShopId != shopId) {
      unawaited(_realtimeSub?.cancel());
      unawaited(_realtime.unsubscribeGoldPrice(_subscribedShopId!));
      _realtimeSub = null;
    }

    _subscribedShopId = shopId;
    _realtimeSub = _realtime
        .subscribeGoldPrice(shopId)
        .listen(_onRealtimeEvent, onError: (_) {});
  }

  void _onRealtimeEvent(GoldPriceUpdatedEvent event) {
    // Defensive: only apply events for our subscribed shop.
    if (_subscribedShopId != null &&
        event.snapshot.shopId != null &&
        event.snapshot.shopId != _subscribedShopId) {
      return;
    }
    _snapshot = event.snapshot;
    _safeNotify();
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    unawaited(_realtimeSub?.cancel());
    _realtimeSub = null;
    final id = _subscribedShopId;
    _subscribedShopId = null;
    if (id != null) {
      unawaited(_realtime.unsubscribeGoldPrice(id));
    }
    super.dispose();
  }
}
