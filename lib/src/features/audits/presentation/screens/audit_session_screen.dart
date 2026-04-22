import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../shared/helpers/show_toast.dart';
import '../../../../shared/widgets/app_error_widget.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../domain/entities/audit_scan.dart';
import '../../domain/entities/audit_scan_result.dart';
import '../../domain/entities/audit_status.dart';
import '../providers/audit_session_provider.dart';
import '../widgets/audit_progress_card.dart';
import '../widgets/audit_scan_row.dart';
import '../widgets/barcode_scanner_view.dart';

/// Active audit session screen: scanner in the top half, live progress +
/// last-20 scan feed in the bottom half. Owner-only "Complete" action.
class AuditSessionScreen extends StatefulWidget {
  const AuditSessionScreen({
    super.key,
    required this.uuid,
    required this.isOwner,
    required this.onCompleted,
  });

  final String uuid;
  final bool isOwner;

  /// Invoked once the session transitions to [AuditStatus.completed].
  /// Track H routes this to the summary screen.
  final ValueChanged<String> onCompleted;

  @override
  State<AuditSessionScreen> createState() => _AuditSessionScreenState();
}

class _AuditSessionScreenState extends State<AuditSessionScreen> {
  int _lastScanId = 0;
  AppStatus _lastScanStatus = AppStatus.initial;
  int _lastDuplicateTick = 0;
  AuditStatus? _observedStatus;
  bool _completionHandled = false;
  AuditSessionProvider? _provider;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _provider ??= context.read<AuditSessionProvider>();
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = _provider ?? context.read<AuditSessionProvider>();
      await provider.join(widget.uuid);
      if (!mounted) return;
      if (provider.status == AppStatus.success) {
        provider.subscribe();
      }
    });
  }

  @override
  void dispose() {
    // Use the cached provider reference — `context.read` is unsafe here
    // because the element is deactivated by dispose time.
    _provider?.unsubscribe();
    super.dispose();
  }

  void _onBarcode(String barcode) {
    final provider = context.read<AuditSessionProvider>();
    provider.scan(barcode);
  }

  Future<void> _complete() async {
    final provider = context.read<AuditSessionProvider>();
    await provider.complete();
    if (!mounted) return;

    if (provider.completeStatus == AppStatus.failure) {
      showToast(
        context,
        message: provider.errorMessage ?? 'audits.session.complete_failed'.tr(),
        status: 'error',
      );
    }
  }

  void _reactToScanStatus(AuditSessionProvider provider) {
    if (provider.scanStatus == _lastScanStatus) return;
    _lastScanStatus = provider.scanStatus;
    if (provider.scanStatus == AppStatus.failure) {
      showToast(
        context,
        message: provider.errorMessage ?? 'audits.session.scan_failed'.tr(),
        status: 'error',
      );
    }
  }

  void _reactToDuplicate(AuditSessionProvider provider) {
    if (provider.duplicateTick == _lastDuplicateTick) return;
    _lastDuplicateTick = provider.duplicateTick;
    showToast(
      context,
      message: 'audits.scan.duplicate'.tr(),
      status: 'warning',
    );
  }

  void _reactToNewScan(AuditSessionProvider provider) {
    final feed = provider.feed;
    if (feed.isEmpty) return;
    final head = feed.first;
    if (head.id == _lastScanId || head.id < 0) return;
    _lastScanId = head.id;

    final (toastStatus, label) = switch (head.result) {
      AuditScanResult.valid => ('success', 'audits.scan.valid'.tr()),
      AuditScanResult.duplicate => ('warning', 'audits.scan.duplicate'.tr()),
      AuditScanResult.notFound => ('error', 'audits.scan.not_found'.tr()),
      AuditScanResult.unexpected => ('warning', 'audits.scan.unexpected'.tr()),
    };

    showToast(context, message: label, status: toastStatus);
  }

  /// Only navigate on an in-progress → completed transition observed during
  /// this screen's lifetime. Opening an already-completed session (e.g. the
  /// user tapped a completed card that got routed here anyway) must NOT
  /// trigger a redirect — the router already picks the right destination.
  void _reactToCompletion(AuditSessionProvider provider) {
    final session = provider.session;
    if (session == null) return;

    final previous = _observedStatus;
    _observedStatus = session.status;

    if (_completionHandled) return;
    if (session.status != AuditStatus.completed) return;
    // First observation of this session — no transition happened yet.
    if (previous == null || previous == AuditStatus.completed) return;

    _completionHandled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      widget.onCompleted(widget.uuid);
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuditSessionProvider>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _reactToScanStatus(provider);
      _reactToDuplicate(provider);
      _reactToNewScan(provider);
      _reactToCompletion(provider);
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('audits.session.title'.tr()),
        actions: [
          if (widget.isOwner &&
              provider.session?.status == AuditStatus.inProgress)
            TextButton.icon(
              onPressed:
                  provider.completeStatus == AppStatus.loading
                      ? null
                      : _complete,
              icon:
                  provider.completeStatus == AppStatus.loading
                      ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.check_circle_outline),
              label: Text('audits.session.complete'.tr()),
            ),
        ],
      ),
      body: switch (provider.status) {
        AppStatus.initial ||
        AppStatus.loading => AppLoading(message: 'audits.session.loading'.tr()),
        AppStatus.failure => AppErrorWidget(
          title: 'audits.session.load_failed'.tr(),
          message: provider.errorMessage,
          onRetry: () => provider.join(widget.uuid),
        ),
        AppStatus.success => _Body(
          session: provider.session,
          feed: provider.feed,
          paused: provider.session?.status == AuditStatus.completed,
          onBarcode: _onBarcode,
        ),
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({
    required this.session,
    required this.feed,
    required this.paused,
    required this.onBarcode,
  });

  final dynamic session;
  final List<AuditScan> feed;
  final bool paused;
  final ValueChanged<String> onBarcode;

  @override
  Widget build(BuildContext context) {
    if (session == null) {
      return const SizedBox.shrink();
    }

    final completedAt = session.completedAt as DateTime?;
    final isCompleted = session.status == AuditStatus.completed;

    return Column(
      children: [
        Expanded(
          flex: 5,
          child: ColoredBox(
            color: Colors.black,
            child: BarcodeScannerView(onBarcode: onBarcode, paused: paused),
          ),
        ),
        AuditProgressCard(session: session),
        if (isCompleted && completedAt != null)
          _CompletedBanner(completedAt: completedAt),
        const Divider(height: 1),
        Expanded(
          flex: 5,
          child:
              feed.isEmpty
                  ? Center(
                    child: Text(
                      'audits.session.feed_empty'.tr(),
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                    ),
                  )
                  : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: feed.length,
                    separatorBuilder:
                        (_, _) =>
                            const Divider(height: 1, indent: 16, endIndent: 16),
                    itemBuilder: (_, i) => AuditScanRow(scan: feed[i]),
                  ),
        ),
      ],
    );
  }
}

class _CompletedBanner extends StatelessWidget {
  const _CompletedBanner({required this.completedAt});

  final DateTime completedAt;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final localeTag = Localizations.maybeLocaleOf(context)?.toLanguageTag();
    final formatted = intl.DateFormat.yMMMd(localeTag)
        .add_jm()
        .format(completedAt.toLocal());

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: cs.secondaryContainer,
      child: Row(
        children: [
          Icon(
            Icons.check_circle_rounded,
            size: 18,
            color: cs.onSecondaryContainer,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'audits.session.completed_at'.tr(namedArgs: {'at': formatted}),
              style: tt.bodySmall?.copyWith(color: cs.onSecondaryContainer),
            ),
          ),
        ],
      ),
    );
  }
}
