import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../printing/printing_setting_screen.dart';
import '../providers/auth_provider.dart';
import '../providers/settings_provider.dart';
import '../constants/auth_strings.dart';
import '../constants/auth_measurements.dart';
import '../constants/auth_constants.dart';
import '../services/biometric_service.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final authProvider = context.watch<MyAuthProvider>();
    final settingsProvider = context.watch<SettingsProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text("Settings"),
        // actions: [
        //   IconButton(
        //     icon: const Icon(Icons.security),
        //     onPressed: settingsProvider.testBiometricAuth,
        //     tooltip: 'Test Biometric Authentication',
        //   ),
        // ],
      ),
      body: settingsProvider.loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
        children: [
          // Card(
          //   margin: const EdgeInsets.all(AuthMeasurements.innerPadding),
          //   child: Padding(
          //     padding: const EdgeInsets.all(AuthMeasurements.innerPadding),
          //     child: Column(
          //       crossAxisAlignment: CrossAxisAlignment.start,
          //       children: [
          //         Row(
          //           children: [
          //             Icon(
          //               Icons.biotech_rounded,
          //               color: theme.colorScheme.primary,
          //               size: AuthMeasurements.iconSizeSmall,
          //             ),
          //             const SizedBox(width: AuthMeasurements.spacingMedium),
          //             const Text(
          //               AuthStrings.biometricStatus,
          //               style: TextStyle(
          //                 fontSize: 18,
          //                 fontWeight: FontWeight.bold,
          //               ),
          //             ),
          //           ],
          //         ),
          //         const SizedBox(height: AuthMeasurements.spacingMedium),
          //         if (settingsProvider.availableBiometrics.isNotEmpty) ...[
          //           const Text(
          //             AuthStrings.availableBiometricMethods,
          //             style: TextStyle(fontWeight: FontWeight.w500),
          //           ),
          //           const SizedBox(height: AuthMeasurements.spacingSmall),
          //           Wrap(
          //             spacing: AuthMeasurements.spacingSmall,
          //             runSpacing: AuthMeasurements.spacingXSmall,
          //             children: settingsProvider.availableBiometrics
          //                 .map(
          //                   (type) => Chip(
          //                 label: Text(settingsProvider.getBiometricTypeName(type)),
          //                 avatar: Icon(
          //                   settingsProvider.getBiometricIcon(type),
          //                   size: 18,
          //                 ),
          //                 visualDensity: VisualDensity.compact,
          //               ),
          //             )
          //                 .toList(),
          //           ),
          //         ] else ...[
          //           const Text(
          //             AuthStrings.noBiometricMethods,
          //             style: TextStyle(color: Colors.grey),
          //           ),
          //         ],
          //       ],
          //     ),
          //   ),
          // ),
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AuthMeasurements.innerPadding,
              vertical: AuthMeasurements.spacingSmall,
            ),
            child: Column(
              children: [
                SwitchListTile(
                  title: const Text(
                    AuthStrings.enableAppLock,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                  subtitle: const Text(AuthStrings.appLockDescription),
                  secondary: const Icon(Icons.lock_rounded),
                  value: authProvider.appLockEnabled,
                  onChanged: (value) async {
                    settingsProvider.setLoading(true);

                    if (value) {
                      final isSupported = await BiometricService().isBiometricSupported();
                      if (!isSupported) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Device does not support biometric authentication'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        settingsProvider.setLoading(false);
                        return;
                      }

                      final canCheck = await BiometricService().canCheckBiometrics();
                      if (!canCheck) {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('No biometrics enrolled on this device'),
                            backgroundColor: Colors.orange,
                          ),
                        );
                        settingsProvider.setLoading(false);
                        return;
                      }

                      final didAuthenticate = await authProvider.authenticateForAppUnlock();
                      if (didAuthenticate) {
                        await authProvider.setAppLockEnabled(true);
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(AuthStrings.appLockEnabled),
                            backgroundColor: Colors.green,
                          ),
                        );
                      } else {
                        if (!mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Authentication failed - App lock not enabled'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    } else {
                      await authProvider.setAppLockEnabled(false);
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text(AuthStrings.appLockDisabled),
                          backgroundColor: Colors.blue,
                        ),
                      );
                    }

                    settingsProvider.setLoading(false);
                  },
                ),
                // if (authProvider.appLockEnabled) ...[
                //   const Divider(height: 1),
                //   ListTile(
                //     leading: const Icon(Icons.timer_rounded),
                //     title: const Text(AuthStrings.autoLockTimeout),
                //     subtitle: const Text(AuthStrings.autoLockDescription),
                //     trailing: const Icon(Icons.chevron_right_rounded),
                //     onTap: _showLockTimeoutDialog,
                //   ),
                //   const Divider(height: 1),
                //   ListTile(
                //     leading: const Icon(Icons.history_rounded),
                //     title: const Text(AuthStrings.lastUnlock),
                //     subtitle: authProvider.lastUnlockTime != null
                //         ? Text(
                //       DateFormat('MMM dd, yyyy - HH:mm').format(authProvider.lastUnlockTime!),
                //     )
                //         : const Text(AuthStrings.neverUnlocked),
                //     trailing: IconButton(
                //       icon: const Icon(Icons.refresh_rounded),
                //       onPressed: () async {
                //         final success = await authProvider.authenticateForAppUnlock();
                //         if (!mounted) return;
                //         ScaffoldMessenger.of(context).showSnackBar(
                //           SnackBar(
                //             content: Text(
                //               success
                //                   ? AuthStrings.reauthenticatedSuccess
                //                   : AuthStrings.reauthenticatedFailed,
                //             ),
                //             backgroundColor: success ? Colors.green : Colors.red,
                //           ),
                //         );
                //       },
                //       tooltip: 'Re-authenticate',
                //     ),
                //   ),
                // ],
              ],
            ),
          ),
          // Card(
          //   margin: const EdgeInsets.symmetric(
          //     horizontal: AuthMeasurements.innerPadding,
          //     vertical: AuthMeasurements.spacingSmall,
          //   ),
          //   child: Column(
          //     children: [
          //       const ListTile(
          //         leading: Icon(Icons.enhanced_encryption_rounded),
          //         title: Text(
          //           AuthStrings.securityFeatures,
          //           style: TextStyle(fontWeight: FontWeight.w600),
          //         ),
          //       ),
          //       const Divider(height: 1),
          //       SwitchListTile(
          //         title: const Text(AuthStrings.requireBiometricOnResume),
          //         subtitle: const Text(AuthStrings.requireBiometricDescription),
          //         secondary: const Icon(Icons.smartphone_rounded),
          //         value: authProvider.appLockEnabled,
          //         onChanged: authProvider.appLockEnabled
          //             ? (value) {
          //           ScaffoldMessenger.of(context).showSnackBar(
          //             const SnackBar(
          //               content: Text(AuthStrings.featureComingSoon),
          //             ),
          //           );
          //         }
          //             : null,
          //       ),
          //       const Divider(height: 1),
          //       SwitchListTile(
          //         title: const Text(AuthStrings.biometricFallbackToPin),
          //         subtitle: const Text(AuthStrings.fallbackDescription),
          //         secondary: const Icon(Icons.pin_rounded),
          //         value: false,
          //         onChanged: (value) {
          //           ScaffoldMessenger.of(context).showSnackBar(
          //             const SnackBar(
          //               content: Text(AuthStrings.featureComingSoon),
          //             ),
          //           );
          //         },
          //       ),
          //     ],
          //   ),
          // ),
          Card(
            margin: const EdgeInsets.symmetric(
              horizontal: AuthMeasurements.innerPadding,
              vertical: AuthMeasurements.spacingSmall,
            ),
            child: Column(
              children: [
                const ListTile(
                  leading: Icon(Icons.quickreply_rounded),
                  title: Text(
                    AuthStrings.quickActions,
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.security_update_good_rounded),
                  title: const Text(AuthStrings.testBiometricNow),
                  subtitle: const Text(AuthStrings.testBiometricDescription),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: settingsProvider.testBiometricAuth,
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.lock_reset_rounded),
                  title: const Text(AuthStrings.forceAppLock),
                  subtitle: const Text(AuthStrings.forceAppLockDescription),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () async {
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.remove('lastUnlockTime');
                    if (!mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(AuthStrings.appWillLock),
                        backgroundColor: Colors.blue,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
          if (authProvider.appLockEnabled) ...[
            Container(
              margin: const EdgeInsets.all(AuthMeasurements.innerPadding),
              padding: const EdgeInsets.all(AuthMeasurements.innerPadding),
              decoration: BoxDecoration(
                color: Colors.green.withOpacity(AuthMeasurements.opacityLow),
                borderRadius: BorderRadius.circular(AuthMeasurements.borderRadiusMedium),
                border: Border.all(color: Colors.green.withOpacity(AuthMeasurements.opacityMedium)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.verified_user_rounded,
                        color: Colors.green[700],
                        size: AuthMeasurements.iconSizeSmall,
                      ),
                      const SizedBox(width: AuthMeasurements.spacingSmall),
                      const Text(
                        AuthStrings.appLockActive,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AuthMeasurements.spacingSmall),
                  const Text(
                    AuthStrings.appLockActiveDescription,
                    style: TextStyle(fontSize: 14),
                  ),
                  const SizedBox(height: AuthMeasurements.spacingSmall),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green,
                      ),
                      SizedBox(width: AuthMeasurements.spacingSmall),
                      Expanded(
                        child: Text(AuthStrings.appLockCondition1),
                      ),
                    ],
                  ),
                  const SizedBox(height: AuthMeasurements.spacingXSmall),
                  const Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.check_circle,
                        size: 16,
                        color: Colors.green,
                      ),
                      SizedBox(width: AuthMeasurements.spacingSmall),
                      Expanded(
                        child: Text(AuthStrings.appLockCondition2),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
          InkWell(
            onTap: (){
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => InvoiceSettingsScreen(),
                ),
              );

            },
            child: Card(
              child: Center(child: Text("Invoicing"),),
              margin: const EdgeInsets.symmetric(
                horizontal: AuthMeasurements.innerPadding,
                vertical: AuthMeasurements.spacingSmall,
              ),

            ),
          ),

        ],

      ),
    );
  }

  Future<void> _showLockTimeoutDialog() async {
    final authProvider = context.read<MyAuthProvider>();
    final prefs = await SharedPreferences.getInstance();
    final currentTimeout = prefs.getInt('lockTimeout') ?? AuthConstants.defaultLockTimeout;

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
                const SizedBox(height: AuthMeasurements.spacingXLarge),
                Text(
                  '$currentTimeout seconds',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.blue,
                  ),
                ),
                const SizedBox(height: AuthMeasurements.spacingMedium),
                Slider(
                  value: currentTimeout.toDouble(),
                  min: AuthConstants.minLockTimeout.toDouble(),
                  max: AuthConstants.maxLockTimeout.toDouble(),
                  divisions: (AuthConstants.maxLockTimeout - AuthConstants.minLockTimeout) ~/ 10,
                  label: '$currentTimeout seconds',
                  onChanged: (value) {
                    setDialogState(() {});
                  },
                  onChangeEnd: (value) async {
                    await authProvider.setLockTimeout(value.toInt());
                    if (!mounted) return;
                    Navigator.of(context).pop();
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Auto lock timeout set to ${value.toInt()} seconds'),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AuthMeasurements.spacingMedium),
                Text(
                  '${AuthConstants.minLockTimeout} sec - ${AuthConstants.maxLockTimeout ~/ 60} min',
                  style: const TextStyle(fontSize: 12, color: Colors.grey),
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
                  await authProvider.setLockTimeout(currentTimeout);
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
}