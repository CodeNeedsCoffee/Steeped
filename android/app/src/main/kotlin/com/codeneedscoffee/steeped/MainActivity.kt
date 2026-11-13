package com.codeneedscoffee.steeped

import android.app.AlarmManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import android.net.ConnectivityManager
import android.content.pm.ApplicationInfo
import android.os.StatFs
import android.util.Log
import androidx.annotation.NonNull
import com.ryanheise.audioservice.AudioServiceActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : AudioServiceActivity() {
    private val channelName = "steeped/device_storage"
    private val reminderChannelName = "steeped/reminders"
    private val preciseChannelName = "steeped/precise"
    private val precise by lazy { PreciseRecognizer(this) }

    // Debug builds only: adb can start a recognition test with
    //   am start -n .../.MainActivity --es precise_url URL --el precise_start MS
    //     --el precise_dur MS --es precise_lang en-US
    // and read the outcome from `logcat -s PreciseSpike`.
    private fun runPreciseSpike(intent: Intent?) {
        val url = intent?.getStringExtra("precise_url") ?: return
        if (applicationInfo.flags and ApplicationInfo.FLAG_DEBUGGABLE == 0) return
        val start = intent.getLongExtra("precise_start", 0)
        val dur = intent.getLongExtra("precise_dur", 30000)
        val lang = intent.getStringExtra("precise_lang") ?: "en-US"
        precise.useFile = intent.getStringExtra("precise_file") == "1"
        precise.segmented = intent.getStringExtra("precise_seg") != "0"
        Log.i("PreciseSpike", "available=${precise.available()} file=${precise.useFile} seg=${precise.segmented}")
        precise.recognize(url, start, dur, lang) { r -> Log.i("PreciseSpike", "result=$r") }
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        runPreciseSpike(intent)
    }

    override fun onPostResume() {
        super.onPostResume()
        runPreciseSpike(intent)
        intent?.removeExtra("precise_url")
    }

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
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, preciseChannelName)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "available" -> result.success(precise.available())
                    "recognize" -> precise.recognize(
                        call.argument<String>("url") ?: "",
                        (call.argument<Number>("startMs") ?: 0).toLong(),
                        (call.argument<Number>("durMs") ?: 30000).toLong(),
                        call.argument<String>("lang") ?: "en-US",
                    ) { r -> result.success(r) }
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
