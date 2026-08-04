package io.github.sondahyun.stiko

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.net.Uri
import android.text.Spannable
import android.text.SpannableString
import android.text.style.StrikethroughSpan
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

/** Backs the scrollable list inside the home widget. */
class StikoWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        StikoRemoteViewsFactory(
            applicationContext,
            intent.getIntExtra(
                AppWidgetManager.EXTRA_APPWIDGET_ID,
                AppWidgetManager.INVALID_APPWIDGET_ID,
            ),
        )
}

class StikoRemoteViewsFactory(
    private val context: Context,
    private val widgetId: Int,
) : RemoteViewsService.RemoteViewsFactory {

    private var items = JSONArray()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = context.getSharedPreferences(
            StikoWidgetProvider.PREFS, Context.MODE_PRIVATE
        )
        val stickyId = prefs.getString("widget_sticker_$widgetId", "") ?: ""
        if (stickyId.isEmpty()) {
            // No sticker chosen for this widget: show every todo.
            items = JSONArray(prefs.getString("todos", "[]") ?: "[]")
        } else {
            // Show only the chosen sticker's todos.
            var found = JSONArray()
            val stickers = JSONArray(prefs.getString("stickers", "[]") ?: "[]")
            for (i in 0 until stickers.length()) {
                val s = stickers.getJSONObject(i)
                if (s.optString("id") == stickyId) {
                    found = s.optJSONArray("todos") ?: JSONArray()
                    break
                }
            }
            items = found
        }
    }

    override fun onDestroy() {
        items = JSONArray()
    }

    override fun getCount(): Int = items.length()

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.stiko_widget_row)
        val obj = items.getJSONObject(position)
        val id = obj.optString("id")
        val stickyId = obj.optString("stickyId")
        val done = obj.optBoolean("done", false)
        val content = obj.optString("content")

        if (done) {
            val struck = SpannableString(content)
            struck.setSpan(
                StrikethroughSpan(), 0, struck.length,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
            views.setTextViewText(R.id.row_text, struck)
            views.setTextColor(R.id.row_text, 0xFF9E9E9E.toInt())
            views.setImageViewResource(R.id.row_circle, R.drawable.ic_widget_check)
        } else {
            views.setTextViewText(R.id.row_text, content)
            views.setTextColor(R.id.row_text, 0xFF222222.toInt())
            views.setImageViewResource(R.id.row_circle, R.drawable.ic_widget_circle)
        }

        // The list's PendingIntent template supplies the component; these fill-in
        // intents add what was tapped. Circle toggles the todo; the text opens
        // that todo's sticker in the app.
        // Unique data per row so each fill-in is a distinct PendingIntent.
        val toggleFill = Intent().apply {
            data = Uri.parse("stiko://toggle/$id")
            putExtra(StikoWidgetProvider.EXTRA_KIND, StikoWidgetProvider.KIND_TOGGLE)
            putExtra(StikoWidgetProvider.EXTRA_ID, id)
        }
        views.setOnClickFillInIntent(R.id.row_circle, toggleFill)

        val openFill = Intent().apply {
            data = Uri.parse("stiko://open/$id")
            putExtra(StikoWidgetProvider.EXTRA_KIND, StikoWidgetProvider.KIND_OPEN)
            putExtra(StikoWidgetProvider.EXTRA_STICKY, stickyId)
        }
        views.setOnClickFillInIntent(R.id.row_text, openFill)
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false
}
