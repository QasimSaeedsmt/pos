import 'package:flutter/material.dart';
import 'package:mpcm/features/users/users_base.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../modules/auth/models/tenant_model.dart';
import '../modules/auth/providers/auth_provider.dart';
import '../../theme_utils.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);
    final tenant = authProvider.currentTenant;
    final user = authProvider.currentUser;

    return Scaffold(
      backgroundColor: ThemeUtils.backgroundSolid(context),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              // Header Section
              _buildHeader(context, tenant!),
              const SizedBox(height: 24),

              // User Info Card
              _buildUserInfoCard(context, user!),
              const SizedBox(height: 20),

              // Subscription Card
              _buildSubscriptionCard(context, tenant),
              const SizedBox(height: 20),

              // Quick Actions
              // _buildQuickActions(context),
              // const SizedBox(height: 20),
              //
              // // Settings
              // _buildSettingsSection(context, authProvider),
              const SizedBox(height: 20),

              // Logout Button
              _buildLogoutButton(context, authProvider),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, Tenant tenant) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: ThemeUtils.appBar(context),
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
      ),
      padding: const EdgeInsets.all(24),
      child: Row(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: ThemeUtils.accent(context),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.business_center_rounded,
              color: Colors.white,
              size: 30,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tenant.businessName,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Business Account',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.8),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUserInfoCard(BuildContext context, AppUser user) {
    return Container(
      decoration: ThemeUtils.cardDecoration(context),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: ThemeUtils.button(context),
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.person_rounded,
              color: Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: ThemeUtils.headlineMedium(context).copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  user.email,
                  style: ThemeUtils.bodyMedium(context),
                ),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                  decoration: BoxDecoration(
                    color: ThemeUtils.primary(context).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    user.role.toString().split('.').last.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      color: ThemeUtils.primary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSubscriptionCard(BuildContext context, Tenant tenant) {
    final isActive = tenant.isSubscriptionActive;
    final daysLeft = tenant.subscriptionExpiry.difference(DateTime.now()).inDays;

    return Container(
      decoration: ThemeUtils.cardDecoration(context),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Subscription',
                style: ThemeUtils.headlineMedium(context).copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isActive ? ThemeUtils.success(context) : ThemeUtils.error(context),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isActive ? 'ACTIVE' : 'EXPIRED',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            context,
            Icons.card_membership_rounded,
            'Plan',
            tenant.subscriptionPlan.toUpperCase(),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            Icons.calendar_today_rounded,
            'Expires',
            DateFormat('MMM dd, yyyy').format(tenant.subscriptionExpiry),
          ),
          const SizedBox(height: 12),
          _buildInfoRow(
            context,
            Icons.timer_rounded,
            'Status',
            isActive ? '$daysLeft days remaining' : 'Subscription expired',
            valueColor: isActive ? ThemeUtils.success(context) : ThemeUtils.error(context),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(BuildContext context, IconData icon, String label, String value, {Color? valueColor}) {
    return Row(
      children: [
        Icon(
          icon,
          color: ThemeUtils.primary(context),
          size: 20,
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: ThemeUtils.bodySmall(context),
              ),
              Text(
                value,
                style: ThemeUtils.bodyLarge(context).copyWith(
                  color: valueColor ?? ThemeUtils.textPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // Widget _buildQuickActions(BuildContext context) {
  //   return Container(
  //     decoration: ThemeUtils.cardDecoration(context),
  //     padding: const EdgeInsets.all(20),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           'Quick Actions',
  //           style: ThemeUtils.headlineMedium(context).copyWith(
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //         Row(
  //           children: [
  //             _buildActionButton(
  //               context,
  //               Icons.support_rounded,
  //               'Support',
  //               ThemeUtils.primary(context),
  //             ),
  //             const SizedBox(width: 12),
  //             _buildActionButton(
  //               context,
  //               Icons.palette_rounded,
  //               'Branding',
  //               ThemeUtils.accentColor(context),
  //             ),
  //           ],
  //         ),
  //         const SizedBox(height: 12),
  //         Row(
  //           children: [
  //             _buildActionButton(
  //               context,
  //               Icons.analytics_rounded,
  //               'Analytics',
  //               Colors.purple,
  //             ),
  //             const SizedBox(width: 12),
  //             _buildActionButton(
  //               context,
  //               Icons.notifications_rounded,
  //               'Alerts',
  //               Colors.orange,
  //             ),
  //           ],
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildActionButton(BuildContext context, IconData icon, String label, Color color) {
  //   return Expanded(
  //     child: Container(
  //       decoration: BoxDecoration(
  //         color: color.withOpacity(0.1),
  //         borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
  //       ),
  //       child: Material(
  //         color: Colors.transparent,
  //         borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
  //         child: InkWell(
  //           borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
  //           onTap: () => _handleActionTap(context, label),
  //           child: Padding(
  //             padding: const EdgeInsets.all(16),
  //             child: Column(
  //               children: [
  //                 Icon(icon, color: color, size: 24),
  //                 const SizedBox(height: 8),
  //                 Text(
  //                   label,
  //                   style: ThemeUtils.bodyMedium(context).copyWith(
  //                     fontWeight: FontWeight.w600,
  //                   ),
  //                 ),
  //               ],
  //             ),
  //           ),
  //         ),
  //       ),
  //     ),
  //   );
  // }

  // Widget _buildSettingsSection(BuildContext context, MyAuthProvider authProvider) {
  //   return Container(
  //     decoration: ThemeUtils.cardDecoration(context),
  //     padding: const EdgeInsets.all(20),
  //     child: Column(
  //       crossAxisAlignment: CrossAxisAlignment.start,
  //       children: [
  //         Text(
  //           'Preferences',
  //           style: ThemeUtils.headlineMedium(context).copyWith(
  //             fontWeight: FontWeight.bold,
  //           ),
  //         ),
  //         const SizedBox(height: 16),
  //         _buildSettingItem(
  //           context,
  //           'Keep me logged in',
  //           authProvider.keepMeLoggedIn,
  //               (value) => authProvider.setKeepMeLoggedIn(value),
  //           Icons.login_rounded,
  //         ),
  //         const SizedBox(height: 12),
  //         _buildSettingItem(
  //           context,
  //           'Biometric Login',
  //           authProvider.fingerprintEnabled,
  //               (value) => authProvider.setFingerprintEnabled(value),
  //           Icons.fingerprint_rounded,
  //         ),
  //         const SizedBox(height: 12),
  //         _buildSettingItem(
  //           context,
  //           'App Lock',
  //           authProvider.appLockEnabled,
  //               (value) => authProvider.setAppLockEnabled(value),
  //           Icons.lock_rounded,
  //         ),
  //       ],
  //     ),
  //   );
  // }

  // Widget _buildSettingItem(BuildContext context, String title, bool value, Function(bool) onChanged, IconData icon) {
  //   return ListTile(
  //     leading: Container(
  //       width: 40,
  //       height: 40,
  //       decoration: BoxDecoration(
  //         color: ThemeUtils.primary(context).withOpacity(0.1),
  //         shape: BoxShape.circle,
  //       ),
  //       child: Icon(icon, color: ThemeUtils.primary(context), size: 20),
  //     ),
  //     title: Text(title, style: ThemeUtils.bodyLarge(context)),
  //     trailing: Switch(
  //       value: value,
  //       onChanged: onChanged,
  //       activeColor: ThemeUtils.primary(context),
  //     ),
  //     contentPadding: EdgeInsets.zero,
  //   );
  // }

  Widget _buildLogoutButton(BuildContext context, MyAuthProvider authProvider) {
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: () => _showLogoutConfirmation(context, authProvider),
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeUtils.error(context),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Text(
              'Logout',
              style: ThemeUtils.buttonText(context).copyWith(color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  void _handleActionTap(BuildContext context, String action) {
    // Handle action taps
    switch (action) {
      case 'Support':
      // Navigator.push(context, MaterialPageRoute(builder: (_) => TicketsScreen()));
        break;
      case 'Branding':
      // Navigator.push(context, MaterialPageRoute(builder: (_) => BrandingScreen()));
        break;
      case 'Analytics':
      // Navigator.push(context, MaterialPageRoute(builder: (_) => AnalyticsScreen()));
        break;
      case 'Alerts':
      // Navigator.push(context, MaterialPageRoute(builder: (_) => NotificationsScreen()));
        break;
    }
  }

  void _showLogoutConfirmation(BuildContext context, MyAuthProvider authProvider) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeUtils.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        ),
        title: Text('Logout', style: ThemeUtils.headlineMedium(context)),
        content: Text('Are you sure you want to logout?', style: ThemeUtils.bodyLarge(context)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel', style: ThemeUtils.bodyLarge(context)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              authProvider.logout();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeUtils.error(context),
            ),
            child: const Text('Logout', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}