package com.example.my_app

import android.annotation.SuppressLint
import android.app.*
import android.content.*
import android.content.pm.PackageManager
import android.os.*
import android.util.Log
import androidx.core.app.NotificationCompat
import android.app.usage.UsageEvents
import android.app.usage.UsageStatsManager
import android.content.pm.ServiceInfo
import org.json.JSONObject
import org.json.JSONArray
import java.util.concurrent.ConcurrentHashMap
import kotlin.random.Random

class AppMonitorService : Service() {

    companion object {
        const val CHANNEL_ID = "app_monitor_channel"
        const val NOTIFICATION_ID = 10050
        const val ACTION_FOREGROUND_CHANGED = "com.example.my_app.FOREGROUND_CHANGED"
        const val EXTRA_PACKAGE = "package_name"

        private const val PREFS_NAME = "app_monitor_data"
        private const val KEY_USAGE = "usage_data"
        private const val KEY_BLOCKED = "blocked_apps"
        private const val KEY_LIMITS = "app_limits"
        private const val KEY_SHOWN_WELCOME = "shown_welcome"

        // Thoughtful messages for different usage levels
        private val WELCOME_MESSAGES = listOf(
            "Time to focus! Your usage is being tracked.",
            "Starting fresh! Make every minute count.",
            "Your digital wellbeing journey begins now.",
            "Mindful usage starts here!",
            "Let's build healthy screen habits together."
        )

        private val MILESTONE_30_MESSAGES = listOf(
            "You've used 30% of your limit. Stay mindful!",
            "Great start! You have 70% left.",
            "30% used. Keep up the balanced usage!",
            "On track! Most of your time is still available.",
            "Nice control! 70% remaining for today.",
            "You're doing well! 30% milestone reached.",
            "Stay focused! You still have plenty of time left.",
            "Good progress! Remember to take breaks.",
            "30% done! Use your remaining time wisely.",
            "Keep going! You're managing your time well."
        )

        private val MILESTONE_70_MESSAGES = listOf(
            "70% of your limit used. Time to slow down!",
            "Alert! Only 30% of your time remains.",
            "You're at 70%! Consider taking a break soon.",
            "Running low! 30% left for today.",
            "Careful! You've used most of your time.",
            "70% milestone! Make your last 30% count.",
            "Time check! You're running out quickly.",
            "Heads up! Better wrap things up soon.",
            "70% used! Plan your remaining time wisely.",
            "Almost there! Use your last 30% mindfully."
        )

        private val MILESTONE_100_MESSAGES = listOf(
            "Time's up! Take a break and recharge.",
            "Limit reached! It's time to disconnect.",
            "100%! Your brain deserves a rest now.",
            "Well done! Now take a healthy break.",
            "Time limit reached. Go do something offline!",
            "You've reached your limit. Time to unplug!",
            "Screen time over! Try something different now.",
            "Limit hit! Your eyes will thank you for a break.",
            "That's enough screen time! Go refresh yourself.",
            "100% done! Step away and enjoy the real world."
        )

        private val BLOCKED_MESSAGES = listOf(
            "App blocked! Time to focus on other things.",
            "Blocked! Your wellbeing comes first.",
            "Time limit exceeded! Take a breather.",
            "App locked! Let's do something productive.",
            "Blocked for your health! Try a walk instead.",
            "Limit reached! Your future self will thank you.",
            "App blocked! Disconnect to reconnect with life.",
            "Time's up! Go enjoy the world around you.",
            "Blocked! Balance is the key to happiness.",
            "Locked! Use this time for self-improvement."
        )
    }

    private val handler = Handler(Looper.getMainLooper())
    private var isRunning = false
    private var foregroundStarted = false

    private val appLimits = ConcurrentHashMap<String, Int>()
    private val appUsage = ConcurrentHashMap<String, Int>()
    private val blockedApps = ConcurrentHashMap.newKeySet<String>()
    private val milestoneFlags = ConcurrentHashMap<String, MutableSet<Int>>()
    private val shownWelcomeNotifications = ConcurrentHashMap.newKeySet<String>()

    private var currentForegroundPkg: String? = null
    private var appStartTime: Long = 0

    private val foregroundReceiver = object : BroadcastReceiver() {
        override fun onReceive(context: Context?, intent: Intent?) {
            if (intent?.action == ACTION_FOREGROUND_CHANGED) {
                val pkg = intent.getStringExtra(EXTRA_PACKAGE)
                if (!pkg.isNullOrBlank()) {
                    onForegroundAppChanged(pkg)
                }
            }
        }
    }

    @SuppressLint("UnspecifiedRegisterReceiverFlag")
    override fun onCreate() {
        super.onCreate()
        AppMonitorServiceHolder.serviceInstance = this
        createNotificationChannel()

        val filter = IntentFilter(ACTION_FOREGROUND_CHANGED)
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            registerReceiver(foregroundReceiver, filter, Context.RECEIVER_NOT_EXPORTED)
        } else {
            registerReceiver(foregroundReceiver, filter)
        }

        Log.d("AppMonitorService", "✅ Service created")
    }

    override fun onStartCommand(intent: Intent?, flags: Int, startId: Int): Int {
        Log.d("AppMonitorService", "📱 Service onStartCommand")

        if (!foregroundStarted) {
            try {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.UPSIDE_DOWN_CAKE) {
                    startForeground(
                        NOTIFICATION_ID,
                        createPersistentNotification(),
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                    )
                } else if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.Q) {
                    startForeground(
                        NOTIFICATION_ID,
                        createPersistentNotification(),
                        ServiceInfo.FOREGROUND_SERVICE_TYPE_DATA_SYNC
                    )
                } else {
                    startForeground(NOTIFICATION_ID, createPersistentNotification())
                }
                foregroundStarted = true
                Log.d("AppMonitorService", "✅ Foreground service started")
            } catch (e: Exception) {
                Log.e("AppMonitorService", "❌ Failed to start foreground: ${e.message}")
            }
        }

        if (!isRunning) {
            isRunning = true
            restoreState()
            startMonitoring()
            Log.d("AppMonitorService", "✅ Monitoring started")
        }

        return START_STICKY
    }

    override fun onDestroy() {
        super.onDestroy()
        isRunning = false
        handler.removeCallbacksAndMessages(null)
        try {
            unregisterReceiver(foregroundReceiver)
        } catch (_: Exception) {}
        saveState()
        AppMonitorServiceHolder.serviceInstance = null
        Log.d("AppMonitorService", "❌ Service destroyed")
    }

    override fun onBind(intent: Intent?): IBinder? = null

    private fun startMonitoring() {
        handler.post(object : Runnable {
            override fun run() {
                if (!isRunning) return
                try {
                    trackCurrentApp()
                } catch (e: Exception) {
                    Log.e("AppMonitorService", "Tracking error: ${e.message}")
                }
                handler.postDelayed(this, 1000)
            }
        })

        handler.post(object : Runnable {
            override fun run() {
                if (!isRunning) return
                try {
                    val pkg = getForegroundAppViaUsageStats()
                    if (pkg != null && pkg != currentForegroundPkg) {
                        onForegroundAppChanged(pkg)
                    }
                } catch (e: Exception) {
                    Log.e("AppMonitorService", "UsageStats error: ${e.message}")
                }
                handler.postDelayed(this, 3000)
            }
        })

        handler.post(object : Runnable {
            override fun run() {
                if (!isRunning) return
                saveState()
                handler.postDelayed(this, 5000)
            }
        })
    }

    private fun onForegroundAppChanged(packageName: String) {
        val now = System.currentTimeMillis()

        currentForegroundPkg?.let { prevPkg ->
            if (isMonitored(prevPkg) && appStartTime > 0) {
                val duration = ((now - appStartTime) / 1000).toInt()
                if (duration > 0) {
                    incrementUsage(prevPkg, duration)
                }
            }
        }

        currentForegroundPkg = packageName
        appStartTime = now

        Log.d("AppMonitorService", "📱 App changed: $packageName")

        if (isMonitored(packageName) && !shownWelcomeNotifications.contains(packageName)) {
            showMonitoringStartNotification(packageName)
            shownWelcomeNotifications.add(packageName)
        }

        if (blockedApps.contains(packageName)) {
            launchBlockingActivity(packageName)
        }
    }

    private fun trackCurrentApp() {
        val pkg = currentForegroundPkg ?: return
        if (!isMonitored(pkg)) return
        if (blockedApps.contains(pkg)) {
            launchBlockingActivity(pkg)
            return
        }
        incrementUsage(pkg, 1)
    }

    private fun incrementUsage(packageName: String, seconds: Int) {
        val newUsage = (appUsage[packageName] ?: 0) + seconds
        appUsage[packageName] = newUsage

        val limit = appLimits[packageName] ?: 0

        Log.d("AppMonitorService", "📊 $packageName: ${newUsage}s / ${limit}s")

        if (limit > 0) {
            val percentage = (newUsage.toDouble() / limit.toDouble() * 100).toInt()
            checkAndNotifyMilestone(packageName, percentage, newUsage, limit)
        }

        if (limit > 0 && newUsage >= limit && !blockedApps.contains(packageName)) {
            blockApp(packageName, newUsage, limit)
        }
    }

    private fun checkAndNotifyMilestone(pkg: String, percentage: Int, usage: Int, limit: Int) {
        val flags = milestoneFlags.getOrPut(pkg) { mutableSetOf() }

        val milestones = listOf(30, 70, 100)
        for (milestone in milestones) {
            if (percentage >= milestone && !flags.contains(milestone)) {
                flags.add(milestone)
                sendMilestoneNotification(pkg, milestone, usage, limit)
            }
        }
    }

    private fun getRandomMessage(messages: List<String>): String {
        return messages[Random.nextInt(messages.size)]
    }

    private fun showMonitoringStartNotification(packageName: String) {
        val appName = getAppName(packageName)
        val limit = appLimits[packageName] ?: 0
        val limitText = formatSeconds(limit)

        val message = getRandomMessage(WELCOME_MESSAGES)

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("🔍 $appName - Monitoring Started")
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("$message\n\nTime limit: $limitText"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 300, 100, 300))
            .build()

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(packageName.hashCode(), notification)

        Log.d("AppMonitorService", "🔔 Welcome: $message")
    }

    private fun sendMilestoneNotification(packageName: String, milestone: Int, usage: Int, limit: Int) {
        val appName = getAppName(packageName)
        val usageText = formatSeconds(usage)
        val limitText = formatSeconds(limit)

        val message = when (milestone) {
            30 -> getRandomMessage(MILESTONE_30_MESSAGES)
            70 -> getRandomMessage(MILESTONE_70_MESSAGES)
            100 -> getRandomMessage(MILESTONE_100_MESSAGES)
            else -> "Milestone $milestone% reached"
        }

        val emoji = when (milestone) {
            30 -> "🟢"
            70 -> "🟡"
            100 -> "🔴"
            else -> "📊"
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("$emoji $appName - $milestone% Used")
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("$message\n\nUsage: $usageText / $limitText"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .build()

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify((packageName.hashCode() + milestone), notification)

        Log.d("AppMonitorService", "🔔 $milestone%: $message")
    }

    private fun blockApp(packageName: String, usage: Int, limit: Int) {
        blockedApps.add(packageName)
        sendBlockedNotification(packageName, usage, limit)
        launchBlockingActivity(packageName)
        saveState()
        Log.d("AppMonitorService", "🚫 Blocked: $packageName")
    }

    private fun sendBlockedNotification(packageName: String, usage: Int, limit: Int) {
        val appName = getAppName(packageName)
        val usageText = formatSeconds(usage)
        val limitText = formatSeconds(limit)

        val message = getRandomMessage(BLOCKED_MESSAGES)

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_delete)
            .setContentTitle("🚫 $appName - Blocked")
            .setContentText(message)
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("$message\n\nUsage: $usageText / $limitText"))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setAutoCancel(false)
            .setOngoing(true)
            .setVibrate(longArrayOf(0, 1000, 500, 1000))
            .build()

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(packageName.hashCode() + 999, notification)

        Log.d("AppMonitorService", "🔔 Blocked: $message")
    }

    private fun launchBlockingActivity(packageName: String) {
        try {
            val intent = Intent(this, BlockingActivity::class.java).apply {
                putExtra("packageName", packageName)
                addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
            }
            startActivity(intent)
        } catch (e: Exception) {
            Log.e("AppMonitorService", "Failed to launch BlockingActivity: ${e.message}")
        }
    }

    private fun getForegroundAppViaUsageStats(): String? {
        try {
            val usm = getSystemService(Context.USAGE_STATS_SERVICE) as UsageStatsManager
            val end = System.currentTimeMillis()
            val begin = end - 10_000
            val events = usm.queryEvents(begin, end)
            var lastPkg: String? = null
            val event = UsageEvents.Event()

            while (events.hasNextEvent()) {
                events.getNextEvent(event)
                if (event.eventType == UsageEvents.Event.ACTIVITY_RESUMED ||
                    event.eventType == UsageEvents.Event.MOVE_TO_FOREGROUND) {
                    lastPkg = event.packageName
                }
            }
            return lastPkg
        } catch (e: Exception) {
            Log.e("AppMonitorService", "UsageStats query failed: ${e.message}")
            return null
        }
    }

    private fun isMonitored(pkg: String): Boolean = appLimits.containsKey(pkg)

    private fun getAppName(packageName: String): String = try {
        packageManager.getApplicationLabel(
            packageManager.getApplicationInfo(packageName, 0)
        ).toString()
    } catch (_: Exception) {
        packageName
    }

    private fun formatSeconds(seconds: Int): String {
        val h = seconds / 3600
        val m = (seconds % 3600) / 60
        val s = seconds % 60
        return when {
            h > 0 -> "${h}h ${m}m"
            m > 0 -> "${m}m ${s}s"
            else -> "${s}s"
        }
    }

    private fun createPersistentNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentTitle("📱 Digital Wellbeing Active")
            .setContentText("Monitoring your app usage")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Usage Monitor",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Monitors app usage and sends thoughtful notifications"
                enableVibration(true)
                vibrationPattern = longArrayOf(0, 300, 100, 300)
            }
            val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            nm.createNotificationChannel(channel)
        }
    }

    private fun saveState() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            val editor = prefs.edit()

            val usageArray = JSONArray()
            appUsage.forEach { (pkg, usage) ->
                usageArray.put(JSONObject().apply {
                    put("pkg", pkg)
                    put("usage", usage)
                })
            }
            editor.putString(KEY_USAGE, usageArray.toString())

            val limitsArray = JSONArray()
            appLimits.forEach { (pkg, limit) ->
                limitsArray.put(JSONObject().apply {
                    put("pkg", pkg)
                    put("limit", limit)
                })
            }
            editor.putString(KEY_LIMITS, limitsArray.toString())

            val blockedArray = JSONArray()
            blockedApps.forEach { blockedArray.put(it) }
            editor.putString(KEY_BLOCKED, blockedArray.toString())

            val welcomeArray = JSONArray()
            shownWelcomeNotifications.forEach { welcomeArray.put(it) }
            editor.putString(KEY_SHOWN_WELCOME, welcomeArray.toString())

            editor.apply()
        } catch (e: Exception) {
            Log.e("AppMonitorService", "Save state error: ${e.message}")
        }
    }

    private fun restoreState() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)

            prefs.getString(KEY_USAGE, null)?.let { json ->
                val array = JSONArray(json)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    appUsage[obj.getString("pkg")] = obj.getInt("usage")
                }
            }

            prefs.getString(KEY_LIMITS, null)?.let { json ->
                val array = JSONArray(json)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    appLimits[obj.getString("pkg")] = obj.getInt("limit")
                }
            }

            prefs.getString(KEY_BLOCKED, null)?.let { json ->
                val array = JSONArray(json)
                for (i in 0 until array.length()) {
                    blockedApps.add(array.getString(i))
                }
            }

            prefs.getString(KEY_SHOWN_WELCOME, null)?.let { json ->
                val array = JSONArray(json)
                for (i in 0 until array.length()) {
                    shownWelcomeNotifications.add(array.getString(i))
                }
            }

            Log.d("AppMonitorService", "📂 State restored: ${appLimits.size} apps")
        } catch (e: Exception) {
            Log.e("AppMonitorService", "Restore state error: ${e.message}")
        }
    }

    fun restartMonitoring(apps: List<Map<String, Any?>>) {
        appLimits.clear()
        milestoneFlags.clear()
        shownWelcomeNotifications.clear()

        for (app in apps) {
            val pkg = app["packageName"] as String
            val limit = (app["limitSeconds"] as? Number)?.toInt() ?: 0
            val usage = (app["usageSeconds"] as? Number)?.toInt() ?: (appUsage[pkg] ?: 0)
            val blocked = app["blocked"] as? Boolean ?: false

            appLimits[pkg] = limit
            appUsage[pkg] = usage
            if (blocked) blockedApps.add(pkg) else blockedApps.remove(pkg)
        }

        saveState()
        Log.d("AppMonitorService", "🔄 Monitoring restarted: ${apps.size} apps")
    }

    fun unblockApp(packageName: String) {
        Log.d("AppMonitorService", "🔓 UNBLOCKING (REMOVING): $packageName")

        blockedApps.remove(packageName)
        appUsage.remove(packageName)
        appLimits.remove(packageName)
        milestoneFlags.remove(packageName)
        shownWelcomeNotifications.remove(packageName)

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(packageName.hashCode())
        nm.cancel(packageName.hashCode() + 30)
        nm.cancel(packageName.hashCode() + 70)
        nm.cancel(packageName.hashCode() + 100)
        nm.cancel(packageName.hashCode() + 999)

        saveState()

        try {
            val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)
            val editor = prefs.edit()

            val usageArray = JSONArray()
            appUsage.forEach { (pkg, usage) ->
                usageArray.put(JSONObject().apply {
                    put("pkg", pkg)
                    put("usage", usage)
                })
            }
            editor.putString(KEY_USAGE, usageArray.toString())

            val limitsArray = JSONArray()
            appLimits.forEach { (pkg, limit) ->
                limitsArray.put(JSONObject().apply {
                    put("pkg", pkg)
                    put("limit", limit)
                })
            }
            editor.putString(KEY_LIMITS, limitsArray.toString())

            val blockedArray = JSONArray()
            blockedApps.forEach { blockedArray.put(it) }
            editor.putString(KEY_BLOCKED, blockedArray.toString())

            val welcomeArray = JSONArray()
            shownWelcomeNotifications.forEach { welcomeArray.put(it) }
            editor.putString(KEY_SHOWN_WELCOME, welcomeArray.toString())

            editor.commit()
        } catch (e: Exception) {
            Log.e("AppMonitorService", "Cache clear error: ${e.message}")
        }

        Log.d("AppMonitorService", "✅ UNBLOCK COMPLETE")
    }

    fun getBlockedApps(): List<String> = blockedApps.toList()

    fun getUsageSnapshot(): List<Map<String, Any>> {
        return appUsage.map { (pkg, usage) ->
            mapOf(
                "packageName" to pkg,
                "usageSeconds" to usage,
                "limitSeconds" to (appLimits[pkg] ?: 0),
                "blocked" to blockedApps.contains(pkg)
            )
        }
    }

    fun usageUpdate(packageName: String, usageSeconds: Int, limitSeconds: Int) {
        appUsage[packageName] = usageSeconds
        appLimits[packageName] = limitSeconds
        if (limitSeconds > 0) {
            val percentage = (usageSeconds.toDouble() / limitSeconds.toDouble() * 100).toInt()
            checkAndNotifyMilestone(packageName, percentage, usageSeconds, limitSeconds)
        }
        if (usageSeconds >= limitSeconds && limitSeconds > 0) {
            blockApp(packageName, usageSeconds, limitSeconds)
        }
        saveState()
    }
}

object AppMonitorServiceHolder {
    var serviceInstance: AppMonitorService? = null
}