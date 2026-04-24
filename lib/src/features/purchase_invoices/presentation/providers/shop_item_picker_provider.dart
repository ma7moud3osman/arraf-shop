import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/failure.dart';
import '../../domain/entities/shop_item.dart';
import '../../domain/repositories/shop_item_repository.dart';

/// Single-select picker for a shop catalog template (Step 2 of the wizard).
class ShopItemPickerProvider extends ChangeNotifier {
  ShopItemPickerProvider({required ShopItemRepository repository})
    : _repository = repository;

  final ShopItemRepository _repository;

  AppStatus _status = AppStatus.initial;
  AppStatus get status => _status;

  List<ShopItem> _items = const [];
  List<ShopItem> get items => _items;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  String _query = '';
  String get query => _query;

  bool _disposed = false;

  Future<void> load({String? search}) async {
    _status = AppStatus.loading;
    _errorMessage = null;
    if (search != null) _query = search;
    _safeNotify();

    final result = await _repository.list(
      search: _query.isEmpty ? null : _query,
      perPage: 50,
    );
    result.fold(
      (Failure f) {
        _status = AppStatus.failure;
        _errorMessage = f.message;
      },
      (List<ShopItem> rows) {
        _items = rows;
        _status = AppStatus.success;
      },
    );
    _safeNotify();
  }

  Future<void> search(String value) async {
    _query = value.trim();
    await load();
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
