SignBridge on-device models
===========================

1) MediaPipe Hand Landmarker (Android, native)
---------------------------------------------
This build expects the official **Hand Landmarker** task bundle on Android:

  File name: hand_landmarker.task
  Location:   android/app/src/main/assets/hand_landmarker.task

Download from Google AI Edge (Hand Landmarker task, `.task` format) and copy
the file into `android/app/src/main/assets/`. Without this file, the Android
MethodChannel still responds but `init` returns `missing_model_asset` and the
camera UI falls back to landmark-only messaging.

2) Optional TFLite classifier (Flutter / tflite_flutter)
-------------------------------------------------------
To classify the first detected hand from 21 landmarks (63 floats: x,y,z per
landmark, normalized):

  Asset path: assets/models/sign_classifier.tflite
  Input:  float32 tensor shape [1, N] with N >= 63 (extra values padded with 0)
  Output: float32 tensor shape [1, C] — logits or pre-softmax per class C

Train with TensorFlow/Keras, convert with the TensorFlow Lite converter, then
add the file and run `flutter pub get`. If the file is absent or invalid, the
app still runs and shows MediaPipe hand count / landmark status only.

There is intentionally **no** bundled `.tflite` in this repo (binary + license
size). Add your own trained model when you have gesture labels.
