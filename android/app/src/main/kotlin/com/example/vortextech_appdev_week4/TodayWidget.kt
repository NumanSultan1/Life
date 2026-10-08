package com.example.vortextech_appdev_week4

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider

/** Home-screen widget showing today's progress; the app pushes new numbers. */
class TodayWidget : HomeWidgetProvider() {
    override fun onUpdate(context: Context, appWidgetManager: AppWidgetManager, appWidgetIds: IntArray, widgetData: SharedPreferences) {
        val percent = widgetData.getInt("percent", 0)
        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.today_widget).apply {
                setTextViewText(R.id.widget_percent, "$percent%")
                setProgressBar(R.id.widget_progress, 100, percent, false)
                setTextViewText(R.id.widget_status, widgetData.getString("status", "Open Life to plan your day"))
                setTextViewText(R.id.widget_next, widgetData.getString("next", "Tap to open"))
                setOnClickPendingIntent(R.id.widget_root, HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java))
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
