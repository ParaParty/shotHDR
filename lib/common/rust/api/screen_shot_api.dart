// This file is automatically generated, so please do not edit it.
// Generated by `flutter_rust_bridge`@ 2.0.0-dev.39.

// ignore_for_file: invalid_use_of_internal_member, unused_import, unnecessary_import

import '../frb_generated.dart';
import 'package:flutter_rust_bridge/flutter_rust_bridge_for_generated.dart';

// These functions are ignored because they are not marked as `pub`: `_raw_buffer_to_avif`
// These types are ignored because they are not used by any `pub` functions: `CaptureFlags`, `Capture`

Stream<CaptureResult> takeFullScreen() =>
    RustLib.instance.api.crateApiScreenShotApiTakeFullScreen();

class CaptureResult {
  final String mode;
  final Uint8List rawData;
  final int frameWidth;
  final int frameHeight;

  const CaptureResult({
    required this.mode,
    required this.rawData,
    required this.frameWidth,
    required this.frameHeight,
  });

  Future<Uint8List> toAvif() =>
      RustLib.instance.api.crateApiScreenShotApiCaptureResultToAvif(
        that: this,
      );

  @override
  int get hashCode =>
      mode.hashCode ^
      rawData.hashCode ^
      frameWidth.hashCode ^
      frameHeight.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is CaptureResult &&
          runtimeType == other.runtimeType &&
          mode == other.mode &&
          rawData == other.rawData &&
          frameWidth == other.frameWidth &&
          frameHeight == other.frameHeight;
}
