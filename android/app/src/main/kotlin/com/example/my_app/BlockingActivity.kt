package com.example.my_app

import android.app.Activity
import android.content.Intent
import android.graphics.Color
import android.graphics.Typeface
import android.os.Bundle
import android.util.TypedValue
import android.view.Gravity
import android.widget.LinearLayout
import android.widget.RelativeLayout
import android.widget.TextView

class BlockingActivity : Activity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        val packageName = intent.getStringExtra("packageName") ?: "Unknown App"
        val appName = try {
            packageManager.getApplicationLabel(
                packageManager.getApplicationInfo(packageName, 0)
            ).toString()
        } catch (_: Exception) {
            packageName
        }

        setContentView(createBlockingUI(appName))
    }

    private fun createBlockingUI(appName: String): android.view.View {
        val context = this

        val mainLayout = RelativeLayout(context).apply {
            setBackgroundColor(Color.parseColor("#000000"))
            setPadding(dp(32), dp(32), dp(32), dp(32))
        }

        val contentLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }

        // Blocked Icon
        val iconText = TextView(context).apply {
            text = "🚫"
            textSize = 80f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(32))
        }
        contentLayout.addView(iconText)

        // Title
        val titleText = TextView(context).apply {
            text = "APP BLOCKED"
            setTextColor(Color.parseColor("#FF5252"))
            textSize = 34f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(16))
        }
        contentLayout.addView(titleText)

        // App Info Card
        val appInfoCard = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#1A1A1A"))
            setPadding(dp(28), dp(28), dp(28), dp(28))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                topMargin = dp(24)
                bottomMargin = dp(16)
            }
        }

        val timerEmoji = TextView(context).apply {
            text = "⏱️"
            textSize = 40f
            gravity = Gravity.CENTER
        }
        appInfoCard.addView(timerEmoji)

        val appNameText = TextView(context).apply {
            text = appName
            setTextColor(Color.WHITE)
            textSize = 22f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dp(12), 0, dp(8))
        }
        appInfoCard.addView(appNameText)

        val limitReachedText = TextView(context).apply {
            text = "Time limit reached"
            setTextColor(Color.parseColor("#BBBBBB"))
            textSize = 15f
            gravity = Gravity.CENTER
        }
        appInfoCard.addView(limitReachedText)

        contentLayout.addView(appInfoCard)

        // Info Message Card
        val infoCard = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(Color.parseColor("#0D0D0D"))
            setPadding(dp(20), dp(18), dp(20), dp(18))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(40)
            }
        }

        val infoEmoji = TextView(context).apply {
            text = "💡"
            textSize = 26f
        }
        infoCard.addView(infoEmoji)

        val infoText = TextView(context).apply {
            text = "Take a break! You can unblock this app from Manage Apps."
            setTextColor(Color.parseColor("#CCCCCC"))
            textSize = 14f
            setPadding(dp(12), 0, 0, 0)
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            )
        }
        infoCard.addView(infoText)

        contentLayout.addView(infoCard)

        // Single "Go to App" Button - Opens Flutter app's home screen
        val goToAppButton = LinearLayout(context).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#007BFF"))
            setPadding(dp(20), dp(18), dp(20), dp(18))
            isClickable = true
            isFocusable = true
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                dp(60)
            )
            setOnClickListener {
                // Navigate to Flutter app's home screen
                val intent = packageManager.getLaunchIntentForPackage(context.packageName)
                intent?.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                finish()
            }
        }

        val buttonEmoji = TextView(context).apply {
            text = "📱"
            textSize = 26f
        }
        goToAppButton.addView(buttonEmoji)

        val buttonText = TextView(context).apply {
            text = "Go to App"
            setTextColor(Color.WHITE)
            textSize = 18f
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(12), 0, 0, 0)
        }
        goToAppButton.addView(buttonText)

        contentLayout.addView(goToAppButton)

        val layoutParams = RelativeLayout.LayoutParams(
            RelativeLayout.LayoutParams.MATCH_PARENT,
            RelativeLayout.LayoutParams.WRAP_CONTENT
        )
        layoutParams.addRule(RelativeLayout.CENTER_IN_PARENT)
        contentLayout.layoutParams = layoutParams

        mainLayout.addView(contentLayout)

        return mainLayout
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()
    }

    override fun onBackPressed() {
        // Go to app home instead of going back to blocked app
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        intent?.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
        startActivity(intent)
        finish()
    }
}