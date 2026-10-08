package com.example.vortextech_appdev_week4

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

// FlutterFragmentActivity is required by Health Connect's permission screen.
class MainActivity : FlutterFragmentActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // App lock: hide Life in recent apps and block screenshots.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "life/security").setMethodCallHandler { call, result ->
            if (call.method == "setSecure") {
                if (call.arguments == true) window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                else window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                result.success(null)
            } else {
                result.notImplemented()
            }
        }
        // Shortcuts for watch/band setup. Only these health apps can be
        // opened, so the channel can't be used to launch arbitrary apps.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "life/health_setup").setMethodCallHandler { call, result ->
            when (call.method) {
                "openHealthConnect" -> result.success(openHealthConnect())
                "openApp" -> {
                    val pkg = call.arguments as? String
                    if (pkg == null || pkg !in HEALTH_APPS) result.error("not_allowed", "Unknown app", null)
                    else result.success(openApp(pkg))
                }
                "installed" -> result.success(HEALTH_APPS.filter { packageManager.getLaunchIntentForPackage(it) != null })
                else -> result.notImplemented()
            }
        }
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "life/app_limits").setMethodCallHandler { call, result ->
            val ctx = applicationContext
            try {
                when (call.method) {
                    "status" -> result.success(mapOf("usageAccess" to AppLimits.hasUsageAccess(ctx), "overlay" to AppLimits.canDrawOverlays(ctx)))
                    "openUsageAccess" -> { AppLimits.openUsageAccessSettings(ctx); result.success(null) }
                    "openOverlay" -> { AppLimits.openOverlaySettings(ctx); result.success(null) }
                    "listApps" -> Thread {
                        val apps = AppLimits.listApps(ctx)
                        runOnUiThread { result.success(apps) }
                    }.start()
                    "getLimits" -> result.success(AppLimits.getLimits(ctx))
                    "setLimits" -> {
                        @Suppress("UNCHECKED_CAST")
                        val limits = (call.arguments as Map<String, Int>)
                        AppLimits.setLimits(ctx, limits)
                        AppLimitService.sync(ctx)
                        result.success(null)
                    }
                    "setFocusUntil" -> {
                        AppLimits.setFocusUntil(ctx, (call.arguments as Number).toLong())
                        AppLimitService.sync(ctx)
                        result.success(null)
                    }
                    "usageToday" -> {
                        val usage = AppLimits.usageToday(ctx, AppLimits.getLimits(ctx).keys)
                        result.success(usage.mapValues { it.value / 60_000 })
                    }
                    "labels" -> {
                        @Suppress("UNCHECKED_CAST")
                        val pkgs = call.arguments as List<String>
                        result.success(pkgs.associateWith { AppLimits.appLabel(ctx, it) })
                    }
                    else -> result.notImplemented()
                }
            } catch (e: Exception) {
                result.error("app_limits", e.message, null)
            }
        }
    }
}

private val HEALTH_APPS = setOf(
    "com.sec.android.app.shealth",
    "com.fitbit.FitbitMobile",
    "com.xiaomi.wearable",
    "com.mi.health",
    "com.huami.watch.hmwatchmanager",
    "com.google.android.apps.fitness",
    "com.garmin.android.apps.connectmobile",
    "com.google.android.apps.healthdata",
)

private fun FlutterFragmentActivity.openHealthConnect(): Boolean {
    val actions = if (Build.VERSION.SDK_INT >= 34) {
        listOf("android.health.connect.action.HEALTH_HOME_SETTINGS", "androidx.health.ACTION_HEALTH_CONNECT_SETTINGS")
    } else {
        listOf("androidx.health.ACTION_HEALTH_CONNECT_SETTINGS")
    }
    for (a in actions) {
        try {
            startActivity(Intent(a))
            return true
        } catch (_: Exception) {
        }
    }
    return openApp("com.google.android.apps.healthdata")
}

/** Opens the app, or its Play Store page if it isn't installed. */
private fun FlutterFragmentActivity.openApp(pkg: String): Boolean {
    val launch = packageManager.getLaunchIntentForPackage(pkg)
    return try {
        if (launch != null) startActivity(launch)
        else startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("market://details?id=$pkg")))
        true
    } catch (_: Exception) {
        try {
            startActivity(Intent(Intent.ACTION_VIEW, Uri.parse("https://play.google.com/store/apps/details?id=$pkg")))
            true
        } catch (_: Exception) {
            false
        }
    }
}

/** Restarts app-limit monitoring after the phone reboots. */
class BootReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == Intent.ACTION_BOOT_COMPLETED) AppLimitService.sync(context)
    }
}
