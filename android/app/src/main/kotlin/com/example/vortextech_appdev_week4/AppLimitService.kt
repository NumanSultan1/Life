package com.example.vortextech_appdev_week4

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.Service
import android.content.Context
import android.content.Intent
import android.content.pm.ServiceInfo
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Keeps an eye on limited apps while any limit is set: every couple of
 * seconds it checks which app is in front, and if that app has used up
 * today's time it shows the "time's up" screen. Also warns 5 minutes
 * before a limit.
 */
class AppLimitService : Service() {
    companion object {
        private const val CHANNEL = "life_app_limits"
        private const val ONGOING_ID = 7001
        private const val CHECK_EVERY_MS = 2_000L
        private const val USAGE_REFRESH_MS = 15_000L

        /** Starts or stops the service to match the saved limits. */
        fun sync(ctx: Context) {
            val intent = Intent(ctx, AppLimitService::class.java)
            if (AppLimits.getLimits(ctx).isEmpty()) {
                ctx.stopService(intent)
            } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                ctx.startForegroundService(intent)
            } else {
                ctx.startService(intent)
            }
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var usage: Map<String, Long> = emptyMap()
    private var usageReadAt = 0L
    private var lastBlockAt = 0L
    private val warned = HashSet<String>()
    private var warnedDay = ""

    private val tick = object : Runnable {
        override fun run() {
            try {
                check()
            } catch (e: Exception) {
                // Never crash the service; try again next tick.
            }
            handler.postDelayed(this, CHECK_EVERY_MS)
        }
    }

    override fun onBind(intent: Intent?): IBinder? = null

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        createChannel()
        val open = PendingIntent.getActivity(
            this, 0, packageManager.getLaunchIntentForPackage(packageName), PendingIntent.FLAG_IMMUTABLE
        )
        val count = AppLimits.getLimits(this).size
        val notification = Notification.Builder(this, CHANNEL)
            .setSmallIcon(R.drawable.ic_stat_life)
            .setContentTitle("App limits are on")
            .setContentText("Life is keeping $count app${if (count == 1) "" else "s"} within today's time.")
            .setContentIntent(open)
            .setOngoing(true)
            .build()
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
            startForeground(ONGOING_ID, notification, ServiceInfo.FOREGROUND_SERVICE_TYPE_SPECIAL_USE)
        } else {
            startForeground(ONGOING_ID, notification)
        }
        handler.removeCallbacks(tick)
        handler.post(tick)
        return START_STICKY
    }

    override fun onDestroy() {
        handler.removeCallbacks(tick)
        super.onDestroy()
    }

    private fun check() {
        val limits = AppLimits.getLimits(this)
        if (limits.isEmpty()) {
            stopSelf()
            return
        }
        val today = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date())
        if (today != warnedDay) {
            warnedDay = today
            warned.clear()
        }
        val now = System.currentTimeMillis()
        val front = AppLimits.foregroundApp(this) ?: return
        val limitMin = limits[front] ?: return

        // Focus mode blocks every limited app until the session ends.
        if (now < AppLimits.focusUntil(this)) {
            if (now - lastBlockAt > 3_000) {
                lastBlockAt = now
                startActivity(
                    Intent(this, BlockActivity::class.java)
                        .putExtra(BlockActivity.EXTRA_APP, AppLimits.appLabel(this, front))
                        .putExtra(BlockActivity.EXTRA_FOCUS_UNTIL, AppLimits.focusUntil(this))
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                )
            }
            return
        }

        if (now - usageReadAt > USAGE_REFRESH_MS) {
            usage = AppLimits.usageToday(this, limits.keys)
            usageReadAt = now
        }
        val usedMs = (usage[front] ?: 0L) + (now - usageReadAt).coerceAtMost(USAGE_REFRESH_MS)
        val limitMs = limitMin * 60_000L

        if (usedMs >= limitMs) {
            // Don't stack the block screen if it's already up.
            if (now - lastBlockAt > 3_000) {
                lastBlockAt = now
                startActivity(
                    Intent(this, BlockActivity::class.java)
                        .putExtra(BlockActivity.EXTRA_APP, AppLimits.appLabel(this, front))
                        .putExtra(BlockActivity.EXTRA_MINUTES, limitMin)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
                )
            }
        } else if (limitMs - usedMs <= 5 * 60_000L && warned.add(front)) {
            val nm = getSystemService(NotificationManager::class.java)
            nm.notify(
                front.hashCode(),
                Notification.Builder(this, CHANNEL)
                    .setSmallIcon(R.drawable.ic_stat_life)
                    .setContentTitle("⏳ 5 minutes left")
                    .setContentText("${AppLimits.appLabel(this, front)} reaches today's ${limitMin}-minute limit soon.")
                    .setAutoCancel(true)
                    .build()
            )
        }
    }

    private fun createChannel() {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.O) return
        val nm = getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(NotificationChannel(CHANNEL, "App limits", NotificationManager.IMPORTANCE_LOW))
        }
    }
}
