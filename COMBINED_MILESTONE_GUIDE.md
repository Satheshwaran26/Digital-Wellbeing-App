# Combined Milestone System Guide

## Overview

The app has been updated to track **all monitored apps together** with a **combined 1-minute time limit** instead of tracking each app individually.

## What Changed

### Before (Individual App Tracking)
- Each app had its own time limit
- Milestones were tracked per app (30%, 70%, 100% for each app)
- Each app could reach milestones independently

### After (Combined Tracking)
- **All selected apps share ONE combined time limit** (default: 60 seconds / 1 minute)
- Usage across ALL monitored apps is summed together
- Milestones are triggered based on total combined usage
- When you use any monitored app, it counts toward the shared limit

## Key Features

### 1. Combined Time Limit
- Default: **60 seconds (1 minute)** for ALL apps combined
- Can be changed using `AppUsageTracker.instance.setCombinedTimeLimit(seconds)`
- All monitored apps share this limit

### 2. Milestone Tracking (Kotlin-based)
- **30% milestone**: Green - "Apps Usage: 30%"
- **70% milestone**: Orange - "Warning: 70% Used!"
- **100% milestone**: Red - "Time Limit Reached!"

Milestones are tracked in native Kotlin code (`MainActivity.kt`) for better performance and persistence.

### 3. Real-time Combined Usage Display
- Shows total usage across all apps
- Displays which apps are being monitored
- Updates every 2 seconds

## How It Works

### Architecture

```
User uses App A (15s) + App B (20s) + App C (10s) = 45s / 60s (75%)
                           ↓
              Kotlin Milestone Tracker
                           ↓
              70% Milestone Reached!
                           ↓
          Show Achievement Screen
```

### Flow
1. User opens any monitored app (e.g., Instagram)
2. App usage is tracked in real-time (every 2 seconds)
3. Usage is added to the **combined total** across all apps
4. Kotlin native code checks if any milestone is reached
5. If new milestone is reached → Show full-screen achievement popup
6. Milestone is saved (won't show again until reset)

## Code Examples

### Setting Combined Time Limit
```dart
// Set 2 minutes for all apps combined
await AppUsageTracker.instance.setCombinedTimeLimit(120);

// Set 30 seconds for all apps combined
await AppUsageTracker.instance.setCombinedTimeLimit(30);
```

### Getting Total Usage
```dart
// Get total usage across all monitored apps
final totalUsage = await AppUsageTracker.instance.getTotalUsage();
print('Total usage: ${totalUsage}s');
```

### Checking Combined Milestone
```dart
final milestone = await AppUsageTracker.instance.checkCombinedMilestone();
print('Percentage: ${milestone['percentage']}%');
print('30% reached: ${milestone['milestone30']}');
print('70% reached: ${milestone['milestone70']}');
print('100% reached: ${milestone['milestone100']}');
```

### Getting Milestone Data for Display
```dart
final data = await AppUsageTracker.instance.getMilestoneData();
print('Apps: ${data['apps']}');
print('Total usage: ${data['totalUsage']}s');
print('Total limit: ${data['totalLimit']}s');
print('Percentage: ${data['percentage']}%');
```

## File Changes

### 1. `app_usage_tracker.dart`
- **Removed**: Per-app time limit tracking
- **Added**: Combined time limit for all apps
- **Added**: `setCombinedTimeLimit(int seconds)` - Set shared limit
- **Added**: `getCombinedTimeLimit()` - Get current limit
- **Added**: `getTotalUsage()` - Get total usage across all apps
- **Added**: `checkCombinedMilestone()` - Check combined milestone status
- **Added**: `getMilestoneData()` - Get milestone display data
- **Changed**: `onMilestoneReached` callback signature to reflect combined tracking

### 2. `MainActivity.kt` (Kotlin Native)
- **Added**: `combinedMilestones` - Track reached combined milestones
- **Added**: `checkCombinedMilestone` method channel handler
- **Added**: `checkAndUpdateCombinedMilestone()` - Combined milestone logic
- **Added**: `loadCombinedMilestones()` - Load saved milestones
- **Added**: `saveCombinedMilestones()` - Persist milestone state
- **Added**: `resetCombinedMilestones()` - Reset all milestones

### 3. `milestone_achievement_screen.dart`
- **Changed**: Now shows combined usage instead of individual app
- **Added**: Display total usage vs total limit
- **Added**: Show list of monitored apps
- **Removed**: Individual app icon/name (now shows combined stats)

### 4. `milestone_page.dart`
- **Changed**: Shows single combined milestone card instead of per-app cards
- **Added**: Display all monitored apps in one card
- **Added**: Show combined usage statistics
- **Added**: Better visual hierarchy for combined tracking

### 5. `main_navigation.dart`
- **Updated**: Milestone callback to use new combined signature
- **Changed**: Fetches app names for milestone display

## Testing

### Test Combined Milestone System
1. Add multiple apps to monitor (e.g., Instagram, YouTube, Chrome)
2. The combined limit is automatically set to 60 seconds
3. Use any monitored app for ~18 seconds → **30% milestone appears**
4. Continue using apps (total ~42 seconds) → **70% milestone appears**
5. Continue using apps (total ~60 seconds) → **100% milestone appears**

### Debug Logging
Look for these logs in Android Studio / Logcat:

```
✓ Usage updated for com.instagram.android: 5s -> 10s (+5s) | Total: 25s/60s
🏆 COMBINED 30% milestone reached! (18/60 seconds)
🏆 COMBINED 70% milestone reached! (42/60 seconds)
🏆 COMBINED 100% milestone reached! (60/60 seconds)
```

### Reset Milestones
```dart
// Call this method to reset milestones (e.g., daily reset)
await AppUsageTracker.instance._channel.invokeMethod('resetCombinedMilestones');
```

Or from Kotlin:
```kotlin
resetCombinedMilestones()
```

## Benefits

### 1. Simpler User Experience
- Users set ONE limit for all distracting apps
- Easier to understand and manage
- More realistic usage tracking

### 2. Better Digital Wellbeing
- Encourages overall reduction in app usage
- Prevents "app hopping" (switching between apps to avoid limits)
- More effective at promoting healthy habits

### 3. Performance
- Milestone tracking in native Kotlin (faster)
- Less storage needed (one milestone set vs. many)
- Efficient SharedPreferences usage

## Migration Notes

### For Existing Users
- Old per-app time limits are removed
- All apps now share the default 60-second limit
- Old individual milestones are preserved but not used
- Combined milestones start fresh

### Data Preservation
- App usage history is preserved
- Individual app usage times are still tracked
- Only the limit and milestone system changed

## Troubleshooting

### Milestones not appearing?
- Check if Usage Stats permission is granted
- Verify apps are being tracked (check debug logs)
- Ensure total usage is being calculated correctly

### Usage not updating?
- Apps must be in monitored list
- Usage Stats permission required
- Check Android logs for tracking errors

### How to change the limit?
```dart
// In your app code (e.g., settings page)
await AppUsageTracker.instance.setCombinedTimeLimit(120); // 2 minutes
```

## Future Enhancements

Possible improvements:
- Allow custom combined limits (user configurable)
- Daily/weekly combined limits
- Category-based combined limits (social media, games, etc.)
- Time-based limits (different limits for different times of day)

---

**Last Updated**: November 5, 2025
**Version**: 2.0 - Combined Milestone System

