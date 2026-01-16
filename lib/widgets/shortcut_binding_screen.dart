import 'dart:convert';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ShortcutBindingScreen extends StatefulWidget {
  final VoidCallback onCompleted;

  const ShortcutBindingScreen({super.key, required this.onCompleted});

  @override
  State<ShortcutBindingScreen> createState() => _ShortcutBindingScreenState();
}

class _ShortcutBindingScreenState extends State<ShortcutBindingScreen> {
  HotKey? _hotKey;

  @override
  void initState() {
    super.initState();
    _loadSavedHotkey();
  }

  Future<void> _loadSavedHotkey() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonStr = prefs.getString('saved_hotkey');
    if (jsonStr != null) {
      try {
        setState(() {
          _hotKey = HotKey.fromJson(jsonDecode(jsonStr));
        });
      } catch (e) {
        debugPrint("Failed to load hotkey: $e");
      }
    }
  }

  Future<void> _saveHotkey(HotKey hotKey) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('saved_hotkey', jsonEncode(hotKey.toJson()));
    // For efficient checking in main without full parse if needed, but json is fine.
    await prefs.setString('hotkey_key_code', hotKey.key.keyLabel); // Using key.keyLabel instead of keyCode
  }

  @override
  Widget build(BuildContext context) {
    return ScaffoldPage(
      header: const PageHeader(title: Text('Setup Shortcut')),
      content: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text("Please set a shortcut to trigger the screenshot:"),
            const SizedBox(height: 20),
            HotKeyRecorder(
              onHotKeyRecorded: (hotKey) {
                // Enforce at least one modifier
                if (hotKey.modifiers == null || hotKey.modifiers!.isEmpty) {
                  displayInfoBar(context,
                      builder: (context, close) => InfoBar(
                            title: const Text("Invalid Shortcut"),
                            content: const Text("Please include a modifier key (e.g. Cmd, Ctrl, Alt)"),
                            severity: InfoBarSeverity.warning,
                            action: IconButton(icon: const Icon(FluentIcons.clear), onPressed: close),
                          ));
                  return;
                }
                setState(() {
                  _hotKey = hotKey;
                });
              },
            ),
            const SizedBox(height: 20),
            if (_hotKey != null)
              Text("Current Shortcut: ${_hotKey!.key.keyLabel}", style: const TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 40),
            FilledButton(
              onPressed: _hotKey != null
                  ? () async {
                      if (_hotKey != null) {
                        try {
                          await _saveHotkey(_hotKey!);
                          // Test registration
                          await hotKeyManager.unregisterAll();
                          await hotKeyManager.register(
                            _hotKey!,
                            keyDownHandler: (_) {},
                          );
                          widget.onCompleted();
                        } catch (e) {
                          displayInfoBar(context,
                              builder: (context, close) => InfoBar(
                                    title: const Text("Error"),
                                    content: Text("Failed to register shortcut: $e"),
                                    severity: InfoBarSeverity.error,
                                  ));
                        }
                      }
                    }
                  : null,
              child: const Text("Confirm & Start"),
            ),
          ],
        ),
      ),
    );
  }
}
