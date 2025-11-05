package com.example.my_app

import android.app.ActivityManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.app.usage.UsageStatsManager
import android.content.Context
import android.content.Intent
import android.graphics.PixelFormat
import android.net.Uri
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.provider.Settings
import android.view.Gravity
import android.view.LayoutInflater
import android.view.WindowManager
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

class MainActivity : FlutterActivity() {
    private val CHANNEL = "app_usage_tracker"
    // Milestone logic removed from Kotlin - handled in Flutter/Dart only

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
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
                    // Milestone logic removed - return default values
                    result.success(mapOf(
                        "percentage" to 0.0,
                        "milestone30" to false,
                        "milestone70" to false,
                        "milestone100" to false,
                        "newMilestoneReached" to false,
                        "milestoneValue" to 0
                    ))
                }
                "checkCombinedMilestone" -> {
                    // Milestone logic removed - return default values
                    result.success(mapOf(
                        "percentage" to 0.0,
                        "milestone30" to false,
                        "milestone70" to false,
                        "milestone100" to false,
                        "newMilestoneReached" to false,
                        "milestoneValue" to 0
                    ))
                }
                "resetCombinedMilestones" -> {
                    // Milestone logic removed - no-op
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
                    // Overlay logic removed
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
    
    // Test overlay display
    private fun testShowOverlay() {
        if (!checkOverlayPermission()) {
            android.util.Log.e("MainActivity", "Cannot test overlay - permission not granted")
            return
        }
        
        try {
            val windowManager = getSystemService(Context.WINDOW_SERVICE) as WindowManager
            val inflater = LayoutInflater.from(this)
            val testView = inflater.inflate(R.layout.milestone_overlay, null)
            
            val layoutFlag = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
                WindowManager.LayoutParams.TYPE_APPLICATION_OVERLAY
            } else {
                WindowManager.LayoutParams.TYPE_PHONE
            }
            
            val params = WindowManager.LayoutParams(
                WindowManager.LayoutParams.MATCH_PARENT,
                WindowManager.LayoutParams.MATCH_PARENT,
                layoutFlag,
                WindowManager.LayoutParams.FLAG_FULLSCREEN or
                WindowManager.LayoutParams.FLAG_LAYOUT_IN_SCREEN or
                WindowManager.LayoutParams.FLAG_NOT_FOCUSABLE,
                PixelFormat.TRANSLUCENT
            )
            
            params.gravity = Gravity.CENTER
            
            windowManager.addView(testView, params)
            android.util.Log.d("MainActivity", "✅ TEST overlay shown")
            
            // Auto-remove after 5 seconds
            Handler(Looper.getMainLooper()).postDelayed({
                try {
                    windowManager.removeView(testView)
                    android.util.Log.d("MainActivity", "Test overlay removed")
                } catch (e: Exception) {
                    android.util.Log.e("MainActivity", "Error removing test overlay: ${e.message}")
                }
            }, 5000)
            
        } catch (e: Exception) {
            android.util.Log.e("MainActivity", "Error showing test overlay: ${e.message}")
        }
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
    
    // All milestone logic removed - handled in Flutter/Dart
}
