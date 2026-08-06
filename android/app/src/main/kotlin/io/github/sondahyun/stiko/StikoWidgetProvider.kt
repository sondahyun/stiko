package io.github.sondahyun.stiko

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject

/**
 * Scrollable home screen widget showing the todo list. Each row's circle
 * completes the todo in place (filled circle + strikethrough); the app persists
 * the change to the cloud on its next resume.
 */
class StikoWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_TOGGLE = "io.github.sondahyun.stiko.WIDGET_TOGGLE"
        const val EXTRA_ID = "todo_id"
        const val EXTRA_STICKY = "sticky_id"
        const val EXTRA_KIND = "kind"
        const val KIND_TOGGLE = "toggle"
        const val KIND_OPEN = "open"
        const val PREFS = "HomeWidgetPreferences"

        // App sticky palette; DEFAULT_BG is a neutral cream when none is chosen.
        const val DEFAULT_BG = 0xFFFBF7EF.toInt()
        val PALETTE = intArrayOf(
            0xFFFEF3BE.toInt(), 0xFFFCE1C8.toInt(), 0xFFDBF4D2.toInt(),
            0xFFCFEEF8.toInt(), 0xFFE0DBF8.toInt(), 0xFFF9DCF1.toInt(),
        )
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TOGGLE) {
            when (intent.getStringExtra(EXTRA_KIND)) {
                // Row text tapped: open that todo's sticker in the app.
                KIND_OPEN -> openSticker(context, intent.getStringExtra(EXTRA_STICKY))
                // Circle tapped (or legacy taps): complete / uncomplete in place.
                else -> intent.getStringExtra(EXTRA_ID)?.let { id ->
                    toggleTodo(context, id)
                    val manager = AppWidgetManager.getInstance(context)
                    val ids = manager.getAppWidgetIds(
                        ComponentName(context, StikoWidgetProvider::class.java)
                    )
                    manager.notifyAppWidgetViewDataChanged(ids, R.id.list)
                }
            }
        }
        super.onReceive(context, intent)
    }

    /** Launches the app on the given sticker's detail (or the board if none). */
    private fun openSticker(context: Context, stickyId: String?) {
        val uri = if (stickyId.isNullOrEmpty()) "stiko://board"
                  else "stiko://sticker/$stickyId"
        val launch = Intent(context, MainActivity::class.java).apply {
            action = Intent.ACTION_VIEW
            data = Uri.parse(uri)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_SINGLE_TOP)
        }
        context.startActivity(launch)
    }

    /** Flips [id]'s done state in the shared data and records it as pending. */
    private fun toggleTodo(context: Context, id: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        var newDone = true
        val todos = JSONArray(prefs.getString("todos", "[]") ?: "[]")
        for (i in 0 until todos.length()) {
            val obj = todos.getJSONObject(i)
            if (obj.optString("id") == id) {
                newDone = !obj.optBoolean("done", false)
                obj.put("done", newDone)
            }
        }
        val pending = JSONArray()
        val existing = JSONArray(prefs.getString("pending", "[]") ?: "[]")
        for (i in 0 until existing.length()) {
            val obj = existing.getJSONObject(i)
            if (obj.optString("id") != id) pending.put(obj)
        }
        pending.put(JSONObject().put("id", id).put("done", newDone))

        // Mirror the flip into the per-sticker breakdown so a widget filtered to
        // one sticker also updates in place.
        val stickers = JSONArray(prefs.getString("stickers", "[]") ?: "[]")
        for (i in 0 until stickers.length()) {
            val arr = stickers.getJSONObject(i).optJSONArray("todos") ?: continue
            for (j in 0 until arr.length()) {
                val o = arr.getJSONObject(j)
                if (o.optString("id") == id) o.put("done", newDone)
            }
        }
        prefs.edit()
            .putString("todos", todos.toString())
            .putString("stickers", stickers.toString())
            .putString("pending", pending.toString())
            .apply()
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.stiko_widget)

            // Per-widget background color (app palette) and transparency (0..100).
            val colorIndex = prefs.getInt("widget_color_$widgetId", -1)
            val color = if (colorIndex in 0..5) PALETTE[colorIndex] else DEFAULT_BG
            views.setInt(R.id.bg, "setColorFilter", color)
            val opacity = prefs.getInt("widget_opacity_$widgetId", 50)
                .coerceIn(0, 100)
            views.setInt(R.id.bg, "setImageAlpha", opacity * 255 / 100)

            // Header: when the widget is pinned to a single sticker, show that
            // sticker's name (its title, else first todo) so a title-only sticker
            // still displays its note even with no to-dos. "전체" widgets hide it.
            val stickyId = prefs.getString("widget_sticker_$widgetId", "") ?: ""
            var title = ""
            if (stickyId.isNotEmpty()) {
                val stickers = JSONArray(prefs.getString("stickers", "[]") ?: "[]")
                for (i in 0 until stickers.length()) {
                    val s = stickers.getJSONObject(i)
                    if (s.optString("id") == stickyId) {
                        title = s.optString("name")
                        break
                    }
                }
            }
            if (title.isNotEmpty()) {
                views.setTextViewText(R.id.title, title)
                views.setViewVisibility(R.id.title, android.view.View.VISIBLE)
            } else {
                views.setViewVisibility(R.id.title, android.view.View.GONE)
            }

            val serviceIntent = Intent(context, StikoWidgetService::class.java).apply {
                putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, widgetId)
                data = Uri.parse(toUri(Intent.URI_INTENT_SCHEME))
            }
            views.setRemoteAdapter(R.id.list, serviceIntent)
            views.setEmptyView(R.id.list, R.id.empty)

            // Template for row taps; mutable so each row's fill-in can add its
            // data + extras. IMPORTANT: no data here, otherwise every row shares
            // one PendingIntent and per-row taps stop registering.
            val templateIntent = Intent(context, StikoWidgetProvider::class.java).apply {
                action = ACTION_TOGGLE
            }
            val template = PendingIntent.getBroadcast(
                context,
                0,
                templateIntent,
                PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_MUTABLE
            )
            views.setPendingIntentTemplate(R.id.list, template)

            appWidgetManager.updateAppWidget(widgetId, views)
            appWidgetManager.notifyAppWidgetViewDataChanged(widgetId, R.id.list)
        }
    }
}
