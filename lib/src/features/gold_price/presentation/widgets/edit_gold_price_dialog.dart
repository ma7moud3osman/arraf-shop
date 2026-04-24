import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../domain/entities/gold_price_snapshot.dart';

/// Admin-only dialog for editing the gold price.
///
/// The shop's standard practice is to publish only the 21-karat anchor
/// (buy + sale); the backend derives 18 / 22 / 24 karat values
/// proportionally. Returns a `Map<String, double>` with exactly two keys
/// (`karat_21_buy`, `karat_21_sale`), or `null` if cancelled.
class EditGoldPriceDialog extends StatefulWidget {
  const EditGoldPriceDialog({super.key, required this.snapshot});

  final GoldPriceSnapshot snapshot;

  static Future<Map<String, double>?> show(
    BuildContext context,
    GoldPriceSnapshot snapshot,
  ) {
    return showDialog<Map<String, double>>(
      context: context,
      barrierDismissible: false,
      builder: (_) => EditGoldPriceDialog(snapshot: snapshot),
    );
  }

  @override
  State<EditGoldPriceDialog> createState() => _EditGoldPriceDialogState();
}

class _EditGoldPriceDialogState extends State<EditGoldPriceDialog> {
  late final TextEditingController _buyController;
  late final TextEditingController _saleController;
  final _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    final item = widget.snapshot.itemByKey('karat_21');
    _buyController = TextEditingController(
      text: (item?.buy ?? 0).toStringAsFixed(2),
    );
    _saleController = TextEditingController(
      text: (item?.sale ?? 0).toStringAsFixed(2),
    );
  }

  @override
  void dispose() {
    _buyController.dispose();
    _saleController.dispose();
    super.dispose();
  }

  String? _validate(String? raw) {
    final trimmed = (raw ?? '').trim();
    if (trimmed.isEmpty) return 'gold_price.edit.required'.tr();
    final value = double.tryParse(trimmed);
    if (value == null) return 'gold_price.edit.numeric'.tr();
    if (value <= 0) return 'gold_price.edit.gt_zero'.tr();
    return null;
  }

  void _onSave() {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final buy = double.parse(_buyController.text.trim());
    final sale = double.parse(_saleController.text.trim());
    Navigator.of(context).pop(<String, double>{
      'karat_21_buy': buy,
      'karat_21_sale': sale,
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('gold_price.edit.title'.tr()),
      content: SizedBox(
        width: 360,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'gold_price.edit.description'.tr(),
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: 16),
              TextFormField(
                key: const ValueKey('gold-price-21-buy'),
                controller: _buyController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'gold_price.edit.karat_21_buy'.tr(),
                ),
                validator: _validate,
              ),
              const SizedBox(height: 12),
              TextFormField(
                key: const ValueKey('gold-price-21-sale'),
                controller: _saleController,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(
                  labelText: 'gold_price.edit.karat_21_sale'.tr(),
                ),
                validator: _validate,
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('gold_price.edit.cancel'.tr()),
        ),
        FilledButton(
          onPressed: _onSave,
          child: Text('gold_price.edit.save'.tr()),
        ),
      ],
    );
  }
}
