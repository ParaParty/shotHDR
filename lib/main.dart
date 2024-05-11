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
          title: "shotHDR",
          content: Column(
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 12, right: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Button(
                      child: const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Icon(FluentIcons.camera),
                      ),
                      onPressed: _onTakeScreen,
                    )
                  ],
                ),
              ),
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
    final r = await takeFullScreen().toList();
    await windowManager.restore();
  }
}
