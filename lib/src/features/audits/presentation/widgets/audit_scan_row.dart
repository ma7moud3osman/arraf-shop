import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../domain/entities/audit_scan.dart';
import '../../domain/entities/audit_scan_result.dart';

/// Compact row showing a single [AuditScan]: status dot, barcode, timestamp.
class AuditScanRow extends StatelessWidget {
  const AuditScanRow({super.key, required this.scan});

  final AuditScan scan;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final (color, label) = _resultStyle(cs, scan.result);
    final isOptimistic = scan.id < 0;
    final hasName = scan.productName != null && scan.productName!.isNotEmpty;

    return Opacity(
      opacity: isOptimistic ? 0.6 : 1.0,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    hasName ? scan.productName! : scan.barcode,
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (hasName) ...[
                    const SizedBox(height: 2),
                    Text(
                      scan.barcode,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  const SizedBox(height: 2),
                  Text(label, style: tt.bodySmall?.copyWith(color: color)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            Text(
              _formatTime(context, scan.scannedAt),
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ],
        ),
      ),
    );
  }

  static (Color, String) _resultStyle(ColorScheme cs, AuditScanResult r) {
    return switch (r) {
      AuditScanResult.valid => (
        Colors.green.shade600,
        'audits.scan.valid'.tr(),
      ),
      AuditScanResult.duplicate => (
        Colors.amber.shade700,
        'audits.scan.duplicate'.tr(),
      ),
      AuditScanResult.notFound => (cs.error, 'audits.scan.not_found'.tr()),
      AuditScanResult.unexpected => (
        Colors.orange.shade700,
        'audits.scan.unexpected'.tr(),
      ),
    };
  }

  static String _formatTime(BuildContext context, DateTime t) {
    final locale = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    return intl.DateFormat.jms(locale).format(t.toLocal());
  }
}
