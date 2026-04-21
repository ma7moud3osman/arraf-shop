import 'package:arraf_shop/src/imports/core_imports.dart';
import 'package:arraf_shop/src/imports/packages_imports.dart';


import 'package:arraf_shop/src/features/auth/presentation/providers/auth_provider.dart';

class SignupScreen extends StatelessWidget {
  const SignupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final formKey = GlobalKey<FormState>();
    final nameController = TextEditingController();
    final emailController = TextEditingController();
    final passwordController = TextEditingController();
    final confirmPasswordController = TextEditingController();
    const obscurePassword = true;
    const obscureConfirmPassword = true;

    final isLoading = context.select((AuthProvider p) => p.isLoading);

    final cs = context.theme.colorScheme;
    final tt = context.theme.textTheme;

    Future<void> handleSignup() async {
      if (!(formKey.currentState?.validate() ?? false)) {
        return;
      }

      context.read<AuthProvider>().signUp(
        context: context, 
        name: nameController.text,
        email: emailController.text, 
        password: passwordController.text,
      );
    }

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(horizontal: AppSpacing.lg.w),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(height: AppSpacing.xl.h),
                Text(
                  'auth.create_account'.tr(),
                  style: tt.headlineMedium?.copyWith(fontWeight: FontWeight.bold),
                ).animate().fadeIn().slideY(begin: 0.2),
                SizedBox(height: AppSpacing.sm.h),
                Text(
                  'auth.create_account_subtitle'.tr(),
                  textAlign: TextAlign.center,
                  style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                ).animate().fadeIn().slideY(begin: 0.2),
                SizedBox(height: AppSpacing.xxxl.h),
                // Form Card
                Form(
                  key: formKey,
                  child: Column(
                    children: [
                      AppTextField(
                        controller: nameController,
                        enabled: !isLoading,
                        label: 'auth.name'.tr(),
                        prefixIcon: const Icon(Icons.person_outline),
                        validator: (v) => AppUtils.isBlank(v) ? 'auth.name_required'.tr() : null,
                      ),
                      SizedBox(height: AppSpacing.md.h),
                      AppTextField(
                        controller: emailController,
                        enabled: !isLoading,
                        keyboardType: TextInputType.emailAddress,
                        label: 'auth.email'.tr(),
                        prefixIcon: const Icon(Icons.email_outlined),
                        validator: (v) {
                          if (AppUtils.isBlank(v)) {
                            return 'auth.email_required'.tr();
                          }
                          if (!AppUtils.isValidEmail(v!)) {
                            return 'auth.email_invalid'.tr();
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: AppSpacing.md.h),
                      AppTextField(
                        controller: passwordController,
                        enabled: !isLoading,
                        label: 'auth.password'.tr(),
                        obscureText: obscurePassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.visibility),
                          onPressed: () => null,
                        ),
                         validator: (v) {
                          if (AppUtils.isBlank(v)) {
                            return 'auth.password_required'.tr();
                          }
                          if (v!.length < 6) {
                            return 'auth.password_too_short'.tr();
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: AppSpacing.md.h),
                      AppTextField(
                        controller: confirmPasswordController,
                        enabled: !isLoading,
                        label: 'auth.confirm_password'.tr(),
                        obscureText: obscureConfirmPassword,
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(Icons.visibility),
                          onPressed: () => null,
                        ),
                        validator: (v) {
                          if (AppUtils.isBlank(v)) {
                            return 'auth.confirm_password_required'.tr();
                          }
                          if (v != passwordController.text) {
                            return 'auth.passwords_do_not_match'.tr();
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: AppSpacing.lg.h),
                      AppButton(
                        label: 'Create Account',
                        isLoading: isLoading,
                        onPressed: isLoading ? null : handleSignup,
                        width: ButtonSize.large,
                        isFullWidth: false,
                      ),
                    ],
                  ),
                ),
                SizedBox(height: AppSpacing.xxxl.h),
                Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      spacing: 20.w,
                      children: [
                        SizedBox(
                          width: 50.w,
                          height: 50.w,
                          child: TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFFEA4335).withValues(alpha: 0.8),
                              padding: EdgeInsets.symmetric(horizontal: 10.w),
                              shape: const RoundedRectangleBorder(
                                borderRadius: AppBorders.button,
                              ),
                            ),
                            child: SvgPicture.asset(AppAssets.googleIcon),
                          ),
                        ),
                        SizedBox(
                          width: 50.w,
                          height: 50.w,
                          child: TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF4285F4),
                              padding: EdgeInsets.symmetric(horizontal: 10.w),
                              shape: const RoundedRectangleBorder(
                                borderRadius: AppBorders.button,
                              ),
                            ),
                            child: SvgPicture.asset(AppAssets.facebookIcon),
                          ),
                        ),
                        SizedBox(
                          width: 50.w,
                          height: 50.w,
                          child: TextButton(
                            onPressed: () {},
                            style: TextButton.styleFrom(
                              backgroundColor: const Color(0xFF000000),
                              padding: EdgeInsets.symmetric(horizontal: 10.w),
                              shape: const RoundedRectangleBorder(
                                borderRadius: AppBorders.button,
                              ),
                            ),
                            child: SvgPicture.asset(AppAssets.appleIcon),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: AppSpacing.xl.h),
                  ],
                ),
                InkWell(
                  onTap: () => Navigator.pop(context),
                  child: RichText(
                    text: TextSpan(
                      text: 'auth.already_have_account'.tr(),
                      style: tt.bodyMedium?.copyWith(color: cs.onSurfaceVariant),
                      children: [
                        TextSpan(
                          text: 'auth.sign_up'.tr(),
                          style: TextStyle(
                            color: cs.primary,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
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
