import 'package:flutter/foundation.dart';

/// Web stub: [package:tflite_flutter] uses `dart:ffi`, which is unavailable on web.
/// Same public API as [TfliteSignClassifier] on IO so [CameraScreen] compiles everywhere.
class TfliteSignClassifier {
  bool _loadAttempted = false;

  bool get isLoaded => false;

  Future<void> tryLoadFromAssetOnce(String assetPath) async {
    if (_loadAttempted) return;
    _loadAttempted = true;
    debugPrint('TfliteSignClassifier (web stub): skip loading $assetPath');
  }

  void close() {
    _loadAttempted = false;
  }

  ({int index, double confidence})? classifyFirstHand(List<double> flat63) => null;
}
