import 'package:arraf_shop/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

/// Shell that hosts the bottom navigation bar for the authenticated area
/// and renders the current branch inside its body. Per-screen scaffolds
/// (each with their own [AppTopBar]) live inside the branches.
///
/// The set of tabs depends on the active session role:
///  * Owner → Home · Employees · Invoices · Settings
///  * Employee → Home · Attendance · Audits · Settings
///
/// Audits stays installed for both roles — only its slot in the owner's
/// nav is replaced by Invoices. Owners can still reach Audits via direct
/// navigation when needed.
class AppShellScaffold extends StatelessWidget {
  const AppShellScaffold({super.key, required this.navShell});

  final StatefulNavigationShell navShell;

  // Keep these in sync with the branch order declared in app_router.dart.
  static const int _homeBranch = 0;
  static const int _attendanceBranch = 1;
  static const int _employeesBranch = 2;
  static const int _auditsBranch = 3;
  static const int _settingsBranch = 4;
  static const int _invoicesBranch = 5;

  @override
  Widget build(BuildContext context) {
    // Owner gating is opt-in rather than opt-out.
    final isOwner = context.select<AuthProvider, bool>(
      (p) => p.isOwner,
    );

    final tabs = _tabsFor(isOwner: isOwner);
    final activeTabIndex = _activeTabIndex(navShell.currentIndex, tabs);

    return Scaffold(
      body: navShell,
      bottomNavigationBar: _ShellBottomBar(
        tabs: tabs,
        currentIndex: activeTabIndex,
        onTap: (index) => _onTap(index, tabs),
      ),
    );
  }

  void _onTap(int index, List<_ShellTab> tabs) {
    final branch = tabs[index].branchIndex;
    // `initialLocation: true` resets the branch's inner stack when re-tapping
    // the same tab — matches the expected mobile pattern (pop to root).
    navShell.goBranch(branch, initialLocation: branch == navShell.currentIndex);
  }

  int _activeTabIndex(int branchIndex, List<_ShellTab> tabs) {
    for (var i = 0; i < tabs.length; i++) {
      if (tabs[i].branchIndex == branchIndex) return i;
    }
    // Active branch isn't in the visible tab list (e.g. employee viewing a
    // tab that only owners see). Fall back to Home.
    return 0;
  }

  List<_ShellTab> _tabsFor({required bool isOwner}) {
    return [
      const _ShellTab(
        branchIndex: _homeBranch,
        labelKey: 'nav.home',
        icon: HugeIcons.strokeRoundedHome05,
        activeIcon: HugeIcons.strokeRoundedHome05,
      ),
      if (isOwner)
        const _ShellTab(
          branchIndex: _employeesBranch,
          labelKey: 'nav.employees',
          icon: HugeIcons.strokeRoundedUserGroup,
          activeIcon: HugeIcons.strokeRoundedUserGroup,
        )
      else
        const _ShellTab(
          branchIndex: _attendanceBranch,
          labelKey: 'nav.attendance',
          icon: HugeIcons.strokeRoundedFingerPrintCheck,
          activeIcon: HugeIcons.strokeRoundedFingerPrintCheck,
        ),
      if (isOwner)
        const _ShellTab(
          branchIndex: _invoicesBranch,
          labelKey: 'nav.invoices',
          icon: HugeIcons.strokeRoundedInvoice03,
          activeIcon: HugeIcons.strokeRoundedInvoice03,
        )
      else
        const _ShellTab(
          branchIndex: _auditsBranch,
          labelKey: 'nav.audits',
          icon: HugeIcons.strokeRoundedClipboard,
          activeIcon: HugeIcons.strokeRoundedClipboard,
        ),
      const _ShellTab(
        branchIndex: _settingsBranch,
        labelKey: 'nav.settings',
        icon: HugeIcons.strokeRoundedSettings02,
        activeIcon: HugeIcons.strokeRoundedSettings02,
      ),
    ];
  }
}

class _ShellTab {
  const _ShellTab({
    required this.branchIndex,
    required this.labelKey,
    required this.icon,
    required this.activeIcon,
  });

  final int branchIndex;
  final String labelKey;
  final List<List<dynamic>> icon;
  final List<List<dynamic>> activeIcon;
}

class _ShellBottomBar extends StatelessWidget {
  const _ShellBottomBar({
    required this.tabs,
    required this.currentIndex,
    required this.onTap,
  });

  final List<_ShellTab> tabs;
  final int currentIndex;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;

    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: cs.surface,
          border: Border(top: BorderSide(color: cs.outlineVariant, width: 0.5)),
        ),
        padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.xs,
          vertical: AppSpacing.xs,
        ),
        child: Row(
          children: [
            for (var i = 0; i < tabs.length; i++)
              Expanded(
                child: _BottomBarItem(
                  tab: tabs[i],
                  isActive: i == currentIndex,
                  onTap: () => onTap(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _BottomBarItem extends StatelessWidget {
  const _BottomBarItem({
    required this.tab,
    required this.isActive,
    required this.onTap,
  });

  final _ShellTab tab;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    final fg = isActive ? cs.primary : cs.onSurfaceVariant;
    final bg =
        isActive ? cs.primary.withValues(alpha: 0.12) : Colors.transparent;

    return Semantics(
      label: tab.labelKey.tr(),
      selected: isActive,
      button: true,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(14.r),
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            padding: EdgeInsets.symmetric(
              vertical: AppSpacing.sm,
              horizontal: AppSpacing.xs,
            ),
            decoration: BoxDecoration(
              color: bg,
              borderRadius: BorderRadius.circular(14.r),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                HugeIcon(
                  icon: isActive ? tab.activeIcon : tab.icon,
                  color: fg,
                  size: 22.sp,
                ),
                SizedBox(height: 4.h),
                Text(
                  tab.labelKey.tr(),
                  style: tt.labelSmall?.copyWith(
                    color: fg,
                    fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    fontSize: 11.sp,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
