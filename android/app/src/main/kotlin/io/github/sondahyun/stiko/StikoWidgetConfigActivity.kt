package io.github.sondahyun.stiko

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.os.Bundle
import android.view.ViewGroup
import android.widget.Button
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.TextView
import org.json.JSONArray

/**
 * Shown when a stiko widget is added, and again when it is reconfigured (long
 * press the widget). Lets the user pick which sticker's todos the widget shows
 * and how transparent it is. Both are stored per widget id.
 */
class StikoWidgetConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // If the user backs out, the widget is not placed.
        setResult(RESULT_CANCELED)

        appWidgetId = intent?.extras?.getInt(
            AppWidgetManager.EXTRA_APPWIDGET_ID,
            AppWidgetManager.INVALID_APPWIDGET_ID,
        ) ?: AppWidgetManager.INVALID_APPWIDGET_ID
        if (appWidgetId == AppWidgetManager.INVALID_APPWIDGET_ID) {
            finish()
            return
        }

        val prefs = getSharedPreferences(StikoWidgetProvider.PREFS, Context.MODE_PRIVATE)
        val stickers = JSONArray(prefs.getString("stickers", "[]") ?: "[]")
        val savedSticker = prefs.getString("widget_sticker_$appWidgetId", "") ?: ""
        val savedOpacity = prefs.getInt("widget_opacity_$appWidgetId", 50)

        val dp = resources.displayMetrics.density
        fun px(v: Int) = (v * dp).toInt()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setBackgroundColor(Color.WHITE)
            setPadding(px(24), px(24), px(24), px(24))
        }
        root.addView(TextView(this).apply {
            text = "위젯에 표시할 스티커"
            textSize = 18f
            setTextColor(Color.parseColor("#26221A"))
            setPadding(0, 0, 0, px(8))
        })

        val group = RadioGroup(this)
        group.addView(RadioButton(this).apply {
            text = "전체"
            id = 1
            isChecked = savedSticker.isEmpty()
        })
        val ids = ArrayList<String>()
        for (i in 0 until stickers.length()) {
            val obj = stickers.getJSONObject(i)
            val id = obj.optString("id")
            ids.add(id)
            group.addView(RadioButton(this).apply {
                text = obj.optString("name").ifEmpty { "새 스티커" }
                this.id = i + 2
                isChecked = id == savedSticker
            })
        }
        root.addView(
            ScrollView(this).apply {
                layoutParams = LinearLayout.LayoutParams(
                    ViewGroup.LayoutParams.MATCH_PARENT, 0, 1f,
                )
                addView(group)
            },
        )

        val opacityLabel = TextView(this).apply {
            text = "투명도  $savedOpacity%"
            setTextColor(Color.parseColor("#26221A"))
            setPadding(0, px(12), 0, px(4))
        }
        root.addView(opacityLabel)
        val seek = SeekBar(this).apply {
            max = 90 // maps to 10%..100%
            progress = (savedOpacity - 10).coerceIn(0, 90)
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(sb: SeekBar, p: Int, fromUser: Boolean) {
                    opacityLabel.text = "투명도  ${p + 10}%"
                }
                override fun onStartTrackingTouch(sb: SeekBar) {}
                override fun onStopTrackingTouch(sb: SeekBar) {}
            })
        }
        root.addView(seek)

        root.addView(Button(this).apply {
            text = "완료"
            setOnClickListener {
                val checked = group.checkedRadioButtonId
                val stickyId = if (checked <= 1) "" else ids.getOrElse(checked - 2) { "" }
                prefs.edit()
                    .putString("widget_sticker_$appWidgetId", stickyId)
                    .putInt("widget_opacity_$appWidgetId", seek.progress + 10)
                    .apply()

                // Rebuild the widget so it renders the chosen sticker + opacity.
                sendBroadcast(
                    Intent(this@StikoWidgetConfigActivity, StikoWidgetProvider::class.java).apply {
                        action = AppWidgetManager.ACTION_APPWIDGET_UPDATE
                        putExtra(
                            AppWidgetManager.EXTRA_APPWIDGET_IDS,
                            intArrayOf(appWidgetId),
                        )
                    },
                )
                AppWidgetManager.getInstance(this@StikoWidgetConfigActivity)
                    .notifyAppWidgetViewDataChanged(appWidgetId, R.id.list)

                setResult(
                    RESULT_OK,
                    Intent().putExtra(AppWidgetManager.EXTRA_APPWIDGET_ID, appWidgetId),
                )
                finish()
            }
        })
        setContentView(root)
    }
}
