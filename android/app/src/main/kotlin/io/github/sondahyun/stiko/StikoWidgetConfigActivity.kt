package io.github.sondahyun.stiko

import android.app.Activity
import android.appwidget.AppWidgetManager
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.View
import android.view.ViewGroup
import android.widget.Button
import android.widget.HorizontalScrollView
import android.widget.LinearLayout
import android.widget.RadioButton
import android.widget.RadioGroup
import android.widget.ScrollView
import android.widget.SeekBar
import android.widget.TextView
import org.json.JSONArray

/**
 * Shown when a stiko widget is added, and again when it is reconfigured (long
 * press the widget). Lets the user pick which sticker the widget shows, its
 * background color, and its transparency. All stored per widget id.
 */
class StikoWidgetConfigActivity : Activity() {

    private var appWidgetId = AppWidgetManager.INVALID_APPWIDGET_ID
    private val ink = Color.parseColor("#6E5E17")
    private val textDark = Color.parseColor("#26221A")

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
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
        var selectedColor = prefs.getInt("widget_color_$appWidgetId", -1)

        val dp = resources.displayMetrics.density
        fun px(v: Int) = (v * dp).toInt()

        val card = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            setPadding(px(22), px(22), px(22), px(18))
            background = GradientDrawable().apply {
                setColor(Color.parseColor("#FBF7EF"))
                cornerRadius = px(22).toFloat()
            }
        }

        fun sectionLabel(t: String) = TextView(this).apply {
            text = t
            textSize = 13f
            setTextColor(ink)
            setPadding(0, px(14), 0, px(6))
        }

        card.addView(TextView(this).apply {
            text = "위젯 설정"
            textSize = 19f
            setTypeface(typeface, Typeface.BOLD)
            setTextColor(textDark)
        })

        // Sticker -------------------------------------------------------------
        card.addView(sectionLabel("표시할 스티커"))
        val group = RadioGroup(this)
        fun styledRadio(label: String, checked: Boolean) = RadioButton(this).apply {
            text = label
            setTextColor(textDark)
            isChecked = checked
            setPadding(px(4), px(6), 0, px(6))
        }
        group.addView(styledRadio("전체", savedSticker.isEmpty()).apply { id = 1 })
        val ids = ArrayList<String>()
        for (i in 0 until stickers.length()) {
            val obj = stickers.getJSONObject(i)
            val id = obj.optString("id")
            ids.add(id)
            group.addView(
                styledRadio(obj.optString("name").ifEmpty { "새 스티커" }, id == savedSticker)
                    .apply { this.id = i + 2 },
            )
        }
        card.addView(group)

        // Color ---------------------------------------------------------------
        card.addView(sectionLabel("색상"))
        val colors = ArrayList<Int>().apply {
            add(-1) // neutral default
            for (i in 0..5) add(i)
        }
        val swatchDrawables = ArrayList<GradientDrawable>()
        fun colorOf(idx: Int) =
            if (idx in 0..5) StikoWidgetProvider.PALETTE[idx] else Color.parseColor("#FBF7EF")
        fun refreshSwatches() {
            for (k in colors.indices) {
                swatchDrawables[k].setStroke(
                    px(if (colors[k] == selectedColor) 3 else 1),
                    if (colors[k] == selectedColor) ink else Color.parseColor("#44000000"),
                )
            }
        }
        val swatchRow = LinearLayout(this).apply { orientation = LinearLayout.HORIZONTAL }
        for (idx in colors) {
            val d = GradientDrawable().apply {
                shape = GradientDrawable.OVAL
                setColor(colorOf(idx))
            }
            swatchDrawables.add(d)
            swatchRow.addView(
                View(this).apply {
                    layoutParams =
                        LinearLayout.LayoutParams(px(34), px(34)).apply { marginEnd = px(10) }
                    background = d
                    setOnClickListener {
                        selectedColor = idx
                        refreshSwatches()
                    }
                },
            )
        }
        refreshSwatches()
        card.addView(
            HorizontalScrollView(this).apply {
                isHorizontalScrollBarEnabled = false
                addView(swatchRow)
            },
        )

        // Transparency --------------------------------------------------------
        val opLabel = TextView(this).apply {
            text = "투명도  $savedOpacity%"
            textSize = 13f
            setTextColor(ink)
            setPadding(0, px(14), 0, px(4))
        }
        card.addView(opLabel)
        val seek = SeekBar(this).apply {
            max = 100
            progress = savedOpacity.coerceIn(0, 100)
            setOnSeekBarChangeListener(object : SeekBar.OnSeekBarChangeListener {
                override fun onProgressChanged(sb: SeekBar, p: Int, fromUser: Boolean) {
                    opLabel.text = "투명도  $p%"
                }
                override fun onStartTrackingTouch(sb: SeekBar) {}
                override fun onStopTrackingTouch(sb: SeekBar) {}
            })
        }
        card.addView(seek)

        // Done ----------------------------------------------------------------
        card.addView(Button(this).apply {
            text = "완료"
            setTextColor(Color.WHITE)
            background = GradientDrawable().apply {
                setColor(ink)
                cornerRadius = px(12).toFloat()
            }
            layoutParams = LinearLayout.LayoutParams(
                ViewGroup.LayoutParams.MATCH_PARENT,
                ViewGroup.LayoutParams.WRAP_CONTENT,
            ).apply { topMargin = px(18) }
            setOnClickListener {
                val checked = group.checkedRadioButtonId
                val stickyId = if (checked <= 1) "" else ids.getOrElse(checked - 2) { "" }
                prefs.edit()
                    .putString("widget_sticker_$appWidgetId", stickyId)
                    .putInt("widget_opacity_$appWidgetId", seek.progress)
                    .putInt("widget_color_$appWidgetId", selectedColor)
                    .apply()

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

        setContentView(
            ScrollView(this).apply {
                setPadding(px(16), px(16), px(16), px(16))
                addView(card)
            },
        )
    }
}
