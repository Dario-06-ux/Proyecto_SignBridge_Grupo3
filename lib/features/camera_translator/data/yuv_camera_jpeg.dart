import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:image/image.dart' as img;

/// Converts a [CameraImage] in YUV420 to a downscaled JPEG for native MediaPipe.
Uint8List? yuv420CameraImageToJpeg(
  CameraImage image, {
  int maxSide = 480,
  int quality = 78,
}) {
  final converted = _yuv420ToRgbImage(image);
  if (converted == null) return null;
  final w = converted.width;
  final h = converted.height;
  final scale = maxSide / (w > h ? w : h);
  final tw = (w * scale).round().clamp(1, 9999);
  final th = (h * scale).round().clamp(1, 9999);
  final resized = img.copyResize(converted, width: tw, height: th, interpolation: img.Interpolation.linear);
  return Uint8List.fromList(img.encodeJpg(resized, quality: quality));
}

img.Image? _yuv420ToRgbImage(CameraImage image) {
  if (image.planes.length < 2) return null;
  final width = image.width;
  final height = image.height;
  final out = img.Image(width: width, height: height);

  final yPlane = image.planes[0];
  final yRowStride = yPlane.bytesPerRow;
  final yBytes = yPlane.bytes;

  if (image.planes.length >= 3) {
    final uPlane = image.planes[1];
    final vPlane = image.planes[2];
    final uRowStride = uPlane.bytesPerRow;
    final vRowStride = vPlane.bytesPerRow;
    final uBytes = uPlane.bytes;
    final vBytes = vPlane.bytes;
    final uPixStride = uPlane.bytesPerPixel ?? 1;
    final vPixStride = vPlane.bytesPerPixel ?? 1;

    for (var y = 0; y < height; y++) {
      final uvRow = (y >> 1) * uRowStride;
      final vRow = (y >> 1) * vRowStride;
      final yRow = y * yRowStride;
      for (var x = 0; x < width; x++) {
        final yp = yBytes[yRow + x];
        final cx = (x >> 1);
        final up = uBytes[uvRow + cx * uPixStride] - 128;
        final vp = vBytes[vRow + cx * vPixStride] - 128;
        final r = (yp + 1.402 * vp).round().clamp(0, 255);
        final g = (yp - 0.344136 * up - 0.714136 * vp).round().clamp(0, 255);
        final b = (yp + 1.772 * up).round().clamp(0, 255);
        out.setPixelRgb(x, y, r, g, b);
      }
    }
    return out;
  }

  // NV21-style: plane1 is interleaved UV
  final uvPlane = image.planes[1];
  final uvRowStride = uvPlane.bytesPerRow;
  final uvBytes = uvPlane.bytes;
  final uvPixStride = uvPlane.bytesPerPixel ?? 2;

  for (var y = 0; y < height; y++) {
    final uvRow = (y >> 1) * uvRowStride;
    final yRow = y * yRowStride;
    for (var x = 0; x < width; x++) {
      final yp = yBytes[yRow + x];
      final uvOffset = (x >> 1) * uvPixStride;
      final u = uvBytes[uvRow + uvOffset] - 128;
      final v = uvBytes[uvRow + uvOffset + 1] - 128;
      final r = (yp + 1.402 * v).round().clamp(0, 255);
      final g = (yp - 0.344136 * u - 0.714136 * v).round().clamp(0, 255);
      final b = (yp + 1.772 * u).round().clamp(0, 255);
      out.setPixelRgb(x, y, r, g, b);
    }
  }
  return out;
}
