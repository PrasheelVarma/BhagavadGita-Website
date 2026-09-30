package com.reshapel.bhagavadgita

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    companion object {
        const val CHANNEL = "com.reshapel.bhagavadgita/background_audio"
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(
            flutterEngine.dartExecutor.binaryMessenger,
            CHANNEL,
        ).setMethodCallHandler { call, result ->
            when (call.method) {
                "startService" -> {
                    BackgroundAudioService.start(this)
                    result.success(null)
                }
                "stopService" -> {
                    BackgroundAudioService.stop(this)
                    result.success(null)
                }
                else -> result.notImplemented()
            }
        }
    }
}
