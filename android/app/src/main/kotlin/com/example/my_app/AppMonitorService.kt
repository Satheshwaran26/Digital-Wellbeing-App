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
import android.provider.Settings


class AppMonitorService : Service() {

    companion object {
        const val CHANNEL_ID = "app_monitor_channel"
        const val NOTIFICATION_ID = 10050
        const val ACTION_FOREGROUND_CHANGED = "com.example.my_app.FOREGROUND_CHANGED"
        const val EXTRA_PACKAGE = "package_name"

        private const val PREFS_NAME = "app_monitor_data"
        private const val KEY_APP_TIMERS = "app_timers" // Store: startTime + limit
        private const val KEY_BLOCKED = "blocked_apps"
        private const val KEY_MILESTONES = "milestone_flags"
        private const val KEY_SHOWN_WELCOME = "shown_welcome"

        // Daily wellbeing routines
        private fun getDailyEyeExercise(): String {
            val exercises = arrayOf(
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
            return exercises[java.util.Calendar.getInstance().get(java.util.Calendar.DAY_OF_YEAR) % exercises.size]
        }

        private fun getDailyPhysicalActivity(): String {
            val activities = arrayOf(
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
            return activities[(java.util.Calendar.getInstance().get(java.util.Calendar.DAY_OF_YEAR) + 5) % activities.size]
        }

        private fun getDailyMotivation(): String {
            val motivations = arrayOf(
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
            return motivations[(java.util.Calendar.getInstance().get(java.util.Calendar.DAY_OF_YEAR) + 10) % motivations.size]
        }
    }

    private val handler = Handler(Looper.getMainLooper())
    private var isRunning = false
    private var foregroundStarted = false

    // Data structure: packageName -> [startTimeMillis, limitSeconds]
    private val appTimers = ConcurrentHashMap<String, Pair<Long, Int>>()
    private val blockedApps = ConcurrentHashMap.newKeySet<String>()
    private val milestoneFlags = ConcurrentHashMap<String, MutableSet<Int>>()
    private val shownWelcomeNotifications = ConcurrentHashMap.newKeySet<String>()

    private var currentForegroundPkg: String? = null

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
        // Check ALL timers every second (whether app is open or not)
        handler.post(object : Runnable {
            override fun run() {
                if (!isRunning) return
                try {
                    checkAllTimers()
                } catch (e: Exception) {
                    Log.e("AppMonitorService", "Timer check error: ${e.message}")
                }
                handler.postDelayed(this, 1000) // Every 1 second
            }
        })

        // Detect foreground app (for blocking screen)
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
                handler.postDelayed(this, 2000)
            }
        })

        // Save state periodically
        handler.post(object : Runnable {
            override fun run() {
                if (!isRunning) return
                saveState()
                handler.postDelayed(this, 10000) // Every 10 seconds
            }
        })
    }

    private fun checkAllTimers() {
        val currentTime = System.currentTimeMillis()

        for ((pkg, timerData) in appTimers) {
            val (startTime, limitSeconds) = timerData

            // Calculate elapsed time since monitoring started
            val elapsedSeconds = ((currentTime - startTime) / 1000).toInt()
            val remainingSeconds = limitSeconds - elapsedSeconds

            // Check if time is up
            if (remainingSeconds <= 0 && !blockedApps.contains(pkg)) {
                // TIME'S UP - BLOCK THE APP
                Log.d("AppMonitorService", "⏰ TIME'S UP for $pkg (${elapsedSeconds}s / ${limitSeconds}s)")
                blockApp(pkg, limitSeconds)
            } else if (remainingSeconds > 0) {
                // Still time remaining - check milestones
                val percentage = (elapsedSeconds.toDouble() / limitSeconds.toDouble() * 100).toInt()
                checkAndNotifyMilestone(pkg, percentage, elapsedSeconds, limitSeconds)
            }
        }
    }

    private fun onForegroundAppChanged(packageName: String) {
        currentForegroundPkg = packageName
        Log.d("AppMonitorService", "📱 Foreground app: $packageName")

        // Show welcome notification first time
        if (appTimers.containsKey(packageName) && !shownWelcomeNotifications.contains(packageName)) {
            showMonitoringStartNotification(packageName)
            shownWelcomeNotifications.add(packageName)
        }

        // If app is blocked, show blocking screen ONCE (don't loop)
        if (blockedApps.contains(packageName)) {
            Log.d("AppMonitorService", "🚫 Blocked app opened: $packageName")

            // Check if BlockingActivity is already showing
            val am = getSystemService(Context.ACTIVITY_SERVICE) as android.app.ActivityManager
            val runningTasks = am.appTasks
            var blockingActivityShowing = false

            for (task in runningTasks) {
                val topActivity = task.taskInfo.topActivity
                if (topActivity?.className == "com.example.my_app.BlockingActivity") {
                    blockingActivityShowing = true
                    break
                }
            }

            // Only launch if not already showing
            if (!blockingActivityShowing) {
                launchBlockingActivity(packageName)
            }
        }
    }

    private fun checkAndNotifyMilestone(pkg: String, percentage: Int, elapsed: Int, limit: Int) {
        val flags = milestoneFlags.getOrPut(pkg) { mutableSetOf() }

        val milestones = listOf(30, 70)
        for (milestone in milestones) {
            if (percentage >= milestone && !flags.contains(milestone)) {
                flags.add(milestone)
                sendMilestoneNotification(pkg, milestone, elapsed, limit)
            }
        }
    }

    private fun showMonitoringStartNotification(packageName: String) {
        val appName = getAppName(packageName)
        val timerData = appTimers[packageName] ?: return
        val limitSeconds = timerData.second
        val limitText = formatSeconds(limitSeconds)

        val message = getDailyMotivation()

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("⏱️ $appName - Timer Active")
            .setContentText("Time limit: $limitText")
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("$message\n\nThis app will be blocked after $limitText from now."))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 300, 100, 300))
            .build()

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(packageName.hashCode(), notification)

        Log.d("AppMonitorService", "🔔 Welcome notification for $appName")
    }

    private fun sendMilestoneNotification(packageName: String, milestone: Int, elapsed: Int, limit: Int) {
        val appName = getAppName(packageName)
        val remainingSeconds = limit - elapsed
        val remainingText = formatSeconds(remainingSeconds)

        val message = when (milestone) {
            30 -> getDailyEyeExercise()
            70 -> getDailyPhysicalActivity()
            else -> getDailyMotivation()
        }

        val emoji = when (milestone) {
            30 -> "🟢"
            70 -> "🟡"
            else -> "📊"
        }

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_dialog_info)
            .setContentTitle("$emoji $appName - $milestone% Time Used")
            .setContentText("$remainingText remaining")
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("$message\n\n⏱️ Remaining: $remainingText"))
            .setPriority(NotificationCompat.PRIORITY_HIGH)
            .setAutoCancel(true)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .build()

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify((packageName.hashCode() + milestone), notification)

        Log.d("AppMonitorService", "🔔 $milestone% milestone for $appName")
    }

    private fun blockApp(packageName: String, limitSeconds: Int) {
        blockedApps.add(packageName)

        val appName = getAppName(packageName)
        val limitText = formatSeconds(limitSeconds)

        Log.d("AppMonitorService", "🚫 BLOCKING $appName (timer expired: $limitText)")

        // Send blocked notification
        val message = getDailyPhysicalActivity()
        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_delete)
            .setContentTitle("🚫 $appName - BLOCKED")
            .setContentText("Time limit reached!")
            .setStyle(NotificationCompat.BigTextStyle()
                .bigText("$message\n\n⏰ Time limit ($limitText) has expired."))
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setAutoCancel(false)
            .setOngoing(true)
            .setVibrate(longArrayOf(0, 1000, 500, 1000))
            .build()

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(packageName.hashCode() + 999, notification)

        // If user is currently using this app, show blocking screen
        if (packageName == currentForegroundPkg) {
            launchBlockingActivity(packageName)
        }

        saveState()
    }

// Update launchBlockingActivity method

// Replace launchBlockingActivity method

    private fun launchBlockingActivity(packageName: String) {
        try {
            Log.d("AppMonitorService", "🚀 Blocking: $packageName")

            // Strategy 1: Try overlay service first (most reliable)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.M) {
                if (Settings.canDrawOverlays(this)) {
                    Log.d("AppMonitorService", "✅ Using overlay service")
                    val overlayIntent = Intent(this, OverlayBlockingService::class.java).apply {
                        putExtra(OverlayBlockingService.EXTRA_PACKAGE, packageName)
                    }
                    startService(overlayIntent)
                    return
                } else {
                    Log.w("AppMonitorService", "⚠️ No overlay permission - fallback to activity")
                }
            }

            // Strategy 2: Standard activity launch
            val intent = Intent(this, BlockingActivity::class.java).apply {
                putExtra("packageName", packageName)
                addFlags(
                    Intent.FLAG_ACTIVITY_NEW_TASK or
                            Intent.FLAG_ACTIVITY_CLEAR_TOP or
                            Intent.FLAG_ACTIVITY_SINGLE_TOP
                )
            }
            startActivity(intent)

            // Strategy 3: Retry with different flags
            handler.postDelayed({
                if (blockedApps.contains(packageName) &&
                    !BlockingActivity.isShowing &&
                    !OverlayBlockingService.isOverlayShowing) {

                    Log.d("AppMonitorService", "🔁 Retry: Re-launching")
                    val retryIntent = Intent(this, BlockingActivity::class.java).apply {
                        putExtra("packageName", packageName)
                        addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_REORDER_TO_FRONT)
                    }
                    startActivity(retryIntent)
                }
            }, 500)

            // Strategy 4: Full screen notification (last resort)
            handler.postDelayed({
                if (blockedApps.contains(packageName) &&
                    !BlockingActivity.isShowing &&
                    !OverlayBlockingService.isOverlayShowing) {

                    Log.d("AppMonitorService", "🔁 Last resort: Full screen notification")
                    showFullScreenNotification(packageName)
                }
            }, 1500)

        } catch (e: Exception) {
            Log.e("AppMonitorService", "❌ Failed to block: ${e.message}", e)
        }
    }

    private fun showFullScreenNotification(packageName: String) {
        val appName = getAppName(packageName)

        val fullScreenIntent = Intent(this, BlockingActivity::class.java).apply {
            putExtra("packageName", packageName)
            addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP)
        }

        val fullScreenPendingIntent = android.app.PendingIntent.getActivity(
            this,
            packageName.hashCode() + 1000,
            fullScreenIntent,
            android.app.PendingIntent.FLAG_UPDATE_CURRENT or android.app.PendingIntent.FLAG_IMMUTABLE
        )

        val notification = NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_delete)
            .setContentTitle("🚫 $appName BLOCKED")
            .setContentText("Time limit reached - Tap to manage")
            .setPriority(NotificationCompat.PRIORITY_MAX)
            .setCategory(NotificationCompat.CATEGORY_ALARM)
            .setFullScreenIntent(fullScreenPendingIntent, true)
            .setAutoCancel(false)
            .setOngoing(true)
            .setVibrate(longArrayOf(0, 500, 200, 500))
            .build()

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.notify(packageName.hashCode() + 2000, notification)
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
            return null
        }
    }

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
        return when {
            h > 0 -> "${h}h ${m}m"
            m > 0 -> "${m}m"
            else -> "${seconds}s"
        }
    }

    private fun createPersistentNotification(): Notification {
        return NotificationCompat.Builder(this, CHANNEL_ID)
            .setSmallIcon(android.R.drawable.ic_menu_info_details)
            .setContentTitle("⏱️ Digital Wellbeing Active")
            .setContentText("${appTimers.size} app timers running")
            .setPriority(NotificationCompat.PRIORITY_LOW)
            .setOngoing(true)
            .build()
    }

    private fun createNotificationChannel() {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val channel = NotificationChannel(
                CHANNEL_ID,
                "App Timer Monitor",
                NotificationManager.IMPORTANCE_HIGH
            ).apply {
                description = "Countdown timers for app limits"
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

            // Save timers: [startTime, limit]
            val timersArray = JSONArray()
            appTimers.forEach { (pkg, timerData) ->
                timersArray.put(JSONObject().apply {
                    put("pkg", pkg)
                    put("startTime", timerData.first)
                    put("limit", timerData.second)
                })
            }
            editor.putString(KEY_APP_TIMERS, timersArray.toString())

            // Save blocked apps
            val blockedArray = JSONArray()
            blockedApps.forEach { blockedArray.put(it) }
            editor.putString(KEY_BLOCKED, blockedArray.toString())

            editor.apply()
        } catch (e: Exception) {
            Log.e("AppMonitorService", "Save error: ${e.message}")
        }
    }

    private fun restoreState() {
        try {
            val prefs = getSharedPreferences(PREFS_NAME, MODE_PRIVATE)

            // Restore timers
            prefs.getString(KEY_APP_TIMERS, null)?.let { json ->
                val array = JSONArray(json)
                for (i in 0 until array.length()) {
                    val obj = array.getJSONObject(i)
                    val pkg = obj.getString("pkg")
                    val startTime = obj.getLong("startTime")
                    val limit = obj.getInt("limit")
                    appTimers[pkg] = Pair(startTime, limit)
                }
            }

            // Restore blocked apps
            prefs.getString(KEY_BLOCKED, null)?.let { json ->
                val array = JSONArray(json)
                for (i in 0 until array.length()) {
                    blockedApps.add(array.getString(i))
                }
            }

            Log.d("AppMonitorService", "📂 State restored: ${appTimers.size} timers, ${blockedApps.size} blocked")
        } catch (e: Exception) {
            Log.e("AppMonitorService", "Restore error: ${e.message}")
        }
    }

    fun restartMonitoring(apps: List<Map<String, Any?>>) {
        appTimers.clear()
        blockedApps.clear()
        milestoneFlags.clear()
        shownWelcomeNotifications.clear()

        val currentTime = System.currentTimeMillis()

        for (app in apps) {
            val pkg = app["packageName"] as String
            val limit = (app["limitSeconds"] as? Number)?.toInt() ?: 0

            if (limit > 0) {
                // START TIMER NOW
                appTimers[pkg] = Pair(currentTime, limit)
                Log.d("AppMonitorService", "⏱️ TIMER STARTED: $pkg → ${formatSeconds(limit)} from NOW")
            }
        }

        saveState()
        Log.d("AppMonitorService", "🔄 ${appTimers.size} timers started")
    }

    fun unblockApp(packageName: String) {
        Log.d("AppMonitorService", "🔓 UNBLOCKING: $packageName")

        appTimers.remove(packageName)
        blockedApps.remove(packageName)
        milestoneFlags.remove(packageName)
        shownWelcomeNotifications.remove(packageName)

        val nm = getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
        nm.cancel(packageName.hashCode())
        nm.cancel(packageName.hashCode() + 30)
        nm.cancel(packageName.hashCode() + 70)
        nm.cancel(packageName.hashCode() + 999)

        saveState()
        Log.d("AppMonitorService", "✅ Unblocked and timer removed")
    }

    fun getBlockedApps(): List<String> = blockedApps.toList()

    fun getUsageSnapshot(): List<Map<String, Any>> {
        val currentTime = System.currentTimeMillis()

        return appTimers.map { (pkg, timerData) ->
            val (startTime, limit) = timerData
            val elapsedSeconds = ((currentTime - startTime) / 1000).toInt()

            mapOf(
                "packageName" to pkg,
                "usageSeconds" to elapsedSeconds,
                "limitSeconds" to limit,
                "blocked" to blockedApps.contains(pkg)
            )
        }
    }

    fun usageUpdate(packageName: String, usageSeconds: Int, limitSeconds: Int) {
        // Not needed in timer-based system
    }
}

object AppMonitorServiceHolder {
    var serviceInstance: AppMonitorService? = null
}