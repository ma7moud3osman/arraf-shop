import 'package:flutter/material.dart';

import '../../domain/entities/gold_price_snapshot.dart';

/// Admin-only dialog for editing the gold price.
///
/// Returns a `Map<String, double>` of field-name → new-value changes
/// (only fields the admin actually touched), or `null` if cancelled.
/// Reuses the backend field names verbatim so the caller can hand them
/// straight to the repository.
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
  /// Only the karat/unit keys the admin endpoint accepts. Each row
  /// renders both `_sale` and `_buy` inputs.
  static const _editableKeys = <String>[
    'karat_24',
    'karat_22',
    'karat_21',
    'karat_18',
    'ounce',
    'pound',
  ];

  late final Map<String, TextEditingController> _sale;
  late final Map<String, TextEditingController> _buy;
  late final Map<String, double> _initialSale;
  late final Map<String, double> _initialBuy;

  @override
  void initState() {
    super.initState();
    _sale = {};
    _buy = {};
    _initialSale = {};
    _initialBuy = {};

    for (final key in _editableKeys) {
      final item = widget.snapshot.itemByKey(key);
      final saleValue = item?.sale ?? 0;
      final buyValue = item?.buy ?? 0;
      _initialSale[key] = saleValue;
      _initialBuy[key] = buyValue;
      _sale[key] = TextEditingController(text: saleValue.toStringAsFixed(2));
      _buy[key] = TextEditingController(text: buyValue.toStringAsFixed(2));
    }
  }

  @override
  void dispose() {
    for (final c in _sale.values) {
      c.dispose();
    }
    for (final c in _buy.values) {
      c.dispose();
    }
    super.dispose();
  }

  Map<String, double> _diff() {
    final out = <String, double>{};
    for (final key in _editableKeys) {
      final newSale = double.tryParse(_sale[key]!.text.trim());
      final newBuy = double.tryParse(_buy[key]!.text.trim());
      if (newSale != null && newSale != _initialSale[key]) {
        out['${key}_sale'] = newSale;
      }
      if (newBuy != null && newBuy != _initialBuy[key]) {
        out['${key}_buy'] = newBuy;
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Edit gold price'),
      content: SizedBox(
        width: 420,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: _editableKeys.map(_buildRow).toList(growable: false),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(_diff()),
          child: const Text('Save'),
        ),
      ],
    );
  }

  Widget _buildRow(String key) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(key, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _sale[key],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Sale',
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _buy[key],
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Buy',
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
