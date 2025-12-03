
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:mpcm/cart_manager.dart';
import 'package:mpcm/modules/auth/screens/login_screen.dart';
import 'package:provider/provider.dart';

import '../../app_theme.dart';
import '../../checkou_screen.dart';
import '../../constants.dart';
import '../../modules/auth/models/activity_type.dart';
import '../../modules/auth/models/tenant_model.dart';
import '../../modules/auth/providers/auth_provider.dart';
import '../../modules/auth/providers/settings_provider.dart';
import '../../theme_provider.dart';
import '../../theme_utils.dart';
import '../ticketing/ticketing.dart';

class SuperAdminDashboard extends StatefulWidget {
  const SuperAdminDashboard({super.key});

  @override
  _SuperAdminDashboardState createState() => _SuperAdminDashboardState();
}

class _SuperAdminDashboardState extends State<SuperAdminDashboard> {
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    // Load tenants when super admin dashboard initializes
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final tenantProvider = Provider.of<TenantProvider>(
        context,
        listen: false,
      );
      tenantProvider.loadAllTenants();
    });
  }

  @override
  Widget build(BuildContext context) {
    final List<Widget> superAdminScreens = [
      /////////
      SuperAdminHome(),
      TenantsManagementScreen(),
      SuperAdminAnalyticsScreen(), SuperAdminTicketsScreen(),
      SuperAdminManagementScreen(), // Make sure this is included
    ];

    return Scaffold(
      appBar: AppBar(
        title: Text('Super Admin Dashboard'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () {
              // Refresh tenants list
              final tenantProvider = Provider.of<TenantProvider>(
                context,
                listen: false,
              );
              tenantProvider.loadAllTenants();
            },
          ),

          IconButton(onPressed: (){
            Navigator.push(context, MaterialPageRoute(builder: (context) => SuperAdminSettingsScreen(),));
          }, icon: Icon(Icons.settings))
        ],
      ),
      body: superAdminScreens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        selectedIconTheme: IconThemeData(color: Colors.black),
        unselectedIconTheme: IconThemeData(color: Colors.grey),
        selectedItemColor: Color(0xff000000),
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        unselectedLabelStyle: TextStyle(color: Colors.grey.shade800),
        currentIndex: _currentIndex,
        onTap: (index) => setState(() => _currentIndex = index),
        items: [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Overview',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.business), label: 'Tenants'),
          BottomNavigationBarItem(
            icon: Icon(Icons.analytics),
            label: 'Analytics',
          ),
          BottomNavigationBarItem(icon: Icon(Icons.support), label: 'Support'),
          BottomNavigationBarItem(
            icon: Icon(Icons.admin_panel_settings),
            label: 'Admins',
          ),
        ],
      ),
    );
  }
}




class SuperAdminSettingsScreen extends StatefulWidget {
  const SuperAdminSettingsScreen({super.key});

  @override
  State<SuperAdminSettingsScreen> createState() => _SuperAdminSettingsScreenState();
}

class _SuperAdminSettingsScreenState extends State<SuperAdminSettingsScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: ThemeUtils.gradientBackground(context),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                _buildHeader(context),
                const SizedBox(height: 24),

                // Settings Cards
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      children: [
                        // Biometric Authentication Card
                        _buildBiometricSettingsCard(context),
                        const SizedBox(height: 16),

                        // Theme Settings Card
                        _buildThemeSettingsCard(context),
                        const SizedBox(height: 16),

                        // Logout Button
                        _buildLogoutButton(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        IconButton(
          icon: Icon(
            Icons.arrow_back,
            color: ThemeUtils.textPrimary(context),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        const SizedBox(width: 8),
        Text(
          'Settings',
          style: ThemeUtils.headlineLarge(context),
        ),
      ],
    );
  }

  Widget _buildBiometricSettingsCard(BuildContext context) {
    return Consumer<SettingsProvider>(
      builder: (context, settingsProvider, child) {
        return Container(
          decoration: ThemeUtils.cardDecoration(context),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(
                      Icons.fingerprint,
                      color: ThemeUtils.accentColor(context),
                      size: 24,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Biometric Authentication',
                      style: ThemeUtils.headlineMedium(context),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Available Biometrics
                if (settingsProvider.availableBiometrics.isNotEmpty)
                  ..._buildBiometricList(context, settingsProvider),

                // Test Biometric Button
                const SizedBox(height: 16),
                _buildTestBiometricButton(context, settingsProvider),

                // No Biometrics Available
                if (settingsProvider.availableBiometrics.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8.0),
                    child: Text(
                      'No biometric sensors available',
                      style: ThemeUtils.bodyMedium(context),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildBiometricList(BuildContext context, SettingsProvider settingsProvider) {
    return [
      Text(
        'Available Biometric Methods:',
        style: ThemeUtils.bodyLarge(context).copyWith(
          fontWeight: FontWeight.w600,
        ),
      ),
      const SizedBox(height: 8),
      ...settingsProvider.availableBiometrics.map((type) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 4.0),
        child: Row(
          children: [
            Icon(
              settingsProvider.getBiometricIcon(type),
              color: ThemeUtils.accentColor(context),
              size: 20,
            ),
            const SizedBox(width: 8),
            Text(
              settingsProvider.getBiometricTypeName(type),
              style: ThemeUtils.bodyMedium(context),
            ),
          ],
        ),
      )),
    ];
  }

  Widget _buildTestBiometricButton(BuildContext context, SettingsProvider settingsProvider) {
    return Container(
      width: double.infinity,
      decoration: ThemeUtils.buttonDecoration(context),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
          onTap: settingsProvider.availableBiometrics.isNotEmpty
              ? () async {
            final result = await settingsProvider.testBiometricAuth();
            _showBiometricResultDialog(context, result);
          }
              : null,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: settingsProvider.loading
                ? SizedBox(
              height: 20,
              width: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                valueColor: AlwaysStoppedAnimation<Color>(
                  ThemeUtils.textOnPrimary(context),
                ),
              ),
            )
                : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.security,
                  color: ThemeUtils.textOnPrimary(context),
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Test Biometric Authentication',
                  style: ThemeUtils.buttonText(context),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildThemeSettingsCard(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);

    return Container(
      decoration: ThemeUtils.cardDecoration(context),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.palette,
                  color: ThemeUtils.accentColor(context),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Theme Settings',
                  style: ThemeUtils.headlineMedium(context),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Dark Mode Toggle
            _buildDarkModeToggle(context, themeProvider),
            const SizedBox(height: 16),

            // System Theme Toggle
            _buildSystemThemeToggle(context, themeProvider),
            const SizedBox(height: 16),

            // Theme Selection
            _buildThemeSelection(context, themeProvider),
          ],
        ),
      ),
    );
  }

  Widget _buildDarkModeToggle(BuildContext context, ThemeProvider themeProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Dark Mode',
              style: ThemeUtils.bodyLarge(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Enable dark theme',
              style: ThemeUtils.bodySmall(context),
            ),
          ],
        ),
        Switch(
          value: themeProvider.isDarkMode,
          onChanged: (value) async {
            await themeProvider.setDarkMode(value);
          },
          activeThumbColor: ThemeUtils.accentColor(context),
          activeTrackColor: ThemeUtils.accentColor(context).withOpacity(0.5),
        ),
      ],
    );
  }

  Widget _buildSystemThemeToggle(BuildContext context, ThemeProvider themeProvider) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Use System Theme',
              style: ThemeUtils.bodyLarge(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Follow system theme settings',
              style: ThemeUtils.bodySmall(context),
            ),
          ],
        ),
        Switch(
          value: themeProvider.useSystemTheme,
          onChanged: (value) async {
            await themeProvider.setUseSystemTheme(value);
          },
          activeThumbColor: ThemeUtils.accentColor(context),
          activeTrackColor: ThemeUtils.accentColor(context).withOpacity(0.5),
        ),
      ],
    );
  }

  Widget _buildThemeSelection(BuildContext context, ThemeProvider themeProvider) {
    return FutureBuilder<List<AppTheme>>(
      future: themeProvider.getAvailableThemes(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Center(
            child: CircularProgressIndicator(
              color: ThemeUtils.accentColor(context),
            ),
          );
        }

        if (snapshot.hasError || !snapshot.hasData) {
          return Text(
            'Error loading themes',
            style: ThemeUtils.bodyMedium(context),
          );
        }

        final themes = snapshot.data!;
        final currentTheme = themeProvider.currentTheme;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Select Theme:',
              style: ThemeUtils.bodyLarge(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: themes.map((theme) {
                final isSelected = currentTheme?.name == theme.name;

                return GestureDetector(
                  onTap: () => themeProvider.setTheme(theme),
                  child: Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: ThemeManager.hexToColors(theme.backgroundGradient),
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                      border: isSelected
                          ? Border.all(
                        color: ThemeUtils.accentColor(context),
                        width: 3,
                      )
                          : Border.all(
                        color: ThemeUtils.textSecondary(context).withOpacity(0.3),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Stack(
                      children: [
                        // Theme preview content
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Primary color indicator
                              Container(
                                width: 20,
                                height: 20,
                                decoration: BoxDecoration(
                                  color: ThemeManager.hexToColor(theme.primaryColor),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(height: 4),
                              // Accent color indicator
                              Container(
                                width: 16,
                                height: 16,
                                decoration: BoxDecoration(
                                  color: ThemeManager.hexToColor(theme.accentColor),
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const Spacer(),
                              // Theme name
                              Text(
                                theme.name.length > 8
                                    ? '${theme.name.substring(0, 8)}...'
                                    : theme.name,
                                style: TextStyle(
                                  fontSize: 10,
                                  color: ThemeManager.hexToColor(theme.primaryTextColor),
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Selected indicator
                        if (isSelected)
                          Positioned(
                            top: 4,
                            right: 4,
                            child: Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: ThemeUtils.accentColor(context),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.check,
                                size: 12,
                                color: ThemeUtils.textOnPrimary(context),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            ThemeUtils.error(context).withOpacity(0.8),
            ThemeUtils.error(context),
          ],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
        ),
        borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: ThemeUtils.buttonElevation(context),
            offset: Offset(0, ThemeUtils.buttonElevation(context) / 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
          onTap: _showLogoutConfirmationDialog,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.logout,
                  color: Colors.white,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  'Logout',
                  style: ThemeUtils.buttonText(context).copyWith(
                    color: Colors.white,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showBiometricResultDialog(BuildContext context, bool success) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeUtils.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        ),
        title: Row(
          children: [
            Icon(
              success ? Icons.check_circle : Icons.error,
              color: success ? ThemeUtils.success(context) : ThemeUtils.error(context),
            ),
            const SizedBox(width: 8),
            Text(
              success ? 'Success' : 'Failed',
              style: ThemeUtils.headlineMedium(context),
            ),
          ],
        ),
        content: Text(
          success
              ? 'Biometric authentication was successful!'
              : 'Biometric authentication failed. Please try again.',
          style: ThemeUtils.bodyMedium(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'OK',
              style: ThemeUtils.buttonText(context).copyWith(
                color: ThemeUtils.accentColor(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showLogoutConfirmationDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: ThemeUtils.surface(context),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        ),
        title: Text(
          'Logout',
          style: ThemeUtils.headlineMedium(context),
        ),
        content: Text(
          'Are you sure you want to logout?',
          style: ThemeUtils.bodyMedium(context),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(
              'Cancel',
              style: ThemeUtils.buttonText(context).copyWith(
                color: ThemeUtils.textSecondary(context),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  ThemeUtils.error(context).withOpacity(0.8),
                  ThemeUtils.error(context),
                ],
              ),
              borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                onTap: () {
                  Provider.of<MyAuthProvider>(context, listen: false).logout();

                  Navigator.of(context).pop();

                  Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => LoginScreen(),));


                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Text(
                    'Logout',
                    style: ThemeUtils.buttonText(context).copyWith(
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }


}
class TenantsManagementScreen extends StatelessWidget {
  const TenantsManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tenantProvider = Provider.of<TenantProvider>(context);

    // Load tenants when this screen is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (tenantProvider.tenants.isEmpty) {
        tenantProvider.loadAllTenants();
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text('Tenants Management'),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: () => tenantProvider.loadAllTenants(),
          ),
        ],
      ),
      body: tenantProvider.isLoading
          ? Center(child: CircularProgressIndicator())
          : tenantProvider.tenants.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 64, color: Colors.grey),
            SizedBox(height: 16),
            Text(
              'No Tenants Found',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 8),
            Text(
              'There are no tenants in the system yet.',
              style: TextStyle(color: Colors.grey),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => tenantProvider.loadAllTenants(),
              child: Text('Refresh'),
            ),
          ],
        ),
      )
          : ListView.builder(
        itemCount: tenantProvider.tenants.length,
        itemBuilder: (context, index) {
          final tenant = tenantProvider.tenants[index];
          return TenantManagementCard(tenant: tenant);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTenantDialog(context),
        tooltip: 'Create New Tenant',
        child: Icon(Icons.add_business),
      ),
    );
  }

  void _showCreateTenantDialog(BuildContext context) {
    showDialog(context: context, builder: (context) => CreateTenantDialog());
  }
}


class TenantManagementCard extends StatefulWidget {
  final Tenant tenant;

  const TenantManagementCard({super.key, required this.tenant});

  @override
  _TenantManagementCardState createState() => _TenantManagementCardState();
}

class _TenantManagementCardState extends State<TenantManagementCard> {
  bool _isUpdatingStatus = false;
  bool _isUpdatingSubscription = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: ThemeUtils.cardDecoration(context),
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Row: Icon + Tenant Info + Status
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Tenant Icon
              Container(
                decoration: BoxDecoration(
                  color: widget.tenant.isSubscriptionActive
                      ? ThemeUtils.success(context)
                      : ThemeUtils.error(context),
                  shape: BoxShape.circle,
                ),
                padding: EdgeInsets.all(12),
                child: Icon(
                  Icons.business,
                  size: 32,
                  color: ThemeUtils.textOnPrimary(context),
                ),
              ),
              SizedBox(width: 16),

              // Tenant Details
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.tenant.businessName,
                      style: ThemeUtils.headlineMedium(context),
                    ),
                    SizedBox(height: 4),
                    Text(
                      'ID: ${widget.tenant.id}',
                      style: ThemeUtils.bodyMedium(context),
                    ),
                    Text(
                      'Plan: ${widget.tenant.subscriptionPlan}',
                      style: ThemeUtils.bodyMedium(context),
                    ),
                    Text(
                      'Expires: ${DateFormat('MMM dd, yyyy').format(widget.tenant.subscriptionExpiry)}',
                      style: ThemeUtils.bodyMedium(context),
                    ),
                  ],
                ),
              ),

              // Switch + Active/Expired Chip
              Column(
                children: [
                  _isUpdatingStatus
                      ? Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ThemeUtils.primary(context),
                        ),
                      ),
                    ),
                  )
                      : Transform.scale(
                    scale: 1.2,
                    child: Switch(
                      value: widget.tenant.isActive,
                      onChanged: (value) => _updateTenantStatus(value),
                      activeThumbColor: ThemeUtils.success(context),
                      inactiveThumbColor: ThemeUtils.error(context),
                    ),
                  ),
                  SizedBox(height: 8),
                  Container(
                    padding: EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                    decoration: BoxDecoration(
                      color: widget.tenant.isSubscriptionActive
                          ? ThemeUtils.success(context)
                          : ThemeUtils.error(context),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      widget.tenant.isSubscriptionActive ? 'Active' : 'Expired',
                      style: ThemeUtils.bodySmall(context).copyWith(
                        color: ThemeUtils.textOnPrimary(context),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          SizedBox(height: 20),

          // Action Buttons
          Row(
            children: [
              Expanded(
                child: _isUpdatingSubscription
                    ? Container(
                  decoration: ThemeUtils.buttonDecoration(context),
                  padding: EdgeInsets.symmetric(vertical: 14),
                  child: Center(
                    child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          ThemeUtils.textOnPrimary(context),
                        ),
                      ),
                    ),
                  ),
                )
                    : InkWell(
                  onTap: () => _renewSubscription(context),
                  borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                  child: Container(
                    decoration: ThemeUtils.buttonDecoration(context),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.autorenew, color: ThemeUtils.textOnPrimary(context)),
                        SizedBox(width: 8),
                        Text('Renew', style: ThemeUtils.buttonText(context)),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _viewDetails(context),
                  borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                  child: Container(
                    decoration: ThemeUtils.buttonDecoration(context),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.visibility, color: ThemeUtils.textOnPrimary(context)),
                        SizedBox(width: 8),
                        Text('Details', style: ThemeUtils.buttonText(context)),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: InkWell(
                  onTap: () => _viewUsers(context),
                  borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                  child: Container(
                    decoration: ThemeUtils.buttonDecoration(context),
                    padding: EdgeInsets.symmetric(vertical: 14),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.people, color: ThemeUtils.textOnPrimary(context)),
                        SizedBox(width: 8),
                        Text('Users', style: ThemeUtils.buttonText(context)),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _updateTenantStatus(bool isActive) async {
    setState(() {
      _isUpdatingStatus = true;
    });

    try {
      final tenantProvider = Provider.of<TenantProvider>(context, listen: false);
      await tenantProvider.updateTenantStatus(widget.tenant.id, isActive);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Tenant status updated successfully'),
          backgroundColor: ThemeUtils.success(context),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error updating tenant: $e'),
          backgroundColor: ThemeUtils.error(context),
        ),
      );
    } finally {
      setState(() {
        _isUpdatingStatus = false;
      });
    }
  }

  void _renewSubscription(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => RenewSubscriptionDialog(
        tenant: widget.tenant,
        onRenew: (plan, expiry) async {
          setState(() {
            _isUpdatingSubscription = true;
          });

          try {
            final tenantProvider = Provider.of<TenantProvider>(context, listen: false);
            await tenantProvider.updateTenantSubscription(widget.tenant.id, plan, expiry);

            Navigator.pop(context);

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Subscription renewed successfully'),
                backgroundColor: ThemeUtils.success(context),
              ),
            );
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error renewing subscription: $e'),
                backgroundColor: ThemeUtils.error(context),
              ),
            );
          } finally {
            setState(() {
              _isUpdatingSubscription = false;
            });
          }
        },
      ),
    );
  }

  void _viewDetails(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => TenantDetailsDialog(tenant: widget.tenant),
    );
  }

  void _viewUsers(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        ),
        backgroundColor: ThemeUtils.surface(context),
        child: Container(
          padding: EdgeInsets.all(20),
          constraints: BoxConstraints(maxWidth: 450, maxHeight: 500),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                '${widget.tenant.businessName} - Users',
                style: ThemeUtils.headlineMedium(context),
              ),
              Divider(
                color: ThemeUtils.secondary(context),
                thickness: 1,
                height: 24,
              ),
              // Users List
              Expanded(
                child: FutureBuilder<QuerySnapshot>(
                  future: FirebaseFirestore.instance
                      .collection('tenants')
                      .doc(widget.tenant.id)
                      .collection('users')
                      .get(),
                  builder: (context, snapshot) {
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return Center(
                        child: CircularProgressIndicator(
                          color: ThemeUtils.primary(context),
                        ),
                      );
                    }
                    if (snapshot.hasError) {
                      return Center(
                        child: Text(
                          'Error loading users: ${snapshot.error}',
                          style: ThemeUtils.bodyMedium(context)
                              .copyWith(color: ThemeUtils.error(context)),
                        ),
                      );
                    }

                    final users = snapshot.data!.docs;
                    if (users.isEmpty) {
                      return Center(
                        child: Text(
                          'No users found',
                          style: ThemeUtils.bodyMedium(context),
                        ),
                      );
                    }

                    return ListView.separated(
                      shrinkWrap: true,
                      itemCount: users.length,
                      separatorBuilder: (_, __) => Divider(
                        color: ThemeUtils.secondary(context).withOpacity(0.3),
                      ),
                      itemBuilder: (context, index) {
                        final user = users[index].data() as Map<String, dynamic>;
                        return ListTile(
                          leading: CircleAvatar(
                            backgroundColor: ThemeUtils.backgroundSolid(context),
                            child: Icon(Icons.person, color: Colors.white),
                          ),
                          title: Text(
                            user['email'] ?? 'Unknown',
                            style: ThemeUtils.bodyLarge(context),
                          ),
                          subtitle: Text(
                            user['role'] ?? 'No role',
                            style: ThemeUtils.bodyMedium(context)
                                .copyWith(color: ThemeUtils.textSecondary(context)),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              SizedBox(height: 16),
              // Close button
              Align(
                alignment: Alignment.centerRight,
                child: InkWell(
                  onTap: () => Navigator.pop(context),
                  borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                  child: Container(
                    padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                    decoration: ThemeUtils.buttonDecoration(context),
                    child: Text(
                      'Close',
                      style: ThemeUtils.buttonText(context),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
class _QuickStat extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final Color color;

  const _QuickStat(this.label, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, size: 20, color: color),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(label, style: TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}




class RenewSubscriptionDialog extends StatefulWidget {
  final Tenant tenant;
  final Function(String plan, DateTime expiry) onRenew;

  const RenewSubscriptionDialog({super.key, required this.tenant, required this.onRenew});

  @override
  _RenewSubscriptionDialogState createState() => _RenewSubscriptionDialogState();
}

class _RenewSubscriptionDialogState extends State<RenewSubscriptionDialog> {
  String _selectedPlan = 'monthly';
  DateTime _selectedDate = DateTime.now().add(Duration(days: 30));
  bool _isRenewing = false;

  @override
  void initState() {
    super.initState();
    _selectedPlan = widget.tenant.subscriptionPlan;
  }

  @override
  Widget build(BuildContext context) {
    final planOptions = {
      'monthly': {'title': 'Monthly', 'subtitle': '\$29 / month'},
      'yearly': {'title': 'Yearly', 'subtitle': '\$299 / year (Save 15%)'},
      'custom': {'title': 'Custom', 'subtitle': 'Select your own expiry date'},
    };

    return AlertDialog(
      backgroundColor: ThemeUtils.surface(context),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
      ),
      title: Text(
        'Renew Subscription - ${widget.tenant.businessName}',
        style: ThemeUtils.headlineMedium(context),
      ),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          DropdownButtonFormField<String>(
            initialValue: _selectedPlan,
            decoration: InputDecoration(
              labelText: 'Subscription Plan',
              labelStyle: ThemeUtils.bodyMedium(context),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
              ),
              contentPadding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
            ),
            selectedItemBuilder: (context) {
              return planOptions.entries.map((entry) {
                return Text(
                  entry.value['title']!,
                  style: ThemeUtils.bodyLarge(context).copyWith(fontWeight: FontWeight.bold),
                  overflow: TextOverflow.ellipsis,
                );
              }).toList();
            },
            items: planOptions.entries.map((entry) {
              return DropdownMenuItem<String>(
                value: entry.key,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      entry.value['title']!,
                      style: ThemeUtils.bodyLarge(context).copyWith(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      entry.value['subtitle']!,
                      style: ThemeUtils.bodySmall(context).copyWith(
                        color: entry.key == 'yearly' ? ThemeUtils.success(context) : ThemeUtils.textSecondary(context),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) => setState(() => _selectedPlan = value!),
          ),

          SizedBox(height: 16),

          if (_selectedPlan == 'custom')
            InkWell(
              onTap: () async {
                final date = await showDatePicker(
                  context: context,
                  initialDate: _selectedDate,
                  firstDate: DateTime.now(),
                  lastDate: DateTime.now().add(Duration(days: 365 * 5)),
                  builder: (context, child) {
                    return Theme(
                      data: Theme.of(context).copyWith(
                        colorScheme: ColorScheme.light(
                          primary: ThemeUtils.primary(context),
                          onPrimary: ThemeUtils.textOnPrimary(context),
                          onSurface: ThemeUtils.textPrimary(context),
                        ),
                        textButtonTheme: TextButtonThemeData(
                          style: TextButton.styleFrom(
                            foregroundColor: ThemeUtils.primary(context),
                          ),
                        ),
                      ),
                      child: child!,
                    );
                  },
                );
                if (date != null) setState(() => _selectedDate = date);
              },
              borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
              child: Container(
                width: double.infinity,
                padding: EdgeInsets.symmetric(vertical: 14, horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                  border: Border.all(color: ThemeUtils.secondary(context)),
                ),
                child: Text(
                  'Select Expiry Date: ${DateFormat('MMM dd, yyyy').format(_selectedDate)}',
                  style: ThemeUtils.bodyMedium(context),
                ),
              ),
            ),
        ],
      ),
      actionsPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: _isRenewing ? null : () => Navigator.pop(context),
          child: Text('Cancel', style: ThemeUtils.bodyMedium(context).copyWith(color: ThemeUtils.secondary(context))),
        ),
        _isRenewing
            ? Container(
          padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
          child: SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(ThemeUtils.textOnPrimary(context)),
            ),
          ),
        )
            : InkWell(
          onTap: _renewSubscription,
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
          child: Container(
            padding: EdgeInsets.symmetric(vertical: 14, horizontal: 24),
            decoration: ThemeUtils.buttonDecoration(context),
            child: Text('Renew', style: ThemeUtils.buttonText(context)),
          ),
        ),
      ],
    );
  }

  void _renewSubscription() {
    final expiry = _selectedPlan == 'monthly'
        ? DateTime.now().add(Duration(days: 30))
        : _selectedPlan == 'yearly'
        ? DateTime.now().add(Duration(days: 365))
        : _selectedDate;

    setState(() {
      _isRenewing = true;
    });

    widget.onRenew(_selectedPlan, expiry);
  }
}


class TenantDetailsDialog extends StatelessWidget {
  final Tenant tenant;
  const TenantDetailsDialog({super.key, required this.tenant});

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
      ),
      backgroundColor: ThemeUtils.surface(context),
      child: Container(
        padding: EdgeInsets.all(20),
        constraints: BoxConstraints(maxWidth: 400),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title
            Text(
              'Tenant Details',
              style: ThemeUtils.headlineMedium(context),
            ),
            SizedBox(height: 8),
            Text(
              tenant.businessName,
              style: ThemeUtils.headlineLarge(context),
              overflow: TextOverflow.ellipsis,
            ),
            Divider(
              color: ThemeUtils.secondary(context),
              height: 24,
              thickness: 1,
            ),
            // Details
            _DetailRow(context, 'Subscription Plan', tenant.subscriptionPlan),
            _DetailRow(
              context,
              'Subscription Expiry',
              DateFormat('MMM dd, yyyy').format(tenant.subscriptionExpiry),
            ),
            _DetailRow(
              context,
              'Status',
              tenant.isSubscriptionActive ? 'Active' : 'Expired',
              valueColor: tenant.isSubscriptionActive
                  ? ThemeUtils.success(context)
                  : ThemeUtils.error(context),
            ),
            _DetailRow(
              context,
              'Primary Color',
              tenant.branding['primaryColor'] ?? 'Not set',
            ),
            _DetailRow(
              context,
              'Currency',
              Constants.CURRENCY_NAME
              // tenant.branding['currency'] ?? 'USD',

            ),
            SizedBox(height: 20),
            // Close button
            Align(
              alignment: Alignment.centerRight,
              child: InkWell(
                onTap: () => Navigator.pop(context),
                borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
                child: Container(
                  padding: EdgeInsets.symmetric(vertical: 12, horizontal: 20),
                  decoration: ThemeUtils.buttonDecoration(context),
                  child: Text(
                    'Close',
                    style: ThemeUtils.buttonText(context),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _DetailRow(
      BuildContext context,
      String title,
      String value, {
        Color? valueColor,
      }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 3,
            child: Text(
              '$title:',
              style: ThemeUtils.bodyMedium(context).copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          Expanded(
            flex: 5,
            child: Text(
              value,
              style: ThemeUtils.bodyMedium(context).copyWith(
                color: valueColor ?? ThemeUtils.textPrimary(context),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class CreateTenantDialog extends StatefulWidget {
  const CreateTenantDialog({super.key});

  @override
  _CreateTenantDialogState createState() => _CreateTenantDialogState();
}

class _CreateTenantDialogState extends State<CreateTenantDialog> {
  final _formKey = GlobalKey<FormState>();
  final _businessNameController = TextEditingController();
  final _adminEmailController = TextEditingController();
  final _adminPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedPlan = 'monthly';
  bool _isLoading = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final radius = ThemeUtils.radius(context);

    return Dialog(
      insetPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius)),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 500, // Makes dialog adaptive but not too wide
        ),
        child: SingleChildScrollView(
          child: Container(
            padding: EdgeInsets.all(16),
            decoration: ThemeUtils.cardDecoration(context),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Row(
                  children: [
                    Icon(Icons.add_business, color: ThemeUtils.primary(context)),
                    SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Create New Tenant',
                        style: ThemeUtils.headlineMedium(context),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 16),

                // Error Box
                if (_error != null)
                  Container(
                    width: double.infinity,
                    padding: EdgeInsets.all(12),
                    margin: EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: ThemeUtils.error(context).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(radius / 2),
                      border: Border.all(color: ThemeUtils.error(context)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.error, color: ThemeUtils.error(context), size: 20),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _error!,
                            style: ThemeUtils.bodyMedium(context).copyWith(
                              color: ThemeUtils.error(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Business Info
                      Text(
                        'Business Information',
                        style: ThemeUtils.bodyLarge(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: ThemeUtils.primary(context),
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildTextField(
                        controller: _businessNameController,
                        label: 'Business Name *',
                        hint: 'Enter business name',
                        icon: Icons.business,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter business name';
                          }
                          if (value.length < 2) {
                            return 'Business name must be at least 2 characters';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 16),

                      // Admin Account
                      Text(
                        'Admin Account',
                        style: ThemeUtils.bodyLarge(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: ThemeUtils.primary(context),
                        ),
                      ),
                      SizedBox(height: 12),
                      _buildTextField(
                        controller: _adminEmailController,
                        label: 'Admin Email *',
                        hint: 'admin@company.com',
                        icon: Icons.email,
                        keyboardType: TextInputType.emailAddress,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter admin email';
                          }
                          if (!AppUtils.isEmailValid(value)) {
                            return 'Please enter a valid email';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 12),
                      _buildTextField(
                        controller: _adminPasswordController,
                        label: 'Admin Password *',
                        hint: 'Enter password',
                        icon: Icons.lock,
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter password';
                          }
                          if (value.length < 6) {
                            return 'Password must be at least 6 characters';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 12),
                      _buildTextField(
                        controller: _confirmPasswordController,
                        label: 'Confirm Password *',
                        hint: 'Confirm password',
                        icon: Icons.lock_outline,
                        obscureText: true,
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please confirm password';
                          }
                          if (value != _adminPasswordController.text) {
                            return 'Passwords do not match';
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 20),

                      // Subscription Plan
                      Text(
                        'Subscription Plan',
                        style: ThemeUtils.bodyLarge(context).copyWith(
                          fontWeight: FontWeight.bold,
                          color: ThemeUtils.primary(context),
                        ),
                      ),
                      SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedPlan,
                        isExpanded: true,
                        decoration: InputDecoration(
                          labelText: 'Subscription Plan *',
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(radius / 2),
                          ),
                          prefixIcon: Icon(Icons.credit_card),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 16),
                        ),
                        items: [
                          DropdownMenuItem(
                            value: 'monthly',
                            child: Row(
                              children: [
                                Icon(Icons.calendar_today, color: Colors.blue),
                                SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Monthly', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text('\$29/month', style: TextStyle(fontSize: 12, color: Colors.grey)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          DropdownMenuItem(
                            value: 'yearly',
                            child: Row(
                              children: [
                                Icon(Icons.calendar_view_month, color: Colors.green),
                                SizedBox(width: 8),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text('Yearly', style: TextStyle(fontWeight: FontWeight.bold)),
                                    Text('\$299/year (Save 15%)', style: TextStyle(fontSize: 12, color: Colors.green)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                        selectedItemBuilder: (context) {
                          return ['monthly', 'yearly'].map((value) {
                            // Only single-line for the field display
                            return Row(
                              children: [
                                Icon(
                                  value == 'monthly' ? Icons.calendar_today : Icons.calendar_view_month,
                                  color: value == 'monthly' ? Colors.blue : Colors.green,
                                ),
                                SizedBox(width: 8),
                                Text(
                                  value == 'monthly' ? 'Monthly' : 'Yearly',
                                  style: TextStyle(fontWeight: FontWeight.bold),
                                ),
                              ],
                            );
                          }).toList();
                        },
                        onChanged: (value) => setState(() => _selectedPlan = value!),
                        validator: (value) {
                          if (value == null || value.isEmpty) return 'Please select a plan';
                          return null;
                        },
                      ),
                      SizedBox(height: 20),

                      // Plan Features
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: ThemeUtils.surface(context),
                          borderRadius: BorderRadius.circular(radius / 2),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('Plan Includes:', style: TextStyle(fontWeight: FontWeight.bold)),
                            SizedBox(height: 8),
                            _buildFeature('✓ Unlimited Products'),
                            _buildFeature('✓ Sales Management'),
                            _buildFeature('✓ User Management'),
                            _buildFeature('✓ Analytics Dashboard'),
                            _buildFeature('✓ Support Tickets'),
                            _buildFeature('✓ Custom Branding'),
                          ],
                        ),
                      ),
                      SizedBox(height: 20),

                      // Actions
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: _isLoading ? null : () => Navigator.pop(context),
                            child: Text('Cancel'),
                          ),
                          SizedBox(width: 12),
                          InkWell(
                            onTap: _isLoading ? null : _createTenant,
                            borderRadius: BorderRadius.circular(radius / 2),
                            child: Container(
                              padding: EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                              decoration: ThemeUtils.buttonDecoration(context),
                              child: _isLoading
                                  ? SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                                  : Text(
                                'Create Tenant',
                                style: ThemeUtils.buttonText(context),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    IconData? icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
    String? Function(String?)? validator,
  }) {
    final radius = ThemeUtils.radius(context);
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        prefixIcon: icon != null ? Icon(icon) : null,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(radius / 2)),
        contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      ),
    );
  }

  Widget _buildFeature(String text) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 2),
      child: Text(
        text,
        style: ThemeUtils.bodySmall(context),
      ),
    );
  }

  Future<void> _createTenant() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final tenantId =
          '${_businessNameController.text.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]'), '_')}_${DateTime.now().millisecondsSinceEpoch}';

      await SuperAdminService.createTenant(
        tenantId: tenantId,
        businessName: _businessNameController.text.trim(),
        adminEmail: _adminEmailController.text.trim(),
        adminPassword: _adminPasswordController.text,
        subscriptionPlan: _selectedPlan,
      );

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Tenant created successfully!'),
            ],
          ),
          backgroundColor: ThemeUtils.success(context),
          duration: Duration(seconds: 3),
        ),
      );

      Navigator.pop(context);

      final tenantProvider = Provider.of<TenantProvider>(context, listen: false);
      await tenantProvider.loadAllTenants();
    } catch (e) {
      setState(() {
        _error = 'Failed to create tenant: $e';
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _businessNameController.dispose();
    _adminEmailController.dispose();
    _adminPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;
  const _DetailRow(this.label, this.value);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Text('$label:', style: TextStyle(fontWeight: FontWeight.bold)),
          SizedBox(width: 8),
          Text(value),
        ],
      ),
    );
  }
}

class SuperAdminHome extends StatelessWidget {
  const SuperAdminHome({super.key});

  @override
  Widget build(BuildContext context) {
    final tenantProvider = Provider.of<TenantProvider>(context);

    return Padding(
      padding: EdgeInsets.all(16),
      child: Column(
        children: [
          // System Overview
          GridView.count(
            crossAxisCount: 3,
            shrinkWrap: true,
            childAspectRatio: 1.4,
            children: [
              _StatCard(
                'Total Tenants',
                tenantProvider.tenants.length.toString(),
                Icons.business,
                Colors.blue,
              ),
              _StatCard(
                'Active Tenants',
                tenantProvider.tenants
                    .where((t) => t.isSubscriptionActive)
                    .length
                    .toString(),
                Icons.check_circle,
                Colors.green,
              ),
              _StatCard(
                'Expired Tenants',
                tenantProvider.tenants
                    .where((t) => !t.isSubscriptionActive)
                    .length
                    .toString(),
                Icons.error,
                Colors.red,
              ),
            ],
          ),

          SizedBox(height: 20),

          // Quick Actions
          Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Actions',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 12),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    childAspectRatio: 3,
                    crossAxisSpacing: 7,
                    mainAxisSpacing: 7,
                    children: [
                      _ActionCard(
                        'Create Tenant',
                        Icons.add_business,
                        Colors.blue,
                            () {
                          showDialog(
                            context: context,
                            builder: (context) => CreateTenantDialog(),
                          );
                        },
                      ),
                      _ActionCard(
                        'View All Tenants',
                        Icons.list_alt,
                        Colors.green,
                            () {
                          // Navigate to tenants management
                          final superAdminState = context
                              .findAncestorStateOfType<
                              _SuperAdminDashboardState
                          >();
                          superAdminState?.setState(() {
                            superAdminState._currentIndex =
                            1; // Tenants tab index
                          });
                        },
                      ),
                      _ActionCard(
                        'System Analytics',
                        Icons.analytics,
                        Colors.orange,
                            () {
                          final superAdminState = context
                              .findAncestorStateOfType<
                              _SuperAdminDashboardState
                          >();
                          superAdminState?.setState(() {
                            superAdminState._currentIndex =
                            2; // Analytics tab index
                          });
                        },
                      ),
                      _ActionCard(
                        'Support Tickets',
                        Icons.support,
                        Colors.purple,
                            () {
                          final superAdminState = context
                              .findAncestorStateOfType<
                              _SuperAdminDashboardState
                          >();
                          superAdminState?.setState(() {
                            superAdminState._currentIndex =
                            3; // Support tab index
                          });
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          SizedBox(height: 20),

          // Recent Tenants
          Expanded(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'Recent Tenants',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Spacer(),
                        TextButton(
                          onPressed: () {
                            final superAdminState = context
                                .findAncestorStateOfType<
                                _SuperAdminDashboardState
                            >();
                            superAdminState?.setState(() {
                              superAdminState._currentIndex =
                              1; // Tenants tab index
                            });
                          },
                          child: Text('View All'),
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Expanded(
                      child: tenantProvider.tenants.isEmpty
                          ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.business,
                              size: 64,
                              color: Colors.grey,
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No Tenants Yet',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.grey,
                              ),
                            ),
                            SizedBox(height: 8),
                            ElevatedButton.icon(
                              onPressed: () {
                                showDialog(
                                  context: context,
                                  builder: (context) =>
                                      CreateTenantDialog(),
                                );
                              },
                              icon: Icon(Icons.add_business),
                              label: Text('Create First Tenant'),
                            ),
                          ],
                        ),
                      )
                          : ListView.builder(
                        itemCount: tenantProvider.tenants.take(5).length,
                        itemBuilder: (context, index) {
                          final tenant = tenantProvider.tenants[index];
                          return ListTile(
                            leading: Icon(
                              Icons.business,
                              color: tenant.isSubscriptionActive
                                  ? Colors.green
                                  : Colors.red,
                            ),
                            title: Text(tenant.businessName),
                            subtitle: Text(
                              '${tenant.subscriptionPlan} - ${DateFormat('MMM dd, yyyy').format(tenant.subscriptionExpiry)}',
                            ),
                            trailing: tenant.isSubscriptionActive
                                ? Chip(
                              label: Text(
                                'Active',
                                style: TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: Colors.green,
                            )
                                : Chip(
                              label: Text(
                                'Expired',
                                style: TextStyle(
                                  color: Colors.white,
                                ),
                              ),
                              backgroundColor: Colors.red,
                            ),
                            onTap: () {
                              // Show tenant details
                              showDialog(
                                context: context,
                                builder: (context) =>
                                    TenantDetailsDialog(tenant: tenant),
                              );
                            },
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class SuperAdminAnalyticsScreen extends StatefulWidget {
  const SuperAdminAnalyticsScreen({super.key});

  @override
  _SuperAdminAnalyticsScreenState createState() =>
      _SuperAdminAnalyticsScreenState();
}




class _SuperAdminAnalyticsScreenState extends State<SuperAdminAnalyticsScreen>
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  List<TenantAnalytics> _tenantsAnalytics = [];
  OverallAnalytics _overallAnalytics = OverallAnalytics.empty();
  bool _isLoading = true;
  String _timeFilter = '7days'; // 7days, 30days, 90days, 1year

  // Performance optimization variables
  double _loadingProgress = 0.0;
  int _completedTenants = 0;
  final Map<String, dynamic> _analyticsCache = {};
  DateTime _lastFetchTime = DateTime.now();
  final Duration _cacheDuration = Duration(minutes: 5);

  // Pagination variables
  final int _tenantsPerPage = 10;
  int _currentTenantsPage = 0;

  @override
  void initState() {
    super.initState();
    _initAnimations();
    _loadSuperAdminAnalytics();
  }

  void _initAnimations() {
    _animationController = AnimationController(
      duration: Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    _animationController.forward();
  }

  DateTime _calculateStartDate() {
    final now = DateTime.now();
    switch (_timeFilter) {
      case '7days':
        return now.subtract(Duration(days: 7));
      case '30days':
        return now.subtract(Duration(days: 30));
      case '90days':
        return now.subtract(Duration(days: 90));
      case '1year':
        return DateTime(now.year - 1, now.month, now.day);
      default:
        return now.subtract(Duration(days: 7));
    }
  }

  Future<void> _loadSuperAdminAnalytics() async {
    final cacheKey = 'analytics_$_timeFilter';
    final now = DateTime.now();

    // Return cached data if still valid
    if (_analyticsCache.containsKey(cacheKey) &&
        now.difference(_lastFetchTime) < _cacheDuration) {
      final cached = _analyticsCache[cacheKey];
      if (mounted) {
        setState(() {
          _overallAnalytics = cached['overall'];
          _tenantsAnalytics = cached['tenants'];
          _isLoading = false;
        });
      }
      return;
    }

    setState(() {
      _isLoading = true;
      _loadingProgress = 0.0;
      _completedTenants = 0;
      _currentTenantsPage = 0; // Reset pagination on refresh
    });

    try {
      final stopwatch = Stopwatch()..start();

      final overall = await _fetchOverallAnalytics();
      _trackPerformance('Fetch overall analytics', stopwatch.elapsed);

      stopwatch.reset();
      final tenants = await _fetchTenantsAnalytics();
      _trackPerformance('Fetch tenants analytics', stopwatch.elapsed);

      // Cache the results
      _analyticsCache[cacheKey] = {
        'overall': overall,
        'tenants': tenants,
      };
      _lastFetchTime = DateTime.now();

      if (mounted) {
        setState(() {
          _overallAnalytics = overall;
          _tenantsAnalytics = tenants;
          _isLoading = false;
          _loadingProgress = 1.0;
        });
      }
    } catch (e) {
     debugPrint('Error loading super admin analytics: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _trackPerformance(String operation, Duration duration) {
    if (duration.inMilliseconds > 1000) {
     debugPrint('Performance: $operation took ${duration.inMilliseconds}ms');
    }
  }

  Future<OverallAnalytics> _fetchOverallAnalytics() async {
    try {
      final tenantsSnapshot = await _firestore.collection('tenants').get();
      final allTenants = tenantsSnapshot.docs;

      if (allTenants.isEmpty) {
        return OverallAnalytics.empty();
      }

      final startDate = _calculateStartDate();
      final now = DateTime.now();

      // Update progress
      setState(() {
        _loadingProgress = 0.1;
      });

      // Use Future.wait to fetch all data in parallel
      final tenantDataFutures = allTenants.map((tenant) async {
        final tenantId = tenant.id;
        final tenantData = tenant.data();

        // Fetch all tenant data in parallel
        final [ordersSnapshot, productsSnapshot, customersSnapshot] = await Future.wait([
          _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('orders')
              .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
              .get(),
          _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('products')
              .where('status', isEqualTo: 'publish')
              .get(),
          _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('customers')
              .get(),
        ]);

        // Update progress
        if (mounted) {
          setState(() {
            _completedTenants++;
            _loadingProgress = 0.1 + (_completedTenants / allTenants.length) * 0.6;
          });
        }

        // Check subscription status
        final subscriptionExpiry = tenantData['subscriptionExpiry'];
        final isActive = subscriptionExpiry is Timestamp &&
            subscriptionExpiry.toDate().isAfter(now);

        // Calculate tenant revenue
        double tenantRevenue = 0.0;
        for (final order in ordersSnapshot.docs) {
          final orderData = order.data();
          tenantRevenue += (orderData['total'] as num?)?.toDouble() ?? 0.0;
        }

        return {
          'revenue': tenantRevenue,
          'orders': ordersSnapshot.docs.length,
          'products': productsSnapshot.docs.length,
          'customers': customersSnapshot.docs.length,
          'isActive': isActive,
        };
      }).toList();

      final tenantDataList = await Future.wait(tenantDataFutures);

      // Aggregate data
      double totalRevenue = 0.0;
      int totalOrders = 0;
      int totalProducts = 0;
      int totalCustomers = 0;
      int activeTenants = 0;

      for (final data in tenantDataList) {
        totalRevenue += data['revenue'] as double;
        totalOrders += data['orders'] as int;
        totalProducts += data['products'] as int;
        totalCustomers += data['customers'] as int;
        if (data['isActive'] as bool) activeTenants++;
      }

      return OverallAnalytics(
        totalRevenue: totalRevenue,
        totalOrders: totalOrders,
        totalProducts: totalProducts,
        totalCustomers: totalCustomers,
        activeTenants: activeTenants,
        expiredTenants: allTenants.length - activeTenants,
        totalTenants: allTenants.length,
        averageRevenuePerTenant: allTenants.isNotEmpty ? totalRevenue / allTenants.length : 0.0,
        timePeriod: _timeFilter,
        startDate: startDate,
      );
    } catch (e) {
     debugPrint('Error fetching overall analytics: $e');
      return OverallAnalytics.empty();
    }
  }

  Future<List<TenantAnalytics>> _fetchTenantsAnalytics() async {
    try {
      final tenantsSnapshot = await _firestore.collection('tenants').get();
      final List<TenantAnalytics> tenantsAnalytics = [];

      if (tenantsSnapshot.docs.isEmpty) {
        return tenantsAnalytics;
      }

      final startDate = _calculateStartDate();
      final now = DateTime.now();

      final tenantAnalyticsFutures = tenantsSnapshot.docs.map((tenant) async {
        final tenantId = tenant.id;
        final tenantData = tenant.data();

        // Fetch tenant-specific data in parallel
        final [ordersSnapshot, productsSnapshot, customersSnapshot] = await Future.wait([
          _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('orders')
              .where('dateCreated', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
              .get(),
          _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('products')
              .where('status', isEqualTo: 'publish')
              .get(),
          _firestore
              .collection('tenants')
              .doc(tenantId)
              .collection('customers')
              .get(),
        ]);

        // Calculate metrics
        double revenue = 0.0;
        for (final order in ordersSnapshot.docs) {
          final orderData = order.data();
          revenue += (orderData['total'] as num?)?.toDouble() ?? 0.0;
        }

        // Check subscription status
        final subscriptionExpiry = tenantData['subscriptionExpiry'];
        final bool isActive = subscriptionExpiry is Timestamp &&
            subscriptionExpiry.toDate().isAfter(now);

        return TenantAnalytics(
          tenantId: tenantId,
          businessName: tenantData['businessName']?.toString() ?? 'Unknown Business',
          subscriptionPlan: tenantData['subscriptionPlan']?.toString() ?? 'Unknown',
          isActive: isActive,
          revenue: revenue,
          ordersCount: ordersSnapshot.docs.length,
          productsCount: productsSnapshot.docs.length,
          customersCount: customersSnapshot.docs.length,
          subscriptionExpiry: subscriptionExpiry is Timestamp
              ? subscriptionExpiry.toDate()
              : null,
          startDate: startDate,
        );
      }).toList();

      final analyticsList = await Future.wait(tenantAnalyticsFutures);

      // Sort by revenue descending
      analyticsList.sort((a, b) => b.revenue.compareTo(a.revenue));
      return analyticsList;
    } catch (e) {
     debugPrint('Error fetching tenants analytics: $e');
      return [];
    }
  }

  void _onTimeFilterChanged(String? filter) {
    if (filter != null && filter != _timeFilter) {
      setState(() {
        _timeFilter = filter;
        _currentTenantsPage = 0; // Reset pagination
      });
      _loadSuperAdminAnalytics();
    }
  }

  List<TenantAnalytics> get _paginatedTenants {
    final startIndex = _currentTenantsPage * _tenantsPerPage;
    if (startIndex >= _tenantsAnalytics.length) {
      return [];
    }
    final endIndex = (startIndex + _tenantsPerPage).clamp(0, _tenantsAnalytics.length);
    return _tenantsAnalytics.sublist(startIndex, endIndex);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text('Super Admin Analytics'),
        backgroundColor: Colors.purple[700],
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
              onPressed: () {
                // Navigator.push(context, MaterialPageRoute(builder: (context) => SuperAdminSettingsScreen()));
              },
              icon: Icon(Icons.settings)
          ),
          PopupMenuButton<String>(
            onSelected: _onTimeFilterChanged,
            itemBuilder: (context) => [
              PopupMenuItem(value: '7days', child: Text('Last 7 Days')),
              PopupMenuItem(value: '30days', child: Text('Last 30 Days')),
              PopupMenuItem(value: '90days', child: Text('Last 90 Days')),
              PopupMenuItem(value: '1year', child: Text('Last 1 Year')),
            ],
            child: Padding(
              padding: EdgeInsets.all(8.0),
              child: Row(
                children: [
                  Text(_getTimeFilterDisplayName()),
                  Icon(Icons.arrow_drop_down),
                ],
              ),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh),
            onPressed: _loadSuperAdminAnalytics,
            tooltip: 'Refresh Analytics',
          ),
        ],
      ),
      body: _isLoading && _tenantsAnalytics.isEmpty
          ? _buildLoadingState()
          : RefreshIndicator(
        onRefresh: _loadSuperAdminAnalytics,
        child: AnimatedBuilder(
          animation: _animationController,
          builder: (context, child) {
            return Opacity(
              opacity: _fadeAnimation.value,
              child: CustomScrollView(
                slivers: [
                  _buildOverallStats(),
                  _buildTenantsList(),
                  SliverToBoxAdapter(child: SizedBox(height: 20)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            value: _isLoading && _loadingProgress > 0 ? _loadingProgress : null,
            valueColor: AlwaysStoppedAnimation(Colors.purple[700]!),
          ),
          SizedBox(height: 16),
          Text(
            'Loading Analytics... ${(_loadingProgress * 100).toStringAsFixed(0)}%',
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          if (_tenantsAnalytics.isNotEmpty)
            Text(
              'Processing $_completedTenants/${_tenantsAnalytics.length} tenants',
              style: TextStyle(fontSize: 12, color: Colors.grey[500]),
            ),
          SizedBox(height: 8),
          Text(
            'Data from ${DateFormat('MMM dd, yyyy').format(_calculateStartDate())} to ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
            style: TextStyle(fontSize: 12, color: Colors.grey[500]),
          ),
        ],
      ),
    );
  }

  Widget _buildOverallStats() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          children: [
            Text(
              'Overall Platform Analytics',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              '${DateFormat('MMM dd, yyyy').format(_overallAnalytics.startDate)} - ${DateFormat('MMM dd, yyyy').format(DateTime.now())}',
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 14,
              ),
            ),
            SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildStatCard(context,
                  'Total Revenue',
                  '${Constants.CURRENCY_NAME}${_overallAnalytics.totalRevenue.toStringAsFixed(0)}',
                  Icons.attach_money,
                  Colors.green,
                  'Across all tenants',
                ),
                _buildStatCard(context,
                  'Total Orders',
                  _overallAnalytics.totalOrders.toString(),
                  Icons.shopping_cart,
                  Colors.blue,
                  'Completed orders',
                ),
                _buildStatCard(context,
                  'Active Tenants',
                  '${_overallAnalytics.activeTenants}/${_overallAnalytics.totalTenants}',
                  Icons.business,
                  _overallAnalytics.activeTenants > 0
                      ? Colors.green
                      : Colors.orange,
                  'Active subscriptions',
                ),
                _buildStatCard(context,
                  'Platform Customers',
                  _overallAnalytics.totalCustomers.toString(),
                  Icons.people,
                  Colors.purple,
                  'Total customers',
                ),
              ],
            ),
            SizedBox(height: 16),
            GridView.count(
              shrinkWrap: true,
              physics: NeverScrollableScrollPhysics(),
              crossAxisCount: 2,
              crossAxisSpacing: 16,
              mainAxisSpacing: 16,
              childAspectRatio: 1.2,
              children: [
                _buildStatCard(context,
                  'Total Products',
                  _overallAnalytics.totalProducts.toString(),
                  Icons.inventory_2,
                  Colors.orange,
                  'Across platform',
                ),
                _buildStatCard(context,
                  'Avg Revenue/Tenant',
                  '${Constants.CURRENCY_NAME}${_overallAnalytics.averageRevenuePerTenant.toStringAsFixed(0)}',
                  Icons.trending_up,
                  Colors.teal,
                  'Average performance',
                ),
                _buildStatCard(context,
                  'Subscription Health',
                  '${((_overallAnalytics.activeTenants / _overallAnalytics.totalTenants) * 100).toStringAsFixed(1)}%',
                  Icons.health_and_safety,
                  _overallAnalytics.activeTenants /
                      _overallAnalytics.totalTenants >
                      0.7
                      ? Colors.green
                      : Colors.orange,
                  'Active rate',
                ),
                _buildStatCard(context,
                  'Time Period',
                  _getTimeFilterDisplayName(),
                  Icons.calendar_today,
                  Colors.indigo,
                  'Analysis period',
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
      BuildContext context,
      String title,
      String value,
      IconData icon,
      Color iconColor,
      String subtitle,
      ) {
    return AspectRatio(
      aspectRatio: 1,
      child: Container(
        constraints: BoxConstraints(
          minWidth: 120,
          minHeight: 120,
          maxWidth: 200,
          maxHeight: 200,
        ),
        decoration: ThemeUtils.cardDecoration(context),
        child: Padding(
          padding: EdgeInsets.all(ThemeUtils.radius(context) * 0.75),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(ThemeUtils.radius(context) * 0.5),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      iconColor.withOpacity(0.3),
                      iconColor.withOpacity(0.1),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                ),
                child: Icon(
                  icon,
                  size: ThemeUtils.radius(context) * 1.5,
                  color: iconColor,
                ),
              ),
              SizedBox(height: ThemeUtils.radius(context) * 0.5),
              Expanded(
                flex: 2,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    value,
                    style: ThemeUtils.headlineMedium(context).copyWith(
                      fontWeight: FontWeight.bold,
                      color: ThemeUtils.textPrimary(context),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ),
              SizedBox(height: ThemeUtils.radius(context) * 0.25),
              Expanded(
                flex: 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    title,
                    style: ThemeUtils.bodyMedium(context).copyWith(
                      fontWeight: FontWeight.w600,
                      color: ThemeUtils.textPrimary(context),
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
                ),
              ),
              SizedBox(height: ThemeUtils.radius(context) * 0.125),
              Expanded(
                flex: 1,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    subtitle,
                    style: ThemeUtils.bodySmall(context).copyWith(
                      color: ThemeUtils.textSecondary(context),
                      fontWeight: FontWeight.w400,
                    ),
                    textAlign: TextAlign.center,
                    maxLines: 2,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTenantsList() {
    final paginatedTenants = _paginatedTenants;
    final totalPages = (_tenantsAnalytics.length / _tenantsPerPage).ceil();
    final startIndex = _currentTenantsPage * _tenantsPerPage;

    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Tenant Performance Ranking',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.grey[800],
              ),
            ),
            SizedBox(height: 8),
            Text(
              'Showing ${startIndex + 1}-${startIndex + paginatedTenants.length} of ${_tenantsAnalytics.length} tenants (${_getTimeFilterDisplayName()})',
              style: TextStyle(color: Colors.grey[600]),
            ),
            SizedBox(height: 16),
            ...paginatedTenants.asMap().entries.map((entry) {
              final index = entry.key;
              final tenant = entry.value;
              final globalIndex = startIndex + index + 1;
              return _buildTenantCard(tenant, globalIndex);
            }),

            if (totalPages > 1) _buildPaginationControls(totalPages),
          ],
        ),
      ),
    );
  }

  Widget _buildPaginationControls(int totalPages) {
    return Padding(
      padding: EdgeInsets.only(top: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          IconButton(
            icon: Icon(Icons.arrow_back_ios),
            onPressed: _currentTenantsPage > 0 ? () {
              setState(() => _currentTenantsPage--);
            } : null,
          ),
          Text(
            'Page ${_currentTenantsPage + 1} of $totalPages',
            style: TextStyle(fontWeight: FontWeight.w500),
          ),
          IconButton(
            icon: Icon(Icons.arrow_forward_ios),
            onPressed: _currentTenantsPage < totalPages - 1 ? () {
              setState(() => _currentTenantsPage++);
            } : null,
          ),
        ],
      ),
    );
  }

  Widget _buildTenantCard(TenantAnalytics tenant, int rank) {
    return Card(
      margin: EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: EdgeInsets.all(16),
        child: Row(
          children: [
            // Rank
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                color: rank <= 3 ? Colors.amber : Colors.grey[300],
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text(
                  rank.toString(),
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: rank <= 3 ? Colors.white : Colors.grey[700],
                  ),
                ),
              ),
            ),
            SizedBox(width: 12),
            // Tenant Info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          tenant.businessName,
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tenant.isActive
                              ? Colors.green[100]
                              : Colors.red[100],
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          tenant.isActive ? 'Active' : 'Expired',
                          style: TextStyle(
                            color: tenant.isActive
                                ? Colors.green[800]
                                : Colors.red[800],
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 4),
                  Text(
                    'Plan: ${tenant.subscriptionPlan}',
                    style: TextStyle(color: Colors.grey[600], fontSize: 12),
                  ),
                  if (tenant.subscriptionExpiry != null)
                    Text(
                      'Expires: ${DateFormat('MMM dd, yyyy').format(tenant.subscriptionExpiry!)}',
                      style: TextStyle(color: Colors.grey[500], fontSize: 11),
                    ),
                  SizedBox(height: 4),
                  Text(
                    'Data from ${DateFormat('MMM dd, yyyy').format(tenant.startDate)}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 10),
                  ),
                ],
              ),
            ),
            SizedBox(width: 12),
            // Performance Metrics
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${Constants.CURRENCY_NAME}${tenant.revenue.toStringAsFixed(0)}',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                    color: Colors.green[700],
                  ),
                ),
                Text(
                  '${tenant.ordersCount} orders',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  '${tenant.productsCount} products',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                Text(
                  '${tenant.customersCount} customers',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  String _getTimeFilterDisplayName() {
    switch (_timeFilter) {
      case '7days':
        return 'Last 7 Days';
      case '30days':
        return 'Last 30 Days';
      case '90days':
        return 'Last 90 Days';
      case '1year':
        return 'Last 1 Year';
      default:
        return 'Last 7 Days';
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }
}

// Analytics Data Models
class OverallAnalytics {
  final double totalRevenue;
  final int totalOrders;
  final int totalProducts;
  final int totalCustomers;
  final int activeTenants;
  final int expiredTenants;
  final int totalTenants;
  final double averageRevenuePerTenant;
  final String timePeriod;
  final DateTime startDate;

  const OverallAnalytics({
    required this.totalRevenue,
    required this.totalOrders,
    required this.totalProducts,
    required this.totalCustomers,
    required this.activeTenants,
    required this.expiredTenants,
    required this.totalTenants,
    required this.averageRevenuePerTenant,
    required this.timePeriod,
    required this.startDate,
  });

  factory OverallAnalytics.empty() {
    final now = DateTime.now();
    return OverallAnalytics(
      totalRevenue: 0.0,
      totalOrders: 0,
      totalProducts: 0,
      totalCustomers: 0,
      activeTenants: 0,
      expiredTenants: 0,
      totalTenants: 0,
      averageRevenuePerTenant: 0.0,
      timePeriod: '7days',
      startDate: now.subtract(Duration(days: 7)),
    );
  }
}

class TenantAnalytics {
  final String tenantId;
  final String businessName;
  final String subscriptionPlan;
  final bool isActive;
  final double revenue;
  final int ordersCount;
  final int productsCount;
  final int customersCount;
  final DateTime? subscriptionExpiry;
  final DateTime startDate;

  const TenantAnalytics({
    required this.tenantId,
    required this.businessName,
    required this.subscriptionPlan,
    required this.isActive,
    required this.revenue,
    required this.ordersCount,
    required this.productsCount,
    required this.customersCount,
    this.subscriptionExpiry,
    required this.startDate,
  });
}

class _ActionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;

  const _ActionCard(this.title, this.icon, this.color, this.onTap);

  @override
  Widget build(BuildContext context) {
    final radius = ThemeUtils.radius(context);
    final textColor = ThemeUtils.textPrimary(context);
    final cardGradient = ThemeUtils.card(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final isCompact = constraints.maxWidth < 220;

        final padding = isCompact ? 8.0 : 12.0;
        final iconSize = isCompact ? 18.0 : 20.0;
        final fontSize = isCompact ? 13.0 : 14.0;
        final spacing = isCompact ? 8.0 : 12.0;

        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: cardGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(radius),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: ThemeUtils.cardElevation(context) * 2,
                offset: Offset(0, ThemeUtils.cardElevation(context)),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(radius),
              onTap: onTap,
              splashColor: color.withOpacity(0.2),
              highlightColor: Colors.transparent,
              child: Padding(
                padding: EdgeInsets.all(padding),
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(radius / 1.5),
                      ),
                      child: Icon(icon, size: iconSize, color: color),
                    ),
                    SizedBox(width: spacing),
                    Expanded(
                      child: Text(
                        title,
                        style: ThemeUtils.bodyMedium(context).copyWith(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w500,
                          color: textColor,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
// Analytics Data Models


class SuperAdminService{
  static final _firestore= FirebaseFirestore.instance;
  static Future<void> createSuperAdminUser({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    return await handleFirebaseCall(() async {
      // Create user in Firebase Auth
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      // Create super admin document
      await _firestore
          .collection('super_admins')
          .doc(userCredential.user!.uid)
          .set({
        'uid': userCredential.user!.uid,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'role': 'super_admin',
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'permissions': {
          'manage_tenants': true,
          'manage_system': true,
          'view_analytics': true,
          'manage_tickets': true,
        },
      });

      return;
    });
  }
  static DateTime _calculateExpiryDate(String plan) {
    final now = DateTime.now();
    switch (plan) {
      case 'monthly':
        return now.add(Duration(days: 30));
      case 'yearly':
        return now.add(Duration(days: 365));
      default:
        return now.add(Duration(days: 30));
    }
  }
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
  static Future<T> handleFirebaseCall<T>(Future<T> Function() call) async {
    try {
      return await call();
    } on FirebaseAuthException catch (e) {
      throw _handleFirebaseAuthError(e);
    } on FirebaseException catch (e) {
      throw _handleFirebaseError(e);
    } catch (e) {
      throw 'An unexpected error occurred: $e';
    }
  }
  static String _handleFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'email-already-in-use':
        return 'This email is already registered.';
      case 'invalid-email':
        return 'Please enter a valid email address.';
      case 'operation-not-allowed':
        return 'Email/password accounts are not enabled.';
      case 'weak-password':
        return 'Password is too weak. Please use a stronger password.';
      default:
        return 'Authentication error: ${e.message}';
    }
  }

  static String _handleFirebaseError(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return 'Access denied. Please check your permissions.';
      case 'not-found':
        return 'Requested data not found.';
      case 'already-exists':
        return 'Item already exists.';
      case 'resource-exhausted':
        return 'Quota exceeded. Please try again later.';
      case 'unavailable':
        return 'Service temporarily unavailable. Please check your connection.';
      case 'unauthenticated':
        return 'Please sign in to continue.';
      default:
        return 'An error occurred: ${e.message}';
    }
  }

  static Future<void> createTenant({
    required String tenantId,
    required String businessName,
    required String adminEmail,
    required String adminPassword,
    required String subscriptionPlan,
  }) async {
    return await handleFirebaseCall(() async {
      // Validate inputs
      if (adminPassword.length < 6) {
        throw 'Password must be at least 6 characters long';
      }

      if (!AppUtils.isEmailValid(adminEmail)) {
        throw 'Please enter a valid email address';
      }

      // Create tenant document
      await _firestore.collection('tenants').doc(tenantId).set({
        'businessName': businessName,
        'subscriptionPlan': subscriptionPlan,
        'subscriptionExpiry': _calculateExpiryDate(subscriptionPlan),
        'isActive': true,
        'createdAt': FieldValue.serverTimestamp(),
        'branding': {
          'primaryColor': '#2196F3',
          'secondaryColor': '#FF9800',
          'logoUrl': '',
          'currency': 'USD',
          'taxRate': 0.0,
        },
      });

      // Create admin user using the enhanced method
      await createUserWithDetails(
        tenantId: tenantId,
        email: adminEmail,
        password: adminPassword,
        displayName: 'Admin',
        role: 'clientAdmin',
        createdBy: 'system',
      );

      return;
    });
  }
  static final _auth = FirebaseAuth.instance;
  static Future<void> createUserWithDetails({
    required String tenantId,
    required String email,
    required String password,
    required String displayName,
    required String role,
    required String createdBy,
    String? phoneNumber,
    Map<String, dynamic>? profile,
    List<String>? permissions,
  }) async {
    return await handleFirebaseCall(() async {
      // Validate password length
      if (password.length < 6) {
        throw 'Password must be at least 6 characters long';
      }

      try {
        // Create user in Firebase Auth
        final UserCredential userCredential = await _auth
            .createUserWithEmailAndPassword(
          email: email.trim(),
          password: password,
        );

        // Update display name in Auth
        await userCredential.user!.updateDisplayName(displayName);

        // Create user document in tenant's users collection
        await _firestore
            .collection('tenants')
            .doc(tenantId)
            .collection('users')
            .doc(userCredential.user!.uid)
            .set({
          'uid': userCredential.user!.uid,
          'email': email.trim(),
          'displayName': displayName,
          'phoneNumber': phoneNumber,
          'role': role,
          'createdBy': createdBy,
          'createdAt': FieldValue.serverTimestamp(),
          'isActive': true,
          'tenantId': tenantId,
          'lastLogin': FieldValue.serverTimestamp(),
          'profile': profile ?? {},
          'permissions': permissions ?? _getDefaultPermissions(role),
        });

        // Log user creation activity
        await _logUserActivity(
          tenantId: tenantId,
          userId: userCredential.user!.uid,
          userEmail: email,
          userDisplayName: displayName,
          action: ActivityType.user_created,
          description: 'User account created by $createdBy',
          metadata: {'role': role, 'displayName': displayName},
        );
      } catch (e) {
        // If user creation fails in Firestore, delete the auth user
        if (_auth.currentUser != null &&
            _auth.currentUser!.email == email.trim()) {
          await _auth.currentUser!.delete();
        }
        rethrow;
      }

      return;
    });
  }
  static List<String> _getDefaultPermissions(String role) {
    switch (role) {
      case 'clientAdmin':
        return [
          'manage_users',
          'manage_products',
          'view_reports',
          'manage_sales',
        ];
      case 'salesInventoryManager':
        return ['manage_products', 'view_reports', 'manage_sales'];
      case 'cashier':
        return ['process_sales', 'view_products'];
      default:
        return ['view_products'];
    }
  }

  static Future<void> _logUserActivity({
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
     debugPrint('Failed to log activity: $e');
      // Don't throw error for failed activity logging
    }
  }
}
class SuperAdminManagementScreen extends StatefulWidget {
  const SuperAdminManagementScreen({super.key});

  @override
  _SuperAdminManagementScreenState createState() =>
      _SuperAdminManagementScreenState();
}


class _SuperAdminManagementScreenState extends State<SuperAdminManagementScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _firstNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  List<Map<String, dynamic>> _superAdmins = [];
  bool _isLoading = false;
  bool _isAddingAdmin = false;
  int _currentPageIndex = 0;

  @override
  void initState() {
    super.initState();
    _loadSuperAdmins();
  }

  Future<void> _loadSuperAdmins() async {
    if (mounted) {
      setState(() => _isLoading = true);
    }
    try {
      final admins = await SuperAdminSetup.getSuperAdmins();
      if (mounted) {
        setState(() => _superAdmins = admins);
      }
    } catch (e) {
      _showErrorSnackbar('Failed to load super admins: $e');
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: ThemeUtils.gradientBackground(context),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              _buildHeader(context),
              const SizedBox(height: 24),

              // Navigation Bar
              _buildNavigationBar(),
              const SizedBox(height: 24),

              // Content based on selected page
              Expanded(
                child: _buildCurrentPage(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              Icons.admin_panel_settings,
              size: 32,
              color: ThemeUtils.primary(context),
            ),
            const SizedBox(width: 12),
            Text(
              'Super Admin Management',
              style: ThemeUtils.headlineLarge(context).copyWith(
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          'Manage system administrators and system settings',
          style: ThemeUtils.bodyMedium(context).copyWith(
            color: ThemeUtils.textSecondary(context),
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationBar() {
    return Container(
      decoration: BoxDecoration(
        color: ThemeUtils.surface(context),
        borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        border: Border.all(color: ThemeUtils.secondary(context).withOpacity(0.2)),
      ),
      child: Row(
        children: [
          _buildNavItem(0, Icons.person_add, 'Add Admin'),
          _buildNavItem(1, Icons.people, 'View Admins'),
        ],
      ),
    );
  }

  Widget _buildNavItem(int index, IconData icon, String label) {
    final isSelected = _currentPageIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => setState(() => _currentPageIndex = index),
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
            decoration: BoxDecoration(
              color: isSelected ? ThemeUtils.primary(context).withOpacity(0.1) : Colors.transparent,
              borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
              border: isSelected ? Border.all(color: ThemeUtils.primary(context)) : null,
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: isSelected ? ThemeUtils.primary(context) : ThemeUtils.textSecondary(context),
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: ThemeUtils.bodyMedium(context).copyWith(
                    fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                    color: isSelected ? ThemeUtils.primary(context) : ThemeUtils.textSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCurrentPage() {
    return _currentPageIndex == 0 ? _buildAddAdminContent() : _buildViewAdminsContent();
  }

  Widget _buildAddAdminContent() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add New Super Admin',
            style: ThemeUtils.headlineMedium(context).copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 16),
          _buildAddAdminCard(context),
        ],
      ),
    );
  }

  Widget _buildViewAdminsContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Existing Super Admins',
              style: ThemeUtils.headlineMedium(context).copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 12),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
              decoration: BoxDecoration(
                color: ThemeUtils.primary(context).withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${_superAdmins.length}',
                style: ThemeUtils.bodySmall(context).copyWith(
                  color: ThemeUtils.primary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            IconButton(
              onPressed: _loadSuperAdmins,
              icon: Icon(Icons.refresh, color: ThemeUtils.primary(context)),
            ),
          ],
        ),
        const SizedBox(height: 16),
        Expanded(
          child: _isLoading
              ? _buildLoadingState()
              : _superAdmins.isEmpty
              ? _buildEmptyState()
              : _buildAdminsList(),
        ),
      ],
    );
  }

  Widget _buildAddAdminCard(BuildContext context) {
    return Container(
      decoration: ThemeUtils.cardDecoration(context),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          _buildFormFields(context),
          const SizedBox(height: 24),
          _buildAddButton(context),
        ],
      ),
    );
  }

  Widget _buildFormFields(BuildContext context) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                controller: _firstNameController,
                label: 'First Name',
                icon: Icons.person_outline,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _buildTextField(
                controller: _lastNameController,
                label: 'Last Name',
                icon: Icons.person_outline,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _emailController,
          label: 'Email Address',
          icon: Icons.email_outlined,
          keyboardType: TextInputType.emailAddress,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _passwordController,
          label: 'Password',
          icon: Icons.lock_outline,
          obscureText: true,
        ),
        const SizedBox(height: 16),
        _buildTextField(
          controller: _confirmPasswordController,
          label: 'Confirm Password',
          icon: Icons.lock_outline,
          obscureText: true,
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    bool obscureText = false,
    TextInputType keyboardType = TextInputType.text,
  }) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      keyboardType: keyboardType,
      style: ThemeUtils.bodyLarge(context),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: ThemeUtils.bodyMedium(context),
        prefixIcon: Icon(icon, color: ThemeUtils.primary(context)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
      ),
    );
  }

  Widget _buildAddButton(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      height: 54,
      child: _isAddingAdmin
          ? Center(
        child: CircularProgressIndicator(
          color: ThemeUtils.primary(context),
        ),
      )
          : ElevatedButton(
        onPressed: _addSuperAdmin,
        style: ElevatedButton.styleFrom(
          backgroundColor: ThemeUtils.primary(context),
          foregroundColor: ThemeUtils.textOnPrimary(context),
        ),
        child: Text('Add Super Admin'),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: ThemeUtils.primary(context),
          ),
          const SizedBox(height: 16),
          Text(
            'Loading super admins...',
            style: ThemeUtils.bodyMedium(context),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.admin_panel_settings_outlined,
            size: 64,
            color: ThemeUtils.textSecondary(context).withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            'No Super Admins Found',
            style: ThemeUtils.headlineMedium(context),
          ),
          const SizedBox(height: 8),
          Text(
            'Add the first super admin to get started',
            style: ThemeUtils.bodyMedium(context).copyWith(
              color: ThemeUtils.textSecondary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAdminsList() {
    return ListView.builder(
      itemCount: _superAdmins.length,
      itemBuilder: (context, index) {
        final admin = _superAdmins[index];
        return _buildAdminListTile(admin);
      },
    );
  }

  Widget _buildAdminListTile(Map<String, dynamic> admin) {
    final isActive = admin['isActive'] ?? false;
    final isCurrentUser = admin['uid'] == FirebaseAuth.instance.currentUser?.uid;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: ThemeUtils.surface(context),
        borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: ThemeUtils.primary(context),
          child: Icon(
            Icons.admin_panel_settings,
            color: Colors.white,
            size: 20,
          ),
        ),
        title: Text(
          '${admin['firstName']} ${admin['lastName']}',
          style: ThemeUtils.bodyLarge(context).copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(admin['email']),
            Text(
              'Created: ${_formatDate(admin['createdAt'])}',
              style: ThemeUtils.bodySmall(context).copyWith(
                color: ThemeUtils.textSecondary(context),
              ),
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isCurrentUser)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: ThemeUtils.primary(context).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'You',
                  style: ThemeUtils.bodySmall(context).copyWith(
                    color: ThemeUtils.primary(context),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            Switch(
              value: isActive,
              onChanged: isCurrentUser ? null : (value) => _toggleAdminStatus(admin, value),
              activeThumbColor: ThemeUtils.success(context),
            ),
          ],
        ),
        onTap: () => _showAdminDetails(admin),
      ),
    );
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return 'Unknown';
    if (timestamp is Timestamp) {
      return DateFormat('MMM dd, yyyy').format(timestamp.toDate());
    }
    return 'Unknown';
  }

  Future<void> _addSuperAdmin() async {
    if (_firstNameController.text.isEmpty ||
        _lastNameController.text.isEmpty ||
        _emailController.text.isEmpty ||
        _passwordController.text.isEmpty ||
        _confirmPasswordController.text.isEmpty) {
      _showErrorSnackbar('Please fill all fields');
      return;
    }

    if (_passwordController.text != _confirmPasswordController.text) {
      _showErrorSnackbar('Passwords do not match');
      return;
    }

    if (!AppUtils.isEmailValid(_emailController.text)) {
      _showErrorSnackbar('Please enter a valid email address');
      return;
    }

    setState(() => _isAddingAdmin = true);

    try {
      await SuperAdminService.createSuperAdminUser(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        firstName: _firstNameController.text.trim(),
        lastName: _lastNameController.text.trim(),
      );

      _emailController.clear();
      _passwordController.clear();
      _firstNameController.clear();
      _lastNameController.clear();
      _confirmPasswordController.clear();

      await _loadSuperAdmins();
      _showSuccessSnackbar('Super Admin added successfully!');
    } catch (e) {
      _showErrorSnackbar('Error: $e');
    } finally {
      if (mounted) {
        setState(() => _isAddingAdmin = false);
      }
    }
  }

  void _toggleAdminStatus(Map<String, dynamic> admin, bool value) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(value ? 'Activate Admin' : 'Deactivate Admin'),
        content: Text(
          value
              ? 'Are you sure you want to activate ${admin['firstName']} ${admin['lastName']}?'
              : 'Are you sure you want to deactivate ${admin['firstName']} ${admin['lastName']}?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _updateAdminStatus(admin, value);
            },
            child: Text('Confirm'),
          ),
        ],
      ),
    );
  }

  Future<void> _updateAdminStatus(Map<String, dynamic> admin, bool value) async {
    try {
      await FirebaseFirestore.instance
          .collection('super_admins')
          .doc(admin['uid'])
          .update({'isActive': value});

      await _loadSuperAdmins();
      _showSuccessSnackbar('Admin status updated successfully!');
    } catch (e) {
      _showErrorSnackbar('Failed to update admin status: $e');
    }
  }

  void _showAdminDetails(Map<String, dynamic> admin) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Admin Details'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Name: ${admin['firstName']} ${admin['lastName']}'),
            Text('Email: ${admin['email']}'),
            Text('Status: ${(admin['isActive'] ?? false) ? 'Active' : 'Inactive'}'),
            Text('Created: ${_formatDate(admin['createdAt'])}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showSuccessSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.green,
      ),
    );
  }

  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    _firstNameController.dispose();
    _lastNameController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }
}
// class SuperAdminSetupScreen extends StatefulWidget {
//   const SuperAdminSetupScreen({super.key});
//
//   @override
//   _SuperAdminSetupScreenState createState() => _SuperAdminSetupScreenState();
// }
//
// class _SuperAdminSetupScreenState extends State<SuperAdminSetupScreen> {
//   final _formKey = GlobalKey<FormState>();
//   final _emailController = TextEditingController();
//   final _passwordController = TextEditingController();
//   final _firstNameController = TextEditingController();
//   final _lastNameController = TextEditingController();
//   final _confirmPasswordController = TextEditingController();
//
//   bool _isLoading = false;
//   String? _error;
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       body: Container(
//         decoration: ThemeUtils.gradientBackground(context),
//         child: Center(
//           child: ConstrainedBox(
//             constraints: const BoxConstraints(maxWidth: 500),
//             child: SingleChildScrollView(
//               padding: const EdgeInsets.all(24),
//               child: Column(
//                 mainAxisSize: MainAxisSize.min,
//                 children: [
//                   // Header Section
//                   _buildHeaderSection(context),
//                   const SizedBox(height: 32),
//
//                   // Setup Form Card
//                   _buildSetupForm(context),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildHeaderSection(BuildContext context) {
//     return Column(
//       children: [
//         Container(
//           padding: const EdgeInsets.all(20),
//           decoration: BoxDecoration(
//             gradient: LinearGradient(
//               colors: ThemeUtils.accent(context),
//               begin: Alignment.topLeft,
//               end: Alignment.bottomRight,
//             ),
//             shape: BoxShape.circle,
//           ),
//           child: Icon(
//             Icons.admin_panel_settings,
//             size: 80,
//             color: ThemeUtils.textOnPrimary(context),
//           ),
//         ),
//         const SizedBox(height: 24),
//         Text(
//           'Super Admin Setup',
//           style: ThemeUtils.headlineLarge(context).copyWith(
//             fontSize: 32,
//             fontWeight: FontWeight.bold,
//           ),
//           textAlign: TextAlign.center,
//         ),
//         const SizedBox(height: 8),
//         Text(
//           'Create the master administrator account for your system',
//           style: ThemeUtils.bodyMedium(context).copyWith(
//             color: ThemeUtils.textSecondary(context),
//           ),
//           textAlign: TextAlign.center,
//         ),
//       ],
//     );
//   }
//
//   Widget _buildSetupForm(BuildContext context) {
//     return Container(
//       decoration: ThemeUtils.cardDecoration(context),
//       padding: const EdgeInsets.all(32),
//       child: Form(
//         key: _formKey,
//         child: Column(
//           mainAxisSize: MainAxisSize.min,
//           children: [
//             // Error Message
//             if (_error != null) _buildErrorSection(context),
//
//             // Form Fields
//             _buildFormFields(context),
//             const SizedBox(height: 24),
//
//             // Create Button
//             _buildCreateButton(context),
//             const SizedBox(height: 24),
//
//             // Permissions Info
//             _buildPermissionsInfo(context),
//           ],
//         ),
//       ),
//     );
//   }
//
//   Widget _buildErrorSection(BuildContext context) {
//     return Container(
//       width: double.infinity,
//       padding: const EdgeInsets.all(16),
//       margin: const EdgeInsets.only(bottom: 24),
//       decoration: BoxDecoration(
//         color: ThemeUtils.error(context).withOpacity(0.1),
//         borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
//         border: Border.all(color: ThemeUtils.error(context)),
//       ),
//       child: Row(
//         children: [
//           Icon(Icons.error_outline, color: ThemeUtils.error(context)),
//           const SizedBox(width: 12),
//           Expanded(
//             child: Text(
//               _error!,
//               style: ThemeUtils.bodyMedium(context).copyWith(
//                 color: ThemeUtils.error(context),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildFormFields(BuildContext context) {
//     return Column(
//       children: [
//         Row(
//           children: [
//             Expanded(
//               child: _buildFormField(
//                 context: context,
//                 controller: _firstNameController,
//                 label: 'First Name',
//                 icon: Icons.person_outline,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter first name';
//                   }
//                   return null;
//                 },
//               ),
//             ),
//             const SizedBox(width: 16),
//             Expanded(
//               child: _buildFormField(
//                 context: context,
//                 controller: _lastNameController,
//                 label: 'Last Name',
//                 icon: Icons.person_outline,
//                 validator: (value) {
//                   if (value == null || value.isEmpty) {
//                     return 'Please enter last name';
//                   }
//                   return null;
//                 },
//               ),
//             ),
//           ],
//         ),
//         const SizedBox(height: 16),
//         _buildFormField(
//           context: context,
//           controller: _emailController,
//           label: 'Email Address',
//           icon: Icons.email_outlined,
//           keyboardType: TextInputType.emailAddress,
//           validator: (value) {
//             if (value == null || value.isEmpty) {
//               return 'Please enter email address';
//             }
//             if (!AppUtils.isEmailValid(value)) {
//               return 'Please enter a valid email address';
//             }
//             return null;
//           },
//         ),
//         const SizedBox(height: 16),
//         _buildFormField(
//           context: context,
//           controller: _passwordController,
//           label: 'Password',
//           icon: Icons.lock_outline,
//           obscureText: true,
//           validator: (value) {
//             if (value == null || value.isEmpty) {
//               return 'Please enter password';
//             }
//             if (value.length < 8) {
//               return 'Password must be at least 8 characters';
//             }
//             return null;
//           },
//         ),
//         const SizedBox(height: 16),
//         _buildFormField(
//           context: context,
//           controller: _confirmPasswordController,
//           label: 'Confirm Password',
//           icon: Icons.lock_outline,
//           obscureText: true,
//           validator: (value) {
//             if (value == null || value.isEmpty) {
//               return 'Please confirm password';
//             }
//             if (value != _passwordController.text) {
//               return 'Passwords do not match';
//             }
//             return null;
//           },
//         ),
//       ],
//     );
//   }
//
//   Widget _buildFormField({
//     required BuildContext context,
//     required TextEditingController controller,
//     required String label,
//     required IconData icon,
//     bool obscureText = false,
//     TextInputType keyboardType = TextInputType.text,
//     String? Function(String?)? validator,
//   }) {
//     return TextFormField(
//       controller: controller,
//       obscureText: obscureText,
//       keyboardType: keyboardType,
//       validator: validator,
//       style: ThemeUtils.bodyLarge(context),
//       decoration: InputDecoration(
//         labelText: label,
//         labelStyle: ThemeUtils.bodyMedium(context),
//         prefixIcon: Icon(icon, color: ThemeUtils.primary(context)),
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
//           borderSide: BorderSide(color: ThemeUtils.secondary(context)),
//         ),
//         focusedBorder: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
//           borderSide: BorderSide(color: ThemeUtils.primary(context), width: 2),
//         ),
//         contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
//       ),
//     );
//   }
//
//   Widget _buildCreateButton(BuildContext context) {
//     return SizedBox(
//       width: double.infinity,
//       height: 54,
//       child: _isLoading
//           ? Container(
//         decoration: ThemeUtils.buttonDecoration(context),
//         child: Center(
//           child: SizedBox(
//             width: 24,
//             height: 24,
//             child: CircularProgressIndicator(
//               strokeWidth: 2,
//               valueColor: AlwaysStoppedAnimation<Color>(
//                 ThemeUtils.textOnPrimary(context),
//               ),
//             ),
//           ),
//         ),
//       )
//           : Material(
//         borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
//         child: InkWell(
//           onTap: _createSuperAdmin,
//           borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
//           child: Container(
//             decoration: ThemeUtils.buttonDecoration(context),
//             child: Center(
//               child: Row(
//                 mainAxisAlignment: MainAxisAlignment.center,
//                 children: [
//                   Icon(
//                     Icons.admin_panel_settings,
//                     color: ThemeUtils.textOnPrimary(context),
//                   ),
//                   const SizedBox(width: 12),
//                   Text(
//                     'Create Super Admin',
//                     style: ThemeUtils.buttonText(context).copyWith(
//                       fontSize: 16,
//                       fontWeight: FontWeight.w600,
//                     ),
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         ),
//       ),
//     );
//   }
//
//   Widget _buildPermissionsInfo(BuildContext context) {
//     return Container(
//       padding: const EdgeInsets.all(20),
//       decoration: BoxDecoration(
//         color: ThemeUtils.surface(context),
//         borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
//         border: Border.all(color: ThemeUtils.secondary(context).withOpacity(0.3)),
//       ),
//       child: Column(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Text(
//             'Super Admin Permissions:',
//             style: ThemeUtils.headlineMedium(context).copyWith(
//               fontSize: 16,
//               fontWeight: FontWeight.w600,
//             ),
//           ),
//           const SizedBox(height: 12),
//           _buildPermissionItem('Manage all tenants and subscriptions'),
//           _buildPermissionItem('Access system-wide analytics and reports'),
//           _buildPermissionItem('Manage support tickets and user issues'),
//           _buildPermissionItem('Configure system settings and preferences'),
//           _buildPermissionItem('Create and manage additional super admins'),
//           _buildPermissionItem('Monitor platform health and performance'),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildPermissionItem(String text) {
//     return Padding(
//       padding: const EdgeInsets.symmetric(vertical: 4),
//       child: Row(
//         crossAxisAlignment: CrossAxisAlignment.start,
//         children: [
//           Icon(
//             Icons.verified,
//             size: 16,
//             color: ThemeUtils.success(context),
//           ),
//           const SizedBox(width: 8),
//           Expanded(
//             child: Text(
//               text,
//               style: ThemeUtils.bodyMedium(context).copyWith(
//                 color: ThemeUtils.textSecondary(context),
//               ),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Future<void> _createSuperAdmin() async {
//     if (!_formKey.currentState!.validate()) {
//       return;
//     }
//
//     setState(() {
//       _isLoading = true;
//       _error = null;
//     });
//
//     try {
//       await SuperAdminService.createSuperAdminUser(
//         email: _emailController.text.trim(),
//         password: _passwordController.text,
//         firstName: _firstNameController.text.trim(),
//         lastName: _lastNameController.text.trim(),
//       );
//
//       // Show success message
//       ScaffoldMessenger.of(context).showSnackBar(
//         SnackBar(
//           content: Row(
//             children: [
//               Icon(Icons.check_circle, color: ThemeUtils.success(context)),
//               const SizedBox(width: 8),
//               Text('Super Admin created successfully!'),
//             ],
//           ),
//           backgroundColor: ThemeUtils.success(context),
//           behavior: SnackBarBehavior.floating,
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(ThemeUtils.radius(context)),
//           ),
//         ),
//       );
//
//       // Auto-login the new super admin
//       final authProvider = Provider.of<MyAuthProvider>(context, listen: false);
//       await authProvider.login(
//         _emailController.text.trim(),
//         _passwordController.text,
//       );
//     } catch (e) {
//       setState(() {
//         _error = 'Failed to create super admin: ${e.toString()}';
//       });
//     } finally {
//       if (mounted) {
//         setState(() {
//           _isLoading = false;
//         });
//       }
//     }
//   }
//
//   @override
//   void dispose() {
//     _emailController.dispose();
//     _passwordController.dispose();
//     _firstNameController.dispose();
//     _lastNameController.dispose();
//     _confirmPasswordController.dispose();
//     super.dispose();
//   }
// }

class SuperAdminSetup {
  static final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  static final FirebaseAuth _auth = FirebaseAuth.instance;

  // Method to create the first super admin
  static Future<void> createSuperAdmin({
    required String email,
    required String password,
    required String firstName,
    required String lastName,
  }) async {
    try {
     debugPrint('Starting super admin creation...');

      // Create user in Firebase Auth
      final UserCredential userCredential = await _auth
          .createUserWithEmailAndPassword(email: email, password: password);

      final User user = userCredential.user!;
     debugPrint('Firebase Auth user created: ${user.uid}');

      // Create super admin document
      await _firestore.collection('super_admins').doc(user.uid).set({
        'uid': user.uid,
        'email': email,
        'firstName': firstName,
        'lastName': lastName,
        'role': 'super_admin',
        'createdAt': FieldValue.serverTimestamp(),
        'isActive': true,
        'permissions': {
          'manage_tenants': true,
          'manage_system': true,
          'view_analytics': true,
          'manage_tickets': true,
        },
      });

     debugPrint('Super admin document created successfully!');
     debugPrint('Super Admin Details:');
     debugPrint('- Email: $email');
     debugPrint('- UID: ${user.uid}');
     debugPrint('- Name: $firstName $lastName');
    } catch (e) {
     debugPrint('Error creating super admin: $e');
      rethrow;
    }
  }

  // Check if any super admin exists
  static Future<bool> hasSuperAdmin() async {
    try {
      final snapshot = await _firestore
          .collection('super_admins')
          .limit(1)
          .get();
      return snapshot.docs.isNotEmpty;
    } catch (e) {
     debugPrint('Error checking super admin: $e');
      return false;
    }
  }

  // Get all super admins (for management)
  static Future<List<Map<String, dynamic>>> getSuperAdmins() async {
    try {
      final snapshot = await _firestore.collection('super_admins').get();
      return snapshot.docs.map((doc) => doc.data()).toList();
    } catch (e) {
     debugPrint('Error getting super admins: $e');
      return [];
    }
  }
}

// Enhanced Ticket Management System



class _StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _StatCard(this.title, this.value, this.icon, this.color);

  @override
  Widget build(BuildContext context) {
    final radius = ThemeUtils.radius(context);
    final textPrimary = ThemeUtils.textPrimary(context);
    final textSecondary = ThemeUtils.textSecondary(context);
    final accentColor = ThemeUtils.accentColor(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final height = constraints.maxHeight;
        final size = width < height ? width : height;

        // scale factors based on card size
        final iconSize = size * 0.25;
        final valueFontSize = size * 0.16;
        final titleFontSize = size * 0.10;
        final padding = size * 0.12;

        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          decoration: ThemeUtils.cardDecoration(context),
          child: InkWell(
            borderRadius: BorderRadius.circular(radius),
            splashColor: accentColor.withOpacity(0.15),
            onTap: () {},
            child: Padding(
              padding: EdgeInsets.all(padding.clamp(8, 20)),
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      fit: FlexFit.loose,
                      child: Icon(
                        icon,
                        size: iconSize.clamp(20, 60),
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Flexible(
                      fit: FlexFit.loose,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          value,
                          style: TextStyle(
                            fontSize: valueFontSize.clamp(14, 26),
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Flexible(
                      fit: FlexFit.loose,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          title,
                          style: TextStyle(
                            fontSize: titleFontSize.clamp(10, 18),
                            color: textSecondary.withOpacity(0.8),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
// this code is taking time in loading data from firestore and seems not to be so efficient and optimized
// do all the optimizations for all the data to make it efficient, enhanced, optimized, fast, and effective
// and provide me complete code without a skip in code, do provide me code from a to z
// without skipping, TODOs, placeholders or things like //existing
