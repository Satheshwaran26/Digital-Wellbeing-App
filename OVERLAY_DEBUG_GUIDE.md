# Overlay Not Showing - Debug Guide

## Quick Test (NEW!)

### Step 1: Enable Debug Mode
1. Open Digital Wellbeing app
2. Tap **bug icon** (🐛) in top-right corner
3. Debug panel appears

### Step 2: Test Overlay Display
1. With debug enabled, you'll see an orange **eye icon** (👁️)
2. Tap the **orange eye icon**
3. **Overlay should appear for 5 seconds** ✅
4. If it shows → Overlay permission works!
5. If NOT → Permission issue (see below)

## Systematic Debugging

### Issue 1: Overlay Permission

**Check if permission is granted:**

```bash
adb shell dumpsys window | grep "mCurrentFocus"
```

**Grant overlay permission manually:**
1. Settings → Apps → Digital Wellbeing
2. "Display over other apps" → **Allow** ✅
3. Return to app and test again

**Verify permission in logs:**
```bash
adb logcat | grep "overlay"
```

Should see: "Overlay permission granted: true"

### Issue 2: Service Not Running

**Check if service is running:**
```bash
adb shell dumpsys activity services | grep AppMonitorService
```

Should see: "AppMonitorService" with "app=ProcessRecord"

**If NOT running:**
1. Tap green eye icon to stop
2. Tap again to start
3. Check logs:
```bash
adb logcat | grep "AppMonitorService"
```

Should see: "✅ Monitoring service started"

### Issue 3: Foreground App Not Detected

**Check if app detection works:**
```bash
adb logcat -s AppMonitorService
```

While using Instagram, should see:
```
Current app: com.instagram.android, Our app: com.example.my_app
Detected foreground: com.instagram.android
```

**If NOT detecting:**
1. Grant Usage Stats permission
2. Settings → Apps → Digital Wellbeing
3. Usage access → Allow ✅

**Test detection:**
```bash
adb shell dumpsys usagestats
```

Should show recent app usage.

### Issue 4: Milestone Not Reached

**Check current usage:**
```bash
adb logcat | grep "Total:"
```

Should see: "Total: 25s/60s" (or similar)

**Manually add usage for testing:**
1. Enable debug panel (bug icon)
2. Find monitored app
3. Tap "Test +30s" button multiple times
4. Usage should increase

### Issue 5: Overlay Creation Failed

**Check overlay creation logs:**
```bash
adb logcat | grep "Creating overlay"
```

Should see:
```
Creating overlay view...
Creating overlay with type: 2038, flags: 16777472
✅ Overlay added to window manager for 30% milestone
```

**If ERROR:**
```
Failed to add overlay to window: ...
```

This means window manager rejected the overlay.

**Solutions:**
1. Restart app completely (not hot reload)
2. Clear app data: Settings → Apps → Digital Wellbeing → Clear data
3. Reinstall app

### Issue 6: Android Version Issues

**Check Android version:**
```bash
adb shell getprop ro.build.version.sdk
```

- **28+** (Android 9+): Use TYPE_APPLICATION_OVERLAY ✅
- **23-27** (Android 6-8): Use TYPE_SYSTEM_ALERT
- **Below 23**: May not support overlay

**Manufacturer restrictions:**
- **Xiaomi (MIUI)**: Settings → Additional settings → Privacy → Display over other apps
- **Huawei (EMUI)**: Settings → Apps → Special access → Display over other apps
- **Samsung (OneUI)**: Usually works fine
- **OnePlus (OxygenOS)**: Settings → Apps → Special access

## Complete Testing Procedure

### Step 1: Basic Setup
```bash
# 1. Enable debug mode
# Tap bug icon in app

# 2. Test overlay permission
# Tap orange eye icon → Should show overlay for 5s

# 3. Check logs
adb logcat -c  # Clear logs
adb logcat | grep -E "AppMonitorService|MainActivity|overlay"
```

### Step 2: Test Service
```bash
# 1. Start monitoring service
# Tap green eye icon

# 2. Verify service running
adb shell dumpsys activity services | grep AppMonitorService

# Expected: Service info with "app=ProcessRecord"
```

### Step 3: Test Detection
```bash
# 1. Open Instagram (or monitored app)

# 2. Watch logs in real-time
adb logcat -s AppMonitorService

# Expected output:
# Current app: com.instagram.android
# Detected foreground: com.instagram.android
```

### Step 4: Test Milestone
```bash
# 1. Use monitored app for 18+ seconds

# 2. Watch for overlay attempt
adb logcat | grep "Attempting to show overlay"

# Expected:
# Attempting to show overlay...
# Creating overlay view...
# ✅ Overlay added to window manager for 30% milestone
```

### Step 5: Visual Verification
1. Use Instagram for 18 seconds
2. **Overlay should appear IMMEDIATELY**
3. Full-screen, black background
4. Shows "30%" in gold
5. Has close button (✕)

## Common Issues & Solutions

### "Overlay permission not granted"
**Solution:**
1. Settings → Apps → Digital Wellbeing
2. "Display over other apps" → Enable
3. Restart app

### "Service not running"
**Solution:**
1. Tap eye icon to toggle OFF
2. Tap again to toggle ON (green)
3. Should see "Overlay monitoring ON" message

### "No foreground app detected"
**Solution:**
1. Settings → Apps → Digital Wellbeing
2. Usage access → Enable
3. Restart app

### "Overlay shows for 1 second then disappears"
**Solution:**
This is expected if you dismissed it!
- Overlay only shows once per milestone
- Close and reopen monitored app
- Or reach next milestone (70%, 100%)

### "Overlay only shows in Recent Apps screen"
**Solution (APPLIED IN LATEST FIX):**
- Updated window flags to FLAG_FULLSCREEN
- Changed to FLAG_NOT_FOCUSABLE
- Added FLAG_SHOW_WHEN_LOCKED
- Should now show over active app

### "Nothing happens at all"
**Solution:**
1. Check ALL three permissions:
   - Overlay permission ✅
   - Usage Stats permission ✅
   - Notification permission ✅
2. Restart app completely
3. Clear app data
4. Reinstall if needed

## Expected Behavior

### When Working Correctly:

**User opens Instagram:**
```
[2s] Service detects: com.instagram.android
[4s] Service detects: com.instagram.android
[6s] Service detects: com.instagram.android
...
[18s] Usage reaches 30%
[18s] shouldShowOverlay() returns true
[18s] Creating overlay view...
[18s] ✅ Overlay appears OVER Instagram
```

**User is using Instagram:**
- Overlay shows full-screen
- Can see "30%" in gold
- Can see close button
- Background is semi-transparent black

**User taps close (✕):**
- Overlay disappears
- Won't show again until 70% or 100%

**User continues using:**
```
[42s] Usage reaches 70%
[42s] ✅ Overlay appears again (NEW milestone)
[60s] Usage reaches 100%
[60s] ✅ Overlay appears again (FINAL milestone)
```

## Logs to Collect for Support

If still not working, collect these logs:

```bash
# 1. Full service logs
adb logcat -s AppMonitorService > service_logs.txt

# 2. MainActivity logs
adb logcat -s MainActivity > main_logs.txt

# 3. Window manager logs
adb shell dumpsys window > window_dump.txt

# 4. Permissions
adb shell dumpsys package com.example.my_app | grep permission

# 5. Service status
adb shell dumpsys activity services > services.txt
```

## Quick Fixes Summary

1. **Permission issue** → Grant "Display over other apps"
2. **Service not running** → Toggle eye icon OFF then ON
3. **Detection issue** → Grant "Usage access" permission
4. **No milestone** → Use app for 18+ seconds
5. **Overlay dismissed** → Reach next milestone (70%, 100%)
6. **Still not working** → Restart app completely

## Test with Controlled Environment

### Manual Test (Recommended):

1. **Set short limit for testing:**
   ```dart
   // In set_timer_page.dart, line 49
   await AppUsageTracker.instance.setCombinedTimeLimit(30); // 30 seconds
   ```

2. **Add apps and start service:**
   - Add Instagram
   - Toggle overlay ON (green eye)

3. **Use Instagram for 9 seconds:**
   - Should see 30% overlay ✅

4. **Continue to 21 seconds:**
   - Should see 70% overlay ✅

5. **Continue to 30 seconds:**
   - Should see 100% overlay ✅

### Automated Test:

```bash
# Use test button (when debug enabled)
# 1. Enable debug (bug icon)
# 2. Tap orange eye icon
# 3. Overlay shows for 5 seconds
# 4. If this works, permission is OK!
```

---

**Last Updated**: November 5, 2025  
**Status**: Active Debugging  
**Support**: Check logs first, then try quick fixes

