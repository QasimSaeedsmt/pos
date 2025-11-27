// app.dart - Optimized Multi-Tenant SaaS System
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'package:hive/hive.dart';
import 'checkou_screen.dart';
import 'firebase_options.dart';
import 'modules/auth/providers/auth_provider.dart';
import 'modules/auth/providers/settings_provider.dart';
import 'modules/auth/screens/auth_wrapper.dart';
import 'modules/auth/services/offline_storage_service.dart';
import 'modules/auth/widgets/app_lifecycle_wrapper.dart';
import 'theme_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Run app immediately with a loading screen
  runApp(const LoadingApp());

  await _initializeApp();
}

Future<void> _initializeApp() async {
  try {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Activate Firebase App Check
    await FirebaseAppCheck.instance.activate(
      androidProvider: kReleaseMode
          ? AndroidProvider.playIntegrity
          : AndroidProvider.debug,
      appleProvider: kReleaseMode
          ? AppleProvider.appAttest
          : AppleProvider.debug,
    );

    // Parallel initialization of heavy dependencies
    final (sharedPreferences, appDir) = await (
    SharedPreferences.getInstance(),
    getApplicationDocumentsDirectory(),
    ).wait;

    // Initialize Hive
    Hive.init(appDir.path);
    await Future.wait([
      Hive.openBox('app_cache'),
      Hive.openBox('offline_data'),
    ]);

    final offlineStorageService = OfflineStorageService(sharedPreferences);

    // Replace loading app with main app
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(
            create: (_) => MyAuthProvider(offlineStorageService),
          ),
          ChangeNotifierProvider(create: (_) => TenantProvider()),
          ChangeNotifierProvider(
            create: (_) => ThemeProvider()..loadSavedTheme(),
          ),
        ],
        child: const MultiTenantSaaSApp(),
      ),
    );
  } catch (e) {
    debugPrint('❌ App initialization error: $e');
    runApp(ErrorApp(error: e));
  }
}

// --- Modern Exit Confirmation Handler ---
class ExitConfirmationHandler {
  DateTime? _lastBackPressTime;
  static const _exitThreshold = Duration(seconds: 2);

  bool get shouldExit {
    final now = DateTime.now();
    final shouldExit = _lastBackPressTime != null &&
        now.difference(_lastBackPressTime!) < _exitThreshold;

    if (shouldExit) {
      _lastBackPressTime = null;
      return true;
    }

    _lastBackPressTime = now;
    return false;
  }

  void reset() {
    _lastBackPressTime = null;
  }
}

class BackPressHandler extends StatefulWidget {
  final Widget child;
  const BackPressHandler({super.key, required this.child});

  @override
  State<BackPressHandler> createState() => _BackPressHandlerState();
}

class _BackPressHandlerState extends State<BackPressHandler> {
  final ExitConfirmationHandler _exitHandler = ExitConfirmationHandler();
  OverlayEntry? _overlayEntry;
  Timer? _overlayTimer;

  @override
  void dispose() {
    _overlayEntry?.remove();
    _overlayTimer?.cancel();
    super.dispose();
  }

  void _showExitToast(BuildContext context) {
    // Remove existing overlay if any
    _overlayEntry?.remove();
    _overlayTimer?.cancel();

    // Create a modern overlay
    _overlayEntry = OverlayEntry(
      builder: (context) => Positioned(
        top: MediaQuery.of(context).viewPadding.top + 80,
        left: 0,
        right: 0,
        child: Material(
          color: Colors.transparent,
          child: Align(
            alignment: Alignment.topCenter,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.inverseSurface,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.touch_app_rounded,
                    color: Theme.of(context).colorScheme.onInverseSurface,
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    'Press back again to exit',
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.onInverseSurface,
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    // Insert overlay
    Overlay.of(context).insert(_overlayEntry!);

    // Auto remove after 2 seconds
    _overlayTimer = Timer(const Duration(seconds: 2), () {
      _overlayEntry?.remove();
      _overlayEntry = null;
    });
  }

  void _hideExitToast() {
    _overlayTimer?.cancel();
    _overlayEntry?.remove();
    _overlayEntry = null;
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;

        if (_exitHandler.shouldExit) {
          // Exit the app
          SystemNavigator.pop();
        } else {
          // Show exit confirmation
          _showExitToast(context);
        }
      },
      child: widget.child,
    );
  }
}

// --- Alternative: Modern Dialog Approach ---
class BackPressHandlerWithDialog extends StatefulWidget {
  final Widget child;
  const BackPressHandlerWithDialog({super.key, required this.child});

  @override
  State<BackPressHandlerWithDialog> createState() => _BackPressHandlerWithDialogState();
}

class _BackPressHandlerWithDialogState extends State<BackPressHandlerWithDialog> {
  final ExitConfirmationHandler _exitHandler = ExitConfirmationHandler();

  Future<void> _showExitDialog(BuildContext context) async {
    final shouldExit = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black54,
      builder: (context) => AlertDialog.adaptive(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        backgroundColor: Theme.of(context).colorScheme.surface,
        surfaceTintColor: Colors.transparent,
        title: Row(
          children: [
            Icon(
              Icons.exit_to_app_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 12),
            Text(
              'Exit App?',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        content: Text(
          'Are you sure you want to exit the application?',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'CANCEL',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurface.withOpacity(0.7),
              ),
            ),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('EXIT'),
          ),
        ],
      ),
    );

    if (shouldExit == true && mounted) {
      SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) async {
        if (didPop) return;

        if (_exitHandler.shouldExit) {
          SystemNavigator.pop();
        } else {
          await _showExitDialog(context);
        }
      },
      child: widget.child,
    );
  }
}

// --- Enhanced App Lifecycle Management ---
class AppStateManager {
  static final AppStateManager _instance = AppStateManager._internal();
  factory AppStateManager() => _instance;
  AppStateManager._internal();

  final List<VoidCallback> _onResumeCallbacks = [];
  final List<VoidCallback> _onPauseCallbacks = [];

  void addResumeListener(VoidCallback callback) => _onResumeCallbacks.add(callback);
  void addPauseListener(VoidCallback callback) => _onPauseCallbacks.add(callback);
  void removeResumeListener(VoidCallback callback) => _onResumeCallbacks.remove(callback);
  void removePauseListener(VoidCallback callback) => _onPauseCallbacks.remove(callback);

  void notifyResumed() {
    for (final callback in _onResumeCallbacks) {
      callback();
    }
  }

  void notifyPaused() {
    for (final callback in _onPauseCallbacks) {
      callback();
    }
  }
}

// --- Updated AppLifecycleWrapper with modern APIs ---
class AppLifecycleWrapper extends StatefulWidget {
  final Widget child;
  const AppLifecycleWrapper({super.key, required this.child});

  @override
  State<AppLifecycleWrapper> createState() => _AppLifecycleWrapperState();
}

class _AppLifecycleWrapperState extends State<AppLifecycleWrapper>
    with WidgetsBindingObserver {
  final _appStateManager = AppStateManager();

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
    switch (state) {
      case AppLifecycleState.resumed:
        _appStateManager.notifyResumed();
      case AppLifecycleState.inactive:
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.hidden:
        _appStateManager.notifyPaused();
    }
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}

// --- Loading and Error Apps ---
class LoadingApp extends StatelessWidget {
  const LoadingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      ),
    );
  }
}

class ErrorApp extends StatelessWidget {
  final dynamic error;
  const ErrorApp({super.key, required this.error});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error, size: 64, color: Colors.red),
                const SizedBox(height: 20),
                const Text(
                  'Initialization Error',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 10),
                Text(
                  'Failed to initialize app:\n$error',
                  textAlign: TextAlign.center,
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 20),
                FilledButton(
                  onPressed: () => main(),
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class MultiTenantSaaSApp extends StatelessWidget {
  const MultiTenantSaaSApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp(
      title: 'Multi-Tenant SaaS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
        primaryColor: themeProvider.getPrimaryColor(),
        colorScheme: ColorScheme.fromSeed(
          seedColor: themeProvider.getPrimaryColor(),
          brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
        ),
        scaffoldBackgroundColor: themeProvider.getBackgroundColor(),
        cardColor: themeProvider.getSurfaceColor(),
        textTheme: TextTheme(
          bodyLarge: TextStyle(color: themeProvider.getPrimaryTextColor()),
          bodyMedium: TextStyle(color: themeProvider.getSecondaryTextColor()),
        ),
      ),
      home: AppLifecycleWrapper(
        // Choose either approach:
        child: BackPressHandler( // Modern toast approach
          // child: BackPressHandlerWithDialog( // Modern dialog approach
          child: const AuthWrapper(),
        ),
      ),
    );
  }
}