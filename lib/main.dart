import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:flutter_acrylic/flutter_acrylic.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:shot_hdr/common/rust/api/screen_shot_api.dart';
import 'package:shot_hdr/widgets/widgets.dart';
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
  await Window.initialize();
  // macOS: Hide title bar and traffic light buttons immediately
  await windowManager.setTitleBarStyle(
    TitleBarStyle.hidden,
    windowButtonVisibility: false,
  );

  await windowManager.center(animate: false);

  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setAlwaysOnTop(true);
    await windowManager.show();
    await windowManager.focus();

    // Windows-specific: tray icon
    if (isWindows) {
      await trayManager.setIcon('assets/tray_icon.ico');
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
  @override
  void initState() {
    super.initState();
    if (isWindows) {
      trayManager.addListener(this);
    }
    windowManager.addListener(this);
    _checkPlatformSupport();
  }

  @override
  void dispose() {
    if (isWindows) {
      trayManager.removeListener(this);
    }
    windowManager.removeListener(this);
    super.dispose();
  }

  bool isWindowForced = true;
  int step = 0;
  Uint8List? hdrJpegData;
  bool _isSupported = true;
  String _platformName = "";

  Future<void> _checkPlatformSupport() async {
    final supported = await isScreenCaptureSupported();
    final platform = await getPlatformName();
    setState(() {
      _isSupported = supported;
      _platformName = platform;
    });
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
      home: Container(
        color: isWindowForced
            ? (isWindows ? Colors.transparent : const Color.fromRGBO(32, 32, 32, 1))
            : const Color.fromRGBO(32, 32, 32, 1),
        child: makeDefaultPage(
          context,
          title: "",
          titleRow: Row(
            children: [
              Expanded(
                child: Text(
                  "shotHDR [${_platformName.toUpperCase()}]${_isSupported ? '' : ' - NOT SUPPORTED'}",
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: _isSupported ? _onTakeScreen : null,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(FluentIcons.camera),
                    ),
                  ),
                  if (hdrJpegData != null) ...[
                    const SizedBox(width: 12),
                    Button(
                      onPressed: _onSave,
                      child: const Padding(
                        padding: EdgeInsets.all(6),
                        child: Icon(FluentIcons.save),
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(width: 168),
            ],
          ),
          content: Column(
            children: [
              if (!_isSupported)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(FluentIcons.warning, size: 48),
                        const SizedBox(height: 12),
                        Text(
                          "Screen capture is not yet supported on $_platformName",
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          "This feature is coming soon!",
                          style: TextStyle(color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                )
              else if (step == 0)
                const Expanded(
                  child: Center(
                    child: Text("Click the camera icon to take a screenshot"),
                  ),
                )
              else if (step == 1)
                const Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [ProgressRing(), SizedBox(height: 6), Text("Processing...")],
                    ),
                  ),
                )
              else if (hdrJpegData != null && step == 2)
                Expanded(child: Center(child: Image.memory(hdrJpegData!))),
            ],
          ),
          automaticallyImplyLeading: false,
          useBodyContainer: false,
        ),
      ),
    );
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {}

  @override
  void onTrayIconRightMouseUp() {}

  @override
  void onTrayIconRightMouseDown() {}

  @override
  void onTrayIconMouseUp() {}

  @override
  void onTrayIconMouseDown() async {
    debugPrint("onTrayIconMouseDown");
    if (await windowManager.isMinimized()) {
      await windowManager.restore();
    } else {
      await windowManager.minimize();
    }
  }

  @override
  void onWindowBlur() async {
    setState(() {
      isWindowForced = false;
    });
  }

  @override
  void onWindowFocus() async {
    setState(() {
      isWindowForced = true;
    });
  }

  @override
  Future<void> onWindowMinimize() async {
    if (isWindows) {
      await windowManager.setSkipTaskbar(true);
    }
  }

  @override
  void onWindowRestore() async {
    if (isWindows) {
      await windowManager.setSkipTaskbar(false);
    }
  }

  Future<void> _onTakeScreen() async {
    if (!_isSupported) return;

    await windowManager.minimize();
    await Future.delayed(const Duration(milliseconds: 200));

    try {
      final r = (await takeFullScreen().toList()).firstOrNull;
      if (r == null) return;

      setState(() {
        step = 1;
      });

      await windowManager.restore();
      final hdrJpegData = await r.toUltraHdrJpeg();

      setState(() {
        this.hdrJpegData = hdrJpegData;
        step = 2;
      });
    } catch (e) {
      await windowManager.restore();
      if (mounted) {
        await displayInfoBar(
          context,
          builder: (context, close) => InfoBar(
            title: const Text("Error"),
            content: Text("Failed to capture screen: $e"),
            severity: InfoBarSeverity.error,
            action: IconButton(
              icon: const Icon(FluentIcons.clear),
              onPressed: close,
            ),
          ),
        );
      }
    }
  }

  void _onSave() async {
    // Ultra HDR JPEG is backwards compatible - uses .jpg extension
    final name = "shot_HDR_${DateTime.now().millisecondsSinceEpoch}.jpg";
    final path = await FilePicker.platform.saveFile(
      dialogTitle: "Save Ultra HDR Screenshot",
      fileName: name,
      lockParentWindow: true,
    );
    if (path != null) {
      final f = File(path);
      await f.create(recursive: true);
      await f.writeAsBytes(hdrJpegData!);
    }
  }
}
