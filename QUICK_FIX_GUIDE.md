# ⚠️ QUICK FIX: Enable App Tracking

## Why Apps Show 0 Seconds

Your app shows **0s** for all apps because **Usage Stats permission is NOT granted**. This permission is REQUIRED for automatic tracking to work.

---

## ✅ SOLUTION (3 Simple Steps)

### Step 1: Run the App
1. Build and run your app on your phone
2. Go to the **Home** screen

### Step 2: You'll See a RED Warning Box
The app will automatically detect that permission is missing and show a **RED warning banner** at the top that says:

```
⚠ Permission Required
Automatic app tracking requires Usage Stats permission.
Without it, tracking will NOT work.

[Open Settings & Grant Permission]
```

### Step 3: Click the Button & Grant Permission
1. Click the **"Open Settings & Grant Permission"** button
2. Android Settings will open to the **Usage access** page
3. Find your **Digital Wellbeing** app in the list
4. **Toggle it ON** to enable "Permit usage access"
5. Go back to your app

**That's it!** The app will automatically detect the permission is granted and start tracking.

---

## 🧪 Test if It's Working

### Option 1: Use Test Buttons (Immediate)
1. Click the **bug icon** (🐛) in the top right of Home screen
2. Next to each app showing **0s**, you'll see a **"Test +30s"** button
3. Click it - if the time updates to **30s**, the system works!
4. This proves tracking works, you just need the permission for automatic tracking

### Option 2: Real Usage Test (Takes 2 minutes)
1. Grant the permission (see Step 3 above)
2. **Close** the Digital Wellbeing app completely
3. Open a monitored app (e.g., Instagram, YouTube, etc.)
4. Use it for **1-2 minutes**
5. Go back to Digital Wellbeing
6. Check if the usage time increased

If it did, **tracking is working!** 🎉

---

## 📊 What You Should See

### Without Permission:
```
Home Screen:
┌─────────────────────────────────────┐
│ ⚠ Permission Required               │ <- RED WARNING BOX
│ Automatic app tracking requires...  │
│ [Open Settings & Grant Permission]  │
└─────────────────────────────────────┘

App List:
Instagram     0s  <- NOT TRACKING ❌
YouTube       0s
```

### After Granting Permission:
```
Home Screen:
┌─────────────────────────────────────┐
│         2h 35m                      │ <- Shows actual usage!
│    Total Usage Today                │
└─────────────────────────────────────┘

App List:
Instagram     1h 25m  <- TRACKING! ✅
YouTube       58m
Facebook      12m
```

---

## 🔍 Check Permission Status

The app shows permission status in two places:

1. **Red warning banner** appears if permission is NOT granted
2. **Debug panel** (click bug icon 🐛) shows:
   ```
   ✓ Permission granted  ← Good!
   or
   ⚠ Permission needed   ← Need to grant it
   ```

---

## 🚨 Important Notes

- **Without this permission, tracking will NEVER work**
- The permission is safe - it just lets the app see which app is currently open
- Android Settings → Apps → Special access → Usage access
- You only need to grant it once

---

## Still Not Working?

If you granted permission but tracking still doesn't work:

1. **Restart the app completely** (close and reopen)
2. Use the **Test +30s** buttons to verify the system works
3. Check the debug panel (bug icon 🐛) to see permission status
4. Try opening the monitored app for at least 1-2 minutes
5. Check debug logs in Android Studio logcat for error messages

---

## Summary

**The tracking WILL NOT WORK until you grant Usage Stats permission.**

The app now has a big red button that opens the settings for you. Just click it and enable the permission!

