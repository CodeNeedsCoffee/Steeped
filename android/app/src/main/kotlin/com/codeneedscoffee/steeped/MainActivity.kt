package com.codeneedscoffee.steeped

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.os.StatFs
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val channelName = "steeped/device_storage"
    private val reminderChannelName = "steeped/reminders"

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
        // Streak reminders (PLAN.md G7): one inexact alarm. Inexact on
        // purpose: `setAndAllowWhileIdle` needs no exact-alarm permission and
        // a reminder a few minutes late is fine. Alarms do not survive a
        // reboot; Dart reschedules on the next app start.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, reminderChannelName)
            .setMethodCallHandler { call, result ->
                val alarms = getSystemService(Context.ALARM_SERVICE) as AlarmManager
                fun pending(extras: Map<String, String?>): PendingIntent {
                    val intent = Intent(this, ReminderReceiver::class.java)
                    extras.forEach { (k, v) -> intent.putExtra(k, v) }
                    return PendingIntent.getBroadcast(
                        this, 4711, intent,
                        PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                    )
                }
                when (call.method) {
                    "schedule" -> {
                        val at = (call.argument<Number>("at") ?: 0).toLong()
                        alarms.setAndAllowWhileIdle(
                            AlarmManager.RTC,
                            at,
                            pending(
                                mapOf(
                                    "title" to call.argument<String>("title"),
                                    "body" to call.argument<String>("body"),
                                    "channelName" to call.argument<String>("channelName"),
                                ),
                            ),
                        )
                        result.success(null)
                    }
                    "cancel" -> {
                        alarms.cancel(pending(emptyMap()))
                        result.success(null)
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
