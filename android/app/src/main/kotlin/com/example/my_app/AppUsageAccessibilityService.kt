package com.example.my_app

import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.util.Log
import android.view.accessibility.AccessibilityEvent

class AppUsageAccessibilityService : AccessibilityService() {

    private var lastPackage: String? = null

    override fun onAccessibilityEvent(event: AccessibilityEvent?) {
        if (event == null) return

        try {
            val packageName = event.packageName?.toString() ?: return

            // Only process meaningful window changes
            when (event.eventType) {
                AccessibilityEvent.TYPE_WINDOW_STATE_CHANGED -> {
                    if (packageName != lastPackage) {
                        lastPackage = packageName
                        broadcastForegroundChange(packageName)
                        Log.d("AccessibilityService", "🔄 App changed: $packageName")
                    }
                }
            }
        } catch (e: Exception) {
            Log.e("AccessibilityService", "Event error: ${e.message}")
        }
    }

    private fun broadcastForegroundChange(packageName: String) {
        try {
            val intent = Intent(AppMonitorService.ACTION_FOREGROUND_CHANGED).apply {
                putExtra(AppMonitorService.EXTRA_PACKAGE, packageName)
                setPackage(application.packageName)
            }
            sendBroadcast(intent)
        } catch (e: Exception) {
            Log.e("AccessibilityService", "Broadcast error: ${e.message}")
        }
    }

    override fun onInterrupt() {
        Log.d("AccessibilityService", "Service interrupted")
    }

    override fun onServiceConnected() {
        super.onServiceConnected()
        Log.d("AccessibilityService", "✅ Service connected")
    }
}