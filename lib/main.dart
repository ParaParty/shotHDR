import 'dart:convert';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shot_hdr/common/rust/api/screen_shot_api.dart';
import 'package:shot_hdr/widgets/screenshot_overlay.dart';
import 'package:shot_hdr/widgets/shortcut_binding_screen.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'common/rust/frb_generated.dart';

/// Check if the current platform is Windows
bool get isWindows => Platform.isWindows;

/// Check if the current platform is macOS
bool get isMacOS => Platform.isMacOS;

/// Check if the current platform is Linux
bool get isLinux => Platform.isLinux;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();

  // Initialize HotKeyManager
  await hotKeyManager.unregisterAll();

  await Window.initialize();

  // macOS: Hide title bar and traffic light buttons immediately
  await windowManager.setTitleBarStyle(
    TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.center(animate: false);

  windowManager.waitUntilReadyToShow().then((_) async {
    // Initial state: don't show yet, let logic decide
    // await windowManager.show();
    // await windowManager.focus();

    // Set always on top to ensure overlay is visible when needed
    // await windowManager.setAlwaysOnTop(true); // Don't force this globally yet

    try {
      await trayManager.setIcon(isWindows ? 'assets/tray_icon.ico' : 'assets/tray_icon.png');
    } catch (e) {
      debugPrint("Failed to set tray icon: $e");
    }

    // Windows-specific: mica effect
    if (isWindows) {
      await Window.setEffect(effect: WindowEffect.mica);
    }
  });

  await RustLib.init();
  runApp(const ProviderScope(child: MainAppUI()));
}

class MainAppUI extends ConsumerStatefulWidget {
  const MainAppUI({super.key});

  @override
  ConsumerState createState() => _MainAppUIState();
}

class _MainAppUIState extends ConsumerState<MainAppUI> with TrayListener, WindowListener {
  bool _isSetupCompleted = false;
  CaptureResult? _captureResult;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
    _initWindow();
    _checkSetup();
  }

  Future<void> _initWindow() async {
    await windowManager.setPreventClose(true);
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  @override
  void onWindowRestore() async {
    if (isWindows) {
      await windowManager.setSkipTaskbar(false);
    }
  }

  @override
  void onWindowClose() async {
    await windowManager.hide();
  }

  Future<void> _checkSetup() async {
    final prefs = await SharedPreferences.getInstance();
    final hasKey = prefs.containsKey('hotkey_key');

    setState(() {
      _isSetupCompleted = hasKey;
      _isLoading = false;
    });

    if (hasKey) {
      await _registerSavedHotkey();
      // Requirement: "Or when cold starting software", take full screen screenshot.
      // We minimize/hide first to clear the view, then capture.
      _onTakeScreen();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }
  }

  Future<void> _registerSavedHotkey() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('saved_hotkey');

    if (jsonStr != null) {
      try {
        final hotKey = HotKey.fromJson(jsonDecode(jsonStr));
        await hotKeyManager.unregisterAll();
        await hotKeyManager.register(
          hotKey,
          keyDownHandler: (_) {
            _onTakeScreen();
          },
        );
      } catch (e) {
        debugPrint("Failed to register saved hotkey: $e");
      }
    }
  }

  Future<void> _onTakeScreen() async {
    if (_captureResult != null) return; // Already capturing

    await windowManager.minimize();
    await windowManager.hide();
    // Wait for animation
    await Future.delayed(const Duration(milliseconds: 300));

    try {
      final stream = takeFullScreen();
      final r = await stream.first;

      if (!mounted) return;

      setState(() {
        _captureResult = r;
      });

      // Prepare overlay
      await windowManager.setFullScreen(true);
      await windowManager.show();
      await windowManager.focus();
      await windowManager.setAlwaysOnTop(true);
    } catch (e) {
      debugPrint("Capture failed: $e");
      await windowManager.show(); // Show back to report error?
      if (mounted) {
        // show error
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return FluentApp(
      debugShowCheckedModeBanner: false,
      theme: FluentThemeData(
        brightness: Brightness.dark,
        navigationPaneTheme: const NavigationPaneThemeData(
          backgroundColor: Colors.transparent,
        ),
      ),
      home: _buildContent(),
    );
  }

  Widget _buildContent() {
    if (_isLoading) return const Center(child: ProgressRing());

    if (!_isSetupCompleted) {
      return ShortcutBindingScreen(
        onCompleted: () async {
          setState(() => _isSetupCompleted = true);
          await _registerSavedHotkey(); // Register the key just bound
          await windowManager.hide();

          // Optional: Trigger first screenshot immediately?
          // _onTakeScreen();
        },
      );
    }

    if (_captureResult != null) {
      return ScreenshotOverlay(
        captureResult: _captureResult!,
        onClose: () async {
          setState(() {
            _captureResult = null;
          });
          await windowManager.setFullScreen(false);
          await windowManager.hide();
        },
      );
    }

    // "Hidden" state visualization (if window accidentally shown)
    return ScaffoldPage(
      content: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("ShotHDR is running in background"),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _onTakeScreen,
              child: const Text("Take Screenshot Now"),
            ),
            const SizedBox(height: 10),
            Button(
              onPressed: () {
                // Re-bind
                setState(() => _isSetupCompleted = false);
              },
              child: const Text("Change Shortcut"),
            )
          ],
        ),
      ),
    );
  }

  @override
  void onTrayIconMouseDown() {
    windowManager.show();
    windowManager.focus();
  }
}
