import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../cart_manager.dart';
import '../../../theme_provider.dart';
import '../providers/auth_provider.dart';
import '../constants/auth_strings.dart';
import '../constants/auth_measurements.dart';
import '../constants/auth_constants.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Widget _buildMessageCard(BuildContext context, String message, bool isSuccess) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AuthMeasurements.innerPadding),
      margin: const EdgeInsets.only(bottom: AuthMeasurements.spacingXLarge),
      decoration: BoxDecoration(
        color: isSuccess
            ? Colors.green.withOpacity(AuthMeasurements.opacityLow)
            : Colors.red.withOpacity(AuthMeasurements.opacityLow),
        borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusLarge),
        border: Border.all(
          color: isSuccess
              ? Colors.green.withOpacity(AuthMeasurements.opacityMedium)
              : Colors.red.withOpacity(AuthMeasurements.opacityMedium),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AuthMeasurements.tinyPadding),
            decoration: BoxDecoration(
              color: isSuccess ? Colors.green : Colors.red,
              shape: BoxShape.circle,
            ),
            child: Icon(
              isSuccess ? Icons.check : Icons.error_outline,
              color: Colors.white,
              size: 16,
            ),
          ),
          const SizedBox(width: AuthMeasurements.spacingMedium),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: isSuccess ? Colors.green : Colors.red,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final gradientColors = themeProvider.getCurrentGradientColors();
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: gradientColors,
          ),
        ),
        child: Stack(
          children: [
            Positioned(
              top: MediaQuery.of(context).padding.top + AuthMeasurements.spacingLarge,
              left: AuthMeasurements.spacingLarge,
              child: IconButton(
                onPressed: () {
                  authProvider.clearResetState();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(AuthMeasurements.opacityLow),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusMedium),
                  ),
                ),
              ),
            ),
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: AuthConstants.maxDialogWidth),
                margin: const EdgeInsets.all(AuthMeasurements.screenPadding),
                child: Card(
                  elevation: AuthMeasurements.elevationCard,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusXXLarge),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(AuthMeasurements.cardPadding),
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              width: AuthMeasurements.iconSizeLarge,
                              height: AuthMeasurements.iconSizeLarge,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradientColors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusXLarge),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(AuthMeasurements.opacityLow),
                                    blurRadius: AuthMeasurements.elevationHigh,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.lock_reset_rounded,
                                color: Colors.white,
                                size: AuthMeasurements.iconSizeMedium,
                              ),
                            ),
                            const SizedBox(height: AuthMeasurements.spacingXXXLarge),
                            Text(
                              AuthStrings.resetYourPassword,
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(AuthConstants.textPrimaryDark),
                              ),
                            ),
                            const SizedBox(height: AuthMeasurements.spacingMedium),
                            Text(
                              AuthStrings.resetInstructions,
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(AuthConstants.textSecondaryColor),
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: AuthMeasurements.spacingSmall),
                            Container(
                              padding: const EdgeInsets.all(AuthMeasurements.innerPadding),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(AuthConstants.darkSurfaceColor).withOpacity(0.5)
                                    : const Color(AuthConstants.primaryColor).withOpacity(AuthMeasurements.opacityLow),
                                borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusMedium),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        color: isDark ? Colors.blue[200] : const Color(AuthConstants.primaryColor),
                                        size: AuthMeasurements.iconSizeSmall,
                                      ),
                                      const SizedBox(width: AuthMeasurements.spacingSmall),
                                      Text(
                                        AuthStrings.howItWorks,
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(AuthConstants.textPrimaryDark),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: AuthMeasurements.spacingSmall),
                                  Text(
                                    AuthStrings.resetSteps,
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.white70 : const Color(AuthConstants.textSecondaryColor),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: AuthMeasurements.spacingXXLarge),
                            if (authProvider.resetSuccess != null)
                              _buildMessageCard(context, authProvider.resetSuccess!, true),
                            if (authProvider.resetError != null)
                              _buildMessageCard(context, authProvider.resetError!, false),
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusLarge),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: AuthMeasurements.elevationMedium,
                                    offset: const Offset(0, 5),
                                  ),
                                ],
                              ),
                              child: TextFormField(
                                controller: _emailController,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                decoration: InputDecoration(
                                  labelText: AuthStrings.emailAddress,
                                  labelStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(AuthConstants.textSecondaryColor),
                                  ),
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.only(
                                      right: AuthMeasurements.spacingMedium,
                                      left: AuthMeasurements.innerPadding,
                                    ),
                                    child: const Icon(
                                      Icons.email_rounded,
                                      color: Color(AuthConstants.primaryColor),
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? const Color(AuthConstants.darkSurfaceColor)
                                      : Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusLarge),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusLarge),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusLarge),
                                    borderSide: const BorderSide(
                                      color: Color(AuthConstants.primaryColor),
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AuthMeasurements.spacingXLarge,
                                    vertical: AuthMeasurements.innerPadding,
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return AuthStrings.pleaseEnterEmail;
                                  }
                                  if (!AppUtils.isEmailValid(value)) {
                                    return AuthStrings.pleaseEnterValidEmail;
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: AuthMeasurements.spacingXXLarge),
                            SizedBox(
                              width: double.infinity,
                              height: AuthMeasurements.buttonHeight,
                              child: ElevatedButton(
                                onPressed: authProvider.isSendingResetEmail
                                    ? null
                                    : () async {
                                  if (_formKey.currentState!.validate()) {
                                    await authProvider.sendPasswordResetEmail(
                                      _emailController.text.trim(),
                                    );
                                  }
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(AuthConstants.primaryColor),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusLarge),
                                  ),
                                  elevation: AuthMeasurements.elevationLow,
                                ),
                                child: authProvider.isSendingResetEmail
                                    ? const SizedBox(
                                  width: AuthMeasurements.iconSizeSmall,
                                  height: AuthMeasurements.iconSizeSmall,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      AuthStrings.sendResetLink,
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: AuthMeasurements.spacingSmall),
                                    Icon(Icons.send_rounded, size: AuthMeasurements.iconSizeSmall),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: AuthMeasurements.spacingXLarge),
                            TextButton(
                              onPressed: () {
                                authProvider.clearResetState();
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                AuthStrings.backToLogin,
                                style: TextStyle(
                                  color: Color(AuthConstants.primaryColor),
                                  fontWeight: FontWeight.w600,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}