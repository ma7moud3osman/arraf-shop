import 'package:easy_localization/easy_localization.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' as intl;

/// Modal that collects an optional title before starting a new audit session.
///
/// Pops with the trimmed title on confirm (empty string when left blank)
/// and `null` when cancelled so the caller can distinguish "start without
/// a title" from "don't start at all".
class StartAuditSessionDialog extends StatefulWidget {
  const StartAuditSessionDialog({super.key});

  static Future<String?> show(BuildContext context) {
    return showDialog<String?>(
      context: context,
      builder: (_) => const StartAuditSessionDialog(),
    );
  }

  @override
  State<StartAuditSessionDialog> createState() =>
      _StartAuditSessionDialogState();
}

class _StartAuditSessionDialogState extends State<StartAuditSessionDialog> {
  final TextEditingController _controller = TextEditingController();
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
    _controller.text = _todayLabel;
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    Navigator.of(context).pop(_controller.text.trim());
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('audits.list.new_dialog_title'.tr()),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          labelText: 'audits.list.title_field_label'.tr(),
          hintText: 'audits.list.title_field_hint'.tr(
            namedArgs: {'example': _todayLabel},
          ),
          border: const OutlineInputBorder(),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text('common.cancel'.tr()),
        ),
        FilledButton(onPressed: _submit, child: Text('audits.list.start'.tr())),
      ],
    );
  }
}
