import 'package:arraf_shop/src/features/employees/presentation/providers/employee_payroll_provider.dart';
import 'package:arraf_shop/src/features/payroll/domain/entities/payslip.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

class EmployeePayrollTab extends StatefulWidget {
  const EmployeePayrollTab({super.key});

  @override
  State<EmployeePayrollTab> createState() => _EmployeePayrollTabState();
}

class _EmployeePayrollTabState extends State<EmployeePayrollTab> {
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<EmployeePayrollProvider>();
      if (provider.status == AppStatus.initial) provider.load();
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      final provider = context.read<EmployeePayrollProvider>();
      if (provider.status == AppStatus.success && provider.hasMore) {
        provider.loadMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
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
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
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
    final provider = context.watch<EmployeePayrollProvider>();

    return RefreshIndicator(
      onRefresh: provider.refresh,
      child: _buildBody(provider),
    );
  }

  Widget _buildBody(EmployeePayrollProvider provider) {
    switch (provider.status) {
      case AppStatus.initial:
      case AppStatus.loading:
        if (provider.payslips.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildList(provider);
      case AppStatus.failure:
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            AppErrorWidget(
              title: 'payroll.load_failed'.tr(),
              message: provider.errorMessage,
              onRetry: provider.refresh,
            ),
          ],
        );
      case AppStatus.success:
        if (provider.payslips.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 120),
              AppEmptyState(
                title: 'payroll.empty_title'.tr(),
                subtitle: 'payroll.empty_subtitle'.tr(),
              ),
            ],
          );
        }
        return _buildList(provider);
    }
  }

  Widget _buildList(EmployeePayrollProvider provider) {
    final items = provider.payslips;
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index == items.length) {
          if (!provider.hasMore && provider.moreStatus != AppStatus.loading) {
            return const SizedBox.shrink();
          }
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Center(
              child:
                  provider.moreStatus == AppStatus.failure
                      ? Text(
                        'errors.generic'.tr(),
                        style: TextStyle(
                          color: context.theme.colorScheme.error,
                        ),
                      )
                      : const CircularProgressIndicator(strokeWidth: 2),
            ),
          );
        }
        return _PayslipCard(
          payslip: items[index],
          onTap: () => _openPdf(items[index]),
        );
      },
    );
  }
}

class _PayslipCard extends StatelessWidget {
  const _PayslipCard({required this.payslip, required this.onTap});

  final Payslip payslip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;
    final period = DateFormat.yMMMM(
      context.locale.languageCode,
    ).format(payslip.periodStart);

    final pillColor =
        payslip.isPaid
            ? Colors.green.shade600
            : payslip.isLocked
            ? Colors.orange.shade700
            : cs.onSurfaceVariant;

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primaryContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                alignment: Alignment.center,
                child: Icon(
                  Icons.description_outlined,
                  color: cs.onPrimaryContainer,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      period,
                      style: tt.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(height: 4.h),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: pillColor.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        payslip.statusKey.tr(),
                        style: tt.labelSmall?.copyWith(
                          color: pillColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                payslip.netSalary.toStringAsFixed(2),
                style: tt.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
