import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

import '../providers/working_week_provider.dart';

/// Owner-only "Working Week" card that lets the shop admin pick which
/// ISO weekdays count as weekly holidays. Renders Sunday-first chips
/// because that's the standard Egyptian week display.
class WorkingWeekSection extends StatefulWidget {
  const WorkingWeekSection({super.key});

  @override
  State<WorkingWeekSection> createState() => _WorkingWeekSectionState();
}

class _WorkingWeekSectionState extends State<WorkingWeekSection> {
  // Display order: Sun, Mon, Tue, Wed, Thu, Fri, Sat. The ints are the
  // ISO weekday values used on the wire (1=Mon … 7=Sun) so we can pass
  // them straight to provider.toggle without conversion.
  static const _displayOrder = <(int, String)>[
    (7, 'sun'),
    (1, 'mon'),
    (2, 'tue'),
    (3, 'wed'),
    (4, 'thu'),
    (5, 'fri'),
    (6, 'sat'),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final provider = context.read<WorkingWeekProvider>();
      if (provider.loadStatus == AppStatus.initial) provider.load();
    });
  }

  Future<void> _save() async {
    final provider = context.read<WorkingWeekProvider>();
    final error = await provider.save();
    if (!mounted) return;
    if (error == null) {
      showToast(
        context,
        message: 'settings.working_week.saved'.tr(),
        status: 'success',
      );
    } else {
      showToast(context, message: error, status: 'error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;
    final provider = context.watch<WorkingWeekProvider>();
    final loading = provider.loadStatus == AppStatus.loading;
    final saving = provider.saveStatus == AppStatus.loading;

    return Container(
      decoration: BoxDecoration(
        color: cs.surfaceContainerLow,
        borderRadius: BorderRadius.circular(18.r),
        border: Border.all(color: cs.outlineVariant),
      ),
      padding: EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 36.w,
                height: 36.w,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10.r),
                ),
                alignment: Alignment.center,
                child: HugeIcon(
                  icon: HugeIcons.strokeRoundedCalendar03,
                  color: cs.primary,
                  size: 20.sp,
                ),
              ),
              SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'settings.working_week.title'.tr(),
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.sm),
          Text(
            'settings.working_week.hint'.tr(),
            style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
          ),
          SizedBox(height: AppSpacing.md),
          if (loading && provider.settings == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final entry in _displayOrder)
                  _DayChip(
                    label:
                        'settings.working_week.weekday.${entry.$2}'.tr(),
                    isSelected:
                        provider.draftWeeklyHolidays.contains(entry.$1),
                    onTap: saving ? null : () => provider.toggle(entry.$1),
                  ),
              ],
            ),
          SizedBox(height: AppSpacing.md),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: AppButton(
              label: 'settings.working_week.save'.tr(),
              onPressed: provider.isDirty && !saving ? _save : null,
              isLoading: saving,
            ),
          ),
        ],
      ),
    );
  }
}

class _DayChip extends StatelessWidget {
  const _DayChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
  });

  final String label;
  final bool isSelected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    final bg = isSelected
        ? cs.surfaceContainerHighest
        : cs.surface;
    final border = isSelected ? cs.onSurfaceVariant : cs.outlineVariant;
    final fg = isSelected ? cs.onSurfaceVariant : cs.onSurface;

    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(999),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          padding:
              EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 10.h),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: tt.labelMedium?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ),
    );
  }
}
