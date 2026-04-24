import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/failure.dart';
import '../../domain/entities/shop_settings.dart';
import '../../domain/repositories/shop_settings_repository.dart';

/// Holds the shop's weekly-holiday selection plus the in-flight edit state.
///
/// * [loadStatus] tracks the lifecycle of the most recent [load] call.
/// * [saveStatus] tracks the lifecycle of the most recent [save] call.
/// * [draftWeeklyHolidays] is the user's pending selection (a [Set] for
///   O(1) toggling); [isDirty] compares it to [settings].
class WorkingWeekProvider extends ChangeNotifier {
  WorkingWeekProvider({required ShopSettingsRepository repository})
    : _repository = repository;

  final ShopSettingsRepository _repository;

  AppStatus _loadStatus = AppStatus.initial;
  AppStatus get loadStatus => _loadStatus;

  AppStatus _saveStatus = AppStatus.initial;
  AppStatus get saveStatus => _saveStatus;

  ShopSettings? _settings;
  ShopSettings? get settings => _settings;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  final Set<int> _draft = <int>{};
  Set<int> get draftWeeklyHolidays => Set<int>.unmodifiable(_draft);

  bool _disposed = false;

  bool get isDirty {
    final saved = (_settings?.weeklyHolidays ?? const <int>[]).toSet();
    return saved.length != _draft.length || !saved.containsAll(_draft);
  }

  Future<void> load() async {
    _loadStatus = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.fetch();
    result.fold(
      (Failure f) {
        _loadStatus = AppStatus.failure;
        _errorMessage = f.message;
      },
      (ShopSettings s) {
        _settings = s;
        _resetDraftFromSettings();
        _loadStatus = AppStatus.success;
      },
    );
    _safeNotify();
  }

  Future<void> refresh() => load();

  /// Toggle whether [isoWeekday] (1..7) is part of the working-week
  /// holiday set in the local draft.
  void toggle(int isoWeekday) {
    if (isoWeekday < 1 || isoWeekday > 7) return;
    if (_draft.contains(isoWeekday)) {
      _draft.remove(isoWeekday);
    } else {
      _draft.add(isoWeekday);
    }
    _safeNotify();
  }

  /// Discard local edits and reset the draft to the last loaded settings.
  void revert() {
    _resetDraftFromSettings();
    _safeNotify();
  }

  /// Persist the draft. Returns null on success or a user-facing error
  /// message so callers can surface it via toast/snackbar.
  Future<String?> save() async {
    _saveStatus = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final payload = (_draft.toList()..sort());
    final result = await _repository.update(payload);

    String? outcome;
    result.fold(
      (Failure f) {
        _saveStatus = AppStatus.failure;
        _errorMessage = f.message;
        outcome = f.message;
      },
      (ShopSettings s) {
        _settings = s;
        _resetDraftFromSettings();
        _saveStatus = AppStatus.success;
      },
    );
    _safeNotify();
    return outcome;
  }

  void _resetDraftFromSettings() {
    _draft
      ..clear()
      ..addAll(_settings?.weeklyHolidays ?? const <int>[]);
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
