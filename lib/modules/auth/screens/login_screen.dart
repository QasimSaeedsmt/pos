import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../cart_manager.dart' show AppUtils;
import '../../../features/tenantBase/tenant_base.dart';
import '../../../theme_provider.dart';
import '../../../theme_selector_bottom_sheet.dart';
import '../providers/auth_provider.dart';
import '../constants/auth_strings.dart';
import '../constants/auth_measurements.dart';
import '../constants/auth_constants.dart';
import 'forgot_password_screen.dart';
import '../../../features/main_navigation/main_navigation_base.dart';
import '../../../features/super_admin/super_admin_base.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _slideAnimation;

  bool _obscurePassword = true;
  bool _isHovering = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration:
      const Duration(milliseconds: AuthConstants.animationDuration),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    _slideAnimation = Tween<double>(begin: 30.0, end: 0.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _showThemeSelector(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => const ThemeSelectorBottomSheet(),
    );
  }

  Future<void> _handleLogin(MyAuthProvider authProvider) async {
    if (!_formKey.currentState!.validate()) return;

    await authProvider.login(
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (!mounted) return;

    if (authProvider.error != null) {
      // show snackbar for error
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(authProvider.error!),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    if (authProvider.currentUser != null) {
      if (authProvider.currentUser!.isSuperAdmin) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const SuperAdminDashboard()),
        );
      } else {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavScreen()),
        );
      }
    }
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
            Center(
              child: Container(
                constraints: const BoxConstraints(
                    maxWidth: AuthConstants.maxDialogWidth),
                margin: const EdgeInsets.all(AuthMeasurements.screenPadding),
                child: AnimatedBuilder(
                  animation: _animationController,
                  builder: (context, child) {
                    return Transform.translate(
                      offset: Offset(0, _slideAnimation.value),
                      child: Opacity(
                        opacity: _fadeAnimation.value,
                        child: child,
                      ),
                    );
                  },
                  child: Card(
                    elevation: AuthMeasurements.elevationCard,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(
                          AuthMeasurements.borderRadiusXXLarge),
                    ),
                    child: Padding(
                      padding:
                      const EdgeInsets.all(AuthMeasurements.cardPadding),
                      child: SingleChildScrollView(
                        child: Form(
                          key: _formKey,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Container(
                                    decoration: BoxDecoration(
                                      color: Colors.white.withOpacity(
                                          AuthMeasurements.opacityLow),
                                      borderRadius: BorderRadius.circular(
                                          AuthMeasurements
                                              .borderRadiusMedium),
                                    ),
                                    child: IconButton(
                                      onPressed: () =>
                                          _showThemeSelector(context),
                                      icon: const Icon(
                                        Icons.palette_rounded,
                                        color: Colors.white,
                                      ),
                                      tooltip: 'Change Theme',
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(
                                  height: AuthMeasurements.spacingLarge),
                              Container(
                                width: AuthMeasurements.iconSizeLarge,
                                height: AuthMeasurements.iconSizeLarge,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: gradientColors,
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(
                                      AuthMeasurements.borderRadiusXLarge),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(
                                          AuthMeasurements.opacityLow),
                                      blurRadius:
                                      AuthMeasurements.elevationHigh,
                                      offset: const Offset(0, 10),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.rocket_launch_rounded,
                                  color: Colors.white,
                                  size: AuthMeasurements.iconSizeMedium,
                                ),
                              ),
                              const SizedBox(
                                  height: AuthMeasurements.spacingXXXLarge),
                              Text(
                                AuthStrings.welcomeBack,
                                style: TextStyle(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w800,
                                  color: isDark
                                      ? Colors.white
                                      : const Color(
                                      AuthConstants.textPrimaryDark),
                                ),
                              ),
                              const SizedBox(
                                  height: AuthMeasurements.spacingSmall),
                              Text(
                                AuthStrings.signInToContinue,
                                style: TextStyle(
                                  fontSize: 16,
                                  color: isDark
                                      ? Colors.white70
                                      : const Color(AuthConstants
                                      .textSecondaryColor),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(
                                  height: AuthMeasurements.spacingXXXLarge),

                              /// ERROR MESSAGE BOX
                              if (authProvider.error != null)
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(
                                      AuthMeasurements.innerPadding),
                                  margin: const EdgeInsets.only(
                                      bottom: AuthMeasurements.spacingXLarge),
                                  decoration: BoxDecoration(
                                    color: Colors.red.withOpacity(
                                        AuthMeasurements.opacityLow),
                                    borderRadius: BorderRadius.circular(
                                        AuthMeasurements.borderRadiusLarge),
                                    border: Border.all(
                                      color: Colors.red.withOpacity(
                                          AuthMeasurements.opacityMedium),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.all(
                                            AuthMeasurements.tinyPadding),
                                        decoration: const BoxDecoration(
                                          color: Colors.red,
                                          shape: BoxShape.circle,
                                        ),
                                        child: const Icon(
                                          Icons.error_outline,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                      ),
                                      const SizedBox(
                                          width:
                                          AuthMeasurements.spacingMedium),
                                      Expanded(
                                        child: Text(
                                          authProvider.error!,
                                          style: const TextStyle(
                                            color: Colors.red,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                              /// EMAIL FIELD
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                      AuthMeasurements.borderRadiusLarge),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                      Colors.black.withOpacity(0.05),
                                      blurRadius:
                                      AuthMeasurements.elevationMedium,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: TextFormField(
                                  autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
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
                                          : const Color(AuthConstants
                                          .textSecondaryColor),
                                    ),
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.only(
                                        right: AuthMeasurements.spacingMedium,
                                        left: AuthMeasurements.innerPadding,
                                      ),
                                      child: const Icon(
                                        Icons.email_rounded,
                                        color:
                                        Color(AuthConstants.primaryColor),
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(AuthConstants
                                        .darkSurfaceColor)
                                        : Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                          AuthMeasurements.borderRadiusLarge),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return AuthStrings.pleaseEnterEmail;
                                    }
                                    if (!AppUtils.isEmailValid(value)) {
                                      return AuthStrings
                                          .pleaseEnterValidEmail;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(
                                  height: AuthMeasurements.spacingXLarge),

                              /// PASSWORD FIELD
                              Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(
                                      AuthMeasurements.borderRadiusLarge),
                                  boxShadow: [
                                    BoxShadow(
                                      color:
                                      Colors.black.withOpacity(0.05),
                                      blurRadius:
                                      AuthMeasurements.elevationMedium,
                                      offset: const Offset(0, 5),
                                    ),
                                  ],
                                ),
                                child: TextFormField(
                                  autovalidateMode:
                                  AutovalidateMode.onUserInteraction,
                                  controller: _passwordController,
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                  ),
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    labelText: AuthStrings.password,
                                    labelStyle: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(AuthConstants
                                          .textSecondaryColor),
                                    ),
                                    prefixIcon: Container(
                                      margin: const EdgeInsets.only(
                                        right: AuthMeasurements.spacingMedium,
                                        left: AuthMeasurements.innerPadding,
                                      ),
                                      child: const Icon(
                                        Icons.lock_rounded,
                                        color:
                                        Color(AuthConstants.primaryColor),
                                      ),
                                    ),
                                    suffixIcon: GestureDetector(
                                      onTap: () {
                                        setState(() {
                                          _obscurePassword =
                                          !_obscurePassword;
                                        });
                                      },
                                      child: Container(
                                        margin: const EdgeInsets.only(
                                            right: AuthMeasurements
                                                .innerPadding),
                                        child: Icon(
                                          _obscurePassword
                                              ? Icons.visibility_rounded
                                              : Icons
                                              .visibility_off_rounded,
                                          color: const Color(AuthConstants
                                              .textSecondaryColor),
                                        ),
                                      ),
                                    ),
                                    filled: true,
                                    fillColor: isDark
                                        ? const Color(AuthConstants
                                        .darkSurfaceColor)
                                        : Colors.white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(
                                          AuthMeasurements.borderRadiusLarge),
                                      borderSide: BorderSide.none,
                                    ),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.isEmpty) {
                                      return AuthStrings.pleaseEnterPassword;
                                    }
                                    if (value.length <
                                        AuthConstants.minPasswordLength) {
                                      return AuthStrings.passwordTooShort;
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(
                                  height: AuthMeasurements.spacingMedium),
                              // const KeepMeLoggedInCheckbox(),
                              Align(
                                alignment: Alignment.centerRight,
                                child: TextButton(
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                        const ForgotPasswordScreen(),
                                      ),
                                    );
                                  },
                                  child: const Text(
                                    AuthStrings.forgotPassword,
                                    style: TextStyle(
                                      color:
                                      Color(AuthConstants.primaryColor),
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.underline,
                                    ),
                                  ),
                                ),
                              ),

                              /// SIGN IN BUTTON
                              MouseRegion(
                                onEnter: (_) =>
                                    setState(() => _isHovering = true),
                                onExit: (_) =>
                                    setState(() => _isHovering = false),
                                child: AnimatedContainer(
                                  duration:
                                  const Duration(milliseconds: 300),
                                  width: double.infinity,
                                  height: AuthMeasurements.buttonHeight,
                                  decoration: BoxDecoration(
                                    gradient: const LinearGradient(
                                      colors: [
                                        Color(AuthConstants.primaryColor),
                                        Color(AuthConstants.secondaryColor),
                                      ],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(
                                        AuthMeasurements.borderRadiusLarge),
                                    boxShadow: _isHovering
                                        ? [
                                      BoxShadow(
                                        color: const Color(AuthConstants
                                            .primaryColor)
                                            .withOpacity(
                                            AuthMeasurements
                                                .opacityHigh),
                                        blurRadius: AuthMeasurements
                                            .elevationHigh,
                                        offset: const Offset(0, 10),
                                      ),
                                    ]
                                        : [
                                      BoxShadow(
                                        color: Colors.black
                                            .withOpacity(0.1),
                                        blurRadius: AuthMeasurements
                                            .elevationMedium,
                                        offset: const Offset(0, 5),
                                      ),
                                    ],
                                  ),
                                  child: ElevatedButton(
                                    onPressed: authProvider.isLoading
                                        ? null
                                        : () => _handleLogin(authProvider),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: Colors.transparent,
                                      shadowColor: Colors.transparent,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            AuthMeasurements
                                                .borderRadiusLarge),
                                      ),
                                      elevation: 0,
                                    ),
                                    child: authProvider.isLoading
                                        ? const SizedBox(
                                      width:
                                      AuthMeasurements.iconSizeSmall,
                                      height:
                                      AuthMeasurements.iconSizeSmall,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                        : const Row(
                                      mainAxisAlignment:
                                      MainAxisAlignment.center,
                                      children: [
                                        Text(
                                          AuthStrings.signIn,
                                          style: TextStyle(
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            color: Colors.white,
                                          ),
                                        ),
                                        SizedBox(
                                            width: AuthMeasurements
                                                .spacingSmall),
                                        Icon(
                                          Icons.arrow_forward_rounded,
                                          color: Colors.white,
                                          size: AuthMeasurements
                                              .iconSizeSmall,
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(
                                  height: AuthMeasurements.spacingXXLarge),

                              /// SIGN UP LINK
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    AuthStrings.newToPlatform,
                                    style: TextStyle(
                                      color: isDark
                                          ? Colors.white70
                                          : const Color(AuthConstants
                                          .textSecondaryColor),
                                    ),
                                  ),
                                  const SizedBox(
                                      width: AuthMeasurements.spacingSmall),
                                  GestureDetector(
                                    onTap: () => Navigator.push(
                                      context,
                                      PageRouteBuilder(
                                        pageBuilder: (_, __, ___) =>
                                        const ClientSignupScreen(),
                                        transitionsBuilder:
                                            (_, animation, __, child) {
                                          return FadeTransition(
                                            opacity: animation,
                                            child: child,
                                          );
                                        },
                                      ),
                                    ),
                                    child: const Text(
                                      AuthStrings.createAccount,
                                      style: TextStyle(
                                        color:
                                        Color(AuthConstants.primaryColor),
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
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
