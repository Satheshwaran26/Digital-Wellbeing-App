package com.example.my_app

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
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
import android.view.Gravity
import android.view.View
import android.view.WindowManager
import android.widget.LinearLayout
import android.widget.RelativeLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat

class AppMonitorService : Service() {
    
    private val CHANNEL_ID = "monitoring_service"
    private val NOTIFICATION_ID = 2001
    private var windowManager: WindowManager? = null
    private var overlayView: View? = null
    private var isOverlayShowing = false

    override fun onCreate() {
        super.onCreate()
        createNotificationChannel()
        windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        android.util.Log.d("AppMonitorService", "✅ Service created - Ready to show milestone overlays")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        android.util.Log.d("AppMonitorService", "Service started")
        
        // Check if we need to show a milestone overlay
        val milestone = intent?.getIntExtra("milestone", -1) ?: -1
        val usage = intent?.getIntExtra("currentUsage", 0) ?: 0
        val limit = intent?.getIntExtra("totalLimit", 60) ?: 60
        
        if (milestone > 0) {
            android.util.Log.d("AppMonitorService", "📢 Showing milestone overlay: $milestone%")
            showMilestoneOverlay(milestone, usage, limit)
        }
        
        // Start foreground service
        startForeground(NOTIFICATION_ID, createNotification())
        
        return START_STICKY
    }

    fun showMilestoneOverlay(milestone: Int, currentUsage: Int, totalLimit: Int) {
        if (isOverlayShowing) {
            android.util.Log.d("AppMonitorService", "Overlay already showing, skipping")
            return
        }
        
        try {
            // Create overlay view programmatically in Kotlin (no XML needed)
            overlayView = createMilestoneOverlayView(milestone, currentUsage, totalLimit)
            
            // Configure window parameters for Android 10-14
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
                WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON or
                WindowManager.LayoutParams.FLAG_SHOW_WHEN_LOCKED or
                WindowManager.LayoutParams.FLAG_DISMISS_KEYGUARD,
                PixelFormat.TRANSLUCENT
            )
            
            params.gravity = Gravity.CENTER
            
            android.util.Log.d("AppMonitorService", "🔧 Window params configured. Adding overlay to window manager...")
            
            // Add view to window manager
            overlayView?.let { view ->
                try {
                    windowManager?.addView(view, params)
                    isOverlayShowing = true
                    
                    android.util.Log.d("AppMonitorService", "✅ SUCCESS! Milestone overlay displayed: $milestone%")
                    
                    // Auto-dismiss after 8 seconds
                    Handler(Looper.getMainLooper()).postDelayed({
                        android.util.Log.d("AppMonitorService", "⏰ Auto-dismissing overlay after 8 seconds...")
                        dismissOverlay()
                    }, 8000)
                } catch (windowException: Exception) {
                    android.util.Log.e("AppMonitorService", "❌ WindowManager.addView failed: ${windowException.message}")
                    windowException.printStackTrace()
                }
            } ?: run {
                android.util.Log.e("AppMonitorService", "❌ overlayView is null! Could not create overlay")
            }
            
        } catch (e: Exception) {
            android.util.Log.e("AppMonitorService", "❌ Error showing overlay: ${e.message}")
            e.printStackTrace()
        }
    }
    
    private fun createMilestoneOverlayView(milestone: Int, currentUsage: Int, totalLimit: Int): View {
        val context = this
        
        // Create main container (RelativeLayout)
        val mainLayout = RelativeLayout(context).apply {
            setBackgroundColor(Color.parseColor("#F0000000")) // Semi-transparent black
            isClickable = true
            isFocusable = true
        }
        
        // Create close button (top-right)
        val closeButton = TextView(context).apply {
            id = View.generateViewId()
            text = "✕"
            textSize = 24f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#66FFFFFF"))
            setPadding(30, 30, 30, 30)
            isClickable = true
            isFocusable = true
            setOnClickListener { dismissOverlay() }
        }
        
        val closeParams = RelativeLayout.LayoutParams(120, 120).apply {
            addRule(RelativeLayout.ALIGN_PARENT_TOP)
            addRule(RelativeLayout.ALIGN_PARENT_END)
            setMargins(0, 100, 60, 0)
        }
        mainLayout.addView(closeButton, closeParams)
        
        // Create content container (center)
        val contentLayout = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setPadding(80, 80, 80, 80)
        }
        
        // Trophy icon
        val trophyIcon = TextView(context).apply {
            text = "🏆"
            textSize = 80f
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 40)
        }
        contentLayout.addView(trophyIcon)
        
        // Milestone title
        val titleText = TextView(context).apply {
            text = "MILESTONE ACHIEVED!"
            textSize = 22f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, 0, 0, 30)
        }
        contentLayout.addView(titleText)
        
        // Percentage text with color based on milestone
        val percentageColor = when (milestone) {
            30 -> "#4CAF50"  // Green
            70 -> "#FF9800"  // Orange  
            100 -> "#F44336" // Red
            else -> "#FFD700" // Gold
        }
        
        val percentageText = TextView(context).apply {
            text = "$milestone%"
            textSize = 64f
            setTextColor(Color.parseColor(percentageColor))
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, 0, 0, 30)
        }
        contentLayout.addView(percentageText)
        
        // Message text
        val message = when (milestone) {
            30 -> "You've used 30% of your time limit\nKeep it up! 🟢"
            70 -> "You've used 70% of your time limit\nSlow down! 🟡" 
            100 -> "You've reached your limit!\nTime to take a break! 🔴"
            else -> "Milestone reached!"
        }
        
        val messageText = TextView(context).apply {
            text = message
            textSize = 16f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(0, 0, 0, 50)
        }
        contentLayout.addView(messageText)
        
        // Usage stats container
        val usageContainer = LinearLayout(context).apply {
            orientation = LinearLayout.VERTICAL
            gravity = Gravity.CENTER
            setBackgroundColor(Color.parseColor("#1AFFFFFF"))
            setPadding(60, 30, 60, 30)
        }
        
        val usageLabel = TextView(context).apply {
            text = "COMBINED USAGE"
            textSize = 10f
            setTextColor(Color.parseColor("#AAFFFFFF"))
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
            setPadding(0, 0, 0, 15)
        }
        usageContainer.addView(usageLabel)
        
        // Format usage
        val usageMin = currentUsage / 60
        val usageSec = currentUsage % 60
        val limitMin = totalLimit / 60
        val limitSec = totalLimit % 60
        
        val usageStr = if (usageMin > 0) "${usageMin}m ${usageSec}s" else "${usageSec}s"
        val limitStr = if (limitMin > 0) "${limitMin}m ${limitSec}s" else "${limitSec}s"
        
        val usageStats = TextView(context).apply {
            text = "$usageStr / $limitStr"
            textSize = 20f
            setTextColor(Color.parseColor("#FFD700"))
            gravity = Gravity.CENTER
            typeface = Typeface.DEFAULT_BOLD
        }
        usageContainer.addView(usageStats)
        
        contentLayout.addView(usageContainer)
        
        // Add content to main layout (centered)
        val contentParams = RelativeLayout.LayoutParams(
            RelativeLayout.LayoutParams.MATCH_PARENT,
            RelativeLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            addRule(RelativeLayout.CENTER_IN_PARENT)
        }
        mainLayout.addView(contentLayout, contentParams)
        
        return mainLayout
    }
    
    private fun dismissOverlay() {
        try {
            overlayView?.let { view ->
                if (isOverlayShowing) {
                    windowManager?.removeView(view)
                    overlayView = null
                    isOverlayShowing = false
                    android.util.Log.d("AppMonitorService", "Overlay dismissed")
                }
            }
        } catch (e: Exception) {
            android.util.Log.e("AppMonitorService", "Error dismissing overlay: ${e.message}")
        }
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "Monitoring Service",
                NotificationManager.IMPORTANCE_LOW
            ).apply {
                description = "Keeps the app monitoring service running"
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
        }
    }

    private fun createNotification(): Notification {
        val notificationIntent = Intent(this, MainActivity::class.java)
        val pendingIntent = PendingIntent.getActivity(
            this, 0, notificationIntent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )

        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setContentTitle("Digital Wellbeing")
            .setContentText("Monitoring your app usage")
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentIntent(pendingIntent)
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .build()
    }

    override fun onDestroy() {
        super.onDestroy()
        dismissOverlay()
        android.util.Log.d("AppMonitorService", "Service destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null
}
