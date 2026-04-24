import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';

import '../../../../shared/helpers/format_weight.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/audit_session.dart';

/// Compact progress card for the active [AuditSession]: running counters,
/// expected totals, and a linear progress bar.
class AuditProgressCard extends StatelessWidget {
  const AuditProgressCard({super.key, required this.session});

  final AuditSession session;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progress =
        session.expectedCount == 0
            ? 0.0
            : (session.scannedCount / session.expectedCount)
                .clamp(0, 1)
                .toDouble();

    return AppCard(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Line 1 — scanned / expected counts on one side, percent on the
          // other. Label sits as a tiny caption above the percent so the
          // counts read big without losing context.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                '${session.progressPercent}%',
                style: tt.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: cs.primary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              Text(
                'audits.session.progress_title'.tr(),
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const SizedBox(width: 8),
              Text.rich(
                TextSpan(
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                  children: [
                    TextSpan(text: '${session.scannedCount}'),
                    TextSpan(
                      text: ' / ${session.expectedCount}',
                      style: TextStyle(
                        color: cs.onSurfaceVariant,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 6,
              backgroundColor: cs.surfaceContainerHighest,
              valueColor: AlwaysStoppedAnimation(cs.primary),
            ),
          ),
          const SizedBox(height: 8),
          // Line 2 — weight values inline next to the scale icon + label.
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Icon(Icons.scale_outlined, size: 14, color: cs.onSurfaceVariant),
              const SizedBox(width: 4),
              Text(
                'audits.session.weight_title'.tr(),
                style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              const Spacer(),
              Flexible(
                child: Text.rich(
                  TextSpan(
                    style: tt.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    children: [
                      TextSpan(text: formatWeight(session.scannedWeightGrams)),
                      TextSpan(
                        text:
                            ' / ${formatWeight(session.expectedWeightGrams)}',
                        style: TextStyle(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                  textAlign: TextAlign.end,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
