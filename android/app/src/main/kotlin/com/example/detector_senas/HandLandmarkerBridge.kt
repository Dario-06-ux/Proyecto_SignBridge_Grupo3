package com.example.detector_senas

import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import com.google.mediapipe.framework.image.BitmapImageBuilder
import com.google.mediapipe.tasks.core.BaseOptions
import com.google.mediapipe.tasks.vision.core.RunningMode
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarker
import com.google.mediapipe.tasks.vision.handlandmarker.HandLandmarkerResult
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

/**
 * Wraps MediaPipe Tasks Vision [HandLandmarker] (VIDEO mode) for JPEG frames from Flutter.
 * Requires [android/app/src/main/assets/hand_landmarker.task] at runtime (see project README).
 */
class HandLandmarkerBridge(private val context: Context) {

    private val executor = Executors.newSingleThreadExecutor()
    private var handLandmarker: HandLandmarker? = null

    fun initialize(callback: (Map<String, Any>) -> Unit) {
        executor.execute {
            val modelExists = assetExists("hand_landmarker.task")
            if (!modelExists) {
                callback(
                    mapOf(
                        "ok" to false,
                        "error" to "missing_model_asset",
                        "hint" to "Add hand_landmarker.task under android/app/src/main/assets/",
                    ),
                )
                return@execute
            }
            try {
                handLandmarker?.close()
                handLandmarker = null
                val baseOptions = BaseOptions.builder()
                    .setModelAssetPath("hand_landmarker.task")
                    .build()
                val options = HandLandmarker.HandLandmarkerOptions.builder()
                    .setBaseOptions(baseOptions)
                    .setNumHands(2)
                    .setMinHandDetectionConfidence(0.5f)
                    .setMinHandPresenceConfidence(0.5f)
                    .setMinTrackingConfidence(0.5f)
                    .setRunningMode(RunningMode.VIDEO)
                    .build()
                handLandmarker = HandLandmarker.createFromOptions(context, options)
                callback(mapOf("ok" to true))
            } catch (e: Exception) {
                callback(
                    mapOf(
                        "ok" to false,
                        "error" to "init_failed",
                        "message" to (e.message ?: e.toString()),
                    ),
                )
            }
        }
    }

    fun detectJpeg(jpeg: ByteArray, timestampMs: Long, callback: (Map<String, Any>) -> Unit) {
        executor.execute {
            val landmarker = handLandmarker
            if (landmarker == null) {
                callback(mapOf("ok" to false, "error" to "not_initialized"))
                return@execute
            }
            var bitmap: Bitmap? = null
            try {
                bitmap = BitmapFactory.decodeByteArray(jpeg, 0, jpeg.size)
                if (bitmap == null) {
                    callback(mapOf("ok" to false, "error" to "decode_failed"))
                    return@execute
                }
                val mpImage = BitmapImageBuilder(bitmap).build()
                val result: HandLandmarkerResult = landmarker.detectForVideo(mpImage, timestampMs)
                val hands = mutableListOf<Map<String, Any>>()
                for (hand in result.landmarks()) {
                    val flat = ArrayList<Double>(21 * 3)
                    for (lm in hand) {
                        flat.add(lm.x().toDouble())
                        flat.add(lm.y().toDouble())
                        flat.add(lm.z().toDouble())
                    }
                    hands.add(mapOf("landmarks" to flat))
                }
                callback(
                    mapOf(
                        "ok" to true,
                        "handCount" to hands.size,
                        "hands" to hands,
                    ),
                )
            } catch (e: Exception) {
                callback(
                    mapOf(
                        "ok" to false,
                        "error" to "detect_failed",
                        "message" to (e.message ?: e.toString()),
                    ),
                )
            } finally {
                bitmap?.recycle()
            }
        }
    }

    /** Releases the native model; the executor stays alive for a later [initialize]. */
    fun releaseModel() {
        executor.execute {
            try {
                handLandmarker?.close()
            } catch (_: Exception) {
            } finally {
                handLandmarker = null
            }
        }
    }

    fun close() {
        executor.execute {
            try {
                handLandmarker?.close()
            } catch (_: Exception) {
            } finally {
                handLandmarker = null
            }
        }
        executor.shutdown()
        try {
            if (!executor.awaitTermination(3, TimeUnit.SECONDS)) {
                executor.shutdownNow()
            }
        } catch (_: InterruptedException) {
            executor.shutdownNow()
        }
    }

    private fun assetExists(path: String): Boolean {
        return try {
            context.assets.open(path).use { true }
        } catch (_: Exception) {
            false
        }
    }

}
