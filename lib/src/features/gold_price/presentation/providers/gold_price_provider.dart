import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/failure.dart';
import '../../domain/entities/gold_price_snapshot.dart';
import '../../domain/realtime/gold_price_realtime.dart';
import '../../domain/repositories/gold_price_repository.dart';

/// Holds the current gold-price snapshot + realtime-patched updates.
///
/// * [status]   — lifecycle of the last [load] call
/// * [updateStatus] — lifecycle of the last admin write
/// * [snapshot] — the latest snapshot (HTTP-loaded OR realtime-patched)
///
/// Subscription lifecycle: [load] lazily [subscribe]s on first success.
/// [dispose] releases the channel refcount.
class GoldPriceProvider extends ChangeNotifier {
  GoldPriceProvider({
    required GoldPriceRepository repository,
    required GoldPriceRealtime realtime,
    String country = 'eg',
  }) : _repository = repository,
       _realtime = realtime,
       _country = country;

  final GoldPriceRepository _repository;
  final GoldPriceRealtime _realtime;
  final String _country;

  StreamSubscription<GoldPriceUpdatedEvent>? _realtimeSub;

  AppStatus _status = AppStatus.initial;
  AppStatus get status => _status;

  AppStatus _updateStatus = AppStatus.initial;
  AppStatus get updateStatus => _updateStatus;

  GoldPriceSnapshot? _snapshot;
  GoldPriceSnapshot? get snapshot => _snapshot;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String get country => _country;

  bool _disposed = false;

  Future<void> load() async {
    _status = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.today(country: _country);
    result.fold(
      (Failure f) {
        _status = AppStatus.failure;
        _errorMessage = f.message;
      },
      (GoldPriceSnapshot snapshot) {
        _snapshot = snapshot;
        _status = AppStatus.success;
        _ensureSubscribed();
      },
    );
    _safeNotify();
  }

  Future<void> refresh() => load();

  /// Admin-only patch. Returns `null` on success, or a user-facing error
  /// message so the caller can display it in a snackbar / dialog.
  Future<String?> update(Map<String, double> updates) async {
    _updateStatus = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.update(
      country: _country,
      updates: updates,
    );

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
        _ensureSubscribed();
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

  void _ensureSubscribed() {
    if (_realtimeSub != null) return;
    _realtimeSub = _realtime.subscribeGoldPrice().listen(
      _onRealtimeEvent,
      onError: (_) {},
    );
  }

  void _onRealtimeEvent(GoldPriceUpdatedEvent event) {
    // Only apply events that match our country, so a multi-country admin
    // edit can't overwrite the wrong display.
    if (event.snapshot.country != _country) return;
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
    unawaited(_realtime.unsubscribeGoldPrice());
    super.dispose();
  }
}
