package io.github.sondahyun.stiko

import android.content.Context
import android.content.Intent
import android.text.Spannable
import android.text.SpannableString
import android.text.style.StrikethroughSpan
import android.widget.RemoteViews
import android.widget.RemoteViewsService
import org.json.JSONArray

/** Backs the scrollable list inside the home widget. */
class StikoWidgetService : RemoteViewsService() {
    override fun onGetViewFactory(intent: Intent): RemoteViewsFactory =
        StikoRemoteViewsFactory(applicationContext)
}

class StikoRemoteViewsFactory(
    private val context: Context,
) : RemoteViewsService.RemoteViewsFactory {

    private var items = JSONArray()

    override fun onCreate() {}

    override fun onDataSetChanged() {
        val prefs = context.getSharedPreferences(
            StikoWidgetProvider.PREFS, Context.MODE_PRIVATE
        )
        items = JSONArray(prefs.getString("todos", "[]") ?: "[]")
    }

    override fun onDestroy() {
        items = JSONArray()
    }

    override fun getCount(): Int = items.length()

    override fun getViewAt(position: Int): RemoteViews {
        val views = RemoteViews(context.packageName, R.layout.stiko_widget_row)
        val obj = items.getJSONObject(position)
        val id = obj.optString("id")
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

        // The list's PendingIntent template supplies the action + component; this
        // fill-in intent adds which todo was tapped.
        val fillIn = Intent().apply {
            putExtra(StikoWidgetProvider.EXTRA_ID, id)
        }
        views.setOnClickFillInIntent(R.id.row_circle, fillIn)
        return views
    }

    override fun getLoadingView(): RemoteViews? = null
    override fun getViewTypeCount(): Int = 1
    override fun getItemId(position: Int): Long = position.toLong()
    override fun hasStableIds(): Boolean = false
}
