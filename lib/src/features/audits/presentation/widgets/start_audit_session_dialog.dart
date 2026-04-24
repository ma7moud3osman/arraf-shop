import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;
import 'package:provider/provider.dart';

import '../../../../shared/enums/app_status.dart';
import '../../../../shared/widgets/app_error_widget.dart';
import '../../../../shared/widgets/app_loading.dart';
import '../../../employees/data/repositories/employees_repository_impl.dart';
import '../../../employees/presentation/providers/employees_picker_provider.dart';

/// Result of the start-audit dialog: a title (possibly empty) plus the
/// selected `shop_employee` ids permitted to scan into the new session.
class StartAuditSessionResult {
  const StartAuditSessionResult({required this.title, required this.participantIds});

  final String title;
  final List<int> participantIds;
}

/// Modal that collects an optional title and the participant employees
/// before starting a new audit session.
///
/// Pops with the chosen [StartAuditSessionResult] on confirm and `null`
/// when cancelled so the caller can distinguish the two.
class StartAuditSessionDialog extends StatefulWidget {
  const StartAuditSessionDialog({super.key});

  static Future<StartAuditSessionResult?> show(BuildContext context) {
    return showDialog<StartAuditSessionResult?>(
      context: context,
      builder: (_) => ChangeNotifierProvider<EmployeesPickerProvider>(
        // Construct the repo locally — it's a thin wrapper around Dio
        // (no shared cache state), so a per-dialog instance is fine and
        // keeps the dialog self-contained.
        create: (_) => EmployeesPickerProvider(
          repository: EmployeesRepositoryImpl(),
        )..load(),
        child: const StartAuditSessionDialog(),
      ),
    );
  }

  @override
  State<StartAuditSessionDialog> createState() =>
      _StartAuditSessionDialogState();
}

class _StartAuditSessionDialogState extends State<StartAuditSessionDialog> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  String _todayLabel = '';
  bool _initialized = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_initialized) return;
    _initialized = true;
    _todayLabel = intl.DateFormat.yMMMd(
      context.locale.toLanguageTag(),
    ).format(DateTime.now());
    _titleController.text = _todayLabel;
  }

  @override
  void dispose() {
    _titleController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _submit() {
    final picker = context.read<EmployeesPickerProvider>();
    Navigator.of(context).pop(
      StartAuditSessionResult(
        title: _titleController.text.trim(),
        participantIds: picker.selectedIds.toList(growable: false),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final picker = context.watch<EmployeesPickerProvider>();
    final canSubmit = picker.selectedCount > 0;

    return AlertDialog(
      title: Text('audits.list.new_dialog_title'.tr()),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _titleController,
              textInputAction: TextInputAction.next,
              decoration: InputDecoration(
                labelText: 'audits.list.title_field_label'.tr(),
                hintText: 'audits.list.title_field_hint'.tr(
                  namedArgs: {'example': _todayLabel},
                ),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'audits.list.participants_label'.tr(),
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search),
                hintText: 'audits.list.participants_search_hint'.tr(),
                isDense: true,
                border: const OutlineInputBorder(),
              ),
              onChanged: (q) => picker.search(q),
            ),
            const SizedBox(height: 8),
            SizedBox(height: 280, child: _Body(picker: picker)),
            if (picker.selectedCount > 0)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  'audits.list.participants_selected'.tr(
                    namedArgs: {'count': '${picker.selectedCount}'},
                  ),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(
          onPressed: canSubmit ? _submit : null,
          child: Text('audits.list.start'.tr()),
        ),
      ],
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.picker});

  final EmployeesPickerProvider picker;

  @override
  Widget build(BuildContext context) {
    switch (picker.status) {
      case AppStatus.initial:
      case AppStatus.loading:
        return const AppLoading();
      case AppStatus.failure:
        return AppErrorWidget(
          title: 'audits.list.participants_load_failed'.tr(),
          message: picker.errorMessage,
          onRetry: picker.load,
        );
      case AppStatus.success:
        if (picker.employees.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'audits.list.participants_empty'.tr(),
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
              ),
            ),
          );
        }
        return ListView.builder(
          itemCount: picker.employees.length,
          itemBuilder: (_, i) {
            final emp = picker.employees[i];
            final selected = picker.isSelected(emp.id);
            final role = emp.role;
            final code = emp.code ?? '';
            final subtitle = role == null || role.isEmpty
                ? code
                : (code.isEmpty ? role : '$role • $code');
            return CheckboxListTile(
              value: selected,
              onChanged: (_) => picker.toggle(emp.id),
              title: Text(emp.name),
              subtitle: subtitle.isEmpty ? null : Text(subtitle),
              dense: true,
            );
          },
        );
    }
  }
}
