package com.example.detector_senas

import android.os.Handler
import android.os.Looper
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val mainHandler = Handler(Looper.getMainLooper())
    private var bridge: HandLandmarkerBridge? = null

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        bridge = HandLandmarkerBridge(applicationContext)
        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "init" -> {
                    bridge?.initialize { map ->
                        mainHandler.post { result.success(map) }
                    } ?: result.error("no_bridge", "Hand landmarker bridge not ready", null)
                }
                "detect" -> {
                    val args = call.arguments as? Map<*, *>
                    val jpeg = args?.get("jpeg") as? ByteArray
                    val t = (args?.get("timestampMs") as? Number)?.toLong() ?: System.currentTimeMillis()
                    if (jpeg == null) {
                        result.error("bad_args", "Missing jpeg byte array", null)
                        return@setMethodCallHandler
                    }
                    bridge?.detectJpeg(jpeg, t) { map ->
                        mainHandler.post { result.success(map) }
                    } ?: result.error("no_bridge", "Hand landmarker bridge not ready", null)
                }
                "dispose" -> {
                    bridge?.releaseModel()
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }

    override fun onDestroy() {
        bridge?.close()
        bridge = null
        super.onDestroy()
    }

    companion object {
        const val CHANNEL = "com.example.detector_senas/sign_vision"
    }
}
