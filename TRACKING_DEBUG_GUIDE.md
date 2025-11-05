# App Usage Tracking - Debug Guide

## How to Check if Tracking is Working

### Step 1: Enable Debug Panel
1. Open the app and go to the Home screen
2. Click the **bug icon** (🐛) in the top right corner
3. A debug panel will appear showing tracking status

### Step 2: Check Debug Information
The debug panel shows:
- **Number of apps being monitored**
- **Total usage time tracked** (in seconds)
- **Instructions about permissions**

### Step 3: Test Manual Tracking
If apps show `0s` usage:
1. Make sure the debug panel is visible (bug icon is filled)
2. Next to each app showing `0s`, you'll see a **"Test +30s"** button
3. Click this button to manually add 30 seconds to that app
4. The usage time should immediately update
5. The pie chart should also update

**If this works**: The tracking system is functioning correctly, but automatic tracking might not be working due to permissions.

**If this doesn't work**: There may be an issue with data storage.

## Step 4: Grant Android Permissions (Required for Automatic Tracking)

For automatic tracking to work, you MUST grant Usage Stats permission:

1. Go to **Android Settings**
2. Navigate to **Apps** → **Special access** → **Usage access**
3. Find your **Digital Wellbeing** app
4. Enable **"Permit usage access"**

Without this permission, automatic foreground app detection will NOT work.

## Step 5: Verify Automatic Tracking

1. Grant the permission (Step 4)
2. Close the Digital Wellbeing app completely
3. Open one of the monitored apps (e.g., Instagram, YouTube)
4. Use it for 1-2 minutes
5. Return to the Digital Wellbeing app
6. Check if the usage time increased

## Refresh Data

- Click the **refresh icon** (🔄) in the top right to manually refresh the data
- Data automatically refreshes every 3 seconds

## Checking Debug Logs

To see detailed tracking logs:

1. Connect your phone to your computer
2. Run: `adb logcat | grep -E "MainActivity|AppUsageTracker"`
3. Look for messages like:
   - `Foreground app detected: com.instagram.android`
   - `Tracking new app: com.instagram.android`
   - `✓ Usage updated for com.instagram.android: 0s -> 2s (+2s)`

## Common Issues

### Issue: Apps show 0s even after using them
**Solution**: Grant Usage Stats permission (see Step 4)

### Issue: "No foreground app detected" in logs
**Solution**: 
1. Ensure Usage Stats permission is granted
2. Some Android versions/manufacturers may restrict this feature
3. Try using the manual test button to verify the system works

### Issue: Test button adds time but automatic tracking doesn't work
**Solution**: This confirms storage works but permission is missing. Grant Usage Stats permission.

### Issue: Total shows 0s in the pie chart center
**Solution**: This is expected if no usage has been tracked yet. Use the test buttons or use monitored apps.

## How Tracking Works

1. **Every 2 seconds**, the app checks which app is in the foreground
2. If it's a monitored app, it accumulates usage time
3. Usage is saved to persistent storage every 2 seconds
4. The home screen refreshes automatically every 3 seconds
5. When you switch apps, the accumulated time is saved immediately

## Need More Help?

Check the debug panel for real-time status and use the test buttons to verify the system is working correctly.

