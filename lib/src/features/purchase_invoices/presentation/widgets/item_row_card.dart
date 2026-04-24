import 'dart:io';

import 'package:arraf_shop/src/features/purchase_invoices/domain/entities/purchase_invoice_draft.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/create_purchase_invoice_provider.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/providers/shop_item_picker_provider.dart';
import 'package:arraf_shop/src/features/purchase_invoices/presentation/widgets/shop_item_picker_sheet.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

/// Single item card on the wizard's items step. Owns its inline text
/// controllers; reads/writes everything else through the parent provider.
class ItemRowCard extends StatefulWidget {
  const ItemRowCard({
    super.key,
    required this.index,
    required this.draft,
    required this.canRemove,
  });

  final int index;
  final DraftItem draft;
  final bool canRemove;

  @override
  State<ItemRowCard> createState() => _ItemRowCardState();
}

class _ItemRowCardState extends State<ItemRowCard> {
  late final TextEditingController _weight = TextEditingController(
    text:
        widget.draft.weightGramsTotal == 0
            ? ''
            : widget.draft.weightGramsTotal.toString(),
  );
  late final TextEditingController _qty = TextEditingController(
    text: widget.draft.quantity.toString(),
  );
  late final TextEditingController _fee = TextEditingController(
    text:
        widget.draft.manufacturerFee == 0
            ? ''
            : widget.draft.manufacturerFee.toString(),
  );
  final ImagePicker _imagePicker = ImagePicker();

  @override
  void dispose() {
    _weight.dispose();
    _qty.dispose();
    _fee.dispose();
    super.dispose();
  }

  Future<void> _pickItem() async {
    final picked = await showModalBottomSheet<dynamic>(
      context: context,
      isScrollControlled: true,
      builder:
          (sheetCtx) => ChangeNotifierProvider.value(
            value: context.read<ShopItemPickerProvider>(),
            child: const ShopItemPickerSheet(),
          ),
    );
    if (picked != null && mounted) {
      context.read<CreatePurchaseInvoiceProvider>().setItemShopItem(
        widget.index,
        picked,
      );
      // Sync the fee controller to the prefilled value.
      final fee =
          context
              .read<CreatePurchaseInvoiceProvider>()
              .items[widget.index]
              .manufacturerFee;
      _fee.text = fee == 0 ? '' : fee.toString();
    }
  }

  Future<void> _pickPieceImage(int pieceIndex, ImageSource source) async {
    final file = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1600,
      imageQuality: 85,
    );
    if (file == null || !mounted) return;
    context.read<CreatePurchaseInvoiceProvider>().setPieceImage(
      widget.index,
      pieceIndex,
      File(file.path),
    );
  }

  void _showImagePickerSheet(int pieceIndex) {
    showModalBottomSheet<void>(
      context: context,
      builder:
          (sheetCtx) => SafeArea(
            child: Wrap(
              children: [
                ListTile(
                  leading: const Icon(Icons.photo_camera_outlined),
                  title: Text('purchase_invoice.image.camera'.tr()),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _pickPieceImage(pieceIndex, ImageSource.camera);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: Text('purchase_invoice.image.gallery'.tr()),
                  onTap: () {
                    Navigator.of(sheetCtx).pop();
                    _pickPieceImage(pieceIndex, ImageSource.gallery);
                  },
                ),
              ],
            ),
          ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = widget.draft;
    final provider = context.read<CreatePurchaseInvoiceProvider>();
    final tt = context.theme.textTheme;
    final cs = context.theme.colorScheme;
    final errors = provider.validationErrors;
    final shopItemError = errors['items.${widget.index}.shop_item_id']?.first;
    final piecesCountError = errors['items.${widget.index}.pieces']?.first;

    return AppCard(
      child: Padding(
        padding: EdgeInsets.all(12.w),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'purchase_invoice.item_n'.tr(args: ['${widget.index + 1}']),
                    style: tt.titleSmall,
                  ),
                ),
                if (widget.canRemove)
                  IconButton(
                    onPressed: () => provider.removeItem(widget.index),
                    icon: Icon(Icons.delete_outline, color: cs.error),
                  ),
              ],
            ),
            SizedBox(height: 8.h),
            InkWell(
              onTap: _pickItem,
              child: InputDecorator(
                decoration: InputDecoration(
                  isDense: true,
                  labelText: 'purchase_invoice.shop_item'.tr(),
                  errorText: shopItemError,
                ),
                child: Text(
                  draft.shopItem?.displayLabel ??
                      'purchase_invoice.tap_to_pick'.tr(),
                  style: tt.bodyMedium,
                ),
              ),
            ),
            SizedBox(height: 12.h),
            Row(
              children: [
                Expanded(
                  child: AppTextField(
                    controller: _weight,
                    label: 'purchase_invoice.weight_total'.tr(),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    onChanged:
                        (v) => provider.setItemWeightTotal(
                          widget.index,
                          double.tryParse(v) ?? 0,
                        ),
                  ),
                ),
                SizedBox(width: 8.w),
                Expanded(
                  child: AppTextField(
                    controller: _qty,
                    label: 'purchase_invoice.quantity'.tr(),
                    keyboardType: TextInputType.number,
                    onChanged:
                        (v) => provider.setItemQuantity(
                          widget.index,
                          int.tryParse(v) ?? 1,
                        ),
                  ),
                ),
              ],
            ),
            SizedBox(height: 8.h),
            AppTextField(
              controller: _fee,
              label: 'purchase_invoice.manufacturer_fee'.tr(),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              onChanged:
                  (v) => provider.setItemManufacturerFee(
                    widget.index,
                    double.tryParse(v) ?? 0,
                  ),
            ),
            if (piecesCountError != null) ...[
              SizedBox(height: 6.h),
              Text(
                piecesCountError,
                style: tt.bodySmall?.copyWith(color: cs.error),
              ),
            ],
            SizedBox(height: 12.h),
            Builder(
              builder: (_) {
                final piecesSum = draft.pieces.fold<double>(
                  0,
                  (s, p) => s + (p.weight ?? 0),
                );
                final mismatch =
                    draft.weightGramsTotal > 0 &&
                    (piecesSum - draft.weightGramsTotal).abs() > 0.01;
                return Row(
                  children: [
                    Expanded(
                      child: Text(
                        'purchase_invoice.pieces_label'.tr(
                          args: ['${draft.pieces.length}'],
                        ),
                        style: tt.titleSmall,
                      ),
                    ),
                    Text(
                      'purchase_invoice.pieces_sum_label'.tr(
                        args: [
                          piecesSum.toStringAsFixed(2),
                          draft.weightGramsTotal.toStringAsFixed(2),
                        ],
                      ),
                      style: tt.bodySmall?.copyWith(
                        color: mismatch ? cs.error : cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                );
              },
            ),
            SizedBox(height: 8.h),
            for (int j = 0; j < draft.pieces.length; j++)
              _PieceRow(
                key: ValueKey('piece_${widget.index}_$j'),
                pieceIndex: j,
                piece: draft.pieces[j],
                onPickImage: () => _showImagePickerSheet(j),
                onClearImage:
                    () => provider.setPieceImage(widget.index, j, null),
                onWeightChanged:
                    (w) => provider.setPieceWeight(widget.index, j, w),
                imageError:
                    errors['items.${widget.index}.pieces.$j.image']?.first,
                weightError:
                    errors['items.${widget.index}.pieces.$j.weight']?.first,
              ),
          ],
        ),
      ),
    );
  }
}

class _PieceRow extends StatelessWidget {
  const _PieceRow({
    super.key,
    required this.pieceIndex,
    required this.piece,
    required this.onPickImage,
    required this.onClearImage,
    required this.onWeightChanged,
    this.imageError,
    this.weightError,
  });

  final int pieceIndex;
  final DraftPiece piece;
  final VoidCallback onPickImage;
  final VoidCallback onClearImage;
  final ValueChanged<double?> onWeightChanged;
  final String? imageError;
  final String? weightError;

  @override
  Widget build(BuildContext context) {
    final tt = context.theme.textTheme;
    final cs = context.theme.colorScheme;
    final hasImage = piece.image != null;
    final missingWeight =
        weightError != null || piece.weight == null || piece.weight! <= 0;

    return Padding(
      padding: EdgeInsets.only(bottom: 12.h),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: onPickImage,
            child: Container(
              width: 64.w,
              height: 64.w,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8.r),
                color: cs.surfaceContainerHighest,
                image:
                    hasImage
                        ? DecorationImage(
                          image: FileImage(piece.image!),
                          fit: BoxFit.cover,
                        )
                        : null,
                border: imageError != null ? Border.all(color: cs.error) : null,
              ),
              alignment: Alignment.center,
              child:
                  hasImage
                      ? null
                      : Icon(
                        Icons.add_a_photo_outlined,
                        color: cs.onSurfaceVariant,
                      ),
            ),
          ),
          SizedBox(width: 12.w),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'purchase_invoice.piece_n'.tr(args: ['${pieceIndex + 1}']),
                  style: tt.bodySmall,
                ),
                SizedBox(height: 4.h),
                AppTextField(
                  hint: 'purchase_invoice.piece_weight_required_hint'.tr(),
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  initialValue: piece.weight?.toString(),
                  onChanged:
                      (v) => onWeightChanged(
                        v.isEmpty ? null : double.tryParse(v),
                      ),
                ),
                if (weightError != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    weightError!,
                    style: tt.bodySmall?.copyWith(color: cs.error),
                  ),
                ] else if (missingWeight) ...[
                  SizedBox(height: 4.h),
                  Text(
                    'purchase_invoice.piece_weight_required'.tr(),
                    style: tt.bodySmall?.copyWith(color: cs.error),
                  ),
                ],
                if (imageError != null) ...[
                  SizedBox(height: 4.h),
                  Text(
                    imageError!,
                    style: tt.bodySmall?.copyWith(color: cs.error),
                  ),
                ],
              ],
            ),
          ),
          if (hasImage)
            IconButton(onPressed: onClearImage, icon: const Icon(Icons.close)),
        ],
      ),
    );
  }
}
