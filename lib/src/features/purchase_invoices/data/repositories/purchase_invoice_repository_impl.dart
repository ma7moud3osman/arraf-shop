import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import '../../../../config/app_config.dart';
import '../../../../utils/typedefs.dart';
import '../../domain/entities/purchase_invoice.dart';
import '../../domain/entities/purchase_invoice_draft.dart';
import '../../domain/repositories/purchase_invoice_repository.dart';
import '../models/purchase_invoice_model.dart';
import '_dio_failure_mapper.dart';

class PurchaseInvoiceRepositoryImpl implements PurchaseInvoiceRepository {
  PurchaseInvoiceRepositoryImpl({Dio? dio}) : _dio = dio ?? AppConfig.dio;

  final Dio _dio;

  @override
  FutureEither<PurchaseInvoice> create({
    required PurchaseInvoiceDraftHeader header,
    required List<DraftItem> items,
  }) {
    return runDio<PurchaseInvoice>(tag: 'PurchaseInvoiceCreate', () async {
      final formData = buildFormData(header: header, items: items);

      final response = await _dio.post<dynamic>(
        'shops/my/purchase-invoices',
        data: formData,
        options: Options(contentType: 'multipart/form-data'),
      );

      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw StateError('Unexpected response shape');
      }
      final data = body['data'];
      if (data is! Map) {
        throw StateError('Missing `data` envelope');
      }
      return PurchaseInvoiceModel.fromJson(Map<String, dynamic>.from(data));
    });
  }

  @override
  FutureEither<String> fetchShareUrl(int invoiceId) {
    return runDio<String>(tag: 'PurchaseInvoiceShareUrl', () async {
      final response = await _dio.get<dynamic>(
        'shops/my/purchase-invoices/$invoiceId/share-url',
      );

      final body = response.data;
      if (body is! Map<String, dynamic>) {
        throw StateError('Unexpected response shape');
      }
      final data = body['data'];
      if (data is! Map) {
        throw StateError('Missing `data` envelope');
      }
      final url = data['url'];
      if (url is! String || url.isEmpty) {
        throw StateError('Missing share url');
      }
      return url;
    });
  }
}

/// Build the multipart payload exactly the way Laravel's `StorePurchaseInvoiceRequest`
/// expects: scalar header fields plus repeated nested `items[i][...]` and
/// `items[i][pieces][j][...]` keys. We construct the entries by hand
/// (rather than passing a Map to `FormData.fromMap`) because Dio's automatic
/// list serialization defaults to comma-joining values, which would lose the
/// per-piece nesting Laravel needs to map `UploadedFile` instances back into
/// the validated array.
FormData buildFormData({
  required PurchaseInvoiceDraftHeader header,
  required List<DraftItem> items,
}) {
  final fields = <MapEntry<String, String>>[];
  final files = <MapEntry<String, MultipartFile>>[];

  void putString(String key, Object? value) {
    if (value == null) return;
    final str = value.toString();
    if (str.isEmpty) return;
    fields.add(MapEntry(key, str));
  }

  putString('shop_customer_id', header.shopCustomerId);
  putString('supplier_name', header.supplierName);
  putString('shop_employee_id', header.shopEmployeeId);
  putString('discount', header.discount);
  putString('paid_amount', header.paidAmount);
  putString('payment_method', header.paymentMethod);
  putString('notes', header.notes);
  if (header.saleDate != null) {
    putString('sale_date', DateFormat('yyyy-MM-dd').format(header.saleDate!));
  }

  for (var i = 0; i < items.length; i++) {
    final item = items[i];
    putString('items[$i][shop_item_id]', item.shopItem?.id);
    putString('items[$i][weight_grams_total]', item.weightGramsTotal);
    putString('items[$i][quantity]', item.quantity);
    putString('items[$i][manufacturer_fee]', item.manufacturerFee);

    for (var j = 0; j < item.pieces.length; j++) {
      final piece = item.pieces[j];
      // Per-piece weight is now required by the backend (no even-split
      // fallback). The provider's [itemsAreValid] guards this client-side;
      // we still always emit the key so 422s correctly point at the missing
      // field if the user somehow bypassed validation.
      putString('items[$i][pieces][$j][weight]', piece.weight);
      final image = piece.image;
      if (image != null) {
        files.add(
          MapEntry(
            'items[$i][pieces][$j][image]',
            MultipartFile.fromFileSync(
              image.path,
              filename:
                  image.uri.pathSegments.isEmpty
                      ? 'piece_${i}_$j.jpg'
                      : image.uri.pathSegments.last,
            ),
          ),
        );
      }
    }
  }

  return FormData()
    ..fields.addAll(fields)
    ..files.addAll(files);
}
