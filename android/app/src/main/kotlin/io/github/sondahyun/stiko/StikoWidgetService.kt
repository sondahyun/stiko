package io.github.sondahyun.stiko

import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Typeface
import android.net.Uri
import android.text.Spannable
import android.text.SpannableString
import android.text.style.StrikethroughSpan
import android.text.style.StyleSpan
import android.view.View
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray
import org.json.JSONObject

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
        val stickers = JSONArray(prefs.getString("stickers", "[]") ?: "[]")
        val out = JSONArray()
        for (i in 0 until stickers.length()) {
            val s = stickers.getJSONObject(i)
            val id = s.optString("id")
            // A pinned widget shows only its sticker (its title is in the header);
            // "전체" shows every sticker, each prefixed with a title row so a
            // title-only sticker (no to-dos) still appears.
            if (stickyId.isNotEmpty() && id != stickyId) continue
            if (stickyId.isEmpty()) {
                out.put(
                    JSONObject()
                        .put("kind", "title")
                        .put("content", s.optString("name"))
                        .put("stickyId", id)
                )
            }
            val todos = s.optJSONArray("todos") ?: JSONArray()
            for (j in 0 until todos.length()) {
                out.put(todos.getJSONObject(j).put("kind", "todo"))
            }
        }
        items = out
    }

    override fun onDestroy() {
        items = JSONArray()
    }

    override fun getCount(): Int = items.length()

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.stiko_widget_row)
        val obj = items.getJSONObject(position)

        // Title row (only in "전체" mode): bold sticker name, no circle, tapping
        // it opens that sticker in the app.
        if (obj.optString("kind") == "title") {
            val name = obj.optString("content").ifEmpty { "새 스티커" }
            val bold = SpannableString(name)
            bold.setSpan(
                StyleSpan(Typeface.BOLD), 0, bold.length,
                Spannable.SPAN_EXCLUSIVE_EXCLUSIVE
            )
            views.setTextViewText(R.id.row_text, bold)
            views.setTextColor(R.id.row_text, 0xFF26221A.toInt())
            views.setViewVisibility(R.id.row_circle, View.GONE)
            val openTitle = Intent().apply {
                data = Uri.parse("stiko://title/${obj.optString("stickyId")}")
                putExtra(StikoWidgetProvider.EXTRA_KIND, StikoWidgetProvider.KIND_OPEN)
                putExtra(StikoWidgetProvider.EXTRA_STICKY, obj.optString("stickyId"))
            }
            views.setOnClickFillInIntent(R.id.row_text, openTitle)
            return views
        }

        views.setViewVisibility(R.id.row_circle, View.VISIBLE)
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
