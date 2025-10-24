import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:local_auth/local_auth.dart';
import '../../app.dart';
import '../../cart_manager.dart' hide AppUtils;
import '../../checkou_screen.dart' hide ActivityType, Tenant, AppUser, UserRole;
import '../../main.dart';
import '../../theme_provider.dart';
import '../../theme_selector_bottom_sheet.dart';
import '../../theme_utils.dart';

enum ActivityType {
  // Keep all existing types
  user_login,
  user_logout,
  user_created,
  user_updated,
  user_deactivated,
  sale_created,
  sale_updated,
  sale_deleted,
  product_created,
  product_updated,
  product_deleted,
  stock_updated,
  tenant_created,
  tenant_updated,
  subscription_updated,
  ticket_created,
  ticket_updated,
  payment_processed,
  report_generated,

  // Add new types for comprehensive tracking
  user_password_changed,
  user_profile_updated,
  product_stock_updated,
  product_category_created,
  product_category_updated,
  sale_refunded,
  sale_cancelled,
  inventory_checked,
  inventory_adjusted,
  low_stock_alert,
  customer_created,
  customer_updated,
  customer_deleted,
  report_exported,
  settings_updated,
  branding_updated,
  ticket_closed,
  ticket_replied,
  payment_failed,
  payment_refunded,
}

class Tenant {
  final String id;
  final String businessName;
  final String subscriptionPlan;
  final DateTime subscriptionExpiry;
  final bool isActive;
  final Map<String, dynamic> branding;

  Tenant({
    required this.id,
    required this.businessName,
    required this.subscriptionPlan,
    required this.subscriptionExpiry,
    required this.isActive,
    required this.branding,
  });

  factory Tenant.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Calculate expiry date with fallback
    final subscriptionExpiry = data['subscriptionExpiry'] != null
        ? (data['subscriptionExpiry'] as Timestamp).toDate()
        : DateTime.now().add(Duration(days: 30)); // Default 30 days

    return Tenant(
      id: doc.id,
      businessName: data['businessName']?.toString() ?? 'Unknown Business',
      subscriptionPlan: data['subscriptionPlan']?.toString() ?? 'monthly',
      subscriptionExpiry: subscriptionExpiry,
      isActive: data['isActive'] ?? false,
      branding: data['branding'] is Map
          ? Map<String, dynamic>.from(data['branding'] as Map)
          : {},
    );
  }

  bool get isSubscriptionActive {
    return isActive && subscriptionExpiry.isAfter(DateTime.now());
  }
}

class AppUser {
  final String uid;
  final String email;
  final String displayName;
  final String? phoneNumber;
  final UserRole role;
  final String tenantId;
  final bool isActive;
  final DateTime createdAt;
  final DateTime? lastLogin;
  final String createdBy;
  final Map<String, dynamic> profile;
  final List<String> permissions;

  AppUser({
    required this.uid,
    required this.email,
    required this.displayName,
    this.phoneNumber,
    required this.role,
    required this.tenantId,
    required this.isActive,
    required this.createdAt,
    this.lastLogin,
    required this.createdBy,
    this.profile = const {},
    this.permissions = const [],
  });

  factory AppUser.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};

    // Extract email with fallback
    final email = data['email']?.toString() ?? 'unknown@email.com';

    // Extract display name with fallback
    final displayName =
        data['displayName']?.toString() ?? email.split('@').first ?? 'User';

    // Parse role with fallback
    final roleString = data['role']?.toString() ?? 'cashier';
    final role = _parseUserRole(roleString);

    // Extract tenant ID with fallback
    final tenantId = data['tenantId']?.toString() ?? 'unknown_tenant';

    // Parse dates with fallbacks
    final createdAt = data['createdAt'] != null
        ? (data['createdAt'] as Timestamp).toDate()
        : DateTime.now();

    final lastLogin = data['lastLogin'] != null
        ? (data['lastLogin'] as Timestamp).toDate()
        : null;

    return AppUser(
      uid: doc.id,
      email: email,
      displayName: displayName,
      phoneNumber: data['phoneNumber']?.toString(),
      role: role,
      tenantId: tenantId,
      isActive: data['isActive'] ?? false,
      createdAt: createdAt,
      lastLogin: lastLogin,
      createdBy: data['createdBy']?.toString() ?? 'system',
      profile: data['profile'] is Map
          ? Map<String, dynamic>.from(data['profile'] as Map)
          : {},
      permissions: data['permissions'] is List
          ? List<String>.from(data['permissions'] as List)
          : [],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'phoneNumber': phoneNumber,
      'role': role.toString().split('.').last,
      'tenantId': tenantId,
      'isActive': isActive,
      'createdAt': Timestamp.fromDate(createdAt),
      'lastLogin': lastLogin != null ? Timestamp.fromDate(lastLogin!) : null,
      'createdBy': createdBy,
      'profile': profile,
      'permissions': permissions,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static UserRole _parseUserRole(String roleString) {
    switch (roleString) {
      case 'superAdmin':
        return UserRole.superAdmin;
      case 'clientAdmin':
        return UserRole.clientAdmin;
      case 'cashier':
        return UserRole.cashier;
      case 'salesInventoryManager':
        return UserRole.salesInventoryManager;
      default:
        return UserRole.cashier; // Default fallback
    }
  }

  bool get canManageProducts =>
      role == UserRole.clientAdmin || role == UserRole.salesInventoryManager;
  bool get canProcessSales =>
      role == UserRole.clientAdmin ||
      role == UserRole.cashier ||
      role == UserRole.salesInventoryManager;
  bool get canManageUsers => role == UserRole.clientAdmin;
  bool get isSuperAdmin => role == UserRole.superAdmin;

  String get formattedName =>
      displayName.isNotEmpty ? displayName : email.split('@').first;
}

enum UserRole { superAdmin, clientAdmin, cashier, salesInventoryManager }

class AuthService {
  static final _firestore = FirebaseFirestore.instance;
  static Future<bool> checkSuperAdminExists() async {
    try {
      final snapshot = await _firestore
          .collection('super_admins')
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
      return false;
    }
  }

  static Future<void> sendPasswordResetEmail(String email) async {
    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email.trim());
    } on FirebaseAuthException catch (e) {
      throw _handlePasswordResetError(e);
    } catch (e) {
      throw 'Failed to send reset email. Please try again.';
    }
  }

  static String _handlePasswordResetError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email address.';
      case 'invalid-email':
        return 'Invalid email address format.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        return 'Network error. Please check your connection.';
      default:
        return 'Failed to send reset email: ${e.message}';
    }
  }

  static Future<void> confirmPasswordReset({
    required String code,
    required String newPassword,
  }) async {
    try {
      await FirebaseAuth.instance.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );
    } on FirebaseAuthException catch (e) {
      throw _handlePasswordResetError(e);
    }
  }

  static Future<void> verifyPasswordResetCode(String code) async {
    try {
      await FirebaseAuth.instance.verifyPasswordResetCode(code);
    } on FirebaseAuthException catch (e) {
      throw 'Invalid or expired reset code. Please request a new one.';
    }
  }
  static Future<void> logUserActivity({
    required String tenantId,
    required String userId,
    required String userEmail,
    required String userDisplayName,
    required ActivityType action,
    required String description,
    Map<String, dynamic> metadata = const {},
    String ipAddress = '',
    String userAgent = '',
  }) async {
    try {
      await _firestore
          .collection('tenants')
          .doc(tenantId)
          .collection('user_activities')
          .add({
            'tenantId': tenantId,
            'userId': userId,
            'userEmail': userEmail,
            'userDisplayName': userDisplayName,
            'action': action.toString().split('.').last,
            'description': description,
            'metadata': metadata,
            'timestamp': FieldValue.serverTimestamp(),
            'ipAddress': ipAddress,
            'userAgent': userAgent,
          });
    } catch (e) {
      print('Failed to log activity: $e');
      // Don't throw error for failed activity logging
    }
  }




  static Future<void> _cacheOfflineData(
    String type,
    Map<String, dynamic> data,
  ) async {
    final offlineBox = Hive.box('offline_data');
    final pendingSync =
        offlineBox.get('pending_sync', defaultValue: []) as List;
    pendingSync.add({'type': type, 'data': data, 'timestamp': DateTime.now()});
    await offlineBox.put('pending_sync', pendingSync);
  }
}

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
  Widget _buildKeepMeLoggedInCheckbox(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return CheckboxListTile(
      title: Text(
        'Keep me logged in',
        style: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF4A5568),
          fontWeight: FontWeight.w500,
        ),
      ),
      value: authProvider.keepMeLoggedIn,
      onChanged: (value) {
        if (value != null) {
          authProvider.setKeepMeLoggedIn(value);
        }
      },
      activeColor: const Color(0xFF667EEA),
      checkColor: Colors.white,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tileColor: isDark
          ? const Color(0xFF2D3748).withOpacity(0.4)
          : Colors.grey[100],
    );
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
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

  Widget _buildSocialButton({
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 50,
        height: 50,
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark
              ? const Color(0xFF2D3748)
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Icon(icon, color: color, size: 24),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    // Use ThemeUtils for consistent theming
    return Scaffold(
      body: Container(
        decoration: ThemeUtils.gradientBackground(context), // Using gradient background
        child: Stack(
          children: [
            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                margin: const EdgeInsets.all(20),
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
                    elevation: ThemeUtils.cardElevation(context),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                    ),
                    child: Container(
                      decoration: ThemeUtils.cardDecoration(context), // Card gradient
                      child: Padding(
                        padding: const EdgeInsets.all(40),
                        child: SingleChildScrollView(
                          child: Form(
                            key: _formKey,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Theme selector button
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    IconButton(
                                      onPressed: () => _showThemeSelector(context),
                                      icon: ShaderMask(
                                        shaderCallback: (bounds) => LinearGradient(
                                          colors: ThemeUtils.accent(context), // your gradient list
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ).createShader(bounds),
                                        child: const Icon(
                                          Icons.palette_rounded,
                                          color: Colors.white, // keep this white for the mask to work
                                        ),
                                      ),
                                      tooltip: 'Change Theme',
                                    )
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // App logo/icon
                                Container(
                                  width: 80,
                                  height: 80,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: ThemeUtils.accent(context),
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.1),
                                        blurRadius: 20,
                                        offset: const Offset(0, 10),
                                      ),
                                    ],
                                  ),
                                  child: Icon(
                                    Icons.rocket_launch_rounded,
                                    color: ThemeUtils.textOnPrimary(context),
                                    size: 40,
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Title
                                Text(
                                  'Welcome Back',
                                  style: ThemeUtils.headlineLarge(context),
                                ),
                                const SizedBox(height: 8),

                                // Subtitle
                                Text(
                                  'Sign in to continue your journey',
                                  style: ThemeUtils.bodyMedium(context)?.copyWith(
                                    color: ThemeUtils.textSecondary(context),
                                  ),
                                ),
                                const SizedBox(height: 32),

                                // Error message
                                if (authProvider.error != null)
                                  Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(16),
                                    margin: const EdgeInsets.only(bottom: 20),
                                    decoration: BoxDecoration(
                                      color: ThemeUtils.error(context).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                                      border: Border.all(
                                        color: ThemeUtils.error(context).withOpacity(0.3),
                                        width: 1,
                                      ),
                                    ),
                                    child: Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: ThemeUtils.error(context),
                                            shape: BoxShape.circle,
                                          ),
                                          child: Icon(
                                            Icons.error_outline,
                                            color: ThemeUtils.textOnPrimary(context),
                                            size: 16,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: Text(
                                            authProvider.error!,
                                            style: ThemeUtils.bodyMedium(context)?.copyWith(
                                              color: ThemeUtils.error(context),
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ),
                                        GestureDetector(
                                          
                                          child: Icon(
                                            Icons.close,
                                            color: ThemeUtils.error(context),
                                            size: 18,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),

                                // Email field
                                _buildEmailField(context),
                                const SizedBox(height: 20),

                                // Password field
                                _buildPasswordField(context),
                                const SizedBox(height: 14),

                                // Keep me logged in
                                _buildKeepMeLoggedInCheckbox(context),

                                // Forgot password
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) => const ForgotPasswordScreen(),
                                        ),
                                      );
                                    },
                                    child: Text(
                                      'Forgot Password?',
                                      style: ThemeUtils.bodyMedium(context)?.copyWith(
                                        color: ThemeUtils.accentColor(context),
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                      ),
                                    ),
                                  ),
                                ),

                                // Login button
                                _buildLoginButton(context, authProvider),
                                const SizedBox(height: 24),

                                // Sign up link
                                _buildSignUpLink(context),
                                const SizedBox(height: 20),

                                // Divider
                                _buildDivider(context),
                                const SizedBox(height: 20),

                                // Social buttons
                                _buildSocialButtons(context),
                              ],
                            ),
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

  // Extracted email field widget
  Widget _buildEmailField(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        controller: _emailController,
        style: ThemeUtils.bodyLarge(context),
        decoration: InputDecoration(
          labelText: 'Email Address',
          labelStyle: ThemeUtils.bodyMedium(context)?.copyWith(
            color: ThemeUtils.textSecondary(context),
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.only(right: 12, left: 16),
            child: Icon(
              Icons.email_rounded,
              color: ThemeUtils.accentColor(context),
            ),
          ),
          filled: true,
          fillColor: ThemeUtils.surface(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
            borderSide: BorderSide(
              color: ThemeUtils.accentColor(context),
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        keyboardType: TextInputType.emailAddress,
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your email';
          }
          if (!AppUtils.isEmailValid(value)) {
            return 'Please enter a valid email';
          }
          return null;
        },
      ),
    );
  }

  // Extracted password field widget
  Widget _buildPasswordField(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: TextFormField(
        autovalidateMode: AutovalidateMode.onUserInteraction,
        controller: _passwordController,
        style: ThemeUtils.bodyLarge(context),
        obscureText: _obscurePassword,
        decoration: InputDecoration(
          labelText: 'Password',
          labelStyle: ThemeUtils.bodyMedium(context)?.copyWith(
            color: ThemeUtils.textSecondary(context),
          ),
          prefixIcon: Container(
            margin: const EdgeInsets.only(right: 12, left: 16),
            child: Icon(
              Icons.lock_rounded,
              color: ThemeUtils.accentColor(context),
            ),
          ),
          suffixIcon: GestureDetector(
            onTap: () {
              setState(() {
                _obscurePassword = !_obscurePassword;
              });
            },
            child: Container(
              margin: const EdgeInsets.only(right: 16),
              child: Icon(
                _obscurePassword ? Icons.visibility_rounded : Icons.visibility_off_rounded,
                color: ThemeUtils.textSecondary(context),
              ),
            ),
          ),
          filled: true,
          fillColor: ThemeUtils.surface(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
            borderSide: BorderSide.none,
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
            borderSide: BorderSide(
              color: ThemeUtils.accentColor(context),
              width: 2,
            ),
          ),
          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'Please enter your password';
          }
          if (value.length < 6) {
            return 'Password must be at least 6 characters';
          }
          return null;
        },
      ),
    );
  }

  // Extracted login button widget
  Widget _buildLoginButton(BuildContext context, MyAuthProvider authProvider) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovering = true),
      onExit: (_) => setState(() => _isHovering = false),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: double.infinity,
        height: 56,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: ThemeUtils.button(context),
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
          boxShadow: _isHovering
              ? [
            BoxShadow(
              color: ThemeUtils.accentColor(context).withOpacity(0.4),
              blurRadius: 20,
              offset: const Offset(0, 10),
            ),
          ]
              : [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: ElevatedButton(
          onPressed: authProvider.isLoading
              ? null
              : () async {
            if (_formKey.currentState!.validate()) {
              await authProvider.login(
                _emailController.text.trim(),
                _passwordController.text,
              );
            }
          },
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.transparent,
            shadowColor: Colors.transparent,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
            ),
            elevation: 0,
          ),
          child: authProvider.isLoading
              ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          )
              : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Sign In',
                style: ThemeUtils.buttonText(context),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.arrow_forward_rounded,
                color: ThemeUtils.textOnPrimary(context),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Extracted sign up link widget
  Widget _buildSignUpLink(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          'New to our platform?',
          style: ThemeUtils.bodyMedium(context)?.copyWith(
            color: ThemeUtils.textSecondary(context),
          ),
        ),
        const SizedBox(width: 8),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            PageRouteBuilder(
              pageBuilder: (_, __, ___) => const ClientSignupScreen(),
              transitionsBuilder: (_, animation, __, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
            ),
          ),
          child: Text(
            'Create account',
            style: ThemeUtils.bodyMedium(context)?.copyWith(
              color: ThemeUtils.accentColor(context),
              fontWeight: FontWeight.w600,
              decoration: TextDecoration.underline,
            ),
          ),
        ),
      ],
    );
  }

  // Extracted divider widget
  Widget _buildDivider(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Row(
      children: [
        Expanded(
          child: Divider(
            color: ThemeUtils.textSecondary(context).withOpacity(0.3),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'or',
            style: ThemeUtils.bodyMedium(context)?.copyWith(
              color: ThemeUtils.textSecondary(context),
            ),
          ),
        ),
        Expanded(
          child: Divider(
            color: ThemeUtils.textSecondary(context).withOpacity(0.3),
          ),
        ),
      ],
    );
  }

  // Extracted social buttons widget
  Widget _buildSocialButtons(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildSocialButton(
          icon: Icons.g_mobiledata_rounded,
          color: ThemeUtils.error(context),
          onTap: () {},
        ),
        const SizedBox(width: 16),
        _buildSocialButton(
          icon: Icons.facebook_rounded,
          color: Colors.blue,
          onTap: () {},
        ),
        const SizedBox(width: 16),
        _buildSocialButton(
          icon: Icons.apple_rounded,
          color: ThemeUtils.textPrimary(context),
          onTap: () {},
        ),
      ],
    );
  }

  // Social button helper method

  // Keep me logged in checkbox
}

class AccountDisabledScreen extends StatelessWidget {
  const AccountDisabledScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    final themeProvider = Provider.of<ThemeProvider>(context);

    final gradientColors = themeProvider.getCurrentGradientColors();

    // Handle system theme
    final brightness = MediaQuery.of(context).platformBrightness;
    final isDark = themeProvider.useSystemTheme
        ? brightness == Brightness.dark
        : themeProvider.isDarkMode;
    return Scaffold(
      body: Center(
        child: Padding(
          padding: EdgeInsets.all(20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 80, color: Colors.red),
              SizedBox(height: 20),
              Text(
                'Account Disabled',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Text(
                'Your account has been disabled. Please contact your administrator or check your subscription status.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Provider.of<MyAuthProvider>(
                  context,
                  listen: false,
                ).logout(),
                child: Text('Return to Login'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            FlutterLogo(size: 100),
            SizedBox(height: 20),
            Text(
              'Multi-Tenant SaaS',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}

class AuthWrapper extends StatelessWidget {
  const AuthWrapper({super.key});

  static final Future<bool> _superAdminFuture =
      AuthService.checkSuperAdminExists();

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: true);

    return FutureBuilder<bool>(
      future: _superAdminFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        if (snapshot.hasData && snapshot.data == false) {
          return const SuperAdminSetupScreen();
        }

        if (snapshot.hasError) {
          debugPrint('⚠️ Error loading super admin state: ${snapshot.error}');
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, userSnapshot) {
            final user = authProvider.currentUser;

            if (userSnapshot.connectionState == ConnectionState.waiting ||
                authProvider.isLoading) {
              return const SplashScreen();
            }

            if ((userSnapshot.hasData && user != null) ||
                (authProvider.isOfflineMode && user != null)) {
              if (!user.isActive) return const AccountDisabledScreen();

              // Show offline mode indicator if applicable
              if (authProvider.isOfflineMode) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.wifi_off, color: Colors.orange[300]),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Offline Mode - Limited functionality',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.orange[800],
                      duration: const Duration(seconds: 3),
                    ),
                  );
                });
              }

              return FutureBuilder<bool>(
                future: _shouldShowAppLock(authProvider),
                builder: (context, lockSnapshot) {
                  if (lockSnapshot.connectionState == ConnectionState.waiting) {
                    return const SplashScreen();
                  }

                  final shouldShowAppLock = lockSnapshot.data ?? false;

                  if (shouldShowAppLock) {
                    return const AppLockScreen();
                  }

                  return user.isSuperAdmin
                      ? const SuperAdminDashboard()
                      : const MainPOSScreen();
                },
              );
            }

            return const LoginScreen();
          },
        );
      },
    );
  }

  Future<bool> _shouldShowAppLock(MyAuthProvider authProvider) async {
    if (!authProvider.appLockEnabled || authProvider.currentUser == null) {
      return false;
    }

    try {
      final isLockRequired = await authProvider.isAppLockRequired();
      return isLockRequired;
    } catch (e) {
      debugPrint('Error checking app lock: $e');
      return true;
    }
  }

  Future<bool> _checkSuperAdminExists() async {
    try {
      return await FirebaseService.checkSuperAdminExists();
    } catch (e, stackTrace) {
      debugPrint('Error checking super admin: $e\n$stackTrace');
      return false;
    }
  }
}

class MyAuthProvider with ChangeNotifier {
  AppUser? _currentUser;
  Tenant? _currentTenant;
  bool _isLoading = false;
  String? _error;
  bool _keepMeLoggedIn = false;
  bool _fingerprintEnabled = false;
  bool _appLockEnabled = false;
  DateTime? _lastUnlockTime;

  // Offline authentication properties
  bool _isOfflineMode = false;
  String? _offlineUserId;
  DateTime? _offlineLoginTime;
  Map<String, dynamic>? _offlineUserData;
  Map<String, dynamic>? _offlineTenantData;

  // Forgot password state
  bool _isSendingResetEmail = false;
  bool _isResettingPassword = false;
  bool _isVerifyingCode = false;
  String? _resetError;
  String? _resetSuccess;
  String? _resetEmail;

  bool get isSendingResetEmail => _isSendingResetEmail;
  bool get isResettingPassword => _isResettingPassword;
  bool get isVerifyingCode => _isVerifyingCode;
  String? get resetError => _resetError;
  String? get resetSuccess => _resetSuccess;
  String? get resetEmail => _resetEmail;

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      _isSendingResetEmail = true;
      _resetError = null;
      _resetSuccess = null;
      _resetEmail = email;
      notifyListeners();

      if (email.isEmpty || !AppUtils.isEmailValid(email)) {
        throw 'Please enter a valid email address';
      }

      await AuthService.sendPasswordResetEmail(email);

      _resetSuccess = 'Password reset email sent! Check your inbox for the reset link.';

      // Log this activity if user was logged in
      if (_currentUser != null && !_currentUser!.isSuperAdmin) {
        await AuthService.logUserActivity(
          tenantId: _currentUser!.tenantId,
          userId: _currentUser!.uid,
          userEmail: _currentUser!.email,
          userDisplayName: _currentUser!.displayName,
          action: ActivityType.user_password_changed,
          description: 'User requested password reset',
          metadata: {'targetEmail': email},
        );
      }
    } catch (e) {
      _resetError = e.toString();
      debugPrint('Password reset error: $e');
    } finally {
      _isSendingResetEmail = false;
      notifyListeners();
    }
  }

  Future<bool> verifyResetCode(String code) async {
    try {
      _isVerifyingCode = true;
      _resetError = null;
      notifyListeners();

      if (code.isEmpty || code.length < 6) {
        throw 'Please enter a valid reset code';
      }

      await AuthService.verifyPasswordResetCode(code);
      return true;
    } catch (e) {
      _resetError = e.toString();
      return false;
    } finally {
      _isVerifyingCode = false;
      notifyListeners();
    }
  }

  Future<void> resetPasswordWithCode({
    required String code,
    required String newPassword,
  }) async {
    try {
      _isResettingPassword = true;
      _resetError = null;
      _resetSuccess = null;
      notifyListeners();

      if (newPassword.length < 6) {
        throw 'Password must be at least 6 characters long';
      }

      if (code.isEmpty) {
        throw 'Please enter a valid reset code';
      }

      await AuthService.confirmPasswordReset(
        code: code,
        newPassword: newPassword,
      );

      _resetSuccess = 'Password reset successfully! You can now login with your new password.';

      // Clear reset state after successful reset
      Future.delayed(const Duration(seconds: 3), () {
        clearResetState();
      });
    } catch (e) {
      _resetError = e.toString();
      debugPrint('Password reset with code error: $e');
    } finally {
      _isResettingPassword = false;
      notifyListeners();
    }
  }

  void clearResetState() {
    _resetError = null;
    _resetSuccess = null;
    _resetEmail = null;
    _isSendingResetEmail = false;
    _isResettingPassword = false;
    _isVerifyingCode = false;
    notifyListeners();
  }

  final LocalAuthentication _auth = LocalAuthentication();

  AppUser? get currentUser => _currentUser;
  Tenant? get currentTenant => _currentTenant;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get keepMeLoggedIn => _keepMeLoggedIn;
  bool get fingerprintEnabled => _fingerprintEnabled;
  bool get appLockEnabled => _appLockEnabled;
  DateTime? get lastUnlockTime => _lastUnlockTime;
  bool get isOfflineMode => _isOfflineMode;
  String? get offlineUserId => _offlineUserId;
  DateTime? get offlineLoginTime => _offlineLoginTime;

  MyAuthProvider() {
    _initializeAuthState();
  }

  Future<void> _initializeAuthState() async {
    final prefs = await SharedPreferences.getInstance();
    _keepMeLoggedIn = prefs.getBool('keepMeLoggedIn') ?? false;
    _fingerprintEnabled = prefs.getBool('fingerprintEnabled') ?? false;
    _appLockEnabled = prefs.getBool('appLockEnabled') ?? false;

    // Load offline session if exists
    _offlineUserId = prefs.getString('offlineUserId');
    final offlineLoginTimestamp = prefs.getInt('offlineLoginTime');
    if (offlineLoginTimestamp != null) {
      _offlineLoginTime = DateTime.fromMillisecondsSinceEpoch(
        offlineLoginTimestamp,
      );
    }

    // Load offline user data
    final offlineUserDataString = prefs.getString('offlineUserData');
    if (offlineUserDataString != null) {
      try {
        _offlineUserData = Map<String, dynamic>.from(
          json.decode(offlineUserDataString),
        );
      } catch (e) {
        debugPrint('Error parsing offline user data: $e');
      }
    }

    // Load offline tenant data
    final offlineTenantDataString = prefs.getString('offlineTenantData');
    if (offlineTenantDataString != null) {
      try {
        _offlineTenantData = Map<String, dynamic>.from(
          json.decode(offlineTenantDataString),
        );
      } catch (e) {
        debugPrint('Error parsing offline tenant data: $e');
      }
    }

    final lastUnlock = prefs.getString('lastUnlockTime');
    if (lastUnlock != null) {
      _lastUnlockTime = DateTime.parse(lastUnlock);
    }

    notifyListeners();

    // Try online authentication first, fallback to offline
    final firebaseUser = FirebaseAuth.instance.currentUser;
    if (firebaseUser != null && _keepMeLoggedIn) {
      await _loadUserData(firebaseUser.uid);
    } else if (_offlineUserId != null && _isOfflineSessionValid()) {
      _isOfflineMode = true;
      await _loadOfflineUserData();
    }
  }

  bool _isOfflineSessionValid() {
    if (_offlineLoginTime == null) return false;

    final now = DateTime.now();
    final difference = now.difference(_offlineLoginTime!);

    // Allow offline access for up to 24 hours for business continuity
    return difference.inHours <= 24;
  }

  Future<void> _saveOfflineSession(
    String userId,
    Map<String, dynamic> userData,
    Map<String, dynamic> tenantData,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('offlineUserId', userId);
    await prefs.setInt(
      'offlineLoginTime',
      DateTime.now().millisecondsSinceEpoch,
    );
    await prefs.setString('offlineUserData', json.encode(userData));
    await prefs.setString('offlineTenantData', json.encode(tenantData));

    _offlineUserId = userId;
    _offlineLoginTime = DateTime.now();
    _offlineUserData = userData;
    _offlineTenantData = tenantData;
  }

  Future<void> _clearOfflineSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('offlineUserId');
    await prefs.remove('offlineLoginTime');
    await prefs.remove('offlineUserData');
    await prefs.remove('offlineTenantData');

    _offlineUserId = null;
    _offlineLoginTime = null;
    _offlineUserData = null;
    _offlineTenantData = null;
    _isOfflineMode = false;
  }

  Future<void> _loadOfflineUserData() async {
    if (_offlineUserData == null || _offlineTenantData == null) return;

    try {
      _isLoading = true;
      notifyListeners();

      final userData = _offlineUserData!;
      final tenantData = _offlineTenantData!;

      // Create user from offline data
      _currentUser = AppUser(
        uid: userData['uid'] ?? '',
        email: userData['email'] ?? 'unknown@email.com',
        displayName: userData['displayName'] ?? 'Offline User',
        role: UserRole.values.firstWhere(
          (e) => e.toString() == userData['role'],
          orElse: () => UserRole.cashier,
        ),
        tenantId: userData['tenantId'] ?? 'offline',
        isActive: userData['isActive'] ?? true,
        createdAt: userData['createdAt'] != null
            ? DateTime.parse(userData['createdAt'])
            : DateTime.now(),
        createdBy: userData['createdBy'] ?? 'system',
        lastLogin: userData['lastLogin'] != null
            ? DateTime.parse(userData['lastLogin'])
            : DateTime.now(),
      );

      // Create tenant from offline data using your original Tenant class structure
      _currentTenant = Tenant(
        id: tenantData['id'] ?? 'offline',
        businessName: tenantData['businessName'] ?? 'Offline Business',
        subscriptionPlan: tenantData['subscriptionPlan'] ?? 'monthly',
        subscriptionExpiry: tenantData['subscriptionExpiry'] != null
            ? DateTime.parse(tenantData['subscriptionExpiry'])
            : DateTime.now().add(const Duration(days: 30)),
        isActive: tenantData['isActive'] ?? true,
        branding: tenantData['branding'] is Map
            ? Map<String, dynamic>.from(tenantData['branding'])
            : {},
      );

      debugPrint('✅ Offline login successful for user: ${_currentUser?.email}');
      debugPrint('✅ Offline tenant: ${_currentTenant?.businessName}');
    } catch (e) {
      debugPrint('❌ Error loading offline user data: $e');
      await _clearOfflineSession();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> login(
    String email,
    String password, {
    bool fromBiometric = false,
  }) async {
    try {
      _isLoading = true;
      _error = null;
      _isOfflineMode = false;
      notifyListeners();

      if (email.isEmpty || password.isEmpty) {
        throw 'Please enter both email and password';
      }
      if (!AppUtils.isEmailValid(email)) {
        throw 'Please enter a valid email address';
      }

      // Try online login first
      final credential = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email.trim(),
        password: password,
      );

      await _loadUserData(credential.user!.uid);

      // Save session for offline use only if we have both user and tenant data
      if (_currentUser != null && _currentTenant != null) {
        final userData = {
          'uid': _currentUser!.uid,
          'email': _currentUser!.email,
          'displayName': _currentUser!.displayName,
          'role': _currentUser!.role.toString(),
          'tenantId': _currentUser!.tenantId,
          'isActive': _currentUser!.isActive,
          'createdAt': _currentUser!.createdAt.toIso8601String(),
          'createdBy': _currentUser!.createdBy,
          'lastLogin': DateTime.now().toIso8601String(),
        };

        final tenantData = {
          'id': _currentTenant!.id,
          'businessName': _currentTenant!.businessName,
          'subscriptionPlan': _currentTenant!.subscriptionPlan,
          'subscriptionExpiry': _currentTenant!.subscriptionExpiry
              .toIso8601String(),
          'isActive': _currentTenant!.isActive,
          'branding': _currentTenant!.branding,
        };

        await _saveOfflineSession(_currentUser!.uid, userData, tenantData);
      }

      if (_appLockEnabled) {
        await _updateLastUnlockTime();
      }



      if (_currentUser != null && !_currentUser!.isSuperAdmin) {
        await AuthService.logUserActivity(
          tenantId: _currentUser!.tenantId,
          userId: _currentUser!.uid,
          userEmail: _currentUser!.email,
          userDisplayName: _currentUser!.displayName,
          action: ActivityType.user_login,
          description: fromBiometric
              ? 'User logged in using biometrics'
              : 'User logged in successfully',
          metadata: {
            'loginMethod': fromBiometric ? 'biometric' : 'email_password',
          },
        );
      }
    } on FirebaseAuthException catch (e) {
      // Check if it's a network error and we have offline session
      if (_isNetworkError(e) &&
          _offlineUserId != null &&
          _isOfflineSessionValid()) {
        _isOfflineMode = true;
        await _loadOfflineUserData();
        if (_currentUser != null) {
          debugPrint('🔄 Falling back to offline mode due to network issues');
          return;
        }
      }
      _error = _handleAuthError(e);
      debugPrint('Firebase Auth Error: ${e.code} - ${e.message}');
    } catch (e) {
      // Check for general network errors
      if (_isGeneralNetworkError(e) &&
          _offlineUserId != null &&
          _isOfflineSessionValid()) {
        _isOfflineMode = true;
        await _loadOfflineUserData();
        if (_currentUser != null) {
          debugPrint('🔄 Falling back to offline mode due to network issues');
          return;
        }
      }
      _error = 'Login failed: $e';
      debugPrint('Login Error: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  bool _isNetworkError(FirebaseAuthException e) {
    return e.code == 'network-request-failed' ||
        e.code == 'too-many-requests' ||
        e.message?.toLowerCase().contains('network') == true;
  }

  bool _isGeneralNetworkError(dynamic e) {
    return e.toString().toLowerCase().contains('network') ||
        e.toString().toLowerCase().contains('socket') ||
        e.toString().toLowerCase().contains('connection');
  }

  Future<void> logout() async {
    if (_currentUser != null &&
        !_currentUser!.isSuperAdmin &&
        !_isOfflineMode) {
      await AuthService.logUserActivity(
        tenantId: _currentUser!.tenantId,
        userId: _currentUser!.uid,
        userEmail: _currentUser!.email,
        userDisplayName: _currentUser!.displayName,
        action: ActivityType.user_logout,
        description: 'User logged out',
      );
    }

    await FirebaseAuth.instance.signOut();
    await _clearOfflineSession();

    _currentUser = null;
    _currentTenant = null;
    _error = null;
    _isOfflineMode = false;

    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastUnlockTime');
    _lastUnlockTime = null;

    notifyListeners();
  }

  Future<void> _loadUserData(String uid) async {
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      // Check super_admin collection first
      final superAdminDoc = await FirebaseFirestore.instance
          .collection('super_admins')
          .doc(uid)
          .get();

      if (superAdminDoc.exists) {
        final data = superAdminDoc.data() ?? {};
        _currentUser = AppUser(
          uid: uid,
          email:
              FirebaseAuth.instance.currentUser?.email ?? 'unknown@email.com',
          displayName:
              '${data['firstName'] ?? 'Admin'} ${data['lastName'] ?? ''}'
                  .trim(),
          role: UserRole.superAdmin,
          tenantId: 'super_admin',
          isActive: data['isActive'] ?? true,
          createdAt:
              (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          createdBy: data['createdBy'] ?? 'system',
          lastLogin: (data['lastLogin'] as Timestamp?)?.toDate(),
        );

        // For super admin, create a basic tenant
        _currentTenant = Tenant(
          id: 'super_admin',
          businessName: 'Super Admin Portal',
          subscriptionPlan: 'enterprise',
          subscriptionExpiry: DateTime.now().add(const Duration(days: 365)),
          isActive: true,
          branding: {},
        );
        return;
      }

      // Check active tenants
      final tenantsSnap = await FirebaseFirestore.instance
          .collection('tenants')
          .where('isActive', isEqualTo: true)
          .get();

      for (final tenantDoc in tenantsSnap.docs) {
        final userDoc = await tenantDoc.reference
            .collection('users')
            .doc(uid)
            .get();
        if (userDoc.exists) {
          _currentUser = AppUser.fromFirestore(userDoc);
          _currentTenant = Tenant.fromFirestore(tenantDoc);
          return;
        }
      }

      throw Exception('User not found in any active tenant.');
    } catch (e) {
      _error = 'Failed to load user data: $e';
      debugPrint('Error in _loadUserData: $e');

      // If online loading fails but we have offline session, use it
      if (_offlineUserId != null && _isOfflineSessionValid()) {
        _isOfflineMode = true;
        await _loadOfflineUserData();
        if (_currentUser != null) {
          debugPrint('🔄 Using offline data due to loading error');
          return;
        }
      }

      await logout();
      rethrow;
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Existing biometric and app lock methods remain exactly the same
  Future<void> setAppLockEnabled(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _appLockEnabled = value;
    await prefs.setBool('appLockEnabled', value);

    if (!value) {
      await prefs.remove('lastUnlockTime');
      _lastUnlockTime = null;
    } else {
      await _updateLastUnlockTime();
    }

    notifyListeners();
  }

  Future<void> _updateLastUnlockTime() async {
    final prefs = await SharedPreferences.getInstance();
    _lastUnlockTime = DateTime.now();
    await prefs.setString('lastUnlockTime', _lastUnlockTime!.toIso8601String());
    notifyListeners();
  }

  Future<bool> isAppLockRequired() async {
    if (!_appLockEnabled) return false;

    final prefs = await SharedPreferences.getInstance();
    final lastUnlock = prefs.getString('lastUnlockTime');

    if (lastUnlock == null) return true;

    try {
      final lastUnlockTime = DateTime.parse(lastUnlock);
      final now = DateTime.now();
      final difference = now.difference(lastUnlockTime);

      return difference.inSeconds > 10;
    } catch (e) {
      debugPrint('Error parsing last unlock time: $e');
      return true;
    }
  }

  Future<bool> authenticateForAppUnlock() async {
    try {
      final isSupported = await _auth.isDeviceSupported();
      if (!isSupported) {
        debugPrint('Device does not support biometrics.');
        return false;
      }

      final canCheck = await _auth.canCheckBiometrics;
      if (!canCheck) {
        debugPrint('No biometrics enrolled on this device.');
        return false;
      }

      final didAuthenticate = await _auth.authenticate(
        localizedReason: 'Authenticate to unlock the app',
        biometricOnly: false,
        sensitiveTransaction: true,
      );

      if (didAuthenticate) {
        await _updateLastUnlockTime();
        return true;
      }

      return false;
    } on PlatformException catch (e) {
      debugPrint(
        'Biometric authentication PlatformException: ${e.code} - ${e.message}',
      );
      return false;
    } catch (e) {
      debugPrint('Biometric authentication failed: $e');
      return false;
    }
  }

  Future<void> setKeepMeLoggedIn(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    _keepMeLoggedIn = value;
    await prefs.setBool('keepMeLoggedIn', value);
    notifyListeners();
  }

  String _handleAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return 'No user found with this email.';
      case 'wrong-password':
        return 'Incorrect password.';
      case 'invalid-email':
        return 'Invalid email address.';
      case 'user-disabled':
        return 'This account has been disabled.';
      case 'too-many-requests':
        return 'Too many attempts. Please try again later.';
      case 'network-request-failed':
        if (_offlineUserId != null && _isOfflineSessionValid()) {
          return 'Network unavailable. Switching to offline mode.';
        }
        return 'Network error. Please check your connection.';
      default:
        return 'Login failed: ${e.message ?? 'Unknown error.'}';
    }
  }
}

class AppLockScreen extends StatefulWidget {
  const AppLockScreen({super.key});

  @override
  State<AppLockScreen> createState() => _AppLockScreenState();
}

class _AppLockScreenState extends State<AppLockScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _scaleAnimation;

  bool _isAuthenticating = false;
  bool _showFallbackButton = false;

  @override
  void initState() {
    super.initState();

    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.0, 0.6, curve: Curves.easeOut),
      ),
    );

    _scaleAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: const Interval(0.4, 1.0, curve: Curves.elasticOut),
      ),
    );

    _animationController.forward();

    // Auto-trigger biometric authentication after a short delay
    _triggerBiometricAuth();
  }

  Future<void> _triggerBiometricAuth() async {
    await Future.delayed(const Duration(milliseconds: 500));

    if (!mounted) return;

    setState(() {
      _isAuthenticating = true;
    });

    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    final success = await authProvider.authenticateForAppUnlock();

    if (!mounted) return;

    setState(() {
      _isAuthenticating = false;
    });

    if (success) {
      await _onAuthenticationSuccess();
    } else {
      setState(() {
        _showFallbackButton = true;
      });
    }
  }

  Future<void> _onAuthenticationSuccess() async {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    final user = authProvider.currentUser;

    if (!mounted) return;

    if (user != null) {
      if (user.isSuperAdmin) {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const SuperAdminDashboard()),
          (route) => false,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (context) => const MainPOSScreen()),
          (route) => false,
        );
      }
    }
  }

  Future<void> _tryAgain() async {
    setState(() {
      _isAuthenticating = true;
      _showFallbackButton = false;
    });

    await _triggerBiometricAuth();
  }

  Future<void> _logout() async {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    await authProvider.logout();

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (context) => const LoginScreen()),
      (route) => false,
    );
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
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
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: Transform.scale(
                scale: _scaleAnimation.value,
                child: child,
              ),
            );
          },
          child: Center(
            child: Container(
              constraints: const BoxConstraints(maxWidth: 400),
              margin: const EdgeInsets.all(24),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // App Icon/Logo
                  Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: gradientColors,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.rocket_launch_rounded,
                      color: Colors.white,
                      size: 50,
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Title
                  Text(
                    'App Locked',
                    style: TextStyle(
                      fontSize: 32,
                      fontWeight: FontWeight.w800,
                      color: isDark ? Colors.white : const Color(0xFF2D3748),
                    ),
                  ),

                  const SizedBox(height: 16),

                  // Description
                  Text(
                    'Authenticate to continue',
                    style: TextStyle(
                      fontSize: 16,
                      color: isDark ? Colors.white70 : const Color(0xFF718096),
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.center,
                  ),

                  const SizedBox(height: 40),

                  // Biometric Icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF2D3748) : Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: _isAuthenticating
                        ? const CircularProgressIndicator(
                            strokeWidth: 3,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Color(0xFF667EEA),
                            ),
                          )
                        : Icon(
                            Icons.fingerprint_rounded,
                            size: 40,
                            color: const Color(0xFF667EEA),
                          ),
                  ),

                  const SizedBox(height: 24),

                  // Status Text
                  Text(
                    _isAuthenticating
                        ? 'Authenticating...'
                        : 'Touch the fingerprint sensor',
                    style: TextStyle(
                      fontSize: 14,
                      color: isDark ? Colors.white60 : const Color(0xFF718096),
                    ),
                  ),

                  const SizedBox(height: 40),

                  // Action Buttons
                  if (_showFallbackButton) ...[
                    Column(
                      children: [
                        // Try Again Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: ElevatedButton(
                            onPressed: _isAuthenticating ? null : _tryAgain,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF667EEA),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              elevation: 5,
                            ),
                            child: _isAuthenticating
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                      color: Colors.white,
                                    ),
                                  )
                                : const Text(
                                    'Try Again',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Logout Button
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: OutlinedButton(
                            onPressed: _logout,
                            style: OutlinedButton.styleFrom(
                              foregroundColor: isDark
                                  ? Colors.white70
                                  : const Color(0xFF718096),
                              side: BorderSide(
                                color: isDark
                                    ? Colors.white30
                                    : const Color(0xFFCBD5E0),
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            child: const Text(
                              'Use Different Account',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else if (!_isAuthenticating) ...[
                    // Manual trigger button
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _tryAgain,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF667EEA),
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 5,
                        ),
                        child: const Text(
                          'Authenticate Now',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _loading = false;
  final LocalAuthentication _localAuth = LocalAuthentication();
  List<BiometricType> _availableBiometrics = [];

  @override
  void initState() {
    super.initState();
    _checkAvailableBiometrics();
  }

  Future<void> _checkAvailableBiometrics() async {
    try {
      final canCheck = await _localAuth.canCheckBiometrics;
      if (canCheck) {
        _availableBiometrics = await _localAuth.getAvailableBiometrics();
        setState(() {});
      }
    } catch (e) {
      debugPrint('Error checking available biometrics: $e');
    }
  }

  String _getBiometricTypeName(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return 'Face ID';
      case BiometricType.fingerprint:
        return 'Fingerprint';
      case BiometricType.iris:
        return 'Iris Scan';
      case BiometricType.strong:
        return 'Strong Biometric';
      case BiometricType.weak:
        return 'Weak Biometric';
      default:
        return 'Biometric';
    }
  }

  IconData _getBiometricIcon(BiometricType type) {
    switch (type) {
      case BiometricType.face:
        return Icons.face_retouching_natural;
      case BiometricType.fingerprint:
        return Icons.fingerprint;
      case BiometricType.iris:
        return Icons.remove_red_eye;
      default:
        return Icons.security;
    }
  }

  Future<void> _testBiometricAuth() async {
    setState(() {
      _loading = true;
    });

    try {
      final didAuthenticate = await _localAuth.authenticate(
        localizedReason: 'Test your biometric authentication',

        biometricOnly: false,
        sensitiveTransaction: true,
        // useErrorDialogs: true,
        // stickyAuth: true,
        // ),
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            didAuthenticate
                ? 'Biometric test successful!'
                : 'Biometric test failed',
          ),
          backgroundColor: didAuthenticate ? Colors.green : Colors.red,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Biometric test error: $e'),
          backgroundColor: Colors.orange,
        ),
      );
    } finally {
      setState(() {
        _loading = false;
      });
    }
  }

  Future<void> _showLockTimeoutDialog() async {
    final authProvider = context.read<MyAuthProvider>();
    final prefs = await SharedPreferences.getInstance();
    final currentTimeout = prefs.getInt('lockTimeout') ?? 30;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: const Text('Auto Lock Timeout'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Set how long before the app automatically locks:'),
                const SizedBox(height: 20),
                Text(
                  '${currentTimeout} seconds',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: 10),
                Slider(
                  value: currentTimeout.toDouble(),
                  min: 10,
                  max: 300,
                  divisions: 29,
                  label: '${currentTimeout} seconds',
                  onChanged: (value) {
                    setDialogState(() {});
                  },
                  onChangeEnd: (value) async {
                    await prefs.setInt('lockTimeout', value.toInt());
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          'Auto lock timeout set to ${value.toInt()} seconds',
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Text(
                  '10 sec - 5 min',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () async {
                  await prefs.setInt('lockTimeout', currentTimeout);
                  Navigator.of(context).pop();
                },
                child: const Text('Save'),
              ),
            ],
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<MyAuthProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Security Settings'),
        actions: [
          IconButton(
            icon: const Icon(Icons.security),
            onPressed: _testBiometricAuth,
            tooltip: 'Test Biometric Authentication',
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: [
                // Biometric Status Card
                Card(
                  margin: const EdgeInsets.all(16),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.biotech_rounded,
                              color: theme.colorScheme.primary,
                              size: 24,
                            ),
                            const SizedBox(width: 12),
                            const Text(
                              'Biometric Status',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (_availableBiometrics.isNotEmpty) ...[
                          const Text(
                            'Available biometric methods:',
                            style: TextStyle(fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            children: _availableBiometrics
                                .map(
                                  (type) => Chip(
                                    label: Text(_getBiometricTypeName(type)),
                                    avatar: Icon(
                                      _getBiometricIcon(type),
                                      size: 18,
                                    ),
                                    visualDensity: VisualDensity.compact,
                                  ),
                                )
                                .toList(),
                          ),
                        ] else ...[
                          const Text(
                            'No biometric methods available',
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),

                // App Lock Setting
                Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      SwitchListTile(
                        title: const Text(
                          'Enable App Lock',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: const Text(
                          'Require biometric authentication to open the app',
                        ),
                        secondary: const Icon(Icons.lock_rounded),
                        value: authProvider.appLockEnabled,
                        onChanged: (value) async {
                          setState(() {
                            _loading = true;
                          });

                          if (value) {
                            // Enable app lock
                            final isSupported = await _localAuth
                                .isDeviceSupported();
                            if (!isSupported) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Device does not support biometric authentication',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              setState(() => _loading = false);
                              return;
                            }

                            final canCheck =
                                await _localAuth.canCheckBiometrics;
                            if (!canCheck) {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'No biometrics enrolled on this device',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                              setState(() => _loading = false);
                              return;
                            }

                            // Test biometric authentication
                            final didAuthenticate = await authProvider
                                .authenticateForAppUnlock();
                            if (didAuthenticate) {
                              await authProvider.setAppLockEnabled(true);
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('App lock enabled'),
                                  backgroundColor: Colors.green,
                                ),
                              );
                            } else {
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Authentication failed - App lock not enabled',
                                  ),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          } else {
                            // Disable app lock
                            await authProvider.setAppLockEnabled(false);
                            if (!mounted) return;
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('App lock disabled'),
                                backgroundColor: Colors.blue,
                              ),
                            );
                          }

                          setState(() {
                            _loading = false;
                          });
                        },
                      ),

                      if (authProvider.appLockEnabled) ...[
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.timer_rounded),
                          title: const Text('Auto Lock Timeout'),
                          subtitle: const Text(
                            'Set when the app automatically locks',
                          ),
                          trailing: const Icon(Icons.chevron_right_rounded),
                          onTap: _showLockTimeoutDialog,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          leading: const Icon(Icons.history_rounded),
                          title: const Text('Last Unlock'),
                          subtitle: authProvider.lastUnlockTime != null
                              ? Text(
                                  DateFormat(
                                    'MMM dd, yyyy - HH:mm',
                                  ).format(authProvider.lastUnlockTime!),
                                )
                              : const Text('Never unlocked'),
                          trailing: IconButton(
                            icon: const Icon(Icons.refresh_rounded),
                            onPressed: () async {
                              final success = await authProvider
                                  .authenticateForAppUnlock();
                              if (!mounted) return;
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    success
                                        ? 'Re-authenticated successfully'
                                        : 'Re-authentication failed',
                                  ),
                                  backgroundColor: success
                                      ? Colors.green
                                      : Colors.red,
                                ),
                              );
                            },
                            tooltip: 'Re-authenticate',
                          ),
                        ),
                      ],
                    ],
                  ),
                ),

                // Security Features Card
                Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.enhanced_encryption_rounded),
                        title: Text(
                          'Security Features',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Require Biometric on App Resume'),
                        subtitle: const Text(
                          'Always require biometric when app comes from background',
                        ),
                        secondary: const Icon(Icons.smartphone_rounded),
                        value: authProvider
                            .appLockEnabled, // You can create a separate setting for this
                        onChanged: authProvider.appLockEnabled
                            ? (value) {
                                // Implement background lock requirement
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Feature coming soon'),
                                  ),
                                );
                              }
                            : null,
                      ),
                      const Divider(height: 1),
                      SwitchListTile(
                        title: const Text('Biometric Fallback to PIN'),
                        subtitle: const Text(
                          'Allow PIN entry if biometric fails multiple times',
                        ),
                        secondary: const Icon(Icons.pin_rounded),
                        value: false, // You can implement this
                        onChanged: (value) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Feature coming soon'),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Quick Actions Card
                Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Column(
                    children: [
                      const ListTile(
                        leading: Icon(Icons.quickreply_rounded),
                        title: Text(
                          'Quick Actions',
                          style: TextStyle(fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.security_update_good_rounded),
                        title: const Text('Test Biometric Now'),
                        subtitle: const Text(
                          'Verify your biometric authentication is working',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: _testBiometricAuth,
                      ),
                      const Divider(height: 1),
                      ListTile(
                        leading: const Icon(Icons.lock_reset_rounded),
                        title: const Text('Force App Lock Now'),
                        subtitle: const Text(
                          'Immediately lock the app for testing',
                        ),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () async {
                          final prefs = await SharedPreferences.getInstance();
                          await prefs.remove('lastUnlockTime');
                          if (!mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('App will lock on next open'),
                              backgroundColor: Colors.blue,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),

                // Information & Help
                if (authProvider.appLockEnabled) ...[
                  Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.green.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.green.withOpacity(0.3)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.verified_user_rounded,
                              color: Colors.green[700],
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'App Lock Active',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          'Your app is protected with biometric authentication. You will need to authenticate when:',
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Opening the app after it was closed',
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        const Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Icon(
                              Icons.check_circle,
                              size: 16,
                              color: Colors.green,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Returning to the app after timeout period',
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
    );
  }
}

class AppLifecycleWrapper extends StatefulWidget {
  final Widget child;

  const AppLifecycleWrapper({super.key, required this.child});

  @override
  State<AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper>
    with WidgetsBindingObserver {
  DateTime? _lastBackgroundTime;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);

    if (state == AppLifecycleState.paused) {
      _lastBackgroundTime = DateTime.now();
      debugPrint('App went to background at $_lastBackgroundTime');
    } else if (state == AppLifecycleState.resumed) {
      if (_lastBackgroundTime != null && authProvider.appLockEnabled) {
        final now = DateTime.now();
        final difference = now.difference(_lastBackgroundTime!);

        if (difference.inSeconds > 5) {
          _forceAppLock(authProvider);
        }
      }
    }
  }

  Future<void> _forceAppLock(MyAuthProvider authProvider) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('lastUnlockTime');

    if (mounted && authProvider.currentUser != null) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const AppLockScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
class KeepMeLoggedInCheckbox extends StatefulWidget {
  const KeepMeLoggedInCheckbox({super.key});

  @override
  State<KeepMeLoggedInCheckbox> createState() => _KeepMeLoggedInCheckboxState();
}

class _KeepMeLoggedInCheckboxState extends State<KeepMeLoggedInCheckbox> {
  bool? _currentValue;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Initialize local state
    if (_currentValue == null) {
      _currentValue = authProvider.keepMeLoggedIn;
    }

    return CheckboxListTile(
      title: Text(
        'Keep me logged in',
        style: TextStyle(
          color: isDark ? Colors.white70 : const Color(0xFF4A5568),
          fontWeight: FontWeight.w500,
        ),
      ),
      value: _currentValue,
      onChanged: (value) async {
        if (value != null) {
          setState(() {
            _currentValue = value;
          });
          await authProvider.setKeepMeLoggedIn(value);
        }
      },
      activeColor: const Color(0xFF667EEA),
      checkColor: Colors.white,
      controlAffinity: ListTileControlAffinity.leading,
      contentPadding: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      tileColor: isDark
          ? const Color(0xFF2D3748).withOpacity(0.4)
          : Colors.grey[100],
    );
  }
}
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
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: isSuccess
            ? Colors.green.withOpacity(0.1)
            : Colors.red.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isSuccess
              ? Colors.green.withOpacity(0.3)
              : Colors.red.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(4),
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
          const SizedBox(width: 12),
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
            // Back button
            Positioned(
              top: MediaQuery.of(context).padding.top + 16,
              left: 16,
              child: IconButton(
                onPressed: () {
                  authProvider.clearResetState();
                  Navigator.of(context).pop();
                },
                icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
                style: IconButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ),

            Center(
              child: Container(
                constraints: const BoxConstraints(maxWidth: 500),
                margin: const EdgeInsets.all(20),
                child: Card(
                  elevation: 24,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(24),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(40),
                    child: SingleChildScrollView(
                      child: Form(
                        key: _formKey,
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Header
                            Container(
                              width: 80,
                              height: 80,
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: gradientColors,
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                ),
                                borderRadius: BorderRadius.circular(20),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.1),
                                    blurRadius: 20,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.lock_reset_rounded,
                                color: Colors.white,
                                size: 40,
                              ),
                            ),
                            const SizedBox(height: 32),

                            Text(
                              'Reset Your Password',
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w800,
                                color: isDark
                                    ? Colors.white
                                    : const Color(0xFF2D3748),
                              ),
                            ),
                            const SizedBox(height: 12),

                            Text(
                              'Enter your email and we\'ll send you a password reset link.',
                              style: TextStyle(
                                fontSize: 16,
                                color: isDark
                                    ? Colors.white70
                                    : const Color(0xFF718096),
                                fontWeight: FontWeight.w500,
                              ),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 8),

                            // Instructions
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark
                                    ? const Color(0xFF2D3748).withOpacity(0.5)
                                    : const Color(0xFF667EEA).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.info_outline_rounded,
                                        color: isDark ? Colors.blue[200] : const Color(0xFF667EEA),
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Text(
                                        'How it works:',
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          color: isDark ? Colors.white : const Color(0xFF2D3748),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    '1. Enter your email below\n'
                                        '2. Check your inbox for the reset link\n'
                                        '3. Click the link to set a new password\n'
                                        '4. Return here to login with your new password',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: isDark ? Colors.white70 : const Color(0xFF718096),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Success/Error Messages
                            if (authProvider.resetSuccess != null)
                              _buildMessageCard(
                                context,
                                authProvider.resetSuccess!,
                                true,
                              ),

                            if (authProvider.resetError != null)
                              _buildMessageCard(
                                context,
                                authProvider.resetError!,
                                false,
                              ),

                            // Email Field
                            Container(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 10,
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
                                  labelText: 'Email Address',
                                  labelStyle: TextStyle(
                                    color: isDark
                                        ? Colors.white70
                                        : const Color(0xFF718096),
                                  ),
                                  prefixIcon: Container(
                                    margin: const EdgeInsets.only(
                                      right: 12,
                                      left: 16,
                                    ),
                                    child: const Icon(
                                      Icons.email_rounded,
                                      color: Color(0xFF667EEA),
                                    ),
                                  ),
                                  filled: true,
                                  fillColor: isDark
                                      ? const Color(0xFF2D3748)
                                      : Colors.white,
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  enabledBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: BorderSide.none,
                                  ),
                                  focusedBorder: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(16),
                                    borderSide: const BorderSide(
                                      color: Color(0xFF667EEA),
                                      width: 2,
                                    ),
                                  ),
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 20,
                                    vertical: 16,
                                  ),
                                ),
                                keyboardType: TextInputType.emailAddress,
                                validator: (value) {
                                  if (value == null || value.isEmpty) {
                                    return 'Please enter your email';
                                  }
                                  if (!AppUtils.isEmailValid(value)) {
                                    return 'Please enter a valid email';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(height: 24),

                            // Send Reset Email Button
                            SizedBox(
                              width: double.infinity,
                              height: 56,
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
                                  backgroundColor: const Color(0xFF667EEA),
                                  foregroundColor: Colors.white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                  elevation: 5,
                                ),
                                child: authProvider.isSendingResetEmail
                                    ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                                    : const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Send Reset Link',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    SizedBox(width: 8),
                                    Icon(Icons.send_rounded, size: 20),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 20),

                            // Back to Login
                            TextButton(
                              onPressed: () {
                                authProvider.clearResetState();
                                Navigator.of(context).pop();
                              },
                              child: const Text(
                                'Back to Login',
                                style: TextStyle(
                                  color: Color(0xFF667EEA),
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