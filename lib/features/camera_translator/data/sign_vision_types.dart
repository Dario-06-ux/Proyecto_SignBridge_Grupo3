/// Native hand pipeline (MediaPipe on Android; graceful fallback elsewhere).
abstract class SignVision {
  Future<SignVisionInitResult> init();

  Future<SignVisionDetectResult> detect(List<int> jpeg, int timestampMs);

  Future<void> releaseModel();

  /// Short line for the bottom card when ML is unavailable or degraded.
  String get platformCaption;
}

class SignVisionInitResult {
  const SignVisionInitResult({required this.ok, this.errorKey, this.hint});

  final bool ok;
  final String? errorKey;
  final String? hint;

  factory SignVisionInitResult.fromMap(Map<Object?, Object?> m) {
    final ok = m['ok'] == true;
    final err = m['error'] as String?;
    final hint = m['hint'] as String? ?? m['message'] as String?;
    return SignVisionInitResult(ok: ok, errorKey: err, hint: hint);
  }
}

class SignVisionDetectResult {
  const SignVisionDetectResult({
    required this.ok,
    this.errorKey,
    this.handCount = 0,
    this.hands = const [],
  });

  final bool ok;
  final String? errorKey;
  final int handCount;
  final List<HandLandmarks> hands;

  factory SignVisionDetectResult.fromMap(Map<Object?, Object?> m) {
    final ok = m['ok'] == true;
    final err = m['error'] as String?;
    final count = (m['handCount'] as num?)?.toInt() ?? 0;
    final rawHands = m['hands'] as List<dynamic>? ?? const [];
    final hands = <HandLandmarks>[];
    for (final h in rawHands) {
      if (h is! Map) continue;
      final lm = (h['landmarks'] as List<dynamic>?)?.map((e) => (e as num).toDouble()).toList() ?? const <double>[];
      hands.add(HandLandmarks(lm));
    }
    return SignVisionDetectResult(ok: ok, errorKey: err, handCount: count, hands: hands);
  }
}

class HandLandmarks {
  const HandLandmarks(this.flat);

  /// Length 63 for one hand (21 × x,y,z), normalized coordinates from MediaPipe.
  final List<double> flat;
}
