import 'dart:io';

import 'package:flutter/foundation.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../audits/data/audit_failures.dart';
import '../../../../utils/failure.dart';
import '../../domain/entities/purchase_invoice.dart';
import '../../domain/entities/purchase_invoice_draft.dart';
import '../../domain/entities/shop_customer.dart';
import '../../domain/entities/shop_item.dart';
import '../../domain/repositories/purchase_invoice_repository.dart';

/// Holds the wizard's draft (header + items) and orchestrates the
/// multipart submit. UI binds to [items], [validationErrors], [status]
/// and the named mutators.
class CreatePurchaseInvoiceProvider extends ChangeNotifier {
  CreatePurchaseInvoiceProvider({required PurchaseInvoiceRepository repository})
    : _repository = repository,
      _items = [const DraftItem()];

  final PurchaseInvoiceRepository _repository;

  // ── Header ────────────────────────────────────────────────────────────
  ShopCustomer? _supplier;
  ShopCustomer? get supplier => _supplier;

  String? _supplierName;
  String? get supplierName => _supplierName;

  int? _shopEmployeeId;
  int? get shopEmployeeId => _shopEmployeeId;

  double? _discount;
  double? get discount => _discount;

  double? _paidAmount;
  double? get paidAmount => _paidAmount;

  String? _paymentMethod;
  String? get paymentMethod => _paymentMethod;

  String? _notes;
  String? get notes => _notes;

  DateTime? _saleDate;
  DateTime? get saleDate => _saleDate;

  // ── Items ─────────────────────────────────────────────────────────────
  final List<DraftItem> _items;
  List<DraftItem> get items => List.unmodifiable(_items);

  // ── Submit lifecycle ──────────────────────────────────────────────────
  AppStatus _status = AppStatus.initial;
  AppStatus get status => _status;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Map<String, List<String>> _validationErrors = const {};
  Map<String, List<String>> get validationErrors => _validationErrors;

  PurchaseInvoice? _created;
  PurchaseInvoice? get created => _created;

  bool _disposed = false;

  // ── Header mutators ───────────────────────────────────────────────────
  void setSupplier(ShopCustomer? value) {
    _supplier = value;
    _safeNotify();
  }

  void setSupplierName(String? value) {
    _supplierName =
        (value == null || value.trim().isEmpty) ? null : value.trim();
    _safeNotify();
  }

  void setShopEmployeeId(int? value) {
    _shopEmployeeId = value;
    _safeNotify();
  }

  // ignore: use_setters_to_change_properties
  void setDiscount(double? value) {
    _discount = value;
  }

  // ignore: use_setters_to_change_properties
  void setPaidAmount(double? value) {
    _paidAmount = value;
  }

  void setPaymentMethod(String? value) {
    _paymentMethod = value;
    _safeNotify();
  }

  void setNotes(String? value) {
    _notes = (value == null || value.trim().isEmpty) ? null : value.trim();
  }

  void setSaleDate(DateTime? value) {
    _saleDate = value;
    _safeNotify();
  }

  // ── Items mutators ────────────────────────────────────────────────────
  void addItem() {
    _items.add(const DraftItem());
    _safeNotify();
  }

  void removeItem(int index) {
    if (_items.length <= 1) return;
    _items.removeAt(index);
    _safeNotify();
  }

  void setItemShopItem(int index, ShopItem item) {
    _items[index] = _items[index].copyWith(
      shopItem: item,
      manufacturerFee:
          _items[index].manufacturerFee == 0
              ? item.manufacturingFee
              : _items[index].manufacturerFee,
    );
    _safeNotify();
  }

  void setItemWeightTotal(int index, double value) {
    _items[index] = _items[index].copyWith(weightGramsTotal: value);
    _safeNotify();
  }

  void setItemQuantity(int index, int value) {
    final clamped = value < 1 ? 1 : value;
    final current = _items[index];
    _items[index] = current.copyWith(
      quantity: clamped,
      pieces: _resizePieces(current.pieces, clamped),
    );
    _safeNotify();
  }

  void setItemManufacturerFee(int index, double value) {
    _items[index] = _items[index].copyWith(manufacturerFee: value);
    _safeNotify();
  }

  void setPieceWeight(int itemIndex, int pieceIndex, double? weight) {
    final pieces = List<DraftPiece>.from(_items[itemIndex].pieces);
    pieces[pieceIndex] = pieces[pieceIndex].copyWith(weight: weight);
    _items[itemIndex] = _items[itemIndex].copyWith(pieces: pieces);
    _safeNotify();
  }

  void setPieceImage(int itemIndex, int pieceIndex, File? image) {
    final pieces = List<DraftPiece>.from(_items[itemIndex].pieces);
    pieces[pieceIndex] = pieces[pieceIndex].copyWith(
      image: image,
      clearImage: image == null,
    );
    _items[itemIndex] = _items[itemIndex].copyWith(pieces: pieces);
    _safeNotify();
  }

  // ── Validation ────────────────────────────────────────────────────────

  /// Quick client-side check. Used by the wizard's "next" button to keep
  /// the user from hitting submit when something obviously isn't right.
  bool get itemsAreValid => submitBlockers.isEmpty;

  /// Human-readable list of what's still missing — surfaced under the
  /// submit button so users aren't left guessing why it's disabled.
  ///
  /// Returns an aggregated count list, e.g.
  /// `['2 pieces missing image', '1 piece missing weight']`. Returns an
  /// empty list when the form is ready to submit.
  List<({String key, int count})> get submitBlockers {
    if (_items.isEmpty) {
      return const [(key: 'no_items', count: 1)];
    }
    var missingItem = 0;
    var missingItemWeight = 0;
    var missingPieceImage = 0;
    var missingPieceWeight = 0;

    for (final item in _items) {
      if (item.shopItem == null) {
        missingItem += 1;
      }
      if (item.weightGramsTotal <= 0) {
        missingItemWeight += 1;
      }
      if (item.pieces.length != item.quantity) {
        // Pieces list is auto-resized; treat any mismatch as a blocker.
        missingPieceWeight += 1;
      }
      for (final piece in item.pieces) {
        if (piece.image == null) missingPieceImage += 1;
        if (piece.weight == null || piece.weight! <= 0) {
          missingPieceWeight += 1;
        }
      }
    }

    final blockers = <({String key, int count})>[];
    if (missingItem > 0) {
      blockers.add((key: 'missing_item', count: missingItem));
    }
    if (missingItemWeight > 0) {
      blockers.add((key: 'missing_item_weight', count: missingItemWeight));
    }
    if (missingPieceImage > 0) {
      blockers.add((key: 'missing_piece_image', count: missingPieceImage));
    }
    if (missingPieceWeight > 0) {
      blockers.add((key: 'missing_piece_weight', count: missingPieceWeight));
    }
    return blockers;
  }

  // ── Submit ────────────────────────────────────────────────────────────
  Future<bool> submit() async {
    _status = AppStatus.loading;
    _errorMessage = null;
    _validationErrors = const {};
    _safeNotify();

    final header = PurchaseInvoiceDraftHeader(
      shopCustomerId: _supplier?.id,
      supplierName: _supplierName,
      shopEmployeeId: _shopEmployeeId,
      discount: _discount,
      paidAmount: _paidAmount,
      paymentMethod: _paymentMethod,
      notes: _notes,
      saleDate: _saleDate,
    );

    final result = await _repository.create(header: header, items: _items);

    var ok = false;
    result.fold(
      (Failure f) {
        _status = AppStatus.failure;
        _errorMessage = f.message;
        if (f is ValidationFailure) {
          _validationErrors = f.errors;
        }
      },
      (PurchaseInvoice invoice) {
        _created = invoice;
        _status = AppStatus.success;
        ok = true;
      },
    );
    _safeNotify();
    return ok;
  }

  // ── Internals ─────────────────────────────────────────────────────────

  /// Resize a pieces list to [target] preserving any existing entries at
  /// the head and dropping (or padding) the tail.
  static List<DraftPiece> _resizePieces(List<DraftPiece> current, int target) {
    if (current.length == target) return current;
    if (current.length > target) {
      return List<DraftPiece>.from(current.take(target));
    }
    return [
      ...current,
      for (var i = current.length; i < target; i++) const DraftPiece(),
    ];
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
