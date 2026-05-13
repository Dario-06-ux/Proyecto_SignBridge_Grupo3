Place the official MediaPipe **Hand Landmarker** task file here:

  hand_landmarker.task

Source: Google AI Edge documentation for Hand Landmarker (download the Android
`.task` bundle). The Kotlin bridge loads it with BaseOptions.setModelAssetPath(
"hand_landmarker.task").

Without this file, `SignVision.init()` on Android returns ok=false with error
missing_model_asset; the Flutter UI still compiles and shows setup hints.
