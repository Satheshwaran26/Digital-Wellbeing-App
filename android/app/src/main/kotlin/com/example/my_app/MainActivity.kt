package com.example.my_app

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Color
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.View
import android.view.WindowManager
import android.widget.RelativeLayout
import android.widget.TextView
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app_usage_tracker"
    private val MILESTONE_PREFS = "milestone_prefs"
    private val MILESTONE_30_KEY = "milestone_30_shown"
    private val MILESTONE_70_KEY = "milestone_70_shown"
    private val MILESTONE_100_KEY = "milestone_100_shown"
    private val MILESTONE_CHANNEL_ID = "milestone_notifications"
    
    private lateinit var sharedPreferences: SharedPreferences

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // Initialize SharedPreferences for milestone tracking
        sharedPreferences = getSharedPreferences(MILESTONE_PREFS, Context.MODE_PRIVATE)
        
        // Create notification channel for milestones
        createMilestoneNotificationChannel()
        
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, CHANNEL).setMethodCallHandler { call, result ->
            when (call.method) {
                "getForegroundApp" -> {
                    val foregroundApp = getForegroundApp()
                    result.success(foregroundApp)
                }
                "checkUsageStatsPermission" -> {
                    val hasPermission = checkUsageStatsPermission()
                    result.success(hasPermission)
                }
                "openUsageStatsSettings" -> {
                    openUsageStatsSettings()
                    result.success(true)
                }
                "checkMilestone" -> {
                    val totalUsage = call.argument<Int>("totalUsage") ?: 0
                    val totalLimit = call.argument<Int>("totalLimit") ?: 60
                    checkMilestoneAndNotify(totalUsage, totalLimit)
                    result.success(true)
                }
                "resetMilestones" -> {
                    resetMilestones()
                    result.success(true)
                }
                "checkOverlayPermission" -> {
                    val hasPermission = checkOverlayPermission()
                    result.success(hasPermission)
                }
                "requestOverlayPermission" -> {
                    requestOverlayPermission()
                    result.success(true)
                }
                "startMonitoringService" -> {
                    startMonitoringService()
                    result.success(true)
                }
                "stopMonitoringService" -> {
                    stopMonitoringService()
                    result.success(true)
                }
                "testOverlay" -> {
                    testMilestoneOverlay()
                    result.success(true)
                }
                "bringAppToForeground" -> {
                    bringAppToForeground()
                    result.success(true)
                }
                else -> {
                    result.notImplemented()
                }
            }
        }
    }
    
    private fun createMilestoneNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val name = "Milestone Notifications"
            val descriptionText = "Notifications for app usage milestones"
            val importance = NotificationManager.IMPORTANCE_HIGH
            val channel = NotificationChannel(MILESTONE_CHANNEL_ID, name, importance).apply {
                description = descriptionText
                enableVibration(true)
                enableLights(true)
            }
            
            val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            notificationManager.createNotificationChannel(channel)
            android.util.Log.d("MainActivity", "✅ Milestone notification channel created")
        }
    }
    
    private fun checkMilestoneAndNotify(totalUsage: Int, totalLimit: Int) {
        if (totalLimit <= 0) return
        
        val percentage = (totalUsage.toDouble() / totalLimit.toDouble()) * 100.0
        android.util.Log.d("MainActivity", "Checking milestones: ${totalUsage}s / ${totalLimit}s = ${percentage}%")
        
        // Check for milestones in reverse order (100%, 70%, 30%)
        when {
            percentage >= 100.0 && !sharedPreferences.getBoolean(MILESTONE_100_KEY, false) -> {
                showMilestoneNotification(100, totalUsage, totalLimit)
                sharedPreferences.edit().putBoolean(MILESTONE_100_KEY, true).apply()
                android.util.Log.d("MainActivity", "🏆 100% Milestone reached!")
            }
            percentage >= 70.0 && !sharedPreferences.getBoolean(MILESTONE_70_KEY, false) -> {
                showMilestoneNotification(70, totalUsage, totalLimit)
                sharedPreferences.edit().putBoolean(MILESTONE_70_KEY, true).apply()
                android.util.Log.d("MainActivity", "🏆 70% Milestone reached!")
            }
            percentage >= 30.0 && !sharedPreferences.getBoolean(MILESTONE_30_KEY, false) -> {
                showMilestoneNotification(30, totalUsage, totalLimit)
                sharedPreferences.edit().putBoolean(MILESTONE_30_KEY, true).apply()
                android.util.Log.d("MainActivity", "🏆 30% Milestone reached!")
            }
        }
    }
    
    private fun showMilestoneNotification(milestonePercent: Int, currentUsage: Int, totalLimit: Int) {
        android.util.Log.d("MainActivity", "🎯 Triggering milestone overlay: $milestonePercent%")
        
        // **METHOD 1: Try direct overlay from MainActivity**
        if (checkOverlayPermission()) {
            android.util.Log.d("MainActivity", "✅ Overlay permission granted - showing direct overlay")
            try {
                showDirectMilestoneOverlay(milestonePercent, currentUsage, totalLimit)
                android.util.Log.d("MainActivity", "✅ Direct milestone overlay shown: $milestonePercent%")
                return // Exit early if direct overlay succeeds
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "❌ Direct overlay failed: ${e.message}")
                // Fall through to service method
            }
        }
        
        // **METHOD 2: Try via AppMonitorService** (fallback)
        if (checkOverlayPermission()) {
            android.util.Log.d("MainActivity", "🔄 Trying overlay via service...")
            val serviceIntent = Intent(this, AppMonitorService::class.java).apply {
                putExtra("milestone", milestonePercent)
                putExtra("currentUsage", currentUsage)
                putExtra("totalLimit", totalLimit)
            }
            
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                    startForegroundService(serviceIntent)
                } else {
                    startService(serviceIntent)
                }
                android.util.Log.d("MainActivity", "✅ Milestone overlay service started: $milestonePercent%")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "❌ Failed to start overlay service: ${e.message}")
            }
        } else {
            android.util.Log.w("MainActivity", "⚠️ Overlay permission not granted - showing notification instead")
        }
        
        // **BACKUP: Also show notification** (works even without overlay permission)
        val notificationManager = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        
        // Format time
        val usageMinutes = currentUsage / 60
        val usageSeconds = currentUsage % 60
        val limitMinutes = totalLimit / 60
        val limitSeconds = totalLimit % 60
        
        val usageText = if (usageMinutes > 0) "${usageMinutes}m ${usageSeconds}s" else "${usageSeconds}s"
        val limitText = if (limitMinutes > 0) "${limitMinutes}m ${limitSeconds}s" else "${limitSeconds}s"
        
        val intent = Intent(this, MainActivity::class.java).apply {
            flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
        }
        val pendingIntent = PendingIntent.getActivity(
            this,
            milestonePercent,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE
        )
        
        val (title, message) = when (milestonePercent) {
            30 -> Pair("🟢 30% Milestone!", "Used $usageText of $limitText")
            70 -> Pair("🟡 70% Milestone!", "Used $usageText of $limitText") 
            100 -> Pair("🔴 Limit Reached!", "Used $usageText of $limitText")
            else -> Pair("Milestone", "Usage update")
        }
        
        val notification = NotificationCompat.Builder(this, MILESTONE_CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle(title)
            .setContentText(message)
            .setPriority(NotificationCompat.PRIORITY_DEFAULT)
            .setAutoCancel(true)
            .setContentIntent(pendingIntent)
            .build()
        
        notificationManager.notify(1000 + milestonePercent, notification)
        android.util.Log.d("MainActivity", "✅ Backup notification also shown: $milestonePercent%")
    }
    
    private fun resetMilestones() {
        sharedPreferences.edit().apply {
            putBoolean(MILESTONE_30_KEY, false)
            putBoolean(MILESTONE_70_KEY, false)
            putBoolean(MILESTONE_100_KEY, false)
            apply()
        }
        android.util.Log.d("MainActivity", "✅ Milestones reset")
    }
    
    private fun checkUsageStatsPermission(): Boolean {
        return try {
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                val time = System.currentTimeMillis()
                val stats = usageStatsManager.queryUsageStats(
                    UsageStatsManager.INTERVAL_DAILY,
                    time - 1000 * 60,
                    time
                )
                // If we can query stats, permission is granted
                stats != null && stats.isNotEmpty()
            } else {
                false
            }
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error checking permission: ${e.message}")
            false
        }
    }
    
    private fun openUsageStatsSettings() {
        try {
            val intent = android.content.Intent(android.provider.Settings.ACTION_USAGE_ACCESS_SETTINGS)
            intent.flags = android.content.Intent.FLAG_ACTIVITY_NEW_TASK
            startActivity(intent)
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error opening settings: ${e.message}")
        }
    }

    private fun getForegroundApp(): String? {
        return try {
            // Try UsageStatsManager first (most reliable, requires PACKAGE_USAGE_STATS permission)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.LOLLIPOP) {
                try {
                    val usageStatsManager = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
                    val time = System.currentTimeMillis()
                    // Query last 5 minutes for more reliable results
                    val stats = usageStatsManager.queryUsageStats(
                        UsageStatsManager.INTERVAL_DAILY,
                        time - 1000 * 60 * 5, // Last 5 minutes
                        time
                    )
                    
                    if (stats != null && stats.isNotEmpty()) {
                        // Find the most recently used app (lastTimeUsed closest to now)
                        var mostRecent = stats[0]
                        for (usageStats in stats) {
                            if (usageStats.lastTimeUsed > mostRecent.lastTimeUsed) {
                                mostRecent = usageStats
                            }
                        }
                        // Only return if it was used very recently (within last 30 seconds)
                        if (time - mostRecent.lastTimeUsed < 30000) {
                            return mostRecent.packageName
                        }
                    }
                } catch (e: SecurityException) {
                    // Permission not granted - fallback to other methods
                    android.util.Log.d("MainActivity", "UsageStats permission not granted, using fallback")
                } catch (e: Exception) {
                    android.util.Log.d("MainActivity", "UsageStats error: ${e.message}")
                }
            }
            
            // Try fallback method (works without special permissions but less reliable)
            val fallbackResult = getForegroundAppFallback()
            if (fallbackResult != null) {
                return fallbackResult
            }
            
            null
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error getting foreground app: ${e.message}")
            null
        }
    }

    private fun getForegroundAppFallback(): String? {
        return try {
            val activityManager = getSystemService(Context.ACTIVITY_SERVICE) as ActivityManager
            
            // Method 1: Try appTasks (Android M+)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                try {
                    val runningTasks = activityManager.appTasks
                    if (runningTasks != null && runningTasks.isNotEmpty()) {
                        val taskInfo = runningTasks[0].taskInfo
                        if (taskInfo != null && taskInfo.topActivity != null) {
                            val packageName = taskInfo.topActivity?.packageName
                            if (packageName != null && packageName != applicationContext.packageName) {
                                return packageName
                            }
                        }
                    }
                } catch (e: Exception) {
                    // Continue to next method
                }
            }
            
            // Method 2: Try running processes (more reliable)
            try {
                val runningProcesses = activityManager.runningAppProcesses
                if (runningProcesses != null) {
                    // Sort by importance - foreground processes first
                    val sortedProcesses = runningProcesses.sortedByDescending { it.importance }
                    
                    for (processInfo in sortedProcesses) {
                        // Check for foreground or visible processes
                        if (processInfo.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_FOREGROUND ||
                            processInfo.importance == ActivityManager.RunningAppProcessInfo.IMPORTANCE_VISIBLE) {
                            if (processInfo.pkgList != null && processInfo.pkgList.isNotEmpty()) {
                                val packageName = processInfo.pkgList[0]
                                // Don't return our own app
                                if (packageName != applicationContext.packageName) {
                                    return packageName
                                }
                            }
                        }
                    }
                }
            } catch (e: Exception) {
                // Continue
            }
            
            null
        } catch (e: Exception) {
            null
        }
    }
    
    // Milestone tracking methods removed - logic moved to Dart
    
    // Check if overlay permission is granted
    private fun checkOverlayPermission(): Boolean {
        return if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            Settings.canDrawOverlays(this)
        } else {
            true
        }
    }
    
    // Request overlay permission
    private fun requestOverlayPermission() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
            if (!Settings.canDrawOverlays(this)) {
                val intent = Intent(
                    Settings.ACTION_MANAGE_OVERLAY_PERMISSION,
                    Uri.parse("package:$packageName")
                )
                startActivityForResult(intent, 100)
                android.util.Log.d("MainActivity", "Requesting overlay permission")
            }
        }
    }
    
    // Start monitoring service
    private fun startMonitoringService() {
        if (checkOverlayPermission()) {
            val serviceIntent = Intent(this, AppMonitorService::class.java)
            
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                startForegroundService(serviceIntent)
            } else {
                startService(serviceIntent)
            }
            android.util.Log.d("MainActivity", "✅ Monitoring service started (milestone logic removed)")
        } else {
            android.util.Log.e("MainActivity", "❌ Overlay permission not granted")
        }
    }
    
    // Stop monitoring service
    private fun stopMonitoringService() {
        val serviceIntent = Intent(this, AppMonitorService::class.java)
        stopService(serviceIntent)
        android.util.Log.d("MainActivity", "Monitoring service stopped")
    }
    

    private fun bringAppToForeground() {
        try {
            android.util.Log.d("MainActivity", "Bringing app to foreground...")
            
            // Create an intent to launch the app
            val intent = Intent(this, MainActivity::class.java).apply {
                flags = Intent.FLAG_ACTIVITY_NEW_TASK or 
                        Intent.FLAG_ACTIVITY_CLEAR_TOP or
                        Intent.FLAG_ACTIVITY_SINGLE_TOP or
                        Intent.FLAG_ACTIVITY_REORDER_TO_FRONT
            }
            
            // Start the activity to bring it to foreground
            startActivity(intent)
            
            android.util.Log.d("MainActivity", "✅ App brought to foreground")
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error bringing app to foreground: ${e.message}")
        }
    }
    
    private fun showDirectMilestoneOverlay(milestone: Int, currentUsage: Int, totalLimit: Int) {
        val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
        
        // Create overlay view programmatically
        val overlayView = createSimpleMilestoneView(milestone, currentUsage, totalLimit)
        
        // Window parameters for Android 10-14
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
            WindowManager.LayoutParams.FLAG_KEEP_SCREEN_ON,
            PixelFormat.TRANSLUCENT
        )
        
        params.gravity = Gravity.CENTER
        
        // Add to window manager
        windowManager.addView(overlayView, params)
        
        // Auto-remove after 5 seconds
        Handler(Looper.getMainLooper()).postDelayed({
            try {
                windowManager.removeView(overlayView)
                android.util.Log.d("MainActivity", "Direct overlay removed")
            } catch (e: Exception) {
                android.util.Log.e("MainActivity", "Error removing direct overlay: ${e.message}")
            }
        }, 5000)
    }
    
    private fun createSimpleMilestoneView(milestone: Int, currentUsage: Int, totalLimit: Int): View {
        // Create a simple overlay view
        val layout = RelativeLayout(this).apply {
            setBackgroundColor(Color.parseColor("#E6000000")) // Semi-transparent black
        }
        
        val textView = TextView(this).apply {
            text = "🏆 ${milestone}% MILESTONE!\n\nUsage: ${currentUsage}s / ${totalLimit}s\n\nTap anywhere to close"
            textSize = 24f
            setTextColor(Color.WHITE)
            gravity = Gravity.CENTER
            setPadding(80, 80, 80, 80)
            setOnClickListener {
                // Remove this view when clicked
                (parent as? android.view.ViewGroup)?.removeView(this@apply)
            }
        }
        
        val params = RelativeLayout.LayoutParams(
            RelativeLayout.LayoutParams.WRAP_CONTENT,
            RelativeLayout.LayoutParams.WRAP_CONTENT
        ).apply {
            addRule(RelativeLayout.CENTER_IN_PARENT)
        }
        
        layout.addView(textView, params)
        return layout
    }
    
    private fun testMilestoneOverlay() {
        android.util.Log.d("MainActivity", "🧪 Testing milestone overlay...")
        
        if (!checkOverlayPermission()) {
            android.util.Log.e("MainActivity", "❌ Cannot test overlay - permission not granted")
            android.util.Log.i("MainActivity", "💡 Grant overlay permission first!")
            return
        }
        
        // Test with 70% milestone
        showMilestoneNotification(70, 42, 60)
        android.util.Log.d("MainActivity", "✅ Test milestone overlay triggered!")
    }
}
