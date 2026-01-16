import 'dart:typed_data';
import 'dart:io';
import 'package:fluent_ui/fluent_ui.dart';
import 'package:shot_hdr/common/rust/api/screen_shot_api.dart';
import 'package:super_clipboard/super_clipboard.dart';
import 'package:file_picker/file_picker.dart';

class ScreenshotOverlay extends StatefulWidget {
  final CaptureResult captureResult;
  final VoidCallback onClose;

  const ScreenshotOverlay({
    super.key,
    required this.captureResult,
    required this.onClose,
  });

  @override
  State<ScreenshotOverlay> createState() => _ScreenshotOverlayState();
}

class _ScreenshotOverlayState extends State<ScreenshotOverlay> {
  Rect? _selectionRect;
  Offset? _dragStart;
  Uint8List? _previewImage;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _generatePreview();
  }

  Future<void> _generatePreview() async {
    try {
      final bytes = await widget.captureResult.toUltraHdrJpeg();
      if (mounted) {
        setState(() {
          _previewImage = bytes;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error generating preview: $e");
      // Handle error
    }
  }

  void _onPanStart(DragStartDetails details) {
    setState(() {
      _dragStart = details.localPosition;
      _selectionRect = Rect.fromPoints(_dragStart!, _dragStart!);
    });
  }

  void _onPanUpdate(DragUpdateDetails details) {
    setState(() {
      _selectionRect = Rect.fromPoints(_dragStart!, details.localPosition);
    });
  }

  void _onPanEnd(DragEndDetails details) {
    // Finalize logic if needed
  }

  Future<void> _processImage({required bool saveToFile}) async {
    try {
      CaptureResult resultToProcess = widget.captureResult;

      if (_selectionRect != null) {
        // Correct negative coords or zero size
        final rect = _selectionRect!;
        if (rect.width > 0 && rect.height > 0) {
          final x = rect.left.toInt().clamp(0, widget.captureResult.frameWidth).toInt();
          final y = rect.top.toInt().clamp(0, widget.captureResult.frameHeight).toInt();
          final w = rect.width.toInt().clamp(1, widget.captureResult.frameWidth - x).toInt();
          final h = rect.height.toInt().clamp(1, widget.captureResult.frameHeight - y).toInt();

          resultToProcess = await widget.captureResult.crop(x: x, y: y, width: w, height: h);
        }
      }

      final jpegBytes = await resultToProcess.toUltraHdrJpeg();

      if (saveToFile) {
        final name = "shot_HDR_${DateTime.now().millisecondsSinceEpoch}.jpg";
        final path = await FilePicker.platform.saveFile(
          dialogTitle: "Save Screenshot",
          fileName: name,
          lockParentWindow: true,
        );
        if (path != null) {
          final f = File(path);
          await f.create(recursive: true);
          await f.writeAsBytes(jpegBytes);
        }
      } else {
        // Copy to clipboard
        final clipboard = SystemClipboard.instance;
        if (clipboard == null) {
          throw Exception("System clipboard not available");
        }
        final item = DataWriterItem();
        item.add(Formats.jpeg(jpegBytes));
        await clipboard.write([item]);
      }

      widget.onClose();
    } catch (e) {
      debugPrint("Error processing image: $e");
      if (mounted) {
        await displayInfoBar(context,
            builder: (context, close) => InfoBar(
                  title: const Text("Error"),
                  content: Text(e.toString()),
                  severity: InfoBarSeverity.error,
                ));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading || _previewImage == null) {
      return const Center(child: ProgressRing());
    }

    return LayoutBuilder(builder: (context, constraints) {
      return Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.memory(_previewImage!, fit: BoxFit.contain),

          // Selection Overlay (CustomPaint)
          // We use a transparent container to capture gestures everywhere
          Positioned.fill(
            child: GestureDetector(
              onPanStart: _onPanStart,
              onPanUpdate: _onPanUpdate,
              onPanEnd: _onPanEnd,
              child: CustomPaint(
                painter: SelectionPainter(_selectionRect),
              ),
            ),
          ),

          // Toolbar
          if (_previewImage != null) _buildToolbar(constraints),
        ],
      );
    });
  }

  Widget _buildToolbar(BoxConstraints constraints) {
    // Default: Bottom Right of screen
    double top = constraints.maxHeight - 80;
    double left = constraints.maxWidth - 150;

    if (_selectionRect != null) {
      // Bottom Right of selection, but kept within screen
      top = _selectionRect!.bottom + 10;
      left = _selectionRect!.right - 100; // Alignment adjustment

      // Bounds check
      if (top + 60 > constraints.maxHeight) {
        top = _selectionRect!.bottom - 60; // Inside if too low? Or just clamp
        if (top > constraints.maxHeight - 60) top = constraints.maxHeight - 60;
      }
      if (left < 10) left = 10;
      if (left + 140 > constraints.maxWidth) left = constraints.maxWidth - 140;
    }

    return Positioned(
      top: top,
      left: left,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF202020), // Dark background
          borderRadius: BorderRadius.circular(8),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.45), blurRadius: 10)],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(FluentIcons.accept, color: Colors.green),
              onPressed: () => _processImage(saveToFile: false),
            ),
            const SizedBox(width: 12),
            Container(width: 1, height: 20, color: Colors.grey),
            const SizedBox(width: 12),
            IconButton(
              icon: Icon(FluentIcons.save, color: Colors.blue),
              onPressed: () => _processImage(saveToFile: true),
            ),
            const SizedBox(width: 4),
            IconButton(
              icon: Icon(FluentIcons.cancel, color: Colors.red),
              onPressed: widget.onClose,
            ),
          ],
        ),
      ),
    );
  }
}

class SelectionPainter extends CustomPainter {
  final Rect? rect;

  SelectionPainter(this.rect);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black.withOpacity(0.54);

    if (rect == null) {
      // Draw nothing or just dim? The requirements say "Full screen capture".
      // User can select. Usually full screen is visible.
      // Maybe we don't dim until selection starts?
      // Or we dim everything and highlight selection.
      // Let's dim nothing initially (clear view) as existing screenshot tools do (CleanShot X etc),
      // or dim everything slightly?
      // "全屏窗口中包含工具栏，未框选时显示在页面右下角" -> implies we see the full image.
      // Let's not dim if no selection.
      return;
    }

    // Draw dimmed background excluding the rect
    // We can draw 4 rectangles around the selection
    // Top
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, rect!.top), paint);
    // Bottom
    canvas.drawRect(Rect.fromLTWH(0, rect!.bottom, size.width, size.height - rect!.bottom), paint);
    // Left
    canvas.drawRect(Rect.fromLTWH(0, rect!.top, rect!.left, rect!.height), paint);
    // Right
    canvas.drawRect(Rect.fromLTWH(rect!.right, rect!.top, size.width - rect!.right, rect!.height), paint);

    // Draw border
    final borderPaint = Paint()
      ..color = Colors.blue
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    canvas.drawRect(rect!, borderPaint);

    // Draw crosshair or handles? (Simplified for now)
  }

  @override
  bool shouldRepaint(covariant SelectionPainter oldDelegate) {
    return oldDelegate.rect != rect;
  }
}
