/// Conditional export: real TFLite on `dart.library.io`; web stub without `tflite_flutter`.
export 'tflite_sign_classifier_web.dart' if (dart.library.io) 'tflite_sign_classifier_io.dart';
