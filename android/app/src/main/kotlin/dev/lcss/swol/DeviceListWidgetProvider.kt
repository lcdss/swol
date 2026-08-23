package dev.lcss.swol

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetBackgroundIntent
import es.antonborri.home_widget.HomeWidgetLaunchIntent
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * Renders the saved device list; tapping a row broadcasts back into the
 * Dart background callback, which sends the wake packets. The Flutter side
 * keeps the "devices" entry in sync with the app's storage.
 */
class DeviceListWidgetProvider : HomeWidgetProvider() {

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val devices = JSONArray(widgetData.getString("devices", null) ?: "[]")

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_device_list)

            views.setOnClickPendingIntent(
                R.id.widget_root,
                HomeWidgetLaunchIntent.getActivity(context, MainActivity::class.java),
            )

            views.removeAllViews(R.id.device_container)

            if (devices.length() == 0) {
                views.setViewVisibility(R.id.widget_empty, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_empty, View.GONE)

                for (index in 0 until minOf(devices.length(), MAX_ROWS)) {
                    val device = devices.getJSONObject(index)
                    val row = RemoteViews(context.packageName, R.layout.widget_device_row)

                    row.setTextViewText(R.id.device_name, device.getString("hostName"))
                    row.setOnClickPendingIntent(
                        R.id.row_root,
                        HomeWidgetBackgroundIntent.getBroadcast(
                            context,
                            Uri.parse("swol://wake?id=" + Uri.encode(device.getString("id"))),
                        ),
                    )

                    views.addView(R.id.device_container, row)
                }
            }

            val hidden = devices.length() - MAX_ROWS
            if (hidden > 0) {
                views.setTextViewText(
                    R.id.widget_more,
                    context.getString(R.string.widget_more, hidden),
                )
                views.setViewVisibility(R.id.widget_more, View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.widget_more, View.GONE)
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }

    companion object {
        private const val MAX_ROWS = 6
    }
}
