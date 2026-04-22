import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/helpers/format_weight.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/app_error_widget.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../../utils/failure.dart';
import '../../domain/entities/audit_report_snapshot.dart';
import '../../domain/entities/audit_scan.dart';
import '../../domain/entities/audit_session_item.dart';
import '../../domain/repositories/audit_repository.dart';

/// Post-audit report screen: headline counts + toggle between the missing
/// and unexpected lists. Reads the completed session's snapshot directly
/// from the repository and paginates the two detail lists.
class AuditSummaryScreen extends StatefulWidget {
  const AuditSummaryScreen({super.key, required this.uuid});

  final String uuid;

  @override
  State<AuditSummaryScreen> createState() => _AuditSummaryScreenState();
}

enum _Tab { missing, unexpected }

class _AuditSummaryScreenState extends State<AuditSummaryScreen> {
  _Tab _tab = _Tab.missing;
  AuditReportSnapshot? _snapshot;
  Failure? _snapshotError;
  bool _snapshotLoading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadSummary());
  }

  Future<void> _loadSummary() async {
    final repo = context.read<AuditRepository>();
    final result = await repo.summary(widget.uuid);
    if (!mounted) return;
    setState(() {
      _snapshotLoading = false;
      result.fold((f) => _snapshotError = f, (snap) => _snapshot = snap);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('audits.summary.title'.tr())),
      body: _body(),
    );
  }

  Widget _body() {
    if (_snapshotLoading) {
      return AppLoading(message: 'audits.summary.loading'.tr());
    }
    if (_snapshotError != null || _snapshot == null) {
      return AppErrorWidget(
        title: 'audits.summary.load_failed'.tr(),
        message: _snapshotError?.message,
        onRetry: () {
          setState(() {
            _snapshotLoading = true;
            _snapshotError = null;
          });
          _loadSummary();
        },
      );
    }
    final snap = _snapshot!;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: _SnapshotPanel(snapshot: snap),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: SegmentedButton<_Tab>(
            segments: [
              ButtonSegment(
                value: _Tab.missing,
                label: Text(
                  'audits.summary.missing'.tr(
                    namedArgs: {'count': '${snap.missingCount}'},
                  ),
                ),
                icon: const Icon(Icons.remove_circle_outline),
              ),
              ButtonSegment(
                value: _Tab.unexpected,
                label: Text(
                  'audits.summary.unexpected'.tr(
                    namedArgs: {'count': '${snap.unexpectedCount}'},
                  ),
                ),
                icon: const Icon(Icons.error_outline),
              ),
            ],
            selected: {_tab},
            onSelectionChanged: (s) => setState(() => _tab = s.first),
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child:
              _tab == _Tab.missing
                  ? _MissingList(uuid: widget.uuid)
                  : _UnexpectedList(uuid: widget.uuid),
        ),
      ],
    );
  }
}

class _SnapshotPanel extends StatelessWidget {
  const _SnapshotPanel({required this.snapshot});
  final AuditReportSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'audits.summary.overview'.tr(),
            style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 12),
          _KeyValue(
            label: 'audits.summary.expected_count'.tr(),
            value: '${snapshot.expectedCount}',
          ),
          _KeyValue(
            label: 'audits.summary.scanned_count'.tr(),
            value: '${snapshot.scannedCount}',
          ),
          _KeyValue(
            label: 'audits.summary.count_difference'.tr(),
            value: snapshot.countDifference.toString(),
            valueColor:
                snapshot.countDifference < 0
                    ? Theme.of(context).colorScheme.error
                    : null,
          ),
          const SizedBox(height: 12),
          _KeyValue(
            label: 'audits.summary.expected_weight'.tr(),
            value: snapshot.expectedWeight.toStringAsFixed(2),
          ),
          _KeyValue(
            label: 'audits.summary.scanned_weight'.tr(),
            value: snapshot.scannedWeight.toStringAsFixed(2),
          ),
          _KeyValue(
            label: 'audits.summary.weight_difference'.tr(),
            value: snapshot.weightDifference.toStringAsFixed(2),
            valueColor:
                snapshot.weightDifference < 0
                    ? Theme.of(context).colorScheme.error
                    : null,
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _Count(
                  label: 'audits.summary.missing_label'.tr(),
                  value: snapshot.missingCount,
                ),
              ),
              Expanded(
                child: _Count(
                  label: 'audits.summary.unexpected_label'.tr(),
                  value: snapshot.unexpectedCount,
                ),
              ),
              Expanded(
                child: _Count(
                  label: 'audits.summary.not_found_label'.tr(),
                  value: snapshot.notFoundCount,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _KeyValue extends StatelessWidget {
  const _KeyValue({required this.label, required this.value, this.valueColor});
  final String label;
  final String value;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
          Text(
            value,
            style: tt.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              color: valueColor,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value});
  final String label;
  final int value;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    return Column(
      children: [
        Text(
          '$value',
          style: tt.headlineSmall?.copyWith(
            fontWeight: FontWeight.w700,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

class _MissingList extends StatefulWidget {
  const _MissingList({required this.uuid});
  final String uuid;

  @override
  State<_MissingList> createState() => _MissingListState();
}

class _MissingListState extends State<_MissingList> {
  bool _loading = true;
  Failure? _error;
  List<AuditSessionItem> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = context.read<AuditRepository>();
    final result = await repo.missing(widget.uuid);
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold((f) => _error = f, (page) => _items = page.items);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppLoading();
    if (_error != null) {
      return AppErrorWidget(
        title: 'audits.summary.missing_failed'.tr(),
        message: _error?.message,
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _load();
        },
      );
    }
    if (_items.isEmpty) {
      return _InlineEmpty(label: 'audits.summary.no_missing'.tr());
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final item = _items[i];
        return ListTile(
          dense: true,
          title: Text(item.name ?? item.barcode),
          subtitle:
              item.name != null
                  ? Text(
                    item.barcode,
                    style: const TextStyle(
                      fontFeatures: [FontFeature.tabularFigures()],
                    ),
                  )
                  : null,
          trailing:
              item.weightGrams != null
                  ? Text(formatWeight(item.weightGrams!))
                  : null,
        );
      },
    );
  }
}

/// Compact, height-flexible empty label that fits even in a tight Expanded
/// slot (unlike [AppEmptyState] which assumes a generous layout).
class _InlineEmpty extends StatelessWidget {
  const _InlineEmpty({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Center(
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
        ),
      ),
    );
  }
}

class _UnexpectedList extends StatefulWidget {
  const _UnexpectedList({required this.uuid});
  final String uuid;

  @override
  State<_UnexpectedList> createState() => _UnexpectedListState();
}

class _UnexpectedListState extends State<_UnexpectedList> {
  bool _loading = true;
  Failure? _error;
  List<AuditScan> _items = const [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final repo = context.read<AuditRepository>();
    final result = await repo.unexpected(widget.uuid);
    if (!mounted) return;
    setState(() {
      _loading = false;
      result.fold((f) => _error = f, (page) => _items = page.items);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const AppLoading();
    if (_error != null) {
      return AppErrorWidget(
        title: 'audits.summary.unexpected_failed'.tr(),
        message: _error?.message,
        onRetry: () {
          setState(() {
            _loading = true;
            _error = null;
          });
          _load();
        },
      );
    }
    if (_items.isEmpty) {
      return _InlineEmpty(label: 'audits.summary.no_unexpected'.tr());
    }
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _items.length,
      separatorBuilder: (_, _) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final scan = _items[i];
        return ListTile(
          dense: true,
          title: Text(
            scan.displayLabel,
            style: const TextStyle(
              fontFeatures: [FontFeature.tabularFigures()],
            ),
          ),
          subtitle: Text(scan.deviceLabel),
          trailing:
              scan.weightGrams != null
                  ? Text(formatWeight(scan.weightGrams!))
                  : null,
        );
      },
    );
  }
}
