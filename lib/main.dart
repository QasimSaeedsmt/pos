// app.dart - Optimized Multi-Tenant SaaS System
import 'dart:async';
import 'dart:ui';

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
// --- Smart Slider Back Press Handler ---


// --- Smart Slider Back Press Handler ---
// --- Smart Slider Back Press Handler ---
class SmartSliderBackPressHandler extends StatefulWidget {
  final Widget child;
  const SmartSliderBackPressHandler({super.key, required this.child});

  @override
  State<SmartSliderBackPressHandler> createState() => _SmartSliderBackPressHandlerState();
}

class _SmartSliderBackPressHandlerState extends State<SmartSliderBackPressHandler> {
  DateTime? _lastBackPressTime;
  OverlayEntry? _overlayEntry;
  double _sliderValue = 0.0;

  void _showSmartSlider() {
    _overlayEntry?.remove();

    _overlayEntry = OverlayEntry(
      builder: (context) {
        return Positioned.fill(
          child: Material(
            color: Colors.black54,
            child: Center(
              child: Container(
                width: 320,
                margin: const EdgeInsets.all(24),
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.3),
                      blurRadius: 30,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: _SliderContent(
                  sliderValue: _sliderValue,
                  onSliderValueChanged: (value) {
                    setState(() {
                      _sliderValue = value;
                    });

                    if (value >= 0.95) {
                      _confirmExit();
                    }
                  },
                  onCancel: _cancelExit,
                ),
              ),
            ),
          ),
        );
      },
    );

    Overlay.of(context).insert(_overlayEntry!);

    // Reset slider when shown
    setState(() {
      _sliderValue = 0.0;
    });
  }

  void _cancelExit() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    setState(() {
      _sliderValue = 0.0;
    });
  }

  void _confirmExit() {
    _overlayEntry?.remove();
    _overlayEntry = null;
    SystemNavigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvoked: (bool didPop) {
        if (didPop) return;

        final now = DateTime.now();
        final shouldExit = _lastBackPressTime != null &&
            now.difference(_lastBackPressTime!) < const Duration(seconds: 2);

        if (shouldExit) {
          // SystemNavigator.pop();
        } else {
          _lastBackPressTime = now;
          _showSmartSlider();
        }
      },
      child: widget.child,
    );
  }

  @override
  void dispose() {
    _overlayEntry?.remove();
    super.dispose();
  }
}

// --- Separate Slider Content Widget ---
class _SliderContent extends StatefulWidget {
  final double sliderValue;
  final ValueChanged<double> onSliderValueChanged;
  final VoidCallback onCancel;

  const _SliderContent({
    required this.sliderValue,
    required this.onSliderValueChanged,
    required this.onCancel,
  });

  @override
  State<_SliderContent> createState() => _ModernSliderContentState();
}

class _ModernSliderContentState extends State<_SliderContent>
    with SingleTickerProviderStateMixin {
  final GlobalKey _sliderKey = GlobalKey();

  late AnimationController _controller;
  bool _isDragging = false;

  static const double trackWidth = 310;
  static const double thumbSize = 52;

  @override
  void initState() {
    super.initState();

    _controller = AnimationController(
      vsync: this,
      value: widget.sliderValue,
      duration: const Duration(milliseconds: 500),
      lowerBound: 0,
      upperBound: 1,
    )..addListener(() {
      widget.onSliderValueChanged(_controller.value);
    });
  }

  @override
  void didUpdateWidget(covariant _SliderContent oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (!_isDragging && widget.sliderValue != _controller.value) {
      _controller.animateTo(
        widget.sliderValue,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeOutQuart,
      );
    }
  }

  double _positionToValue(Offset globalPos) {
    final RenderBox renderBox =
    _sliderKey.currentContext!.findRenderObject() as RenderBox;

    final local = renderBox.globalToLocal(globalPos);

    double pos = (local.dx - (thumbSize / 2));
    double value = pos / (trackWidth - thumbSize);

    return value.clamp(0.0, 1.0);
  }

  void _onDragUpdate(DragUpdateDetails details) {
    setState(() => _isDragging = true);

    final value = _positionToValue(details.globalPosition);

    // Beautiful magnetic pull
    if (value > 0.88) {
      HapticFeedback.lightImpact();
      _controller.value = value + (1 - value) * 0.40;
    } else {
      _controller.value = value;
    }
  }

  void _onDragEnd(DragEndDetails details) {
    setState(() => _isDragging = false);

    if (_controller.value >= 0.94) {
      HapticFeedback.heavyImpact();
      widget.onSliderValueChanged(1.0);
      return;
    }

    // Smooth rebound
    _controller.animateTo(
      0.0,
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutBack,
    );
    widget.onSliderValueChanged(0.0);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        /* -------------------- HEADER -------------------- */
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              colors: [
                theme.colorScheme.primary.withOpacity(0.15),
                theme.colorScheme.primary.withOpacity(0.05),
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.shadowColor.withOpacity(0.15),
                blurRadius: 20,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      theme.colorScheme.primary,
                      theme.colorScheme.primary.withOpacity(0.7),
                    ],
                  ),
                ),
                child: const Icon(Icons.power_settings_new_rounded,
                    color: Colors.white, size: 26),
              ),
              const SizedBox(width: 18),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Exit Application",
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  Text(
                    "Slide to confirm",
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                ],
              )
            ],
          ),
        ),

        const SizedBox(height: 32),

        /* -------------------- MODERN SLIDER -------------------- */
        ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Container(
            key: _sliderKey,
            height: 70,
            width: trackWidth,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(40),
            ),
            child: Stack(
              children: [
                // Background blur glass
                Positioned.fill(
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
                    child: Container(
                      decoration: BoxDecoration(
                        color: theme.colorScheme.surface.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(40),
                      ),
                    ),
                  ),
                ),

                // Liquid progress bar
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    return Align(
                      alignment: Alignment.centerLeft,
                      child: Container(
                        width: _controller.value * trackWidth,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              theme.colorScheme.primary,
                              theme.colorScheme.primary.withOpacity(0.6),
                              theme.colorScheme.primary.withOpacity(0.3),
                            ],
                            begin: Alignment.centerLeft,
                            end: Alignment.centerRight,
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Glow highlight
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    return Positioned(
                      left: (_controller.value * trackWidth) -
                          (thumbSize / 2) -
                          20,
                      top: 0,
                      bottom: 0,
                      child: Container(
                        width: 40,
                        decoration: BoxDecoration(
                          gradient: RadialGradient(
                            colors: [
                              theme.colorScheme.primary.withOpacity(0.4),
                              Colors.transparent
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),

                // Thumb
                AnimatedBuilder(
                  animation: _controller,
                  builder: (_, __) {
                    return Positioned(
                      left: _controller.value * (trackWidth - thumbSize),
                      top: 9,
                      child: GestureDetector(
                        onHorizontalDragUpdate: _onDragUpdate,
                        onHorizontalDragEnd: _onDragEnd,
                        child: Container(
                          width: thumbSize,
                          height: thumbSize,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: theme.colorScheme.surface,
                            boxShadow: [
                              BoxShadow(
                                color:
                                theme.colorScheme.primary.withOpacity(0.25),
                                blurRadius: 20,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                          child: Icon(
                            Icons.arrow_forward_rounded,
                            color: theme.colorScheme.primary,
                            size: 28,
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),

        const SizedBox(height: 24),

        Text(
          "${(_controller.value * 100).toInt()}%",
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.primary,
          ),
        ),

        const SizedBox(height: 10),

        Text(
          _controller.value > 0.88
              ? "Release to exit"
              : "Slide to the right to exit",
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.6),
          ),
        ),

        const SizedBox(height: 28),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton(
            onPressed: widget.onCancel,
            style: ElevatedButton.styleFrom(
              backgroundColor: theme.colorScheme.surfaceVariant,
              foregroundColor: theme.colorScheme.onSurfaceVariant,
              elevation: 0,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            child: const Text("Cancel"),
          ),
        )
      ],
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}

// --- Updated MultiTenantSaaSApp ---
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
      ),
      home: AppLifecycleWrapper(
        child: SmartSliderBackPressHandler(
          child: const AuthWrapper(),
        ),
      ),
    );
  }
}
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

// class MultiTenantSaaSApp extends StatelessWidget {
//   const MultiTenantSaaSApp({super.key});
//
//   @override
//   Widget build(BuildContext context) {
//     final themeProvider = context.watch<ThemeProvider>();
//
//     return MaterialApp(
//       title: 'Multi-Tenant SaaS',
//       debugShowCheckedModeBanner: false,
//       theme: ThemeData(
//         useMaterial3: true,
//         brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
//         primaryColor: themeProvider.getPrimaryColor(),
//         colorScheme: ColorScheme.fromSeed(
//           seedColor: themeProvider.getPrimaryColor(),
//           brightness: themeProvider.isDarkMode ? Brightness.dark : Brightness.light,
//         ),
//         scaffoldBackgroundColor: themeProvider.getBackgroundColor(),
//         cardColor: themeProvider.getSurfaceColor(),
//         textTheme: TextTheme(
//           bodyLarge: TextStyle(color: themeProvider.getPrimaryTextColor()),
//           bodyMedium: TextStyle(color: themeProvider.getSecondaryTextColor()),
//         ),
//       ),
//       home: AppLifecycleWrapper(
//         // Choose either approach:
//         child: BackPressHandler( // Modern toast approach
//           // child: BackPressHandlerWithDialog( // Modern dialog approach
//           child: const AuthWrapper(),
//         ),
//       ),
//     );
//   }
// }