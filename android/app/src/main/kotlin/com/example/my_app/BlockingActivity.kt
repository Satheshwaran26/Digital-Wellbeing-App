package com.example.my_app

import android.app.Activity
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.net.Uri
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.KeyEvent
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.RelativeLayout
import android.widget.TextView

class BlockingActivity : Activity() {

    private val handler = Handler(Looper.getMainLooper())
    private var checkRunnable: Runnable? = null
    private var blockedPackageName: String = ""
    private var overlayView: View? = null
    private var windowManager: WindowManager? = null

    companion object {
        private const val TAG = "BlockingActivity"
        var isShowing = false
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        Log.d(TAG, "🚫 BlockingActivity onCreate")
        isShowing = true

        // Critical flags for all devices
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O_MR1) {
            setShowWhenLocked(true)
            setTurnScreenOn(true)
        }

        window.addFlags(
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                    WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                    WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD
        )

        blockedPackageName = intent.getStringExtra("packageName") ?: "Unknown App"
        val appName = getAppName(blockedPackageName)

        Log.d(TAG, "Blocking app: $appName ($blockedPackageName)")

        setContentView(createBlockingUI(appName))

        // Add overlay for extra protection on aggressive devices
        tryAddOverlay()

        // Monitor if app is still blocked
        startBlockedCheck()
    }

    private fun tryAddOverlay() {
        try {
            // Check overlay permission
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (!Settings.canDrawOverlays(this)) {
                    Log.w(TAG, "No overlay permission - blocking may fail on some devices")
                    return
                }
            }

            windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

            val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                @Suppress("DEPRECATION")
                WindowManager.LayoutParams.TYPE_SYSTEM_ALERT
            }

            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                layoutFlag,
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE or
                        WindowManager.LayoutParams.FLAG_NOT_TOUCH_MODAL or
                        WindowManager.LayoutParams.FLAG_WATCH_OUTSIDE_TOUCH or
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
                PixelFormat.TRANSLUCENT
            )

            params.gravity = Gravity.CENTER

            // Create semi-transparent overlay
            overlayView = RelativeLayout(this).apply {
                setBackgroundColor(Color.parseColor("#CC000000"))

                val textView = TextView(this@BlockingActivity).apply {
                    text = "⏱️\n\nApp Blocked\nTime Limit Reached"
                    textSize = 20f
                    setTextColor(Color.WHITE)
                    gravity = Gravity.CENTER
                    typeface = Typeface.DEFAULT_BOLD
                }

                addView(textView, RelativeLayout.LayoutParams(
                    RelativeLayout.LayoutParams.WRAP_CONTENT,
                    RelativeLayout.LayoutParams.WRAP_CONTENT
                ).apply {
                    addRule(RelativeLayout.CENTER_IN_PARENT)
                })
            }

            windowManager?.addView(overlayView, params)
            Log.d(TAG, "✅ Overlay window added")
        } catch (e: Exception) {
            Log.e(TAG, "Failed to add overlay: ${e.message}")
        }
    }

    private fun startBlockedCheck() {
        checkRunnable = object : Runnable {
            override fun run() {
                val service = AppMonitorServiceHolder.serviceInstance
                if (service != null) {
                    val blockedApps = service.getBlockedApps()

                    if (!blockedApps.contains(blockedPackageName)) {
                        Log.d(TAG, "App unblocked, finishing")
                        finish()
                        return
                    }
                }

                handler.postDelayed(this, 500)
            }
        }
        handler.post(checkRunnable!!)
    }

    override fun onResume() {
        super.onResume()
        Log.d(TAG, "🟢 onResume")
        isShowing = true
    }

    override fun onPause() {
        super.onPause()
        Log.d(TAG, "🟡 onPause")
    }

    override fun onStop() {
        super.onStop()
        Log.d(TAG, "🔴 onStop")
    }

    override fun onDestroy() {
        super.onDestroy()
        Log.d(TAG, "💀 onDestroy")
        isShowing = false
        checkRunnable?.let { handler.removeCallbacks(it) }

        // Remove overlay
        if (overlayView != null && windowManager != null) {
            try {
                windowManager?.removeView(overlayView)
                overlayView = null
            } catch (e: Exception) {
                Log.e(TAG, "Error removing overlay: ${e.message}")
            }
        }
    }

    override fun onBackPressed() {
        Log.d(TAG, "Back pressed - going to home screen")
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
        finish()
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_HOME) {
            Log.d(TAG, "Home button pressed")
            finish()
            return true
        }

        if (keyCode == KeyEvent.KEYCODE_APP_SWITCH) {
            Log.d(TAG, "Recent apps button pressed")
            finish()
            return true
        }

        return super.onKeyDown(keyCode, event)
    }

    private fun createBlockingUI(appName: String): android.view.View {
        val mainLayout = RelativeLayout(this).apply {
            setBackgroundColor(Color.parseColor("#000000"))
            setPadding(dp(32), dp(32), dp(32), dp(32))
        }

        val contentLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
        }

        // Blocked Icon
        val iconText = TextView(this).apply {
            text = "🚫"
            textSize = 80f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(32))
        }
        contentLayout.addView(iconText)

        // Title
        val titleText = TextView(this).apply {
            text = "APP BLOCKED"
            setTextColor(Color.parseColor("#FF5252"))
            textSize = 34f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(16))
        }
        contentLayout.addView(titleText)

        // App Info Card
        val appInfoCard = LinearLayout(this).apply {
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

        val timerEmoji = TextView(this).apply {
            text = "⏱️"
            textSize = 40f
            gravity = Gravity.CENTER
        }
        appInfoCard.addView(timerEmoji)

        val appNameText = TextView(this).apply {
            text = appName
            setTextColor(Color.WHITE)
            textSize = 22f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dp(12), 0, dp(8))
        }
        appInfoCard.addView(appNameText)

        val limitReachedText = TextView(this).apply {
            text = "Time limit reached"
            setTextColor(Color.parseColor("#BBBBBB"))
            textSize = 15f
            gravity = Gravity.CENTER
        }
        appInfoCard.addView(limitReachedText)

        contentLayout.addView(appInfoCard)

        // Info Message
        val infoCard = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER_VERTICAL
            setBackgroundColor(Color.parseColor("#0D0D0D"))
            setPadding(dp(20), dp(18), dp(20), dp(18))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                bottomMargin = dp(24)
            }
        }

        val infoEmoji = TextView(this).apply {
            text = "💡"
            textSize = 26f
        }
        infoCard.addView(infoEmoji)

        val infoText = TextView(this).apply {
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

        // Buttons
        val buttonsLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        // Go Home Button
        val goHomeButton = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#333333"))
            setPadding(dp(16), dp(14), dp(16), dp(14))
            isClickable = true
            isFocusable = true
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            ).apply {
                rightMargin = dp(8)
            }
            setOnClickListener {
                Log.d(TAG, "Go Home clicked")
                val intent = Intent(Intent.ACTION_MAIN).apply {
                    addCategory(Intent.CATEGORY_HOME)
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK
                }
                startActivity(intent)
                finish()
            }
        }

        val homeEmoji = TextView(this).apply {
            text = "🏠"
            textSize = 20f
        }
        goHomeButton.addView(homeEmoji)

        val homeText = TextView(this).apply {
            text = "Home"
            setTextColor(Color.WHITE)
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(8), 0, 0, 0)
        }
        goHomeButton.addView(homeText)

        buttonsLayout.addView(goHomeButton)

        // Manage Button
        val manageButton = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#007BFF"))
            setPadding(dp(16), dp(14), dp(16), dp(14))
            isClickable = true
            isFocusable = true
            layoutParams = LinearLayout.LayoutParams(
                0,
                LinearLayout.LayoutParams.WRAP_CONTENT,
                1f
            ).apply {
                leftMargin = dp(8)
            }
            setOnClickListener {
                Log.d(TAG, "Manage clicked")
                val intent = packageManager.getLaunchIntentForPackage(packageName)
                intent?.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP or Intent.FLAG_ACTIVITY_NEW_TASK)
                startActivity(intent)
                finish()
            }
        }

        val manageEmoji = TextView(this).apply {
            text = "📱"
            textSize = 20f
        }
        manageButton.addView(manageEmoji)

        val manageText = TextView(this).apply {
            text = "Manage"
            setTextColor(Color.WHITE)
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            setPadding(dp(8), 0, 0, 0)
        }
        manageButton.addView(manageText)

        buttonsLayout.addView(manageButton)

        contentLayout.addView(buttonsLayout)

        val layoutParams = RelativeLayout.LayoutParams(
            RelativeLayout.LayoutParams.MATCH_PARENT,
            RelativeLayout.LayoutParams.WRAP_CONTENT
        )
        layoutParams.addRule(RelativeLayout.CENTER_IN_PARENT)
        contentLayout.layoutParams = layoutParams

        mainLayout.addView(contentLayout)

        return mainLayout
    }

    private fun getAppName(packageName: String): String = try {
        packageManager.getApplicationLabel(
            packageManager.getApplicationInfo(packageName, 0)
        ).toString()
    } catch (_: Exception) {
        packageName
    }

    private fun dp(value: Int): Int {
        return TypedValue.applyDimension(
            TypedValue.COMPLEX_UNIT_DIP,
            value.toFloat(),
            resources.displayMetrics
        ).toInt()
    }
}