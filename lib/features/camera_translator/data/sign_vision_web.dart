import 'sign_vision_types.dart';

SignVision createSignVisionFromPlatform() => _WebStubSignVision();

class _WebStubSignVision implements SignVision {
  @override
  String get platformCaption => 'La cámara con ML de manos no está disponible en web en este demo.';

  @override
  Future<SignVisionDetectResult> detect(List<int> jpeg, int timestampMs) async {
    return const SignVisionDetectResult(ok: false, errorKey: 'web_stub');
  }

  @override
  Future<SignVisionInitResult> init() async {
    return const SignVisionInitResult(ok: false, errorKey: 'web_stub');
  }

  @override
  Future<void> releaseModel() async {}
}
