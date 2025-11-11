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

        // 🧘 Digital Wellbeing Daily Routine Generator
        private fun getDailyEyeExercise(): String {
            val eyeExercises = arrayOf(
                "🔄 Slow Blinks\nBlink slowly 20 times, holding each blink for 2 seconds to relax your eyes.",
                "👁 20-20-20 Rule\nLook at an object 20 feet away for 20 seconds to rest your eye muscles.",
                "🎯 Focus Shift\nFocus on your finger 6 inches away, then something far. Repeat 10 times.",
                "🔵 Figure 8\nTrace an imaginary figure 8 with your eyes 5 times, 10 feet away.",
                "⬆ Eye Movements\nLook up, down, left, right for 3 seconds each without moving your head.",
                "🌀 Eye Rolls\nRoll your eyes in circles 5 times clockwise, then counterclockwise.",
                "👆 Near & Far\nFocus on your thumb at arm's length, then something far for 5 seconds each.",
                "✋ Palming\nCup your palms over closed eyes for 30 seconds, breathing deeply.",
                "💧 Rapid Blinks\nBlink rapidly 10 times to stimulate tear production.",
                "😴 Rest & Breathe\nClose your eyes, take 5 deep breaths, and relax for 30 seconds."
            )
            val dayOfYear = java.util.Calendar.getInstance().get(java.util.Calendar.DAY_OF_YEAR)
            return eyeExercises[dayOfYear % eyeExercises.size]
        }

        private fun getDailyPhysicalActivity(): String {
            val physicalActivities = arrayOf(
                "🚶 Quick Walk\nTake a 5-10 minute walk to refresh your mind and body.",
                "🧘 Stretch Break\nDo 5 minutes of neck, shoulder, and back stretches.",
                "🏃 Cardio Burst\nDo 2 minutes of jumping jacks or high knees.",
                "🎯 Active Game\nPlay catch or juggle for 5 minutes to stay active.",
                "💪 Bodyweight Workout\nDo 10 push-ups, 15 squats, or a 30-second plank.",
                "🌿 Nature Moment\nStep outside and observe nature for 5 minutes.",
                "🎵 Dance Party\nDance to a favorite song for 3-5 minutes.",
                "🧘‍♀ Meditation\nPractice 5 minutes of deep breathing or meditation.",
                "🏠 Quick Chore\nOrganize your desk or water plants for 5 minutes.",
                "📞 Social Break\nCall a friend for a quick, uplifting chat."
            )
            val dayOfYear = java.util.Calendar.getInstance().get(java.util.Calendar.DAY_OF_YEAR)
            return physicalActivities[(dayOfYear + 5) % physicalActivities.size]
        }

        private fun getDailyMotivation(): String {
            val motivationalBreaks = arrayOf(
                "🌱 Reflect\n\"Take 5 minutes to think about your goals and dreams.\"",
                "🧠 Mindful Break\n\"Give your brain a rest with 5 minutes of quiet breathing.\"",
                "💭 Creative Spark\n\"Let your mind wander freely for new ideas.\"",
                "🌍 Real World\n\"Step outside and experience the world beyond screens.\"",
                "💪 Willpower Win\n\"You're mastering technology with every break you take!\"",
                "🎯 Focus Boost\n\"Screen breaks enhance your focus across all tasks.\"",
                "⚖ Balance\n\"You're creating a healthier tech-life balance.\"",
                "🌟 Be Present\n\"Embrace the moment without digital distractions.\"",
                "🧘 Inner Peace\n\"Connect with yourself in a quiet moment.\"",
                "🚀 Productivity\n\"Breaks boost productivity by 23%. Keep it up!\""
            )
            val dayOfYear = java.util.Calendar.getInstance().get(java.util.Calendar.DAY_OF_YEAR)
            return motivationalBreaks[(dayOfYear + 10) % motivationalBreaks.size]
        }
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

    private fun getRandomMessage(messageType: String): String {
        return when (messageType) {
            "welcome" -> getDailyMotivation()
            "30" -> getDailyEyeExercise()
            "70" -> getDailyPhysicalActivity()
            "100" -> getDailyMotivation()
            "blocked" -> getDailyPhysicalActivity()
            else -> getDailyMotivation()
        }
    }

    private fun showMonitoringStartNotification(packageName: String) {
        val appName = getAppName(packageName)
        val limit = appLimits[packageName] ?: 0
        val limitText = formatSeconds(limit)

        val message = getRandomMessage("welcome")

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("🔍 $appName - Monitoring Started")
            .setContentText(message.split("\n")[0])
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
            30 -> getRandomMessage("30")
            70 -> getRandomMessage("70")
            100 -> getRandomMessage("100")
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
            .setContentText(message.split("\n")[0])
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

        val message = getRandomMessage("blocked")

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_delete)
            .setContentTitle("🚫 $appName - Blocked")
            .setContentText(message.split("\n")[0])
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