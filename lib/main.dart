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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.center(animate: false);
  windowManager.waitUntilReadyToShow().then((_) async {
    await windowManager.setAlwaysOnTop(true);
    await windowManager.setTitleBarStyle(
      TitleBarStyle.hidden,
      windowButtonVisibility: false,
    );
    await trayManager.setIcon(
      'assets/tray_icon.ico',
    );
    await Window.initialize();
    await Window.hideWindowControls();
    await Window.setEffect(effect: WindowEffect.mica);
  });
  await RustLib.init();
  runApp(const ProviderScope(child: MainAppUI()));
}

class MainAppUI extends ConsumerStatefulWidget {
  const MainAppUI({super.key});

  @override
  ConsumerState createState() => _MainAppUIState();
}

class _MainAppUIState extends ConsumerState<MainAppUI>
    with TrayListener, WindowListener {
  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    windowManager.addListener(this);
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    windowManager.removeListener(this);
    super.dispose();
  }

  bool isWindowForced = true;

  int step = 0;

  Uint8List? avifData;

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
        color: isWindowForced ? null : const Color.fromRGBO(32, 32, 32, 1),
        child: makeDefaultPage(
          context,
          title: "",
          titleRow: Row(
            children: [
              const Expanded(child: Text("shotHDR [DEMO]")),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  FilledButton(
                    onPressed: _onTakeScreen,
                    child: const Padding(
                      padding: EdgeInsets.all(6),
                      child: Icon(FluentIcons.camera),
                    ),
                  ),
                  if (avifData != null) ...[
                    const SizedBox(width: 12),
                    Button(
                        onPressed: _onSave,
                        child: const Padding(
                          padding: EdgeInsets.all(6),
                          child: Icon(FluentIcons.save),
                        )),
                  ],
                ],
              ),
              SizedBox(width: 168),
            ],
          ),
          content: Column(
            children: [
              if (step == 0)
                const Expanded(
                    child: Center(
                  child: Text("Click the camera icon to take a screenshot"),
                ))
              else if (step == 1)
                const Expanded(
                    child: Center(
                        child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ProgressRing(),
                    SizedBox(height: 6),
                    Text("Processing...")
                  ],
                )))
              else if (avifData != null && step == 2)
                Expanded(child: Center(child: Image.memory(avifData!))),
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
    await windowManager.setSkipTaskbar(true);
  }

  @override
  void onWindowRestore() async {
    await windowManager.setSkipTaskbar(false);
  }

  _onTakeScreen() async {
    await windowManager.minimize();
    await Future.delayed(const Duration(milliseconds: 200));
    final r = (await takeFullScreen().toList()).firstOrNull;
    if (r == null) return;
    setState(() {
      step = 1;
    });
    await windowManager.restore();
    final avifData = await r.toAvif();
    setState(() {
      this.avifData = avifData;
      step = 2;
    });
  }

  void _onSave() async {
    final name = "shot_HDR_${DateTime.now().millisecondsSinceEpoch}.avif";
    final path = await FilePicker.platform.saveFile(
        dialogTitle: "Save screenshot", fileName: name, lockParentWindow: true);
    if (path != null) {
      final f = File(path);
      await f.create(recursive: true);
      await f.writeAsBytes(avifData!);
    }
  }
}
