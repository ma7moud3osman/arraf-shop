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

/// Two phases the wizard can be in. In [creating] mode the user fills the
/// header + items from scratch; in [editingDraft] mode the header + items
/// were loaded from a server-side draft and are locked, and only per-piece
/// data is editable.
enum CreatePurchaseInvoiceMode { creating, editingDraft }

/// Holds the wizard's draft (header + items) and orchestrates the
/// multipart submit. UI binds to [items], [validationErrors], [status]
/// and the named mutators.
class CreatePurchaseInvoiceProvider extends ChangeNotifier {
  CreatePurchaseInvoiceProvider({required PurchaseInvoiceRepository repository})
    : _repository = repository,
      _items = [const DraftItem()];

  final PurchaseInvoiceRepository _repository;

  // ── Mode / draft id ───────────────────────────────────────────────────
  CreatePurchaseInvoiceMode _mode = CreatePurchaseInvoiceMode.creating;
  CreatePurchaseInvoiceMode get mode => _mode;
  bool get isEditingDraft => _mode == CreatePurchaseInvoiceMode.editingDraft;

  int? _draftInvoiceId;
  int? get draftInvoiceId => _draftInvoiceId;

  AppStatus _draftLoadStatus = AppStatus.initial;
  AppStatus get draftLoadStatus => _draftLoadStatus;

  // ── Header ────────────────────────────────────────────────────────────
  ShopCustomer? _supplier;
  ShopCustomer? get supplier => _supplier;

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

  AppStatus _saveDraftStatus = AppStatus.initial;
  AppStatus get saveDraftStatus => _saveDraftStatus;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Map<String, List<String>> _validationErrors = const {};
  Map<String, List<String>> get validationErrors => _validationErrors;

  PurchaseInvoice? _created;
  PurchaseInvoice? get created => _created;

  bool _disposed = false;

  // ── Header mutators ───────────────────────────────────────────────────
  void setSupplier(ShopCustomer? value) {
    if (isEditingDraft) return;
    _supplier = value;
    _safeNotify();
  }

  void setShopEmployeeId(int? value) {
    if (isEditingDraft) return;
    _shopEmployeeId = value;
    _safeNotify();
  }

  void setDiscount(double? value) {
    if (isEditingDraft) return;
    _discount = value;
  }

  void setPaidAmount(double? value) {
    if (isEditingDraft) return;
    _paidAmount = value;
  }

  void setPaymentMethod(String? value) {
    if (isEditingDraft) return;
    _paymentMethod = value;
    _safeNotify();
  }

  void setNotes(String? value) {
    if (isEditingDraft) return;
    _notes = (value == null || value.trim().isEmpty) ? null : value.trim();
  }

  void setSaleDate(DateTime? value) {
    if (isEditingDraft) return;
    _saleDate = value;
    _safeNotify();
  }

  // ── Items mutators ────────────────────────────────────────────────────
  void addItem() {
    if (isEditingDraft) return;
    _items.add(const DraftItem());
    _safeNotify();
  }

  void removeItem(int index) {
    if (isEditingDraft) return;
    if (_items.length <= 1) return;
    _items.removeAt(index);
    _safeNotify();
  }

  void setItemShopItem(int index, ShopItem item) {
    if (isEditingDraft) return;
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
    if (isEditingDraft) return;
    _items[index] = _items[index].copyWith(weightGramsTotal: value);
    _safeNotify();
  }

  void setItemQuantity(int index, int value) {
    if (isEditingDraft) return;
    final clamped = value < 1 ? 1 : value;
    final current = _items[index];
    _items[index] = current.copyWith(
      quantity: clamped,
      pieces: _resizePieces(current.pieces, clamped),
    );
    _safeNotify();
  }

  void setItemManufacturerFee(int index, double value) {
    if (isEditingDraft) return;
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

  /// Quick check used to enable/disable the "Continue" / "Create invoice"
  /// CTAs based on per-piece data.
  bool get itemsAreValid => submitBlockers.isEmpty;

  /// Phase 1 (header + items) validity — the "Save draft" / "Continue"
  /// CTAs need at least a catalog item + total weight on every line.
  bool get phaseOneIsValid {
    if (_items.isEmpty) return false;
    for (final item in _items) {
      if (item.shopItem == null) return false;
      if (item.weightGramsTotal <= 0) return false;
      if (item.quantity < 1) return false;
    }
    return true;
  }

  /// Human-readable list of what's still missing — surfaced under the
  /// submit button so users aren't left guessing why it's disabled.
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
        missingPieceWeight += 1;
      }
      for (final piece in item.pieces) {
        if (!kDebugMode && piece.image == null) missingPieceImage += 1;
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

  // ── Draft load / save ─────────────────────────────────────────────────

  /// Load an existing server-side draft into the wizard and switch to
  /// [CreatePurchaseInvoiceMode.editingDraft]. Header + items become
  /// read-only; only per-piece weight + image are editable.
  Future<bool> loadDraft(int invoiceId) async {
    _draftLoadStatus = AppStatus.loading;
    _errorMessage = null;
    _safeNotify();

    final result = await _repository.fetch(invoiceId);
    var ok = false;
    result.fold(
      (Failure f) {
        _draftLoadStatus = AppStatus.failure;
        _errorMessage = f.message;
      },
      (PurchaseInvoice invoice) {
        _draftInvoiceId = invoice.id;
        _mode = CreatePurchaseInvoiceMode.editingDraft;
        _supplier =
            invoice.shopCustomerId == null
                ? null
                : ShopCustomer(
                  id: invoice.shopCustomerId!,
                  name: invoice.customerName ?? '',
                  phone: invoice.customerPhone,
                );
        _paymentMethod = invoice.paymentMethod;
        _discount = invoice.discount;
        _paidAmount = invoice.paidAmount;
        _notes = invoice.notes;
        _saleDate = invoice.saleDate;
        _items
          ..clear()
          ..addAll(_draftItemsToDraftItems(invoice.draftItems));
        _draftLoadStatus = AppStatus.success;
        ok = true;
      },
    );
    _safeNotify();
    return ok;
  }

  static List<DraftItem> _draftItemsToDraftItems(
    List<PurchaseInvoiceDraftItem> draftItems,
  ) {
    return draftItems.map((d) {
      // We don't have the full ShopItem hydrated client-side; build a minimal
      // stub from the embedded shop_item summary so the row card can render
      // its label.
      final stub = ShopItem(
        id: d.shopItemId,
        shopId: 0,
        karat: d.karat,
        costFee: 0,
        manufacturingFee: d.manufacturerFee,
        minimumStockLevel: 0,
        displayLabel: d.shopItemLabel ?? '#${d.shopItemId}',
        stockOnHand: 0,
      );
      return DraftItem(
        shopItem: stub,
        weightGramsTotal: d.weightGramsTotal,
        quantity: d.quantity,
        manufacturerFee: d.manufacturerFee,
        pieces: List<DraftPiece>.generate(d.quantity, (_) => const DraftPiece()),
      );
    }).toList();
  }

  /// `POST /api/shops/my/purchase-invoices/draft` — save Phase 1 only.
  Future<bool> saveDraft() async {
    _saveDraftStatus = AppStatus.loading;
    _errorMessage = null;
    _validationErrors = const {};
    _safeNotify();

    final header = _buildHeader();
    final result = await _repository.createDraft(
      header: header,
      items: _items,
    );

    var ok = false;
    result.fold(
      (Failure f) {
        _saveDraftStatus = AppStatus.failure;
        _errorMessage = f.message;
        if (f is ValidationFailure) {
          _validationErrors = f.errors;
        }
      },
      (PurchaseInvoice invoice) {
        _created = invoice;
        _saveDraftStatus = AppStatus.success;
        ok = true;
      },
    );
    _safeNotify();
    return ok;
  }

  // ── Submit / Complete ─────────────────────────────────────────────────
  PurchaseInvoiceDraftHeader _buildHeader() {
    return PurchaseInvoiceDraftHeader(
      shopCustomerId: _supplier?.id,
      shopEmployeeId: _shopEmployeeId,
      discount: _discount,
      paidAmount: _paidAmount,
      paymentMethod: _paymentMethod,
      notes: _notes,
      saleDate: _saleDate,
    );
  }

  /// Either creates a fresh invoice with pieces OR completes a previously
  /// saved draft, depending on [mode].
  Future<bool> complete() async {
    _status = AppStatus.loading;
    _errorMessage = null;
    _validationErrors = const {};
    _safeNotify();

    final result = isEditingDraft
        ? await _repository.completeDraft(
            invoiceId: _draftInvoiceId!,
            items: _items,
          )
        : await _repository.create(
            header: _buildHeader(),
            items: _items,
          );

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

  /// Backwards-compatible alias for [complete] — the original wizard call
  /// site used [submit()].
  Future<bool> submit() => complete();

  // ── Internals ─────────────────────────────────────────────────────────
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
