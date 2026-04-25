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
      padding: EdgeInsets.all(AppSpacing.sm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedCalendar03,
                color: cs.primary,
                size: 18.sp,
              ),
              SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'settings.working_week.title'.tr(),
                  style: tt.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: cs.onSurface,
                  ),
                ),
              ),
              SizedBox(
                height: 28.h,
                child: AppButton(
                  label: 'settings.working_week.save'.tr(),
                  onPressed: provider.isDirty && !saving ? _save : null,
                  isLoading: saving,
                  height: ButtonSize.small,
                ),
              ),
            ],
          ),
          SizedBox(height: AppSpacing.xs),
          Text(
            'settings.working_week.hint'.tr(),
            style: tt.bodySmall?.copyWith(
              color: cs.onSurfaceVariant,
              fontSize: 11.sp,
            ),
          ),
          SizedBox(height: AppSpacing.sm),
          if (loading && provider.settings == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Center(child: CircularProgressIndicator()),
            )
          else
            Row(
              children: [
                for (var i = 0; i < _displayOrder.length; i++) ...[
                  if (i > 0) SizedBox(width: 4.w),
                  Expanded(
                    child: _DayChip(
                      label:
                          'settings.working_week.weekday.${_displayOrder[i].$2}'
                              .tr(),
                      isSelected: provider.draftWeeklyHolidays.contains(
                        _displayOrder[i].$1,
                      ),
                      onTap: saving
                          ? null
                          : () => provider.toggle(_displayOrder[i].$1),
                    ),
                  ),
                ],
              ],
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
          padding: EdgeInsets.symmetric(vertical: 6.h),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: border),
          ),
          child: Text(
            label,
            style: tt.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w700,
              fontSize: 10.sp,
            ),
          ),
        ),
      ),
    );
  }
}
