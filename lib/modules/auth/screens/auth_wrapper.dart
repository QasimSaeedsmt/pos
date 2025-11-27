import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart' hide AuthProvider;
import 'package:package_info_plus/package_info_plus.dart';

import '../../../features/main_navigation/main_navigation_base.dart';
import '../../../features/super_admin/super_admin_base.dart';
import '../constants/auth_measurements.dart';
import '../models/tenant_model.dart';
import '../providers/auth_provider.dart';
import '../repositories/auth_repository.dart';

import '../subscription_expired_screen.dart';
import 'login_screen.dart';
import 'splash_screen.dart';
import 'account_disabled_screen.dart';
import 'app_lock_screen.dart';

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  static final Future<bool> _superAdminFuture =
  AuthRepository.checkSuperAdminExists();

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _isCheckingUpdate = false;
  bool _updateAvailable = false;
  bool _isDownloading = false;
  static const MethodChannel _apkChannel = MethodChannel('apk_install');

  final StreamController<double> _progressStreamController =
  StreamController<double>.broadcast();

  @override
  void initState() {
    super.initState();
    _initializeApp();
  }

  @override
  void dispose() {
    _progressStreamController.close();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      try {
        await Future.delayed(const Duration(milliseconds: 1000));
        if (mounted) {
          await _checkForUpdate();
        }
      } catch (e) {
        debugPrint("Update check initialization failed: $e");
      }
    });
  }

  Future<void> _checkForUpdate() async {
    if (_isCheckingUpdate) return;

    setState(() {
      _isCheckingUpdate = true;
    });

    try {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        debugPrint("📶 No internet connection for update check");
        return;
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;
      final buildNumber = packageInfo.buildNumber;

      debugPrint("🔍 Checking for updates...");
      debugPrint("📱 Current version: $currentVersion+$buildNumber");

      final response = await http.get(
        Uri.parse('https://vetsall.com/wp-content/uploads/app/update.json'),
      ).timeout(const Duration(seconds: 30));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final latestVersion = data["latest_version"] as String;
        final apkUrl = data["apk_url"] as String;
        final message = data["message"] as String? ??
            "A new update is available. Please update to continue using the app.";

        debugPrint("📦 Latest version available: $latestVersion");

        if (_isVersionNewer(latestVersion, currentVersion)) {
          setState(() {
            _updateAvailable = true;
          });

          if (mounted) {
            _showUpdateDialog(context, message, apkUrl);
          }
        } else {
          debugPrint("✅ App is up to date");
        }
      } else {
        debugPrint("❌ Update check failed with status: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("❌ Error checking update: $e");
    } finally {
      if (mounted) {
        setState(() {
          _isCheckingUpdate = false;
        });
      }
    }
  }

  bool _isVersionNewer(String serverVersion, String localVersion) {
    try {
      final String cleanLocalVersion = localVersion.split('+').first;
      final String cleanServerVersion = serverVersion.split('+').first;

      debugPrint(
          "🔄 Comparing versions - Local: $cleanLocalVersion, Server: $cleanServerVersion");

      final serverParts = cleanServerVersion.split('.').map(int.parse).toList();
      final localParts = cleanLocalVersion.split('.').map(int.parse).toList();

      while (serverParts.length < 3) serverParts.add(0);
      while (localParts.length < 3) localParts.add(0);

      for (int i = 0; i < 3; i++) {
        if (serverParts[i] > localParts[i]) return true;
        if (serverParts[i] < localParts[i]) return false;
      }
      return false;
    } catch (e) {
      debugPrint("❌ Version comparison error: $e");
      return false;
    }
  }

  void _showUpdateDialog(BuildContext context, String message, String apkUrl) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => WillPopScope(
        onWillPop: () async => false,
        child: AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.system_update, color: Colors.blue),
              SizedBox(width: 8),
              Text(
                "Update Required",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message,
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 16),
              const Text(
                "Update size: ~93 MB",
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                  color: Colors.blue,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                "The update will download and install automatically. Please ensure you have a stable internet connection.",
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey,
                ),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _downloadAndInstallApk(apkUrl);
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  "UPDATE NOW",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                child: const Text(
                  "LATER",
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
            ),
          ],
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),
    );
  }

  void _showDownloadProgressDialog(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return WillPopScope(
          onWillPop: () async => false,
          child: AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.download, color: Colors.blue),
                SizedBox(width: 8),
                Text(
                  "Downloading Update",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: StreamBuilder<double>(
              stream: _progressStreamController.stream,
              builder: (context, snapshot) {
                final progress = snapshot.data ?? 0.0;
                final hasError = snapshot.hasError;

                if (hasError) {
                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.error, color: Colors.red, size: 48),
                      const SizedBox(height: 16),
                      const Text(
                        "Download Failed",
                        style: TextStyle(
                          color: Colors.red,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Error: ${snapshot.error}",
                        style: const TextStyle(color: Colors.red, fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        "Please check your internet connection and try again.",
                        style: TextStyle(fontSize: 12),
                        textAlign: TextAlign.center,
                      ),
                    ],
                  );
                }

                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Downloading update (93 MB)...",
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 20),
                    LinearProgressIndicator(
                      value: progress,
                      backgroundColor: Colors.grey[300],
                      valueColor: AlwaysStoppedAnimation<Color>(Colors.blue),
                      minHeight: 10,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      "${(progress * 100).toStringAsFixed(1)}%",
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.blue,
                      ),
                    ),
                    const SizedBox(height: 8),
                    if (progress > 0 && progress < 1)
                      Text(
                        _getDownloadStatus(progress),
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.grey,
                        ),
                      ),
                    if (progress == 1.0)
                      const Column(
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green, size: 18),
                              SizedBox(width: 8),
                              Text(
                                "Download Complete!",
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.green,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: 4),
                          Text(
                            "Installing update...",
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.grey,
                            ),
                          ),
                        ],
                      ),
                  ],
                );
              },
            ),
            actions: [
              TextButton(
                onPressed: _isDownloading
                    ? () {
                  setState(() {
                    _isDownloading = false;
                  });
                  Navigator.of(context).pop();
                }
                    : null,
                child: const Text("CANCEL DOWNLOAD"),
              ),
            ],
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      },
    );
  }

  String _getDownloadStatus(double progress) {
    if (progress == 0) return "Starting download...";
    if (progress < 0.1) return "Initializing...";
    if (progress < 0.25) return "Downloading...";
    if (progress < 0.5) return "Getting there...";
    if (progress < 0.75) return "Almost halfway...";
    if (progress < 0.9) return "Nearly complete...";
    if (progress < 1.0) return "Finalizing...";
    return "Complete!";
  }

  Future<void> _downloadAndInstallApk(String url) async {
    http.Client? client;
    IOSink? sink;
    File? file;

    try {
      debugPrint("🔽 Starting APK download from: $url");
      debugPrint("📦 File size: ~93 MB");

      final storageStatus = await Permission.storage.status;
      if (storageStatus.isDenied) {
        await Permission.storage.request();
      }

      final installStatus = await Permission.requestInstallPackages.status;
      if (installStatus.isDenied) {
        await Permission.requestInstallPackages.request();
      }

      final Directory dir = await getTemporaryDirectory();
      final String filePath =
          "${dir.path}/mpcm_update_${DateTime.now().millisecondsSinceEpoch}.apk";

      debugPrint("📁 Saving APK to: $filePath");

      if (mounted) {
        _showDownloadProgressDialog(context, url);
      }

      setState(() {
        _isDownloading = true;
      });

      _progressStreamController.add(0.0);

      client = http.Client();
      file = File(filePath);

      final request = http.Request('GET', Uri.parse(url));
      request.headers['User-Agent'] = 'Mozilla/5.0 (Linux; Android 10; Mobile) AppleWebKit/537.36';
      request.headers['Accept'] = '*/*';
      request.headers['Accept-Encoding'] = 'gzip, deflate';
      request.headers['Connection'] = 'keep-alive';

      final response = await client.send(request).timeout(
        const Duration(minutes: 15),
        onTimeout: () {
          throw TimeoutException('Download timed out after 15 minutes');
        },
      );

      if (response.statusCode == 200) {
        final int contentLength = response.contentLength ?? 93 * 1024 * 1024;
        int receivedLength = 0;
        int lastUpdateTime = DateTime.now().millisecondsSinceEpoch;

        debugPrint("📊 Total file size: ${(contentLength / (1024 * 1024)).toStringAsFixed(1)} MB");

        sink = file.openWrite();

        await for (final chunk in response.stream) {
          if (!_isDownloading) {
            debugPrint("❌ Download cancelled by user");
            await sink.close();
            await file.delete();
            return;
          }

          receivedLength += chunk.length;
          sink.add(chunk);

          final currentTime = DateTime.now().millisecondsSinceEpoch;
          if (contentLength > 0 && (currentTime - lastUpdateTime > 100 || receivedLength == contentLength)) {
            final progress = receivedLength / contentLength;
            _progressStreamController.add(progress);

            if ((progress * 100) % 5 < 0.1 || progress == 1.0) {
              debugPrint("📥 Download progress: ${(progress * 100).toStringAsFixed(1)}% "
                  "(${(receivedLength / (1024 * 1024)).toStringAsFixed(1)}MB/"
                  "${(contentLength / (1024 * 1024)).toStringAsFixed(1)}MB)");
            }

            lastUpdateTime = currentTime;
          }
        }

        await sink.close();
        debugPrint("✅ APK downloaded successfully: ${file.lengthSync()} bytes");

        setState(() {
          _isDownloading = false;
        });

        _progressStreamController.add(1.0);

        final fileSize = await file.length();
        if (await file.exists() && fileSize > 10 * 1024 * 1024) {
          debugPrint("📦 File verified, size: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB");

          await Future.delayed(const Duration(seconds: 2));

          if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
            Navigator.of(context, rootNavigator: true).pop();
          }

          await _installApk(filePath);
        } else {
          throw Exception("Downloaded file is too small or corrupted: ${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB");
        }
      } else {
        throw Exception("HTTP ${response.statusCode}: ${response.reasonPhrase}");
      }
    } catch (e, stack) {
      debugPrint("❌ APK DOWNLOAD/INSTALL ERROR: $e");
      debugPrint("Stack trace: $stack");

      try {
        await sink?.close();
        await file?.delete();
      } catch (cleanupError) {
        debugPrint("Cleanup error: $cleanupError");
      }

      setState(() {
        _isDownloading = false;
      });

      _progressStreamController.addError(e.toString());

      await Future.delayed(const Duration(seconds: 2));

      if (mounted && Navigator.of(context, rootNavigator: true).canPop()) {
        Navigator.of(context, rootNavigator: true).pop();
      }

      if (mounted) {
        _showRetryDialog(url, e.toString());
      }
    } finally {
      client?.close();
    }
  }

  Future<void> _installApk(String filePath) async {
    try {
      debugPrint("🔧 Installing APK from: $filePath");

      final result = await _apkChannel.invokeMethod('installApk', {'path': filePath});
      debugPrint("📲 Installation result: $result");
    } on PlatformException catch (e) {
      debugPrint("❌ Platform error during installation: ${e.message}");
      throw Exception("Installation failed: ${e.message}");
    } catch (e) {
      debugPrint("❌ Installation error: $e");
      throw Exception("Installation failed: $e");
    }
  }

  void _showRetryDialog(String url, String error) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text("Download Failed"),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("The update couldn't be downloaded."),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                error.length > 150 ? '${error.substring(0, 150)}...' : error,
                style: const TextStyle(fontSize: 10, fontFamily: 'monospace'),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              "This might be due to:\n• Unstable internet connection\n• Server issues\n• File size too large\n\nPlease try again with a stable Wi-Fi connection.",
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text("CANCEL"),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              _downloadAndInstallApk(url);
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blue,
              foregroundColor: Colors.white,
            ),
            child: const Text("TRY AGAIN"),
          ),
        ],
      ),
    );
  }

  // ------------------------------
  // AUTH FLOW
  // ------------------------------

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<MyAuthProvider>(context);

    return FutureBuilder<bool>(
      future: AuthWrapper._superAdminFuture,
      builder: (context, superAdminSnapshot) {
        if (superAdminSnapshot.connectionState == ConnectionState.waiting) {
          return const SplashScreen();
        }

        return StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, userSnapshot) {
            final user = authProvider.currentUser;
            final tenant = authProvider.currentTenant;
            final subscriptionState = authProvider.subscriptionState;

            if (userSnapshot.connectionState == ConnectionState.waiting ||
                authProvider.isLoading) {
              return const SplashScreen();
            }

            // CRITICAL: Handle subscription states BEFORE checking logged-in user
            if (subscriptionState == SubscriptionState.expired) {
              return const SubscriptionExpiredScreen();
            }

            if (subscriptionState == SubscriptionState.tenantInactive) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.business, size: 64, color: Colors.red),
                      SizedBox(height: 16),
                      Text(
                        'Account Inactive',
                        style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'This business account is no longer active.',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 24),
                      ElevatedButton(
                        onPressed: () {
                          authProvider.logout();
                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(builder: (_) => const LoginScreen()),
                                (route) => false,
                          );
                        },
                        child: Text('Return to Login'),
                      ),
                    ],
                  ),
                ),
              );
            }

            // Logged-in user - only proceed if subscription is valid
            if ((userSnapshot.hasData && user != null) ||
                (authProvider.isOfflineMode && user != null)) {

              if (!user.isActive) return const AccountDisabledScreen();

              // Show offline mode snackbar
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

              // Show subscription warning if expiring soon
              if (authProvider.showSubscriptionWarning && tenant != null) {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Row(
                        children: [
                          Icon(Icons.warning, color: Colors.orange[300]),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Subscription expiring in ${tenant.daysUntilExpiry} days',
                              style: TextStyle(fontWeight: FontWeight.w500),
                            ),
                          ),
                        ],
                      ),
                      backgroundColor: Colors.orange[800],
                      duration: const Duration(seconds: 5),
                      action: SnackBarAction(
                        label: 'Dismiss',
                        onPressed: () {
                          authProvider.dismissSubscriptionWarning();
                        },
                      ),
                    ),
                  );
                });
              }

              // Check if app lock should be shown
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

                  // Navigate based on super admin flag
                  return user.isSuperAdmin
                      ? const SuperAdminDashboard()
                      : const MainNavScreen();
                },
              );
            }

            // Not logged in
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
      return await authProvider.isAppLockRequired();
    } catch (e) {
      debugPrint("App lock error: $e");
      return true;
    }
  }
}