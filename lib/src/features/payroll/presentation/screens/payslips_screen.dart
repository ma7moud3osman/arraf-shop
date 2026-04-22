import '../../../../imports/imports.dart';
import '../../domain/entities/payslip.dart';
import '../providers/payroll_list_provider.dart';

/// Read-only list of payslips. Month + year filter in the app bar, tap a row
/// to open the PDF (opens the server-rendered print view in the system
/// browser, where users can "Save as PDF" from the native share sheet).
class PayslipsScreen extends StatefulWidget {
  const PayslipsScreen({super.key});

  @override
  State<PayslipsScreen> createState() => _PayslipsScreenState();
}

class _PayslipsScreenState extends State<PayslipsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<PayrollListProvider>();
      if (provider.status == AppStatus.initial) provider.load();
    });
  }

  Future<void> _openFilter() async {
    final provider = context.read<PayrollListProvider>();
    final picked = await showModalBottomSheet<_FilterResult>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      isScrollControlled: true,
      builder:
          (_) => _FilterSheet(
            initialYear: provider.year,
            initialMonth: provider.month,
          ),
    );
    if (picked != null && mounted) {
      if (picked.clear) {
        provider.clearFilter();
      } else {
        provider.setFilter(year: picked.year, month: picked.month);
      }
    }
  }

  Future<void> _openPdf(Payslip p) async {
    final url = p.pdfUrl;
    if (url == null || url.isEmpty) {
      showToast(
        context,
        message: 'payroll.toast.pdf_unavailable'.tr(),
        status: 'error',
      );
      return;
    }
    final uri = Uri.parse(url);
    final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      showToast(
        context,
        message: 'payroll.toast.open_failed'.tr(),
        status: 'error',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<PayrollListProvider>();

    return Scaffold(
      appBar: AppBar(
        title: Text('payroll.title'.tr()),
        actions: [
          IconButton(
            tooltip: 'payroll.filter'.tr(),
            icon: Icon(
              provider.hasFilter ? Icons.filter_alt : Icons.filter_alt_outlined,
            ),
            onPressed: _openFilter,
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: provider.refresh,
        child: _body(provider),
      ),
    );
  }

  Widget _body(PayrollListProvider provider) {
    return switch (provider.status) {
      AppStatus.initial || AppStatus.loading => const AppLoading(),
      AppStatus.failure => AppErrorWidget(
        title: 'payroll.load_failed'.tr(),
        message: provider.errorMessage,
        onRetry: provider.load,
      ),
      AppStatus.success =>
        provider.payslips.isEmpty
            ? ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                const SizedBox(height: 120),
                AppEmptyState(
                  title: 'payroll.empty_title'.tr(),
                  subtitle: 'payroll.empty_subtitle'.tr(),
                ),
              ],
            )
            : ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              physics: const AlwaysScrollableScrollPhysics(),
              itemCount: provider.payslips.length,
              separatorBuilder: (_, _) => const SizedBox(height: 12),
              itemBuilder:
                  (context, i) => _PayslipCard(
                    payslip: provider.payslips[i],
                    onOpen: () => _openPdf(provider.payslips[i]),
                  ),
            ),
    };
  }
}

class _PayslipCard extends StatelessWidget {
  const _PayslipCard({required this.payslip, required this.onOpen});

  final Payslip payslip;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return AppCard(
      onTap: onOpen,
      child: Row(
        children: [
          Container(
            width: 54,
            height: 54,
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(14),
            ),
            alignment: Alignment.center,
            child: Icon(
              Icons.description_outlined,
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  DateFormat.yMMMM(
                    context.locale.languageCode,
                  ).format(payslip.periodStart),
                  style: tt.titleMedium?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    _Pill(
                      labelKey: payslip.statusKey,
                      color: _statusColor(payslip, cs),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '${payslip.workingDays} ${'payroll.days'.tr()} · ${payslip.absentDays} ${'payroll.absent'.tr()}',
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                payslip.netSalary.toStringAsFixed(2),
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ],
      ),
    );
  }

  Color _statusColor(Payslip p, ColorScheme cs) {
    if (p.isPaid) return Colors.green.shade600;
    if (p.isLocked) return Colors.orange.shade700;
    return cs.onSurfaceVariant;
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.labelKey, required this.color});
  final String labelKey;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        labelKey.tr(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.4,
        ),
      ),
    );
  }
}

class _FilterResult {
  final int? year;
  final int? month;
  final bool clear;
  _FilterResult({this.year, this.month, this.clear = false});
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({this.initialYear, this.initialMonth});
  final int? initialYear;
  final int? initialMonth;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late int? _year = widget.initialYear;
  late int? _month = widget.initialMonth;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final years = List<int>.generate(5, (i) => now.year - i);
    const months = [1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12];

    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 16,
        bottom: MediaQuery.viewInsetsOf(context).bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'payroll.filter_title'.tr(),
            style: tt.titleLarge?.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 16),
          Text('payroll.year'.tr(), style: tt.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              for (final y in years)
                ChoiceChip(
                  label: Text('$y'),
                  selected: _year == y,
                  onSelected: (sel) => setState(() => _year = sel ? y : null),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Text('payroll.month'.tr(), style: tt.labelMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (final m in months)
                ChoiceChip(
                  label: Text(
                    DateFormat.MMM(
                      context.locale.languageCode,
                    ).format(DateTime(now.year, m)),
                  ),
                  selected: _month == m,
                  onSelected: (sel) => setState(() => _month = sel ? m : null),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed:
                      () => Navigator.pop(context, _FilterResult(clear: true)),
                  child: Text('payroll.clear'.tr()),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton(
                  onPressed:
                      () => Navigator.pop(
                        context,
                        _FilterResult(year: _year, month: _month),
                      ),
                  child: Text('payroll.apply'.tr()),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
