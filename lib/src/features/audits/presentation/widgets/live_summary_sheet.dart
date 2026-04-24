import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../shared/widgets/app_error_widget.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../domain/entities/audit_report_snapshot.dart';
import '../../domain/repositories/audit_repository.dart';
import '../providers/audit_summary_provider.dart';
import 'missing_items_sheet.dart';

/// Bottom sheet that renders the live audit summary on top of the active
/// session screen. Kicks off [AuditSummaryProvider.load] on mount and
/// re-fetches on a pull-down or via the retry CTA.
class LiveSummarySheet extends StatelessWidget {
  const LiveSummarySheet({super.key, required this.uuid});

  final String uuid;

  /// Convenience launcher — wires the provider into a draggable sheet.
  static Future<void> show(BuildContext context, {required String uuid}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => ChangeNotifierProvider<AuditSummaryProvider>(
        create: (ctx) =>
            AuditSummaryProvider(repository: ctx.read<AuditRepository>())
              ..load(uuid),
        child: LiveSummarySheet(uuid: uuid),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuditSummaryProvider>();
    final tt = Theme.of(context).textTheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return SingleChildScrollView(
          controller: scrollController,
          padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        'audits.live_summary.title'.tr(),
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'audits.live_summary.refresh'.tr(),
                      icon: const Icon(Icons.refresh),
                      onPressed: provider.status == AppStatus.loading
                          ? null
                          : () => provider.load(uuid),
                    ),
                  ],
                ),
              ),
              switch (provider.status) {
                AppStatus.initial ||
                AppStatus.loading => const Padding(
                    padding: EdgeInsets.symmetric(vertical: 32),
                    child: AppLoading(),
                  ),
                AppStatus.failure => AppErrorWidget(
                    title: 'audits.live_summary.load_failed'.tr(),
                    message: provider.errorMessage,
                    onRetry: () => provider.load(uuid),
                  ),
                AppStatus.success => _Content(
                    snapshot: provider.snapshot!,
                    uuid: uuid,
                  ),
              },
            ],
          ),
        );
      },
    );
  }
}

class _Content extends StatelessWidget {
  const _Content({required this.snapshot, required this.uuid});

  final AuditReportSnapshot snapshot;
  final String uuid;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'audits.live_summary.expected_count'.tr(),
                value: '${snapshot.expectedCount}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'audits.live_summary.scanned_count'.tr(),
                value: '${snapshot.scannedCount}',
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'audits.live_summary.count_difference'.tr(),
                value: snapshot.countDifference.toString(),
                valueColor: snapshot.countDifference < 0 ? cs.error : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'audits.live_summary.expected_weight'.tr(),
                value: snapshot.expectedWeight.toStringAsFixed(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'audits.live_summary.scanned_weight'.tr(),
                value: snapshot.scannedWeight.toStringAsFixed(2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'audits.live_summary.weight_difference'.tr(),
                value: snapshot.weightDifference.toStringAsFixed(2),
                valueColor: snapshot.weightDifference < 0 ? cs.error : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Text(
          'audits.live_summary.exceptions'.tr(),
          style: tt.titleSmall?.copyWith(
            color: cs.onSurfaceVariant,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: _StatTile(
                label: 'audits.live_summary.missing_count'.tr(),
                value: '${snapshot.missingCount}',
                valueColor: snapshot.missingCount > 0 ? cs.error : null,
                onTap: snapshot.missingCount > 0
                    ? () => MissingItemsSheet.show(context, uuid: uuid)
                    : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'audits.live_summary.unexpected_count'.tr(),
                value: '${snapshot.unexpectedCount}',
                valueColor: snapshot.unexpectedCount > 0 ? cs.error : null,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatTile(
                label: 'audits.live_summary.not_found_count'.tr(),
                value: '${snapshot.notFoundCount}',
                valueColor: snapshot.notFoundCount > 0 ? cs.error : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.valueColor,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final body = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: tt.labelSmall?.copyWith(
                    color: cs.onSurfaceVariant,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (onTap != null)
                Icon(
                  Icons.chevron_right,
                  size: 16,
                  color: cs.onSurfaceVariant,
                ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: tt.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return body;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: body,
      ),
    );
  }
}
