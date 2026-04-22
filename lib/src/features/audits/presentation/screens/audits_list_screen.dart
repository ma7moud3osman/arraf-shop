import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../shared/helpers/show_toast.dart';
import '../../../../shared/widgets/app_empty_state.dart';
import '../../../../shared/widgets/app_error_widget.dart';
import '../../domain/entities/audit_session.dart';
import '../../domain/entities/audit_status.dart';
import '../providers/audits_list_provider.dart';
import '../widgets/audit_session_card.dart';

/// Paginated list of audit sessions with pull-to-refresh and a FAB
/// that starts a new session (owner-only).
///
/// Navigation is delegated: [onOpen] is invoked with the target session's
/// uuid when a card is tapped or a newly-started session is ready.
class AuditsListScreen extends StatefulWidget {
  const AuditsListScreen({
    super.key,
    required this.onOpen,
    required this.isOwner,
  });

  /// Invoked when a session is selected (tap on a card, or after starting a
  /// new one). Caller inspects the session status to choose between the
  /// live session screen (in-progress) and the summary (completed).
  final ValueChanged<AuditSession> onOpen;
  final bool isOwner;

  @override
  State<AuditsListScreen> createState() => _AuditsListScreenState();
}

class _AuditsListScreenState extends State<AuditsListScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final provider = context.read<AuditsListProvider>();
      if (provider.status == AppStatus.initial) {
        provider.load();
      }
    });
  }

  Future<void> _startNew() async {
    final provider = context.read<AuditsListProvider>();
    await provider.startNew();
    if (!mounted) return;

    if (provider.startStatus == AppStatus.failure) {
      showToast(
        context,
        message: provider.errorMessage ?? 'audits.list.start_failed'.tr(),
        status: 'error',
      );
      return;
    }

    final started = provider.consumeLastStarted();
    if (started != null) {
      widget.onOpen(started);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<AuditsListProvider>();

    return Scaffold(
      appBar: AppBar(title: Text('audits.list.title'.tr())),
      body: _buildBody(provider),
      floatingActionButton:
          widget.isOwner
              ? FloatingActionButton.extended(
                onPressed:
                    provider.startStatus == AppStatus.loading
                        ? null
                        : _startNew,
                icon:
                    provider.startStatus == AppStatus.loading
                        ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Icon(Icons.add, color: Colors.white),
                label: Text(
                  'audits.list.start_new'.tr(),
                  style: const TextStyle(color: Colors.white),
                ),
              )
              : null,
    );
  }

  Widget _buildBody(AuditsListProvider provider) {
    switch (provider.status) {
      case AppStatus.initial:
      case AppStatus.loading:
        return const _SkeletonList();
      case AppStatus.failure:
        return AppErrorWidget(
          title: 'audits.list.load_failed'.tr(),
          message: provider.errorMessage,
          onRetry: provider.refresh,
        );
      case AppStatus.success:
        if (provider.sessions.isEmpty) {
          return RefreshIndicator(
            onRefresh: provider.refresh,
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                AppEmptyState(
                  title: 'audits.list.empty_title'.tr(),
                  subtitle: 'audits.list.empty_subtitle'.tr(),
                ),
              ],
            ),
          );
        }
        return RefreshIndicator(
          onRefresh: provider.refresh,
          child: ListView.builder(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            physics: const AlwaysScrollableScrollPhysics(),
            itemCount: provider.sessions.length,
            itemBuilder: (context, index) {
              final session = provider.sessions[index];
              return AuditSessionCard(
                session: session,
                onTap: () => widget.onOpen(session),
              );
            },
          ),
        );
    }
  }
}

class _SkeletonList extends StatelessWidget {
  const _SkeletonList();

  @override
  Widget build(BuildContext context) {
    const placeholder = AuditSession(
      uuid: '-------- -------- --------',
      shopId: 0,
      status: AuditStatus.inProgress,
      expectedCount: 100,
      expectedWeightGrams: 1000,
      scannedCount: 42,
      scannedWeightGrams: 420,
      progressPercent: 42,
      channel: 'private-shop-audit.0',
      notes: 'Loading…',
    );

    return Skeletonizer(
      child: ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        itemCount: 4,
        itemBuilder:
            (_, _) => AuditSessionCard(session: placeholder, onTap: () {}),
      ),
    );
  }
}
