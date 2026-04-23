import 'package:arraf_shop/src/features/auth/presentation/providers/auth_provider.dart';
import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _mobileController = TextEditingController();

  @override
  void dispose() {
    _mobileController.dispose();
    super.dispose();
  }

  Future<void> _handleForgotPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final error = await context.read<AuthProvider>().forgotPassword(
      mobile: _mobileController.text.trim(),
    );

    if (!mounted) return;

    if (error != null) {
      showToast(context, message: error, status: 'error');
      return;
    }
    showToast(
      context,
      message: 'auth.reset_code_sent'.tr(),
      status: 'success',
    );
    context.go(AppRoutes.login);
  }

  @override
  Widget build(BuildContext context) {
    final isLoading = context.select((AuthProvider p) => p.isSendingResetCode);

    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    return Scaffold(
      appBar: const AppTopBar(title: ''),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: AppSpacing.xl.h),
                Text(
                  'auth.forgot_password_title'.tr(),
                  style: tt.headlineMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: AppSpacing.sm.h),
                Text(
                  'auth.forgot_password_mobile_subtitle'.tr(),
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ),
                SizedBox(height: AppSpacing.xxxl.h),
                Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      AppTextField(
                        controller: _mobileController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.phone,
                        label: 'auth.mobile'.tr(),
                        prefixIcon: const Icon(Icons.phone_outlined),
                        maxLength: 15,
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                        ],
                        validator: (v) {
                          if (AppUtils.isBlank(v)) {
                            return 'auth.mobile_required'.tr();
                          }
                          if (!AppUtils.isValidMobile(v!)) {
                            return 'auth.mobile_invalid'.tr();
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: AppSpacing.lg.h),
                      AppButton(
                        label: 'auth.send_reset_link'.tr(),
                        isLoading: isLoading,
                        onPressed: isLoading ? null : _handleForgotPassword,
                        width: ButtonSize.large,
                        isFullWidth: false,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.xxxl.h),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'auth.back_to_login'.tr(),
                    style: tt.labelLarge?.copyWith(
                      color: cs.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                SizedBox(height: AppSpacing.xl.h),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
