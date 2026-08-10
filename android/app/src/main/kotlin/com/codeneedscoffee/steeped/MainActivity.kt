package com.codeneedscoffee.steeped

import android.os.StatFs
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val channelName = "steeped/device_storage"

    override fun configureFlutterEngine(@NonNull flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, channelName)
            .setMethodCallHandler { call, result ->
                if (call.method == "freeBytes") {
                    val stat = StatFs(filesDir.path)
                    result.success(stat.availableBytes)
                } else {
                    result.notImplemented()
                }
            }
    }
}
