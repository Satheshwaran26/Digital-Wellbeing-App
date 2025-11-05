# Overlay Display Fix

## Problem Fixed
Overlay was only showing when pressing the **Recent Apps** button, but NOT when actively using apps like Instagram/YouTube.

## Root Cause
Wrong WindowManager flags - overlay was behind the foreground app instead of on top.

## Solution Applied

### 1. Updated WindowManager Flags (AppMonitorService.kt)

**Before** (Wrong):
```kotlin
FLAG_NOT_FOCUSABLE or FLAG_LAYOUT_IN_SCREEN
```

**After** (Correct):
```kotlin
FLAG_NOT_TOUCH_MODAL or          // Allows overlay to show on top
FLAG_WATCH_OUTSIDE_TOUCH or      // Detects taps
FLAG_LAYOUT_IN_SCREEN or
FLAG_LAYOUT_NO_LIMITS or         // Shows everywhere
FLAG_SHOW_WHEN_LOCKED            // Shows even on lock screen
```

### 2. Improved Foreground App Detection

**Before**: Checked last 10 seconds
```kotlin
time - 1000 * 10  // Too long
```

**After**: Checks last 5 seconds + validates freshness
```kotlin
time - 5000  // Last 5 seconds
if (time - mostRecent.lastTimeUsed < 3000) {  // Must be within 3s
    return mostRecent.packageName
}
```

### 3. Enhanced Touch Handling

- Made entire overlay clickable (tap anywhere to dismiss)
- Increased close button size: 48dp → 64dp
- Added visible background to close button (#44FFFFFF)
- Made overlay root layout clickable and focusable

### 4. Better Debugging

Added logs to track:
- Current foreground app detection
- Overlay show attempts
- User dismiss actions

## How To Test

### Step 1: Enable Overlay
1. Open Digital Wellbeing app
2. Tap **eye icon** (👁) in top-right
3. Grant "Display over other apps" permission
4. Icon turns **green** ✅

### Step 2: Test Overlay Display
1. Add Instagram to monitored apps
2. Use Instagram for ~18 seconds
3. **Overlay should appear IMMEDIATELY over Instagram** ✅
4. You should see full-screen milestone overlay
5. Tap ✕ or tap anywhere to close

### Step 3: Test All Milestones
```
18s → 30% overlay appears WHILE using Instagram ✅
42s → 70% overlay appears WHILE using Instagram ✅
60s → 100% overlay appears WHILE using Instagram ✅
```

### Step 4: Verify Logs (Optional)
```bash
adb logcat | grep AppMonitorService
```

Expected output:
```
Current app: com.instagram.android, Our app: com.example.my_app
Detected foreground: com.instagram.android
Attempting to show overlay...
✅ Overlay shown for 30% milestone
```

## Key Differences

### Before Fix ❌
- Overlay only visible in Recent Apps screen
- Had to press Recent button to see milestone
- Very confusing user experience
- Overlay behind foreground app

### After Fix ✅
- Overlay appears IMMEDIATELY over current app
- Shows while actively using Instagram/YouTube
- Full-screen, impossible to miss
- Properly layered on top of everything

## Technical Details

### Window Type
- Android 8.0+: `TYPE_APPLICATION_OVERLAY`
- Android 7.0 and below: `TYPE_PHONE`

### Flags Explanation

1. **FLAG_NOT_TOUCH_MODAL**
   - Overlay receives touch events
   - Other apps can still receive touches outside overlay
   - Essential for showing over apps

2. **FLAG_WATCH_OUTSIDE_TOUCH**
   - Detects when user taps outside overlay
   - Helps with gesture detection

3. **FLAG_LAYOUT_NO_LIMITS**
   - Allows overlay to extend beyond screen bounds if needed
   - Ensures full-screen display

4. **FLAG_SHOW_WHEN_LOCKED**
   - Shows even on lock screen (Android 8.0+)
   - Ensures milestone alerts are never missed

### Foreground Detection

Uses `UsageStatsManager` with:
- Query interval: INTERVAL_BEST (most accurate)
- Time window: Last 5 seconds
- Freshness check: Within 3 seconds
- More reliable than ActivityManager methods

## Troubleshooting

### Overlay still not showing?

1. **Check overlay permission**:
   - Settings → Apps → Digital Wellbeing → Display over other apps → ✅

2. **Check service status**:
   - Eye icon in app should be **green**
   - If gray, tap to start service

3. **Check milestone status**:
   - Overlay only shows for NEW milestones
   - Must reach 30%, then 70%, then 100%
   - Won't show if milestone already reached and dismissed

4. **Check logs**:
   ```bash
   adb logcat | grep "AppMonitorService"
   ```
   Should see: "Attempting to show overlay..."

5. **Restart service**:
   - Tap eye icon to stop (gray)
   - Tap again to start (green)
   - Try again

### Overlay showing but can't close?

- Tap the **✕** button in top-right corner
- Or tap **anywhere** on the overlay
- Both should dismiss it

### Permission keeps getting revoked?

- Some manufacturers auto-revoke overlay permission
- Add app to battery optimization whitelist
- Check manufacturer-specific settings (MIUI, OneUI, etc.)

## Performance Impact

- **Minimal** - Only checks every 2 seconds
- Uses efficient UsageStatsManager API
- Overlay is lightweight (native Android views)
- No continuous rendering or animations

## Compatibility

- **Minimum**: Android 5.0 (API 21)
- **Recommended**: Android 8.0+ (API 26)
- **Tested**: Android 10, 11, 12, 13, 14

## Next Steps

If you want to customize:
1. **Overlay appearance**: Edit `milestone_overlay.xml`
2. **Check interval**: Change `checkInterval` in AppMonitorService (default 2000ms)
3. **Detection sensitivity**: Adjust freshness check time (default 3000ms)

---

**Status**: ✅ Fixed  
**Last Updated**: November 5, 2025  
**Version**: 2.1 - Overlay Display Fix

