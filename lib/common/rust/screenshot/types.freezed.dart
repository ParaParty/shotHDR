// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'types.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$CaptureResult {
  String get mode => throw _privateConstructorUsedError;
  Uint8List get rawData => throw _privateConstructorUsedError;
  int get frameWidth => throw _privateConstructorUsedError;
  int get frameHeight => throw _privateConstructorUsedError;

  /// Create a copy of CaptureResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CaptureResultCopyWith<CaptureResult> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CaptureResultCopyWith<$Res> {
  factory $CaptureResultCopyWith(
          CaptureResult value, $Res Function(CaptureResult) then) =
      _$CaptureResultCopyWithImpl<$Res, CaptureResult>;
  @useResult
  $Res call({String mode, Uint8List rawData, int frameWidth, int frameHeight});
}

/// @nodoc
class _$CaptureResultCopyWithImpl<$Res, $Val extends CaptureResult>
    implements $CaptureResultCopyWith<$Res> {
  _$CaptureResultCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CaptureResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mode = null,
    Object? rawData = null,
    Object? frameWidth = null,
    Object? frameHeight = null,
  }) {
    return _then(_value.copyWith(
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as String,
      rawData: null == rawData
          ? _value.rawData
          : rawData // ignore: cast_nullable_to_non_nullable
              as Uint8List,
      frameWidth: null == frameWidth
          ? _value.frameWidth
          : frameWidth // ignore: cast_nullable_to_non_nullable
              as int,
      frameHeight: null == frameHeight
          ? _value.frameHeight
          : frameHeight // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CaptureResultImplCopyWith<$Res>
    implements $CaptureResultCopyWith<$Res> {
  factory _$$CaptureResultImplCopyWith(
          _$CaptureResultImpl value, $Res Function(_$CaptureResultImpl) then) =
      __$$CaptureResultImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call({String mode, Uint8List rawData, int frameWidth, int frameHeight});
}

/// @nodoc
class __$$CaptureResultImplCopyWithImpl<$Res>
    extends _$CaptureResultCopyWithImpl<$Res, _$CaptureResultImpl>
    implements _$$CaptureResultImplCopyWith<$Res> {
  __$$CaptureResultImplCopyWithImpl(
      _$CaptureResultImpl _value, $Res Function(_$CaptureResultImpl) _then)
      : super(_value, _then);

  /// Create a copy of CaptureResult
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? mode = null,
    Object? rawData = null,
    Object? frameWidth = null,
    Object? frameHeight = null,
  }) {
    return _then(_$CaptureResultImpl(
      mode: null == mode
          ? _value.mode
          : mode // ignore: cast_nullable_to_non_nullable
              as String,
      rawData: null == rawData
          ? _value.rawData
          : rawData // ignore: cast_nullable_to_non_nullable
              as Uint8List,
      frameWidth: null == frameWidth
          ? _value.frameWidth
          : frameWidth // ignore: cast_nullable_to_non_nullable
              as int,
      frameHeight: null == frameHeight
          ? _value.frameHeight
          : frameHeight // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$CaptureResultImpl implements _CaptureResult {
  const _$CaptureResultImpl(
      {required this.mode,
      required this.rawData,
      required this.frameWidth,
      required this.frameHeight});

  @override
  final String mode;
  @override
  final Uint8List rawData;
  @override
  final int frameWidth;
  @override
  final int frameHeight;

  @override
  String toString() {
    return 'CaptureResult(mode: $mode, rawData: $rawData, frameWidth: $frameWidth, frameHeight: $frameHeight)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CaptureResultImpl &&
            (identical(other.mode, mode) || other.mode == mode) &&
            const DeepCollectionEquality().equals(other.rawData, rawData) &&
            (identical(other.frameWidth, frameWidth) ||
                other.frameWidth == frameWidth) &&
            (identical(other.frameHeight, frameHeight) ||
                other.frameHeight == frameHeight));
  }

  @override
  int get hashCode => Object.hash(runtimeType, mode,
      const DeepCollectionEquality().hash(rawData), frameWidth, frameHeight);

  /// Create a copy of CaptureResult
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CaptureResultImplCopyWith<_$CaptureResultImpl> get copyWith =>
      __$$CaptureResultImplCopyWithImpl<_$CaptureResultImpl>(this, _$identity);
}

abstract class _CaptureResult implements CaptureResult {
  const factory _CaptureResult(
      {required final String mode,
      required final Uint8List rawData,
      required final int frameWidth,
      required final int frameHeight}) = _$CaptureResultImpl;

  @override
  String get mode;
  @override
  Uint8List get rawData;
  @override
  int get frameWidth;
  @override
  int get frameHeight;

  /// Create a copy of CaptureResult
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CaptureResultImplCopyWith<_$CaptureResultImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
