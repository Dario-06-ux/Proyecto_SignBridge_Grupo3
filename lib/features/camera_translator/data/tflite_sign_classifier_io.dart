import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

/// Optional landmark classifier using [tflite_flutter] (VM / mobile / desktop only).
///
/// Expects a float32 model with input shape `[1, N]` where `N >= 63` (one hand,
/// 21 landmarks × xyz; extra inputs are padded with 0). Output shape `[1, C]`
/// logits or pre-softmax scores per class `C`.
class TfliteSignClassifier {
  Interpreter? _interpreter;
  int _numClasses = 0;
  int _inputLen = 0;
  bool _loadAttempted = false;

  bool get isLoaded => _interpreter != null && _numClasses > 0;

  Future<void> tryLoadFromAssetOnce(String assetPath) async {
    if (_loadAttempted) return;
    _loadAttempted = true;
    try {
      final data = await rootBundle.load(assetPath);
      if (data.lengthInBytes < 64) {
        return;
      }
      _interpreter?.close();
      final interpreter = Interpreter.fromBuffer(data.buffer.asUint8List());
      final inShape = interpreter.getInputTensor(0).shape;
      final outShape = interpreter.getOutputTensor(0).shape;
      if (inShape.length != 2 || inShape[0] != 1 || outShape.length != 2 || outShape[0] != 1) {
        interpreter.close();
        return;
      }
      _inputLen = inShape[1];
      _numClasses = outShape[1];
      if (_inputLen < 63 || _numClasses < 1) {
        interpreter.close();
        return;
      }
      _interpreter = interpreter;
      debugPrint('TfliteSignClassifier: loaded in=$inShape out=$outShape');
    } catch (e, st) {
      debugPrint('TfliteSignClassifier: skip ($assetPath): $e\n$st');
      _interpreter?.close();
      _interpreter = null;
      _numClasses = 0;
    }
  }

  void close() {
    _interpreter?.close();
    _interpreter = null;
    _numClasses = 0;
    _loadAttempted = false;
  }

  ({int index, double confidence})? classifyFirstHand(List<double> flat63) {
    final interpreter = _interpreter;
    if (interpreter == null || _numClasses == 0 || flat63.length < 63) {
      return null;
    }
    final input = <List<double>>[
      List<double>.generate(_inputLen, (i) => i < 63 ? flat63[i] : 0.0),
    ];
    final output = <List<double>>[List<double>.filled(_numClasses, 0.0)];
    try {
      interpreter.run(input, output);
    } catch (e, st) {
      debugPrint('TfliteSignClassifier run failed: $e\n$st');
      return null;
    }
    return _softmaxArgmax(output[0]);
  }

  ({int index, double confidence}) _softmaxArgmax(List<double> logits) {
    var maxL = logits[0];
    for (final l in logits) {
      if (l > maxL) maxL = l;
    }
    var sum = 0.0;
    final exp = List<double>.filled(logits.length, 0);
    for (var i = 0; i < logits.length; i++) {
      exp[i] = math.exp(logits[i] - maxL);
      sum += exp[i];
    }
    if (sum <= 0) {
      return (index: 0, confidence: 0);
    }
    var bestI = 0;
    var bestP = exp[0] / sum;
    for (var i = 1; i < exp.length; i++) {
      final p = exp[i] / sum;
      if (p > bestP) {
        bestP = p;
        bestI = i;
      }
    }
    return (index: bestI, confidence: bestP);
  }
}
