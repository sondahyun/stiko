package io.github.sondahyun.stiko

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.net.Uri
import android.text.SpannableString
import android.text.Spannable
import android.text.style.StrikethroughSpan
import android.view.View
import android.widget.RemoteViews
import es.antonborri.home_widget.HomeWidgetProvider
import org.json.JSONArray
import org.json.JSONObject

/**
 * Home screen widget showing the todo list. Each row has a circle that, when
 * tapped, completes the todo in place: it stays visible with a filled circle
 * and a strikethrough (the app persists the change to the cloud on next resume).
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
                toggleTodo(context, id)
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
        prefs.edit()
            .putString("todos", todos.toString())
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
                    val done = obj.optBoolean("done", false)
                    val content = obj.optString("content")

                    views.setViewVisibility(rowIds[i], View.VISIBLE)
                    if (done) {
                        val struck = SpannableString(content)
                        struck.setSpan(
                            StrikethroughSpan(), 0, struck.length,
                            Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
                        )
                        views.setTextViewText(textIds[i], struck)
                        views.setTextColor(textIds[i], 0xFF9E9E9E.toInt())
                        views.setImageViewResource(circleIds[i], R.drawable.ic_widget_check)
                    } else {
                        views.setTextViewText(textIds[i], content)
                        views.setTextColor(textIds[i], 0xFF222222.toInt())
                        views.setImageViewResource(circleIds[i], R.drawable.ic_widget_circle)
                    }

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
