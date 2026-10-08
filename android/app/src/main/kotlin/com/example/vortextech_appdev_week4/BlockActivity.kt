package com.example.vortextech_appdev_week4

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.graphics.drawable.GradientDrawable
import android.os.Bundle
import android.view.Gravity
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView
import android.window.OnBackInvokedDispatcher
import android.os.Build

/** Full-screen "time's up" message shown over an app past its limit. */
class BlockActivity : Activity() {
    companion object {
        const val EXTRA_APP = "app"
        const val EXTRA_MINUTES = "minutes"
        const val EXTRA_FOCUS_UNTIL = "focusUntil"
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        val app = intent.getStringExtra(EXTRA_APP) ?: "This app"
        val minutes = intent.getIntExtra(EXTRA_MINUTES, 0)
        val density = resources.displayMetrics.density
        fun dp(v: Int) = (v * density).toInt()

        val root = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(dp(32), dp(32), dp(32), dp(32))
            background = GradientDrawable(
                GradientDrawable.Orientation.TOP_BOTTOM,
                intArrayOf(Color.parseColor("#0B1B4D"), Color.parseColor("#1E4FD8"), Color.parseColor("#7B3AE6"))
            )
        }
        fun text(value: String, size: Float, bold: Boolean, alpha: Float = 1f) = TextView(this).apply {
            text = value
            textSize = size
            setTextColor(Color.WHITE)
            this.alpha = alpha
            gravity = Gravity.CENTER
            if (bold) typeface = Typeface.DEFAULT_BOLD
            setPadding(0, dp(8), 0, dp(8))
        }
        val focusUntil = intent.getLongExtra(EXTRA_FOCUS_UNTIL, 0L)
        if (focusUntil > System.currentTimeMillis()) {
            val left = ((focusUntil - System.currentTimeMillis()) / 60_000L) + 1
            root.addView(text("🎯", 64f, false))
            root.addView(text("You're in focus mode", 26f, true))
            root.addView(text("$app is blocked for about $left more minute${if (left == 1L) "" else "s"}.", 16f, false, 0.85f))
            root.addView(text("Stay with it. You can check it after your session.", 15f, false, 0.75f))
        } else {
            root.addView(text("⏳", 64f, false))
            root.addView(text("Time's up for $app", 26f, true))
            root.addView(text("You set a limit of $minutes minutes a day. It resets at midnight.", 16f, false, 0.85f))
            root.addView(text("Take a breath, stretch, or tick something off in Life instead.", 15f, false, 0.75f))
        }
        root.addView(Button(this).apply {
            text = "Go to home screen"
            isAllCaps = false
            textSize = 16f
            setTextColor(Color.parseColor("#0B4DBF"))
            background = GradientDrawable().apply { cornerRadius = dp(20).toFloat(); setColor(Color.WHITE) }
            setPadding(dp(24), dp(14), dp(24), dp(14))
            setOnClickListener { goHome() }
            layoutParams = LinearLayout.LayoutParams(LinearLayout.LayoutParams.MATCH_PARENT, LinearLayout.LayoutParams.WRAP_CONTENT).apply {
                topMargin = dp(28)
            }
        })
        setContentView(root)

        // Back also goes home rather than back into the limited app.
        if (Build.VERSION.SDK_INT >= 33) {
            onBackInvokedDispatcher.registerOnBackInvokedCallback(OnBackInvokedDispatcher.PRIORITY_DEFAULT) { goHome() }
        }
    }

    @Deprecated("Handled by OnBackInvokedDispatcher on Android 13+")
    override fun onBackPressed() = goHome()

    private fun goHome() {
        startActivity(Intent(Intent.ACTION_MAIN).addCategory(Intent.CATEGORY_HOME).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        finish()
    }
}
