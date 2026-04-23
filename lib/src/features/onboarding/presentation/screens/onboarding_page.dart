import 'dart:async';

import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

/// Key under which the onboarding-completed flag is persisted in
/// [StorageService]. Exposed so the router redirect can read the same key.
const String onboardingCompletedStorageKey = 'onboarding_completed';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  late final PageController _pageController;
  int _currentIndex = 0;

  late final List<_Slide> _slides;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _slides = [
      const _Slide(
        icon: HugeIcons.strokeRoundedBarcodeScan,
        titleKey: 'onboarding.onboarding_title_1',
        subtitleKey: 'onboarding.onboarding_subtitle_1',
      ),
      const _Slide(
        icon: HugeIcons.strokeRoundedSmartPhone01,
        titleKey: 'onboarding.onboarding_title_2',
        subtitleKey: 'onboarding.onboarding_subtitle_2',
      ),
      const _Slide(
        icon: HugeIcons.strokeRoundedCheckmarkBadge01,
        titleKey: 'onboarding.onboarding_title_3',
        subtitleKey: 'onboarding.onboarding_subtitle_3',
      ),
    ];
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  bool get _isLast => _currentIndex == _slides.length - 1;

  void _onPrimary() {
    if (_isLast) {
      _finishOnboarding();
      return;
    }
    _pageController.nextPage(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeOutCubic,
    );
  }

  void _onSkip() => _finishOnboarding();

  void _finishOnboarding() {
    // Persist the completion flag so the router can skip onboarding on
    // every subsequent launch. Fire-and-forget — nav must not wait on disk.
    unawaited(
      StorageService.instance.setBool(onboardingCompletedStorageKey, true),
    );
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return Scaffold(
      backgroundColor: cs.surface,
      body: SafeArea(
        child: Column(
          children: [
            // Branding + skip
            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg.w,
                AppSpacing.lg.h,
                AppSpacing.lg.w,
                AppSpacing.sm.h,
              ),
              child: Row(
                children: [
                  Text(
                    'shared.app_name'.tr(),
                    style: tt.titleLarge?.copyWith(
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                      fontSize: 22.sp,
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _onSkip,
                    child: Text(
                      'onboarding.skip'.tr(),
                      style: tt.labelLarge?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _slides.length,
                onPageChanged: (i) => setState(() => _currentIndex = i),
                itemBuilder:
                    (context, index) => _SlideView(slide: _slides[index]),
              ),
            ),

            // Dots
            Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md.h),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < _slides.length; i++)
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 250),
                      curve: Curves.easeOut,
                      margin: EdgeInsets.symmetric(horizontal: 4.w),
                      height: 8.h,
                      width: i == _currentIndex ? 24.w : 8.w,
                      decoration: BoxDecoration(
                        color:
                            i == _currentIndex
                                ? cs.primary
                                : cs.onSurfaceVariant.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                ],
              ),
            ),

            Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.xl.w,
                AppSpacing.md.h,
                AppSpacing.xl.w,
                AppSpacing.xl.h,
              ),
              child: AppButton(
                label:
                    _isLast
                        ? 'shared.get_started'.tr()
                        : 'onboarding.next'.tr(),
                onPressed: _onPrimary,
                variant: ButtonVariant.primary,
                width: ButtonSize.large,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Slide {
  const _Slide({
    required this.icon,
    required this.titleKey,
    required this.subtitleKey,
  });

  final List<List<dynamic>> icon;
  final String titleKey;
  final String subtitleKey;
}

class _SlideView extends StatelessWidget {
  const _SlideView({required this.slide});
  final _Slide slide;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: AppSpacing.xl.w),
      child: Column(
        children: [
          Expanded(child: Center(child: _Illustration(icon: slide.icon))),
          Text(
            slide.titleKey.tr(),
            textAlign: TextAlign.center,
            style: tt.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: cs.onSurface,
              height: 1.2,
              fontSize: 26.sp,
            ),
          ),
          SizedBox(height: AppSpacing.md.h),
          Text(
            slide.subtitleKey.tr(),
            textAlign: TextAlign.center,
            style: tt.bodyMedium?.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.6,
              fontSize: 14.sp,
            ),
          ),
          SizedBox(height: 32.h),
        ],
      ),
    );
  }
}

/// Concentric gold rings behind a single large icon — evokes a hallmark
/// stamp without needing raster assets.
class _Illustration extends StatelessWidget {
  const _Illustration({required this.icon});
  final List<List<dynamic>> icon;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;

    return SizedBox(
      width: 220.w,
      height: 220.w,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Container(
            width: 220.w,
            height: 220.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.06),
            ),
          ),
          Container(
            width: 170.w,
            height: 170.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.12),
            ),
          ),
          Container(
            width: 120.w,
            height: 120.w,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: cs.primary.withValues(alpha: 0.2),
            ),
          ),
          HugeIcon(icon: icon, size: 64.sp, color: cs.primary),
        ],
      ),
    );
  }
}
