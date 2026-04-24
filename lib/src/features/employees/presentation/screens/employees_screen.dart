import 'package:arraf_shop/src/features/employees/domain/entities/employee.dart';
import 'package:arraf_shop/src/features/employees/presentation/providers/employees_list_provider.dart';
import 'package:arraf_shop/src/features/employees/presentation/screens/employee_detail_screen.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

/// Admin-only Employees tab. Lists the shop's employees with debounced
/// search + pagination. Tap a row to drill into the detail screen.
class EmployeesScreen extends StatefulWidget {
  const EmployeesScreen({super.key});

  @override
  State<EmployeesScreen> createState() => _EmployeesScreenState();
}

class _EmployeesScreenState extends State<EmployeesScreen> {
  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<EmployeesListProvider>();
      if (provider.status == AppStatus.initial) {
        provider.load();
      }
    });
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final pos = _scrollController.position;
    if (pos.pixels >= pos.maxScrollExtent - 240) {
      final provider = context.read<EmployeesListProvider>();
      if (provider.status == AppStatus.success && provider.hasMore) {
        provider.loadMore();
      }
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openDetail(Employee e) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => EmployeeDetailScreen(employeeId: e.id, name: e.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Owner-only access is enforced at the shell level (the tab is only
    // shown to owners) and at the API level (a 403 returns a
    // ForbiddenFailure that's surfaced via the standard failure state).
    final provider = context.watch<EmployeesListProvider>();
    final cs = context.theme.colorScheme;

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppTopBar(title: 'employees.title'.tr()),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: _SearchField(
                controller: _searchController,
                onChanged: provider.setSearch,
              ),
            ),
            Expanded(
              child: RefreshIndicator(
                onRefresh: provider.refresh,
                child: _buildBody(provider),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(EmployeesListProvider provider) {
    switch (provider.status) {
      case AppStatus.initial:
      case AppStatus.loading:
        if (provider.employees.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        return _buildList(provider);
      case AppStatus.failure:
        return ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            const SizedBox(height: 120),
            AppErrorWidget(
              title: 'employees.load_failed'.tr(),
              message: provider.errorMessage,
              onRetry: provider.refresh,
            ),
          ],
        );
      case AppStatus.success:
        if (provider.employees.isEmpty) {
          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 120),
              AppEmptyState(
                title: 'employees.empty_title'.tr(),
                subtitle: 'employees.empty_subtitle'.tr(),
              ),
            ],
          );
        }
        return _buildList(provider);
    }
  }

  Widget _buildList(EmployeesListProvider provider) {
    final items = provider.employees;
    return ListView.separated(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.xs,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      itemCount: items.length + 1,
      separatorBuilder: (_, _) => SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        if (index == items.length) {
          return _PagingFooter(
            status: provider.moreStatus,
            hasMore: provider.hasMore,
          );
        }
        return _EmployeeTile(
          employee: items[index],
          onTap: () => _openDetail(items[index]),
        );
      },
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({required this.controller, required this.onChanged});

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    return TextField(
      controller: controller,
      onChanged: onChanged,
      textInputAction: TextInputAction.search,
      decoration: InputDecoration(
        hintText: 'employees.search_hint'.tr(),
        prefixIcon: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            color: cs.onSurfaceVariant,
            size: 18.sp,
          ),
        ),
        prefixIconConstraints: const BoxConstraints(
          minWidth: 36,
          minHeight: 36,
        ),
        suffixIcon:
            controller.text.isEmpty
                ? null
                : IconButton(
                  tooltip: 'common.clear'.tr(),
                  icon: const Icon(Icons.close),
                  onPressed: () {
                    controller.clear();
                    onChanged('');
                  },
                ),
        filled: true,
        fillColor: cs.surfaceContainerHighest.withValues(alpha: 0.5),
        contentPadding: EdgeInsets.symmetric(vertical: 12.h),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: cs.outlineVariant),
        ),
      ),
    );
  }
}

class _EmployeeTile extends StatelessWidget {
  const _EmployeeTile({required this.employee, required this.onTap});

  final Employee employee;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    final lastSeenLabel =
        employee.lastAttendanceDate != null
            ? DateFormat.yMMMd(
              context.locale.languageCode,
            ).format(employee.lastAttendanceDate!)
            : 'employees.never_seen'.tr();

    final payroll = employee.latestPayroll;
    final payrollLabel =
        payroll != null
            ? DateFormat.yMMM(
              context.locale.languageCode,
            ).format(payroll.periodStart)
            : 'employees.no_payslip'.tr();

    return Material(
      color: cs.surfaceContainerLow,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: EdgeInsets.all(AppSpacing.md),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _Avatar(employee: employee),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            employee.name,
                            style: tt.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (!employee.isActive)
                          _StatusPill(
                            label: 'employees.inactive_badge'.tr(),
                            color: cs.error,
                          ),
                      ],
                    ),
                    SizedBox(height: 2.h),
                    Text(
                      (employee.role?.isNotEmpty ?? false)
                          ? 'roles.${employee.role}'.tr()
                          : (employee.code ?? ''),
                      style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 6.h),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: [
                        _MetaPill(
                          icon: HugeIcons.strokeRoundedFingerPrintCheck,
                          label: lastSeenLabel,
                        ),
                        _MetaPill(
                          icon: HugeIcons.strokeRoundedDollarReceive02,
                          label: payrollLabel,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  const _Avatar({required this.employee});

  final Employee employee;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final size = 48.w;

    if (employee.avatarUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(size / 2),
        child: CachedNetworkImage(
          imageUrl: employee.avatarUrl!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          placeholder: (_, _) => _initialsFallback(cs, size),
          errorWidget: (_, _, _) => _initialsFallback(cs, size),
        ),
      );
    }
    return _initialsFallback(cs, size);
  }

  Widget _initialsFallback(ColorScheme cs, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Text(
        employee.initials,
        style: TextStyle(
          color: cs.onPrimaryContainer,
          fontWeight: FontWeight.w800,
          fontSize: 16.sp,
        ),
      ),
    );
  }
}

class _MetaPill extends StatelessWidget {
  const _MetaPill({required this.icon, required this.label});

  final List<List<dynamic>> icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        HugeIcon(icon: icon, size: 14.sp, color: cs.onSurfaceVariant),
        SizedBox(width: 4.w),
        Text(label, style: tt.labelSmall?.copyWith(color: cs.onSurfaceVariant)),
      ],
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.label, required this.color});

  final String label;
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
        label,
        style: context.theme.textTheme.labelSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _PagingFooter extends StatelessWidget {
  const _PagingFooter({required this.status, required this.hasMore});

  final AppStatus status;
  final bool hasMore;

  @override
  Widget build(BuildContext context) {
    if (!hasMore && status != AppStatus.loading) {
      return const SizedBox.shrink();
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Center(
        child:
            status == AppStatus.failure
                ? Text(
                  'errors.generic'.tr(),
                  style: TextStyle(color: context.theme.colorScheme.error),
                )
                : const CircularProgressIndicator(strokeWidth: 2),
      ),
    );
  }
}
