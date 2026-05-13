# SignBridge (Flutter)

SignBridge is a demo app for sign-language literacy exploration: a **chat** tab that maps a few Spanish phrases to example GIF paths, and a **camera** tab (**SignBridge Visión**) with an **Android-first** on-device pipeline:

- **MediaPipe Tasks Vision — Hand Landmarker** (Kotlin) on JPEG frames from the Flutter `camera` stream, exposed over a **`MethodChannel`** (`com.example.detector_senas/sign_vision`).
- **TensorFlow Lite** (optional) in Dart via **`tflite_flutter`**, consuming the **63 floats** (21 landmarks × x,y,z) of the first detected hand. If no `.tflite` is present, the UI still shows **live hand counts** and a simple **depth heuristic** from landmark z.

**iOS** compiles and runs: the same channel is registered in Swift with a **stub** response; the camera UI shows **“Próximamente en iOS”** and does not start the JPEG → native pipeline. Wiring MediaPipe Tasks + a `.task` bundle on iOS is left as a follow-up (CocoaPods / SPM + Swift bridge).

The Dart package name remains **`detector_senas`** for imports; user-visible branding uses **SignBridge**.

---

## Requirements

- Flutter SDK (Dart `>=3.0.0 <4.0.0`)
- **Android**
  - **Android Studio** with **Android SDK** and **NDK** (Flutter’s template already sets `ndkVersion` from the Flutter Gradle plugin; MediaPipe pulls native libs — use a recent stable Flutter + AGP).
  - **`minSdk` 24** (see `android/app/build.gradle.kts`).
- **iOS**
  - **Xcode** and **CocoaPods** (`ios/Podfile` is included; run `pod install` inside `ios/` after `flutter pub get` if you build for a device or simulator).

---

## What you must download (not committed here)

### 1) Hand Landmarker task (Android, required for real landmarks)

1. Download the official **Hand Landmarker** `.task` bundle from **Google AI Edge** / MediaPipe documentation (same artifact used in the Android Tasks Vision samples).
2. Copy the file to:

   `android/app/src/main/assets/hand_landmarker.task`

   (exact filename; see also `android/app/src/main/assets/README_HAND_LANDMARKER.txt`.)

Without this file, Android `init` returns `missing_model_asset` and the UI explains that the task bundle is missing.

### 2) Optional gesture classifier (Flutter / TFLite)

1. Train a small model whose **float32** input is shape **`[1, N]`** with **`N >= 63`** (first 63 values = one hand’s x,y,z in MediaPipe order; pad extras with `0` if needed).
2. Output shape **`[1, C]`** — logits or pre-softmax scores per class **`C`** (the app applies softmax in Dart).
3. Save as **`assets/models/sign_classifier.tflite`** and run `flutter pub get`.

Details: `assets/models/README_MODELS.txt`.

There is **no** bundled `.tflite` in this repository (size + licensing). The app runs **landmark-only** until you add one.

---

## Trade-offs (MediaPipe + Flutter)

| Approach | Pros | Cons |
|----------|------|------|
| **Native MediaPipe + MethodChannel** (this project on Android) | Full Tasks Vision model, GPU-friendly native runtime | JPEG bridge + YUV→RGB in Dart adds latency; tune `maxSide` / FPS throttle |
| **Single end-to-end TFLite** | One model in Dart; simpler channel | Training data / architecture must replace hand solution quality |
| **Dual-platform MediaPipe in one pass** | Parity | Large effort (iOS Pods/SPM, task assets, lifecycle, performance tuning) |

This repo **ships Android-first** with iOS stub + UI fallback so **both platforms keep compiling**.

---

## Setup

1. `flutter pub get`
2. Add **`hand_landmarker.task`** to Android assets (above).
3. (Optional) Add **`assets/models/sign_classifier.tflite`** and keep it listed under `flutter: assets:` (`assets/models/` is already included).
4. **GIFs** (chat tab): see `assets/gifs/README.txt` and `tool/create_placeholder_assets.dart` as before.

### iOS CocoaPods

From the project root:

```bash
cd ios
pod install
cd ..
flutter run
```

---

## Run

```bash
cd /path/to/detector_senas
flutter run
```

---

## Cómo ejecutar (español)

1. **Instala dependencias**

   ```bash
   cd /ruta/a/detector_senas
   flutter pub get
   ```

2. **Comprueba dispositivos disponibles**

   ```bash
   flutter devices
   ```

   Anota el **id** del dispositivo (por ejemplo `chrome`, `windows`, o un id largo de un teléfono Android).

3. **Ejecutar en Chrome (web)**

   ```bash
   flutter run -d chrome
   ```

   En web el **chat** y los GIFs funcionan con normalidad; la **cámara con MediaPipe en tiempo real está pensada sobre todo para Android** (en web verás un aviso en la pestaña de cámara).

4. **Ejecutar en Android (recomendado para cámara + ML)**

   - Coloca el modelo **`hand_landmarker.task`** en  
     `android/app/src/main/assets/hand_landmarker.task`  
     (sin este archivo, Android mostrará el error `missing_model_asset`; ver README arriba).
   - Conecta el dispositivo o arranca un emulador y ejecuta:

     ```bash
     flutter run -d <id_del_dispositivo>
     ```

     El `<id_del_dispositivo>` es el que lista `flutter devices` (no hace falta que sea exactamente la palabra `android`).

5. **iOS (Xcode + CocoaPods)**

   Tras `flutter pub get`, instala pods y abre el workspace generado:

   ```bash
   cd ios
   pod install
   cd ..
   flutter run -d <id_simulador_o_iphone>
   ```

   En iOS la cámara compila, pero el **puente nativo de MediaPipe va como stub**: la experiencia completa **cámara + hand landmarker** es **prioritaria en Android** por ahora.

---

## Permissions

- **Android**: `CAMERA` in `AndroidManifest.xml`; runtime permission on the camera tab via `permission_handler`.
- **iOS**: `NSCameraUsageDescription` in `ios/Runner/Info.plist`. For `permission_handler` extras (e.g. `PERMISSION_CAMERA=1`), follow the [permission_handler iOS setup](https://pub.dev/packages/permission_handler) if you extend permissions later.

---

## Training / replacing the TFLite model

1. Build a dataset of **63-D vectors** (or more with padding) from MediaPipe landmarks (or from your own preprocessing aligned with the same landmark order).
2. Train a classifier (TensorFlow/Keras), then convert:

   `tensorflow.lite.TFLiteConverter.from_keras_model(model).convert()`

3. Validate input/output dtypes are **float32** and shapes match the contract in `README_MODELS.txt`.
4. Drop the file into `assets/models/sign_classifier.tflite` and hot-restart the app (or bump the asset and rebuild).

---

## Deferred / follow-ups

- **iOS**: bundle MediaPipe Tasks, ship `hand_landmarker.task` in the app, run inference in Swift, return the same JSON shape as Android (or adopt **Pigeon** for typed contracts).
- **Performance**: move JPEG encoding to an **isolate**, lower preview JPEG size further, or pass **NV21** buffers natively to avoid Dart-side YUV conversion.
- **Riverpod**: camera screen is still `StatefulWidget`; you can migrate pipeline state to providers later without changing the native contract.
