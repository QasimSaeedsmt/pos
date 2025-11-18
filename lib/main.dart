// app.dart - Optimized Multi-Tenant SaaS System
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
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

  // Run app immediately with a loading screen to avoid main-thread blocking
  runApp(const LoadingApp());

  try {
    // --- Initialize Firebase first ---
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // --- Activate Firebase App Check ---
    await FirebaseAppCheck.instance.activate(
      androidProvider: kReleaseMode
          ? AndroidProvider.playIntegrity
          : AndroidProvider.debug,
    );

    // --- Run remaining heavy initializations in parallel ---
    final sharedPrefsFuture = SharedPreferences.getInstance();
    final appDirFuture = getApplicationDocumentsDirectory();

    final sharedPreferences = await sharedPrefsFuture;
    final appDir = await appDirFuture;

    // --- Initialize Hive ---
    Hive.init(appDir.path);
    await Future.wait([
      Hive.openBox('app_cache'),
      Hive.openBox('offline_data'),
    ]);

    final offlineStorageService = OfflineStorageService(sharedPreferences);

    // --- Once all init done, replace the loading app with the real one ---
    runApp(
      MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (_) => SettingsProvider()),
          ChangeNotifierProvider(create: (_) => MyAuthProvider(offlineStorageService)),
          ChangeNotifierProvider(create: (_) => TenantProvider()),
          ChangeNotifierProvider(
            create: (_) => ThemeProvider()..loadSavedTheme(),
          ),
        ],
        child: const MultiTenantSaaSApp(),
      ),
    );
  } catch (e) {
    debugPrint('❌ Firebase initialization error: $e');
    runApp(ErrorApp(error: e));
  }
}

//
// --- Simple lightweight placeholder during initialization ---
//
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

//
// --- Error screen for initialization failures ---
//
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
                ElevatedButton(
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
      home: const AppLifecycleWrapper(
        child: AuthWrapper(),
      ),
    );
  }
}
