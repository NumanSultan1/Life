package com.example.vortextech_appdev_week4

import android.app.AppOpsManager
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.Bitmap
import android.graphics.Canvas
import android.net.Uri
import android.os.Build
import android.os.Process
import android.provider.Settings
import org.json.JSONObject
import java.io.ByteArrayOutputStream
import java.util.Calendar

/**
 * App time limits: which apps are limited, how long they've been used
 * today (from Android's usage stats), and which app is in front.
 */
object AppLimits {
    private const val PREFS = "life_app_limits"
    private const val KEY_LIMITS = "limits"

    // --- Limits (package -> minutes per day), stored natively so the
    // background service can read them without Flutter running. ---

    fun getLimits(ctx: Context): Map<String, Int> {
        val json = ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getString(KEY_LIMITS, "{}") ?: "{}"
        val obj = JSONObject(json)
        return obj.keys().asSequence().associateWith { obj.getInt(it) }
    }

    fun setLimits(ctx: Context, limits: Map<String, Int>) {
        val obj = JSONObject()
        limits.forEach { (pkg, minutes) -> obj.put(pkg, minutes) }
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putString(KEY_LIMITS, obj.toString()).apply()
    }

    // --- Focus mode: limited apps are blocked until this time ---

    fun focusUntil(ctx: Context): Long =
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).getLong("focusUntil", 0L)

    fun setFocusUntil(ctx: Context, until: Long) {
        ctx.getSharedPreferences(PREFS, Context.MODE_PRIVATE).edit().putLong("focusUntil", until).apply()
    }

    // --- Permissions ---

    fun hasUsageAccess(ctx: Context): Boolean {
        val ops = ctx.getSystemService(Context.APP_OPS_SERVICE) as AppOpsManager
        val mode = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
            ops.unsafeCheckOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        } else {
            @Suppress("DEPRECATION")
            ops.checkOpNoThrow(AppOpsManager.OPSTR_GET_USAGE_STATS, Process.myUid(), ctx.packageName)
        }
        return mode == AppOpsManager.MODE_ALLOWED
    }

    fun canDrawOverlays(ctx: Context): Boolean = Settings.canDrawOverlays(ctx)

    fun openUsageAccessSettings(ctx: Context) {
        ctx.startActivity(Intent(Settings.ACTION_USAGE_ACCESS_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
    }

    fun openOverlaySettings(ctx: Context) {
        ctx.startActivity(
            Intent(Settings.ACTION_MANAGE_OVERLAY_PERMISSION, Uri.parse("package:${ctx.packageName}")).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    // --- Installed apps ---

    /** Launchable apps (not Life itself), with a small PNG icon. */
    fun listApps(ctx: Context): List<Map<String, Any>> {
        val pm = ctx.packageManager
        val intent = Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_LAUNCHER)
        return pm.queryIntentActivities(intent, 0)
            .map { it.activityInfo.applicationInfo }
            .distinctBy { it.packageName }
            .filter { it.packageName != ctx.packageName }
            .map { info ->
                mapOf(
                    "package" to info.packageName,
                    "label" to pm.getApplicationLabel(info).toString(),
                    "icon" to iconPng(pm.getApplicationIcon(info)),
                )
            }
            .sortedBy { (it["label"] as String).lowercase() }
    }

    fun appLabel(ctx: Context, pkg: String): String = try {
        val pm = ctx.packageManager
        pm.getApplicationLabel(pm.getApplicationInfo(pkg, 0)).toString()
    } catch (e: Exception) {
        pkg
    }

    private fun iconPng(drawable: android.graphics.drawable.Drawable): ByteArray {
        val size = 96
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        drawable.setBounds(0, 0, size, size)
        drawable.draw(canvas)
        val out = ByteArrayOutputStream()
        bitmap.compress(Bitmap.CompressFormat.PNG, 100, out)
        return out.toByteArray()
    }

    // --- Usage ---

    private fun midnight(): Long = Calendar.getInstance().apply {
        set(Calendar.HOUR_OF_DAY, 0); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0); set(Calendar.MILLISECOND, 0)
    }.timeInMillis

    /** Foreground time today, in milliseconds, for each of [packages]. */
    fun usageToday(ctx: Context, packages: Set<String>): Map<String, Long> {
        if (packages.isEmpty() || !hasUsageAccess(ctx)) return emptyMap()
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val events = usm.queryEvents(midnight(), end)
        val event = UsageEvents.Event()
        val openedAt = HashMap<String, Long>()
        val totals = HashMap<String, Long>()
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            val pkg = event.packageName ?: continue
            if (pkg !in packages) continue
            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> openedAt[pkg] = event.timeStamp
                UsageEvents.Event.ACTIVITY_PAUSED, UsageEvents.Event.ACTIVITY_STOPPED ->
                    openedAt.remove(pkg)?.let { totals[pkg] = (totals[pkg] ?: 0L) + (event.timeStamp - it) }
            }
        }
        // Apps still on screen count up to now.
        openedAt.forEach { (pkg, start) -> totals[pkg] = (totals[pkg] ?: 0L) + (end - start) }
        return totals
    }

    /** The app currently in front, from the last minute of events. */
    fun foregroundApp(ctx: Context): String? {
        if (!hasUsageAccess(ctx)) return null
        val usm = ctx.getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
        val end = System.currentTimeMillis()
        val events = usm.queryEvents(end - 60_000, end)
        val event = UsageEvents.Event()
        var current: String? = null
        while (events.hasNextEvent()) {
            events.getNextEvent(event)
            when (event.eventType) {
                UsageEvents.Event.ACTIVITY_RESUMED -> current = event.packageName
                UsageEvents.Event.ACTIVITY_PAUSED -> if (event.packageName == current) current = null
            }
        }
        return current
    }
}
