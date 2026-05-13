import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'sign_vision_types.dart';

const _kChannelName = 'com.example.detector_senas/sign_vision';

SignVision createSignVisionFromPlatform() {
  if (kIsWeb) {
    return _DesktopStubSignVision();
  }
  if (Platform.isAndroid) {
    return _AndroidChannelSignVision();
  }
  if (Platform.isIOS) {
    return _IosChannelSignVision();
  }
  return _DesktopStubSignVision();
}

class _AndroidChannelSignVision implements SignVision {
  static const MethodChannel _ch = MethodChannel(_kChannelName);

  @override
  String get platformCaption =>
      'Android: MediaPipe Hand Landmarker + opcional clasificador TFLite (ver README).';

  @override
  Future<SignVisionInitResult> init() async {
    final raw = await _ch.invokeMethod<Map<Object?, Object?>>('init');
    if (raw == null) {
      return const SignVisionInitResult(ok: false, errorKey: 'null_response');
    }
    return SignVisionInitResult.fromMap(raw);
  }

  @override
  Future<SignVisionDetectResult> detect(List<int> jpeg, int timestampMs) async {
    final raw = await _ch.invokeMethod<Map<Object?, Object?>>(
      'detect',
      <String, Object>{
        'jpeg': Uint8List.fromList(jpeg),
        'timestampMs': timestampMs,
      },
    );
    if (raw == null) {
      return const SignVisionDetectResult(ok: false, errorKey: 'null_response');
    }
    return SignVisionDetectResult.fromMap(raw);
  }

  @override
  Future<void> releaseModel() async {
    try {
      await _ch.invokeMethod<void>('dispose');
    } catch (_) {}
  }
}

/// iOS: native channel returns stub until MediaPipe Tasks + task bundle are wired.
class _IosChannelSignVision implements SignVision {
  static const MethodChannel _ch = MethodChannel(_kChannelName);

  @override
  String get platformCaption =>
      'Próximamente en iOS: MediaPipe Hand Landmarker + TFLite (Android tiene el pipeline completo).';

  @override
  Future<SignVisionInitResult> init() async {
    try {
      final raw = await _ch.invokeMethod<Map<Object?, Object?>>('init');
      if (raw != null) {
        return SignVisionInitResult.fromMap(raw);
      }
    } catch (_) {}
    return const SignVisionInitResult(ok: false, errorKey: 'ios_stub');
  }

  @override
  Future<SignVisionDetectResult> detect(List<int> jpeg, int timestampMs) async {
    try {
      final raw = await _ch.invokeMethod<Map<Object?, Object?>>(
        'detect',
        <String, Object>{
          'jpeg': Uint8List.fromList(jpeg),
          'timestampMs': timestampMs,
        },
      );
      if (raw != null) {
        return SignVisionDetectResult.fromMap(raw);
      }
    } catch (_) {}
    return const SignVisionDetectResult(ok: false, errorKey: 'ios_stub');
  }

  @override
  Future<void> releaseModel() async {
    try {
      await _ch.invokeMethod<void>('dispose');
    } catch (_) {}
  }
}

class _DesktopStubSignVision implements SignVision {
  @override
  String get platformCaption => 'Vista previa: detección de manos solo en Android en este build.';

  @override
  Future<SignVisionDetectResult> detect(List<int> jpeg, int timestampMs) async {
    return const SignVisionDetectResult(ok: false, errorKey: 'stub');
  }

  @override
  Future<SignVisionInitResult> init() async {
    return const SignVisionInitResult(ok: false, errorKey: 'stub');
  }

  @override
  Future<void> releaseModel() async {}
}
