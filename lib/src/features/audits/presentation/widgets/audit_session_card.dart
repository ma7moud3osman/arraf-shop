import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

import '../../../../shared/helpers/format_weight.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../domain/entities/audit_session.dart';
import '../../domain/entities/audit_status.dart';

/// List-row card for an [AuditSession]: title line, status pill, progress bar,
/// and counts. Tappable via [onTap].
class AuditSessionCard extends StatelessWidget {
  const AuditSessionCard({
    super.key,
    required this.session,
    required this.onTap,
  });

  final AuditSession session;
  final VoidCallback onTap;

  static String _formatStartedAt(BuildContext context, DateTime at) {
    return intl.DateFormat.yMMMd(
      context.locale.toLanguageTag(),
    ).add_jm().format(at.toLocal());
  }

  static String _resolveTitle(BuildContext context, AuditSession session) {
    final notes = session.notes;
    if (notes != null && notes.isNotEmpty) return notes;
    final startedAt = session.startedAt;
    if (startedAt == null) return 'audits.list.untitled'.tr();
    final date = intl.DateFormat.yMMMd(
      context.locale.toLanguageTag(),
    ).format(startedAt.toLocal());
    return '$date • ${formatWeight(session.expectedWeightGrams)}';
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final progress = (session.progressPercent.clamp(0, 100)) / 100.0;

    return AppCard(
      onTap: onTap,
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _resolveTitle(context, session),
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      session.uuid,
                      style: tt.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (session.startedAt != null) ...[
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Icon(
                            Icons.event,
                            size: 14,
                            color: cs.onSurfaceVariant,
                          ),
                          const SizedBox(width: 4),
                          Text(
                            _formatStartedAt(context, session.startedAt!),
                            style: tt.bodySmall?.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: 12),
              _StatusPill(status: session.status),
            ],
          ),
          const SizedBox(height: 12),
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
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'audits.list.progress_counts'.tr(
                  namedArgs: {
                    'scanned': '${session.scannedCount}',
                    'expected': '${session.expectedCount}',
                  },
                ),
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
              Text(
                '${session.progressPercent}%',
                style: tt.bodySmall?.copyWith(
                  color: cs.onSurfaceVariant,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final AuditStatus status;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final (bg, fg, label) = switch (status) {
      AuditStatus.draft => (
        cs.surfaceContainerHighest,
        cs.onSurfaceVariant,
        'audits.status.draft'.tr(),
      ),
      AuditStatus.inProgress => (
        cs.primaryContainer,
        cs.onPrimaryContainer,
        'audits.status.in_progress'.tr(),
      ),
      AuditStatus.completed => (
        cs.secondaryContainer,
        cs.onSecondaryContainer,
        'audits.status.completed'.tr(),
      ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: fg,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
