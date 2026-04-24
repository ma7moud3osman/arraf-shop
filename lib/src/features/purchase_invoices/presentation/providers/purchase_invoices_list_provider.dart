import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/debouncer.dart';
import '../../../../utils/failure.dart';
import '../../../employees/domain/entities/paginated.dart';
import '../../domain/entities/purchase_invoice_list_item.dart';
import '../../domain/repositories/purchase_invoice_repository.dart';

/// Owner-facing paginated list of purchase invoices with debounced
/// server-side search. Mirrors [EmployeesListProvider] so the UI patterns
/// stay consistent across admin tabs.
///
/// * [load]    — replace + reset paging.
/// * [refresh] — re-fetch page 1 with the current search.
/// * [loadMore] — append the next page; no-op if [hasMore] is false.
/// * [setSearch] — debounces by 350ms then calls [load].
class PurchaseInvoicesListProvider extends ChangeNotifier {
  PurchaseInvoicesListProvider({
    required PurchaseInvoiceRepository repository,
    Duration searchDebounce = const Duration(milliseconds: 350),
  })  : _repository = repository,
        _debouncer = Debouncer(delay: searchDebounce);

  final PurchaseInvoiceRepository _repository;
  final Debouncer _debouncer;

  AppStatus _status = AppStatus.initial;
  AppStatus _moreStatus = AppStatus.initial;
  Paginated<PurchaseInvoiceListItem> _page =
      Paginated.empty<PurchaseInvoiceListItem>();
  String _search = '';
  String? _errorMessage;
  bool _disposed = false;

  AppStatus get status => _status;
  AppStatus get moreStatus => _moreStatus;
  List<PurchaseInvoiceListItem> get invoices => _page.items;
  String get search => _search;
  String? get errorMessage => _errorMessage;
  bool get hasMore => _page.hasMore;
  int get total => _page.total;

  Future<void> load() async {
    _status = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.list(
      page: 1,
      search: _search.isEmpty ? null : _search,
    );
    result.fold(
      (Failure f) {
        _status = AppStatus.failure;
        _errorMessage = f.message;
      },
      (Paginated<PurchaseInvoiceListItem> page) {
        _page = page;
        _status = AppStatus.success;
      },
    );
    _safeNotify();
  }

  Future<void> refresh() => load();

  Future<void> loadMore() async {
    if (!hasMore) return;
    if (_moreStatus == AppStatus.loading) return;
    _moreStatus = AppStatus.loading;
    _safeNotify();

    final next = _page.currentPage + 1;
    final result = await _repository.list(
      page: next,
      search: _search.isEmpty ? null : _search,
    );
    result.fold(
      (Failure f) {
        _moreStatus = AppStatus.failure;
        _errorMessage = f.message;
      },
      (Paginated<PurchaseInvoiceListItem> page) {
        _page = _page.appending(page);
        _moreStatus = AppStatus.success;
      },
    );
    _safeNotify();
  }

  /// Updates the search term and schedules a debounced reload. Pass empty
  /// to clear the filter.
  void setSearch(String query) {
    final next = query.trim();
    if (next == _search) return;
    _search = next;
    _safeNotify();
    _debouncer.run(() {
      if (_disposed) return;
      load();
    });
  }

  void _safeNotify() {
    if (_disposed) return;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debouncer.dispose();
    super.dispose();
  }
}
