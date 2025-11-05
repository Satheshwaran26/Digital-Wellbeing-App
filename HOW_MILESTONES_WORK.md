# 🏆 How Milestone System Works - Complete Guide

## ⚡ Quick Action: "Set 1 Minute Total"

### What It Means:
- **1 minute TOTAL** is divided equally among **ALL** selected apps
- **NOT** 1 minute per app - it's shared!

### Example:
```
If you select 5 apps and click "Set 1 Minute Total":
- Total time: 60 seconds
- Each app gets: 60 ÷ 5 = 12 seconds

App 1 (Instagram):  12 seconds limit
App 2 (YouTube):    12 seconds limit  
App 3 (Facebook):   12 seconds limit
App 4 (Twitter):    12 seconds limit
App 5 (TikTok):     12 seconds limit
```

### Milestone Timing:
```
For each app with 12-second limit:
- 30% = 3.6 seconds  (4 seconds)
- 70% = 8.4 seconds  (8 seconds)
- 100% = 12 seconds  (12 seconds)
```

---

## 🎯 Complete Flow

### Step 1: Setup
1. Go to **Manage Apps**
2. Select **5 apps** (for example)
3. Click **"Start Monitoring"**
4. On Set Timer page, click **"⚡ Set 1 Minute Total"**
5. System calculates: `60 seconds ÷ 5 apps = 12 seconds each`

### Step 2: Automatic Tracking
1. **Grant Permission**: Usage Stats permission must be enabled
2. **Background Tracking**: App tracks usage every 2 seconds
3. **Milestone Checking**: Every usage update checks for new milestones

### Step 3: Using Apps
```
User opens Instagram (12s limit):
0s  → Tracking starts
4s  → 30% reached → 🟢 Full-screen "30% MILESTONE!" pops up
8s  → 70% reached → 🟠 Full-screen "70% WARNING!" pops up
12s → 100% reached → 🔴 Full-screen "100% LIMIT!" pops up
```

### Step 4: Milestone Storage (Kotlin)
- Milestones saved in **SharedPreferences**
- Key: `milestone_<packageName>`
- Value: "30,70,100" (comma-separated)
- **Persistent** across app restarts
- **One-time trigger** - won't show again

---

## 📱 Two Ways to View Milestones

### 1. Full-Screen Popup (Automatic)
**When:** Milestone reached while using monitored app
**How:** Appears automatically over any screen
**Display:** 4 seconds (or tap to dismiss)
**Trigger:** Once per milestone per app

**Flow:**
```
You're using Instagram
    ↓
Usage tracker updates (every 2s)
    ↓
Kotlin checks: percentage >= 30%?
    ↓
New milestone detected!
    ↓
Callback triggers in Flutter
    ↓
Navigator shows MilestoneAchievementScreen
    ↓
Full-screen celebration appears!
```

### 2. Milestone Page (Manual)
**When:** You click 🏆 trophy icon on Home screen
**How:** Shows all apps with time limits
**Display:** List of achievement cards
**Shows:** Current progress + unlocked badges

**What You See:**
```
🏆 Milestones

┌─────────────────────────────────┐
│ [Icon] Instagram                │
│        75.0% of limit used      │
│ ████████████████░░░░            │
│                                 │
│  🟢30%    🟠70%    ⚪100%       │
│ Achieved Achieved  Locked       │
└─────────────────────────────────┘

┌─────────────────────────────────┐
│ [Icon] YouTube                  │
│        25.0% of limit used      │
│ ████░░░░░░░░░░░░                │
│                                 │
│  ⚪30%    ⚪70%    ⚪100%        │
│ Locked   Locked   Locked        │
└─────────────────────────────────┘
```

---

## 🔧 Technical Architecture

### 1. Kotlin Layer (MainActivity.kt)
```kotlin
private fun checkAndUpdateMilestone(
    packageName: String,
    currentUsage: Int, 
    totalLimit: Int
): Map<String, Any> {
    val percentage = (currentUsage / totalLimit) * 100.0
    val appMilestones = reachedMilestones.getOrPut(packageName) { mutableSetOf() }
    
    var newMilestoneReached = false
    var newMilestoneValue = 0
    
    // Check 30%
    if (percentage >= 30.0 && !appMilestones.contains(30)) {
        appMilestones.add(30)
        newMilestoneReached = true
        newMilestoneValue = 30
        saveMilestones(packageName, appMilestones)
    }
    
    // Check 70%, 100% similarly...
    
    return mapOf(
        "percentage" to percentage,
        "milestone30" to appMilestones.contains(30),
        "milestone70" to appMilestones.contains(70),
        "milestone100" to appMilestones.contains(100),
        "newMilestoneReached" to newMilestoneReached,
        "milestoneValue" to newMilestoneValue
    )
}
```

### 2. Flutter Layer (app_usage_tracker.dart)
```dart
Future<void> updateUsage(String packageName, int secondsToAdd) async {
  // Update usage time
  apps[appIndex] = app.copyWith(
    totalUsageSeconds: newTotal,
    lastUpdated: DateTime.now(),
  );
  await _saveMonitoredApps(apps);
  
  // Check milestones if app has time limit
  if (app.timeLimit > 0) {
    _checkMilestoneAndNotify(
      app.packageName, 
      app.appName, 
      app.iconData, 
      newTotal, 
      app.timeLimit
    );
  }
}

Future<void> _checkMilestoneAndNotify(...) async {
  final result = await _channel.invokeMethod('checkMilestone', {
    'packageName': packageName,
    'currentUsage': currentUsage,
    'totalLimit': timeLimit,
  });
  
  if (result['newMilestoneReached'] == true) {
    // Trigger callback
    if (onMilestoneReached != null) {
      onMilestoneReached!(packageName, appName, iconData, milestoneValue, percentage);
    }
  }
}
```

### 3. UI Layer (main_navigation.dart)
```dart
void _setupMilestoneCallback() {
  AppUsageTracker.instance.onMilestoneReached = (
    packageName, appName, iconData, milestoneValue, percentage
  ) {
    // Show full-screen achievement
    Navigator.of(context).push(
      PageRouteBuilder(
        opaque: false,
        pageBuilder: (context, animation, secondaryAnimation) {
          return MilestoneAchievementScreen(
            appName: appName,
            appIcon: iconData,
            milestoneValue: milestoneValue,
            percentage: percentage,
          );
        },
      ),
    );
  };
}
```

---

## 🧪 Testing Guide

### Test 1: Quick Manual Test
1. Click **bug icon** 🐛 on Home screen
2. Find an app with time limit
3. Click **"Test +30s"** multiple times
4. Watch milestones pop up:
   - First click (if limit is 60s): 50% - no popup (not a milestone)
   - Keep clicking until you hit 30%, 70%, or 100%

### Test 2: Real Usage Test
1. **Select 5 apps**
2. Click **"Set 1 Minute Total"** (each gets 12s)
3. **Grant Usage Stats permission**
4. **Use one app for 5 seconds**
5. Return to Digital Wellbeing
6. **🟢 30% popup should appear!** (4s ≈ 30% of 12s)

### Test 3: View All Milestones
1. Click **🏆 trophy icon** on Home
2. See all apps with limits
3. Progress bars show current usage
4. Badges show unlocked milestones

---

## 🎨 Color System

### Green (30%) - #2E7D32
- **Meaning**: Getting started, safe zone
- **Icon**: Trophy 🏆
- **Message**: "Getting Started!"
- **Action**: Informational

### Orange (70%) - #F57C00
- **Meaning**: Warning, approaching limit
- **Icon**: Warning ⚠️
- **Message**: "Warning Zone!"
- **Action**: Be careful

### Red (100%) - #CC3333
- **Meaning**: Limit reached/exceeded
- **Icon**: Block 🚫
- **Message**: "Limit Reached!"
- **Action**: Stop using

---

## 📊 Data Flow Diagram

```
┌─────────────────────────────────────────────┐
│          User Uses Monitored App            │
└──────────────────┬──────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────┐
│   Foreground App Checker (every 2s)         │
│   - getForegroundApp() via Kotlin           │
└──────────────────┬──────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────┐
│   Usage Tracker Updates                     │
│   - updateUsage(packageName, seconds)       │
└──────────────────┬──────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────┐
│   Check if App Has Time Limit               │
│   - if (app.timeLimit > 0)                  │
└──────────────────┬──────────────────────────┘
                   │ Yes
                   ↓
┌─────────────────────────────────────────────┐
│   Kotlin Milestone Checker                  │
│   - checkAndUpdateMilestone()               │
│   - Calculates percentage                   │
│   - Checks 30%, 70%, 100%                   │
│   - Saves to SharedPreferences              │
└──────────────────┬──────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────┐
│   New Milestone Detected?                   │
└──────────────────┬──────────────────────────┘
                   │ Yes
                   ↓
┌─────────────────────────────────────────────┐
│   Trigger Callback                          │
│   - onMilestoneReached(...)                 │
└──────────────────┬──────────────────────────┘
                   │
                   ↓
┌─────────────────────────────────────────────┐
│   Show Full-Screen Achievement              │
│   - Navigator.push()                        │
│   - MilestoneAchievementScreen              │
│   - Auto-dismiss after 4s                   │
└─────────────────────────────────────────────┘
```

---

## ⚙️ Configuration

### Time Limits
- Set via `timeLimit` field in `MonitoredApp`
- Stored in seconds
- 0 = no limit (won't show in milestones)

### Milestone Thresholds
- **30%** - First warning
- **70%** - Second warning  
- **100%** - Limit exceeded

### Auto-Dismiss Timing
- **4 seconds** - Achievement screen duration
- Configurable in `milestone_achievement_screen.dart` line 63

### Tracking Interval
- **2 seconds** - Usage update frequency
- Configurable in `app_usage_tracker.dart` line 270

---

## 🚀 Summary

**Quick Action Changed:**
- ✅ "Set 1 Minute Total" now means 60s ÷ number of apps
- ✅ Example: 5 apps = 12 seconds each

**Milestone System:**
- ✅ Tracked in Kotlin (MainActivity.kt)
- ✅ Stored in SharedPreferences (persistent)
- ✅ Triggers full-screen popup when reached
- ✅ Shows on Milestone Page (🏆 icon)
- ✅ Three levels: 30%, 70%, 100%
- ✅ Color-coded: Green, Orange, Red

**How to Use:**
1. Select apps
2. Click "Set 1 Minute Total"
3. Grant Usage Stats permission
4. Use the apps
5. Watch milestone popups appear!
6. View all achievements via 🏆 icon

**Your milestone system is ready!** 🎉

