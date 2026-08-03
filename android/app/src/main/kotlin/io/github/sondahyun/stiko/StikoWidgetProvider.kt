package io.github.sondahyun.stiko

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray

/**
 * Home screen widget showing the todo list. Each row has a circle that, when
 * tapped, completes the todo: it disappears at once (and the app persists the
 * completion to the cloud on its next resume).
 */
class StikoWidgetProvider : HomeWidgetProvider() {

    companion object {
        const val ACTION_TOGGLE = "io.github.sondahyun.stiko.WIDGET_TOGGLE"
        const val EXTRA_ID = "todo_id"
        const val PREFS = "HomeWidgetPreferences"
        const val MAX_ROWS = 5
    }

    override fun onReceive(context: Context, intent: Intent) {
        if (intent.action == ACTION_TOGGLE) {
            intent.getStringExtra(EXTRA_ID)?.let { id ->
                completeTodo(context, id)
                val manager = AppWidgetManager.getInstance(context)
                val ids = manager.getAppWidgetIds(
                    ComponentName(context, StikoWidgetProvider::class.java)
                )
                onUpdate(
                    context,
                    manager,
                    ids,
                    context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                )
            }
        }
        super.onReceive(context, intent)
    }

    /** Removes [id] from the shared todo list and records it as pending. */
    private fun completeTodo(context: Context, id: String) {
        val prefs = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
        val kept = JSONArray()
        val todos = JSONArray(prefs.getString("todos", "[]") ?: "[]")
        for (i in 0 until todos.length()) {
            val obj = todos.getJSONObject(i)
            if (obj.optString("id") != id) kept.put(obj)
        }
        val pending = JSONArray(prefs.getString("pending", "[]") ?: "[]")
        var exists = false
        for (i in 0 until pending.length()) {
            if (pending.getString(i) == id) exists = true
        }
        if (!exists) pending.put(id)
        prefs.edit()
            .putString("todos", kept.toString())
            .putString("pending", pending.toString())
            .apply()
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
        widgetData: SharedPreferences,
    ) {
        val rowIds = intArrayOf(R.id.row0, R.id.row1, R.id.row2, R.id.row3, R.id.row4)
        val textIds = intArrayOf(R.id.text0, R.id.text1, R.id.text2, R.id.text3, R.id.text4)
        val circleIds =
            intArrayOf(R.id.circle0, R.id.circle1, R.id.circle2, R.id.circle3, R.id.circle4)

        val todos = JSONArray(widgetData.getString("todos", "[]") ?: "[]")

        for (widgetId in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.stiko_widget)
            views.setViewVisibility(
                R.id.empty,
                if (todos.length() == 0) View.VISIBLE else View.GONE
            )

            for (i in 0 until MAX_ROWS) {
                if (i < todos.length()) {
                    val obj = todos.getJSONObject(i)
                    val todoId = obj.optString("id")
                    views.setViewVisibility(rowIds[i], View.VISIBLE)
                    views.setTextViewText(textIds[i], obj.optString("content"))

                    val toggle = Intent(context, StikoWidgetProvider::class.java).apply {
                        action = ACTION_TOGGLE
                        putExtra(EXTRA_ID, todoId)
                        data = Uri.parse("stiko://toggle/$todoId")
                    }
                    val pending = PendingIntent.getBroadcast(
                        context,
                        todoId.hashCode(),
                        toggle,
                        PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
                    )
                    views.setOnClickPendingIntent(circleIds[i], pending)
                } else {
                    views.setViewVisibility(rowIds[i], View.GONE)
                }
            }

            appWidgetManager.updateAppWidget(widgetId, views)
        }
    }
}
