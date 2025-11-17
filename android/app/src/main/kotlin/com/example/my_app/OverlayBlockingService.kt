package com.example.my_app

import android.app.Service
import android.content.Context
import android.content.Intent
import android.graphics.Color
import android.graphics.PixelFormat
import android.graphics.Typeface
import android.os.Build
import android.os.Handler
import android.os.IBinder
import android.os.Looper
import android.provider.Settings
import android.util.Log
import android.util.TypedValue
import android.view.Gravity
import android.view.MotionEvent
import android.view.View
import android.view.WindowManager
import android.widget.Button
import android.widget.LinearLayout
import android.widget.TextView

class OverlayBlockingService : Service() {

    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var blockedPackageName: String = ""
    private val handler = Handler(Looper.getMainLooper())
    private var checkRunnable: Runnable? = null

    companion object {
        private const val TAG = "OverlayBlockingService"
        const val EXTRA_PACKAGE = "packageName"
        var isOverlayShowing = false
    }

    override fun onCreate() {
        super.onCreate()
        Log.d(TAG, "✅ OverlayBlockingService created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        blockedPackageName = intent?.getStringExtra(EXTRA_PACKAGE) ?: ""

        if (blockedPackageName.isEmpty()) {
            Log.e(TAG, "❌ No package name provided")
            stopSelf()
            return START_NOT_STICKY
        }

        Log.d(TAG, "🚫 Showing overlay for: $blockedPackageName")

        if (canDrawOverlays()) {
            showOverlay()
            startMonitoring()
        } else {
            Log.e(TAG, "❌ No overlay permission")
            // Fallback to activity
            launchBlockingActivity()
            stopSelf()
        }

        return START_STICKY
    }

    private fun canDrawOverlays(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }

    private fun showOverlay() {
        if (isOverlayShowing) {
            Log.d(TAG, "Overlay already showing")
            return
        }

        try {
            windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager

            // Use TYPE_APPLICATION_OVERLAY for Android 8.0+
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
                        WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                        WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                        WindowManager.LayoutParams.FLAG_TURN_SCREEN_ON or
                        WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
                PixelFormat.TRANSLUCENT
            )

            params.gravity = Gravity.CENTER

            overlayView = createOverlayView()

            windowManager?.addView(overlayView, params)
            isOverlayShowing = true

            Log.d(TAG, "✅ Overlay window added")
        } catch (e: Exception) {
            Log.e(TAG, "❌ Failed to add overlay: ${e.message}", e)
            // Fallback
            launchBlockingActivity()
            stopSelf()
        }
    }

    private fun createOverlayView(): View {
        val appName = getAppName(blockedPackageName)

        val mainLayout = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#000000"))
            setPadding(dp(40), dp(60), dp(40), dp(60))
            isClickable = true
            isFocusable = true
        }

        // Warning Icon
        val iconView = TextView(this).apply {
            text = "🚫"
            textSize = 100f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(30))
        }
        mainLayout.addView(iconView)

        // Title
        val titleView = TextView(this).apply {
            text = "APP BLOCKED"
            setTextColor(Color.parseColor("#FF5252"))
            textSize = 36f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, dp(20))
        }
        mainLayout.addView(titleView)

        // App Info Card
        val cardView = LinearLayout(this).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#1A1A1A"))
            setPadding(dp(30), dp(30), dp(30), dp(30))
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            ).apply {
                setMargins(0, 0, 0, dp(30))
            }
        }

        val timerIcon = TextView(this).apply {
            text = "⏱️"
            textSize = 48f
            gravity = Gravity.CENTER
        }
        cardView.addView(timerIcon)

        val appNameView = TextView(this).apply {
            text = appName
            setTextColor(Color.WHITE)
            textSize = 24f
            typeface = Typeface.DEFAULT_BOLD
            gravity = Gravity.CENTER
            setPadding(0, dp(15), 0, dp(10))
        }
        cardView.addView(appNameView)

        val messageView = TextView(this).apply {
            text = "Time limit reached\nTake a break!"
            setTextColor(Color.parseColor("#BBBBBB"))
            textSize = 16f
            gravity = Gravity.CENTER
        }
        cardView.addView(messageView)

        mainLayout.addView(cardView)

        // Info Message
        val infoView = TextView(this).apply {
            text = "💡 You can unblock this app from Manage Apps"
            setTextColor(Color.parseColor("#CCCCCC"))
            textSize = 14f
            gravity = Gravity.CENTER
            setPadding(dp(20), dp(20), dp(20), dp(30))
        }
        mainLayout.addView(infoView)

        // Buttons Container
        val buttonsLayout = LinearLayout(this).apply {
            orientation = LinearLayout.HORIZONTAL
            gravity = Gravity.CENTER
            layoutParams = LinearLayout.LayoutParams(
                LinearLayout.LayoutParams.MATCH_PARENT,
                LinearLayout.LayoutParams.WRAP_CONTENT
            )
        }

        // Home Button
        val homeButton = createStyledButton("🏠 Home", Color.parseColor("#333333"))
        homeButton.setOnClickListener {
            Log.d(TAG, "Home button clicked")
            goHome()
        }
        buttonsLayout.addView(homeButton, LinearLayout.LayoutParams(
            0,
            dp(55),
            1f
        ).apply {
            rightMargin = dp(10)
        })

        // Manage Button
        val manageButton = createStyledButton("📱 Manage", Color.parseColor("#007BFF"))
        manageButton.setOnClickListener {
            Log.d(TAG, "Manage button clicked")
            openApp()
        }
        buttonsLayout.addView(manageButton, LinearLayout.LayoutParams(
            0,
            dp(55),
            1f
        ).apply {
            leftMargin = dp(10)
        })

        mainLayout.addView(buttonsLayout)

        // Prevent touch events from passing through
        mainLayout.setOnTouchListener { _, event ->
            if (event.action == MotionEvent.ACTION_OUTSIDE) {
                Log.d(TAG, "Touch outside detected")
                return@setOnTouchListener true
            }
            false
        }

        return mainLayout
    }

    private fun createStyledButton(text: String, bgColor: Int): Button {
        return Button(this).apply {
            this.text = text
            setTextColor(Color.WHITE)
            textSize = 16f
            typeface = Typeface.DEFAULT_BOLD
            setBackgroundColor(bgColor)
            isAllCaps = false
            setPadding(dp(20), dp(15), dp(20), dp(15))
        }
    }

    private fun goHome() {
        val intent = Intent(Intent.ACTION_MAIN).apply {
            addCategory(Intent.CATEGORY_HOME)
            flags = Intent.FLAG_ACTIVITY_NEW_TASK
        }
        startActivity(intent)
        removeOverlay()
        stopSelf()
    }

    private fun openApp() {
        val intent = packageManager.getLaunchIntentForPackage(packageName)
        intent?.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        startActivity(intent)
        removeOverlay()
        stopSelf()
    }

    private fun startMonitoring() {
        checkRunnable = object : Runnable {
            override fun run() {
                val service = AppMonitorServiceHolder.serviceInstance
                if (service != null) {
                    val blockedApps = service.getBlockedApps()

                    if (!blockedApps.contains(blockedPackageName)) {
                        Log.d(TAG, "App unblocked, removing overlay")
                        removeOverlay()
                        stopSelf()
                        return
                    }
                }

                handler.postDelayed(this, 1000)
            }
        }
        handler.post(checkRunnable!!)
    }

    private fun removeOverlay() {
        try {
            if (overlayView != null && windowManager != null) {
                windowManager?.removeView(overlayView)
                overlayView = null
                isOverlayShowing = false
                Log.d(TAG, "✅ Overlay removed")
            }
        } catch (e: Exception) {
            Log.e(TAG, "Error removing overlay: ${e.message}")
        }
    }

    private fun launchBlockingActivity() {
        val intent = Intent(this, BlockingActivity::class.java).apply {
            putExtra("packageName", blockedPackageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }
        startActivity(intent)
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

    override fun onDestroy() {
        super.onDestroy()
        removeOverlay()
        checkRunnable?.let { handler.removeCallbacks(it) }
        Log.d(TAG, "💀 OverlayBlockingService destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null
}