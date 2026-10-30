package com.codeneedscoffee.steeped

import android.content.Context
import android.net.ConnectivityManager
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
                when (call.method) {
                    "freeBytes" -> {
                        val stat = StatFs(filesDir.path)
                        result.success(stat.availableBytes)
                    }
                    // True when the active network is metered (cellular, or a
                    // Wi-Fi hotspot marked as metered). ACCESS_NETWORK_STATE
                    // is already merged in via connectivity_plus.
                    "isMetered" -> {
                        val cm = getSystemService(Context.CONNECTIVITY_SERVICE)
                            as ConnectivityManager
                        result.success(cm.isActiveNetworkMetered)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
