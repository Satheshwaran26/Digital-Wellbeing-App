import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';

class WeeklyStorageService {
  static const String _weeklyDataKey = 'weekly_app_usage_data';
  static const String _weekStartKey = 'current_week_start';
  static const String _lastSavedUsageKey = 'last_saved_usage';

  // Save daily usage to weekly data (accumulate properly)
  static Future<void> saveDailyUsage(Map<String, int> currentUsage) async {
    final prefs = await SharedPreferences.getInstance();

    // Get current week start
    final weekStart = _getCurrentWeekStart();
    final storedWeekStart = prefs.getString(_weekStartKey);

    // Check if we need to reset (new week started)
    if (storedWeekStart != null && storedWeekStart != weekStart) {
      // New week - clear old data
      await prefs.remove(_weeklyDataKey);
      await prefs.remove(_lastSavedUsageKey);
      await prefs.setString(_weekStartKey, weekStart);
      debugPrint('🔄 New week started - cleared old data');
    } else if (storedWeekStart == null) {
      // First time - set week start
      await prefs.setString(_weekStartKey, weekStart);
      debugPrint('📅 First time setup - week starts: $weekStart');
    }

    // Get last saved usage to calculate delta
    final lastSavedUsageString = prefs.getString(_lastSavedUsageKey);
    Map<String, int> lastSavedUsage = {};

    if (lastSavedUsageString != null) {
      try {
        final decoded = jsonDecode(lastSavedUsageString) as Map<String, dynamic>;
        lastSavedUsage = decoded.map((key, value) => MapEntry(key, value as int));
      } catch (e) {
        debugPrint('Error decoding last saved usage: $e');
      }
    }

    // Get existing weekly data
    final existingData = await getWeeklyData();

    // Calculate delta and add to weekly totals
    for (var entry in currentUsage.entries) {
      final packageName = entry.key;
      final currentSeconds = entry.value;
      final lastSeconds = lastSavedUsage[packageName] ?? 0;

      // Calculate the delta (new usage since last save)
      // Handle reset case: if current < last, it means the day reset
      int deltaSeconds;
      if (currentSeconds >= lastSeconds) {
        deltaSeconds = currentSeconds - lastSeconds;
      } else {
        // Day was reset, count full current usage
        deltaSeconds = currentSeconds;
      }

      if (deltaSeconds > 0) {
        if (existingData.containsKey(packageName)) {
          existingData[packageName]!['totalSeconds'] =
              (existingData[packageName]!['totalSeconds'] as int) + deltaSeconds;
          existingData[packageName]!['lastUpdated'] = DateTime.now().toIso8601String();
        } else {
          existingData[packageName] = {
            'totalSeconds': deltaSeconds,
            'lastUpdated': DateTime.now().toIso8601String(),
          };
        }

        debugPrint('📊 $packageName: +${deltaSeconds}s (total: ${existingData[packageName]!['totalSeconds']}s)');
      }
    }

    // Save updated data
    await prefs.setString(_weeklyDataKey, jsonEncode(existingData));

    // Save current usage as last saved
    await prefs.setString(_lastSavedUsageKey, jsonEncode(currentUsage));

    debugPrint('✅ Weekly data saved - ${existingData.length} apps tracked');
  }

  // Get weekly data
  static Future<Map<String, dynamic>> getWeeklyData() async {
    final prefs = await SharedPreferences.getInstance();
    final dataString = prefs.getString(_weeklyDataKey);

    if (dataString == null) return {};

    try {
      return Map<String, dynamic>.from(jsonDecode(dataString));
    } catch (e) {
      debugPrint('Error decoding weekly data: $e');
      return {};
    }
  }

  // Get current week start date (Monday)
  static String _getCurrentWeekStart() {
    final now = DateTime.now();
    final weekday = now.weekday; // Monday = 1, Sunday = 7
    final monday = now.subtract(Duration(days: weekday - 1));
    return DateTime(monday.year, monday.month, monday.day).toIso8601String();
  }

  // Check if current data is from this week
  static Future<bool> isCurrentWeek() async {
    final prefs = await SharedPreferences.getInstance();
    final storedWeekStart = prefs.getString(_weekStartKey);
    final currentWeekStart = _getCurrentWeekStart();

    return storedWeekStart == currentWeekStart;
  }

  // Manually clear old data (can be called on app start)
  static Future<void> clearIfNewWeek() async {
    final prefs = await SharedPreferences.getInstance();
    final weekStart = _getCurrentWeekStart();
    final storedWeekStart = prefs.getString(_weekStartKey);

    if (storedWeekStart != null && storedWeekStart != weekStart) {
      await prefs.remove(_weeklyDataKey);
      await prefs.remove(_lastSavedUsageKey);
      await prefs.setString(_weekStartKey, weekStart);
      debugPrint('🗑️ Old week data cleared');
    }
  }

  // Get all app packages that have been tracked this week
  static Future<Set<String>> getTrackedPackages() async {
    final weeklyData = await getWeeklyData();
    return weeklyData.keys.toSet();
  }

  // Debug: Print current weekly data
  static Future<void> printWeeklyData() async {
    final data = await getWeeklyData();
    debugPrint('📈 Weekly Data Summary:');
    data.forEach((pkg, value) {
      final seconds = (value as Map)['totalSeconds'] as int;
      final hours = (seconds / 3600).toStringAsFixed(1);
      debugPrint('  $pkg: ${hours}h ($seconds seconds)');
    });
  }
}