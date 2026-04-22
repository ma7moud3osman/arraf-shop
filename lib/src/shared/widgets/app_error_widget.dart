import '../../imports/imports.dart';

/// Displays an error state with an icon, title, optional body, and retry button.
///
/// Usage:
/// ```dart
/// AppErrorWidget(
///   title: 'Something went wrong',
///   message: error.toString(),
///   onRetry: () => ref.invalidate(myProvider),
/// )
/// ```
class AppErrorWidget extends StatelessWidget {
  const AppErrorWidget({
    super.key,
    this.title = 'Something went wrong',
    this.message,
    this.onRetry,
    this.icon = HugeIcons.strokeRoundedAlertCircle,
  });

  final String title;
  final String? message;
  final VoidCallback? onRetry;
  final List<List<dynamic>> icon;

  @override
  Widget build(BuildContext context) {
    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            HugeIcon(icon: icon, size: 36, color: cs.error),
            SizedBox(height: 8.h),
            Text(
              title,
              style: tt.titleMedium?.copyWith(
                color: cs.onSurface,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              SizedBox(height: 8.h),
              Text(
                message!,
                style: tt.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
            if (onRetry != null) ...[
              SizedBox(height: 12.h),
              AppButton(
                label: 'Try Again',
                onPressed: onRetry,
                height: ButtonSize.small,
                variant: ButtonVariant.outline,
              ),
            ],
          ],
        ),
      ),
    );
  }
}
