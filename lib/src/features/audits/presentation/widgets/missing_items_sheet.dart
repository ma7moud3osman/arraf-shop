import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../shared/helpers/format_weight.dart';
import '../../../../shared/widgets/app_error_widget.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../domain/entities/audit_session_item.dart';
import '../../domain/repositories/audit_repository.dart';
import '../../../../utils/failure.dart';

/// Bottom sheet that lists items expected in the audit session but not yet
/// scanned. Opened from the live summary's "missing" tile.
class MissingItemsSheet extends StatefulWidget {
  const MissingItemsSheet({super.key, required this.uuid});

  final String uuid;

  static Future<void> show(BuildContext context, {required String uuid}) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => Provider.value(
        value: context.read<AuditRepository>(),
        child: MissingItemsSheet(uuid: uuid),
      ),
    );
  }

  @override
  State<MissingItemsSheet> createState() => _MissingItemsSheetState();
}

class _MissingItemsSheetState extends State<MissingItemsSheet> {
  bool _loading = true;
  Failure? _error;
  List<AuditSessionItem> _items = const [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
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
    final tt = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.9,
      builder: (_, scrollController) {
        return Padding(
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
                        'audits.live_summary.missing_title'.tr(
                          namedArgs: {'count': '${_items.length}'},
                        ),
                        style: tt.titleLarge?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'audits.live_summary.refresh'.tr(),
                      icon: const Icon(Icons.refresh),
                      onPressed: _loading ? null : _load,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _loading
                    ? const AppLoading()
                    : _error != null
                        ? AppErrorWidget(
                            title: 'audits.summary.missing_failed'.tr(),
                            message: _error!.message,
                            onRetry: _load,
                          )
                        : _items.isEmpty
                            ? Center(
                                child: Text(
                                  'audits.summary.no_missing'.tr(),
                                  style: tt.bodyMedium?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              )
                            : ListView.separated(
                                controller: scrollController,
                                itemCount: _items.length,
                                separatorBuilder: (_, _) =>
                                    const Divider(height: 1),
                                itemBuilder: (_, i) {
                                  final item = _items[i];
                                  return ListTile(
                                    dense: true,
                                    title: Text(item.name ?? item.barcode),
                                    subtitle: item.name != null
                                        ? Text(
                                            item.barcode,
                                            style: const TextStyle(
                                              fontFeatures: [
                                                FontFeature.tabularFigures(),
                                              ],
                                            ),
                                          )
                                        : null,
                                    trailing: item.weightGrams != null
                                        ? Text(
                                            formatWeight(item.weightGrams!),
                                          )
                                        : null,
                                  );
                                },
                              ),
              ),
            ],
          ),
        );
      },
    );
  }
}
