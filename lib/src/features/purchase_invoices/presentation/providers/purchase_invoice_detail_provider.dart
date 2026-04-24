import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../utils/failure.dart';
import '../../domain/entities/purchase_invoice.dart';
import '../../domain/repositories/purchase_invoice_repository.dart';

/// Loads a single purchase invoice (draft or completed) for the detail
/// screen. Backed by `GET /api/shops/my/purchase-invoices/{id}`.
class PurchaseInvoiceDetailProvider extends ChangeNotifier {
  PurchaseInvoiceDetailProvider({
    required PurchaseInvoiceRepository repository,
    required this.invoiceId,
  }) : _repository = repository;

  final PurchaseInvoiceRepository _repository;
  final int invoiceId;

  AppStatus _loadStatus = AppStatus.initial;
  AppStatus get loadStatus => _loadStatus;

  PurchaseInvoice? _invoice;
  PurchaseInvoice? get invoice => _invoice;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  bool _disposed = false;

  Future<void> load() async {
    _loadStatus = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.fetch(invoiceId);
    result.fold(
      (Failure f) {
        _loadStatus = AppStatus.failure;
        _errorMessage = f.message;
      },
      (PurchaseInvoice invoice) {
        _invoice = invoice;
        _loadStatus = AppStatus.success;
      },
    );
    _safeNotify();
  }

  Future<void> refresh() => load();

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
