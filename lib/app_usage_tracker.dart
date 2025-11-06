import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonitoredApp {
  final String packageName;
  final String appName;
  final Uint8List? iconData;
  final int totalUsageSeconds; // Total usage in seconds
  final DateTime lastUpdated;

  MonitoredApp({
    required this.packageName,
    required this.appName,
    this.iconData,
    this.totalUsageSeconds = 0,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'packageName': packageName,
      'appName': appName,
      'iconData': iconData != null ? base64Encode(iconData!) : null,
      'totalUsageSeconds': totalUsageSeconds,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory MonitoredApp.fromJson(Map<String, dynamic> json) {
    return MonitoredApp(
      packageName: json['packageName'] as String,
      appName: json['appName'] as String,
      iconData: json['iconData'] != null
          ? base64Decode(json['iconData'] as String)
          : null,
      totalUsageSeconds: json['totalUsageSeconds'] as int? ?? 0,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : DateTime.now(),
    );
  }

  String get formattedUsage {
    final hours = totalUsageSeconds ~/ 3600;
    final minutes = (totalUsageSeconds % 3600) ~/ 60;
    final seconds = totalUsageSeconds % 60;

    if (hours > 0) {
      if (minutes > 0) {
        return '${hours}h ${minutes}m';
      }
      return '${hours}h';
    } else if (minutes > 0) {
      return '${minutes}m';
    } else {
      return '${seconds}s';
    }
  }

  MonitoredApp copyWith({
    String? packageName,
    String? appName,
    Uint8List? iconData,
    int? totalUsageSeconds,
    DateTime? lastUpdated,
  }) {
    return MonitoredApp(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      iconData: iconData ?? this.iconData,
      totalUsageSeconds: totalUsageSeconds ?? this.totalUsageSeconds,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class AppUsageTracker {
  static const String _monitoredAppsKey = 'monitored_apps';
  static const String _combinedTimeLimitKey = 'combined_time_limit';
  static AppUsageTracker? _instance;
  SharedPreferences? _prefs;
  
  // Method channel for platform-specific tracking
  static const MethodChannel _channel = MethodChannel('app_usage_tracker');
  
  // Public getter for testing
  MethodChannel get channel => _channel;
  
  // Track current foreground app
  String? _currentForegroundApp;
  DateTime? _appStartTime;
  DateTime? _lastSaveTime;
  
  // Logging control
  static DateTime? _lastChannelErrorLog;
  DateTime? _lastMissingAppLog;
  
  // Combined time limit (in seconds) for ALL monitored apps
  int _combinedTimeLimit = 60; // Default: 1 minute for all apps combined
  
  // Milestone tracking is now handled in native Kotlin code
 
  AppUsageTracker._();

  static AppUsageTracker get instance {
    _instance ??= AppUsageTracker._();
    return _instance!;
  }

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _initFailed = false;
  DateTime? _lastInitAttempt;

  Future<void> initialize() async {
    // Prevent multiple simultaneous initializations
    if (_isInitialized) return;
    
    // If initialization failed recently, don't retry immediately (prevents spam)
    if (_initFailed && _lastInitAttempt != null) {
      final timeSinceLastAttempt = DateTime.now().difference(_lastInitAttempt!);
      if (timeSinceLastAttempt.inSeconds < 5) {
        return; // Don't retry for 5 seconds
      }
    }
    
    if (_isInitializing) {
      // Wait for ongoing initialization
      int waitCount = 0;
      while (_isInitializing && waitCount < 50) {
        await Future.delayed(const Duration(milliseconds: 100));
        waitCount++;
      }
      return;
    }

    _isInitializing = true;
    _lastInitAttempt = DateTime.now();
    try {
      _prefs = await SharedPreferences.getInstance();
      // Load combined time limit
      _combinedTimeLimit = _prefs!.getInt(_combinedTimeLimitKey) ?? 60;
      _isInitialized = true;
      _initFailed = false;
      _startTracking();
    } catch (e) {
      _initFailed = true;
      _isInitialized = false;
      _prefs = null;
      // Only log once every 30 seconds to avoid spam
      final now = DateTime.now();
      if (_lastInitAttempt == null || 
          now.difference(_lastInitAttempt!).inSeconds > 30) {
        debugPrint('AppUsageTracker: SharedPreferences plugin not available.');
        debugPrint('Cause: $e');
        debugPrint('Solution: Stop the app completely and restart (not hot reload).');
        _lastInitAttempt = now; // Update to prevent spam
      }
      // Don't rethrow - allow app to continue
      // The tracker will try to initialize again on next use
    } finally {
      _isInitializing = false;
    }
  }

  Future<void> _startTracking() async {
    if (!_isInitialized) return;
    
    // Ensure monitoring service is running for milestone overlays
    await _ensureMonitoringServiceRunning();
    
    // Start periodic foreground app checking
    _checkForegroundApp();
  }
  
  Future<void> _ensureMonitoringServiceRunning() async {
    try {
      // Check if overlay permission is granted
      final hasOverlayPermission = await checkOverlayPermission();
      if (hasOverlayPermission) {
        await startMonitoringService();
        debugPrint('✅ Monitoring service started for milestone overlays');
      } else {
        debugPrint('⚠️ Overlay permission not granted - milestones will show as notifications only');
      }
    } catch (e) {
      debugPrint('Error starting monitoring service: $e');
    }
  }

  Future<void> _checkForegroundApp() async {
    if (!_isInitialized) return;
    
    try {
      // Get current foreground app using method channel with timeout
      final String? foregroundApp = await _getForegroundApp()
          .timeout(const Duration(seconds: 1), onTimeout: () {
        return null;
      });
      
      final now = DateTime.now();
      
      if (foregroundApp != null) {
        // Check if this is a monitored app
        final monitoredApps = await getMonitoredApps();
        final isMonitored = monitoredApps.any((app) => app.packageName == foregroundApp);
        
        if (isMonitored) {
          // If app changed, update usage for previous app
          if (_currentForegroundApp != null && _currentForegroundApp != foregroundApp && _appStartTime != null) {
            final duration = now.difference(_appStartTime!);
            final seconds = duration.inSeconds;
            if (seconds > 0) {
              debugPrint('App switched: $foregroundApp. Updating usage for $_currentForegroundApp: +${seconds}s');
              await updateUsage(_currentForegroundApp!, seconds);
            }
            _lastSaveTime = null; // Reset save time for new app
          }
          
          // Track new foreground app
          if (_currentForegroundApp != foregroundApp) {
            debugPrint('Tracking new app: $foregroundApp');
            _currentForegroundApp = foregroundApp;
            _appStartTime = now;
            _lastSaveTime = null;
          } else {
            // Same app - periodically save usage (every 2 seconds for faster updates)
            if (_appStartTime != null) {
              if (_lastSaveTime == null || now.difference(_lastSaveTime!).inSeconds >= 2) {
                final duration = now.difference(_appStartTime!);
                final seconds = duration.inSeconds;
                if (seconds > 0) {
                  debugPrint('Updating usage for $foregroundApp: +${seconds}s (total tracking: ${duration.inSeconds}s)');
                  await updateUsage(foregroundApp, seconds);
                  // Reset start time to current time to continue tracking
                  _appStartTime = now;
                  _lastSaveTime = now;
                }
              }
            }
          }
        } else {
          // If switched to non-monitored app, update usage for previous monitored app
          if (_currentForegroundApp != null && _appStartTime != null) {
            final duration = now.difference(_appStartTime!);
            final seconds = duration.inSeconds;
            if (seconds > 0) {
              debugPrint('Switched to non-monitored app. Updating usage for $_currentForegroundApp: +${seconds}s');
              await updateUsage(_currentForegroundApp!, seconds);
            }
            _currentForegroundApp = null;
            _appStartTime = null;
            _lastSaveTime = null;
          }
        }
      } else {
        // If no foreground app detected, update previous app if exists
        if (_currentForegroundApp != null && _appStartTime != null) {
          final duration = now.difference(_appStartTime!);
          final seconds = duration.inSeconds;
          if (seconds > 0) {
            debugPrint('No foreground app detected. Updating usage for $_currentForegroundApp: +${seconds}s');
            await updateUsage(_currentForegroundApp!, seconds);
          }
          _currentForegroundApp = null;
          _appStartTime = null;
          _lastSaveTime = null;
        }
      }
    } catch (e) {
      debugPrint('Error checking foreground app: $e');
      // Continue tracking even if there's an error
    }
    
    // Check again in 2 seconds (with error handling)
    Future.delayed(const Duration(seconds: 2), () {
      if (_isInitialized) {
        try {
          _checkForegroundApp();
        } catch (e) {
          debugPrint('Error scheduling next check: $e');
          // Retry after a longer delay if there's an error
          Future.delayed(const Duration(seconds: 5), () {
            if (_isInitialized) {
              _checkForegroundApp();
            }
          });
        }
      }
    });
  }

  Future<String?> _getForegroundApp() async {
    try {
      // Try to get foreground app via method channel with timeout
      final String? result = await _channel.invokeMethod<String?>('getForegroundApp')
          .timeout(const Duration(seconds: 1), onTimeout: () => null);
      
      // Log occasionally to help debug
      final now = DateTime.now();
      if (_lastChannelErrorLog == null || 
          now.difference(_lastChannelErrorLog!).inSeconds > 30) {
        if (result != null) {
          debugPrint('✓ Foreground app detected: $result');
        } else {
          debugPrint('⚠ No foreground app detected (may need Usage Stats permission)');
        }
        _lastChannelErrorLog = now;
      }
      
      return result;
    } catch (e) {
      // Method channel error - log only occasionally to avoid spam
      final now = DateTime.now();
      if (_lastChannelErrorLog == null || 
          now.difference(_lastChannelErrorLog!).inSeconds > 30) {
        debugPrint('❌ Method channel error (may need Usage Stats permission): $e');
        _lastChannelErrorLog = now;
      }
      return null;
    }
  }
  

  // Check if Usage Stats permission is granted
  Future<bool> checkUsageStatsPermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool?>('checkUsageStatsPermission')
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking permission: $e');
      return false;
    }
  }
  
  // Open Usage Stats settings
  Future<void> openUsageStatsSettings() async {
    try {
      await _channel.invokeMethod('openUsageStatsSettings');
    } catch (e) {
      debugPrint('Error opening settings: $e');
    }
  }
  
  // Check if overlay permission is granted
  Future<bool> checkOverlayPermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool?>('checkOverlayPermission')
          .timeout(const Duration(seconds: 2), onTimeout: () => false);
      return result ?? false;
    } catch (e) {
      debugPrint('Error checking overlay permission: $e');
      return false;
    }
  }
  
  // Request overlay permission
  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint('Error requesting overlay permission: $e');
    }
  }
  
  // Request both usage stats and overlay permissions
  Future<Map<String, bool>> requestAllPermissions() async {
    debugPrint('📋 Requesting all required permissions...');
    
    // Check current permissions
    final hasUsageStats = await checkUsageStatsPermission();
    final hasOverlay = await checkOverlayPermission();
    
    debugPrint('Current permissions - Usage Stats: $hasUsageStats, Overlay: $hasOverlay');
    
    // Request usage stats permission if not granted
    if (!hasUsageStats) {
      debugPrint('🔓 Requesting Usage Stats permission...');
      await openUsageStatsSettings();
    }
    
    // Request overlay permission if not granted
    if (!hasOverlay) {
      debugPrint('🔓 Requesting Overlay permission...');
      await requestOverlayPermission();
    }
    
    // Wait a moment for permissions to be processed
    await Future.delayed(const Duration(seconds: 1));
    
    // Check permissions again after requests
    final finalUsageStats = await checkUsageStatsPermission();
    final finalOverlay = await checkOverlayPermission();
    
    final result = {
      'usageStats': finalUsageStats,
      'overlay': finalOverlay,
      'allGranted': finalUsageStats && finalOverlay,
    };
    
    debugPrint('Final permissions - Usage Stats: $finalUsageStats, Overlay: $finalOverlay, All granted: ${result['allGranted']}');
    
    return result;
  }
  
  // Start monitoring service (shows overlay when using other apps)
  Future<void> startMonitoringService() async {
    try {
      final totalUsage = await getTotalUsage();
      final milestoneData = await checkCombinedMilestone();
      
      await _channel.invokeMethod('startMonitoringService', {
        'currentUsage': totalUsage,
        'totalLimit': _combinedTimeLimit,
        'percentage': milestoneData['percentage'],
      });
      debugPrint('✅ Monitoring service started');
    } catch (e) {
      debugPrint('Error starting monitoring service: $e');
    }
  }
  
  // Stop monitoring service
  Future<void> stopMonitoringService() async {
    try {
      await _channel.invokeMethod('stopMonitoringService');
      debugPrint('Monitoring service stopped');
    } catch (e) {
      debugPrint('Error stopping monitoring service: $e');
    }
  }
  
  // Test overlay functionality
  Future<void> testOverlay() async {
    try {
      await _channel.invokeMethod('testOverlay');
      debugPrint('✅ Test overlay triggered');
    } catch (e) {
      debugPrint('Error testing overlay: $e');
    }
  }
  
  // Update overlay service with new milestone data (called automatically on usage updates)
  // This ensures monitoring continues even after milestones are reached
  Future<void> _updateOverlayService(int totalUsage) async {
    try {
      final milestoneData = await checkCombinedMilestone();
      
      // ALWAYS restart service with updated data - this ensures monitoring continues
      // even after milestones (30%, 70%, 100%) are reached
      await _channel.invokeMethod('startMonitoringService', {
        'currentUsage': totalUsage,
        'totalLimit': _combinedTimeLimit,
        'percentage': milestoneData['percentage'],
        'milestone30': milestoneData['milestone30'] ?? false,
        'milestone70': milestoneData['milestone70'] ?? false,
        'milestone100': milestoneData['milestone100'] ?? false,
      });
      debugPrint('✅ Overlay service updated: ${totalUsage}s/${_combinedTimeLimit}s (${milestoneData['percentage']}%)');
    } catch (e) {
      // Service might not be running - that's okay
      debugPrint('Could not update overlay service: $e');
    }
  }

  Future<void> addMonitoredApps(List<Map<String, dynamic>> apps) async {
    await initialize();
    final existingApps = await getMonitoredApps();
    final existingPackageNames = existingApps.map((a) => a.packageName).toSet();

    for (var app in apps) {
      final packageName = app['packageName'] as String;
      
      if (!existingPackageNames.contains(packageName)) {
        final monitoredApp = MonitoredApp(
          packageName: packageName,
          appName: app['name'] as String,
          iconData: app['iconData'] as Uint8List?,
        );
        existingApps.add(monitoredApp);
      }
    }

    await _saveMonitoredApps(existingApps);
  }
  
  // Set combined time limit for ALL apps (in seconds)
  Future<void> setCombinedTimeLimit(int seconds) async {
    await initialize();
    if (_prefs == null || !_isInitialized) return;
    
    _combinedTimeLimit = seconds;
    await _prefs!.setInt(_combinedTimeLimitKey, seconds);
    debugPrint('Combined time limit set to ${seconds}s for all apps');
  }
  
  // Get combined time limit
  int getCombinedTimeLimit() {
    return _combinedTimeLimit;
  }
  
  // Get total usage across all monitored apps
  Future<int> getTotalUsage() async {
    final apps = await getMonitoredApps();
    return apps.fold<int>(0, (sum, app) => sum + app.totalUsageSeconds);
  }
  
  // Check combined milestone for ALL apps
  Future<Map<String, dynamic>> checkCombinedMilestone() async {
    final totalUsage = await getTotalUsage();
    
    try {
      final result = await _channel.invokeMethod('checkCombinedMilestone', {
        'currentUsage': totalUsage,
        'totalLimit': _combinedTimeLimit,
      });
      
      if (result is Map) {
        return Map<String, dynamic>.from(result);
      }
    } catch (e) {
      debugPrint('Error checking combined milestone: $e');
    }
    
    // Fallback calculation
    final percentage = _combinedTimeLimit > 0 
        ? (totalUsage / _combinedTimeLimit) * 100.0 
        : 0.0;
    
    return {
      'percentage': percentage,
      'totalUsage': totalUsage,
      'totalLimit': _combinedTimeLimit,
      'milestone30': percentage >= 30.0,
      'milestone70': percentage >= 70.0,
      'milestone100': percentage >= 100.0,
    };
  }
  
  // Get milestone data (for display on milestone page)


  Future<void> _saveMonitoredApps(List<MonitoredApp> apps) async {
    if (!_isInitialized && !_initFailed) {
      await initialize();
    }
    if (_prefs == null || !_isInitialized) {
      // SharedPreferences not available - this is expected if plugin isn't loaded
      // (e.g., during hot reload). Don't log to avoid spam.
      return;
    }
    try {
      final jsonList = apps.map((app) => app.toJson()).toList();
      await _prefs!.setString(_monitoredAppsKey, jsonEncode(jsonList));
    } catch (e) {
      debugPrint('Error saving monitored apps: $e');
    }
  }

  Future<List<MonitoredApp>> getMonitoredApps() async {
    if (!_isInitialized && !_initFailed) {
      await initialize();
    }
    if (_prefs == null || !_isInitialized) {
      // Don't log every time - it's expected if plugin isn't available
      return [];
    }
    final jsonString = _prefs!.getString(_monitoredAppsKey);
    if (jsonString == null) return [];

    try {
      final jsonList = jsonDecode(jsonString) as List<dynamic>;
      return jsonList
          .map((json) => MonitoredApp.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      debugPrint('Error parsing monitored apps: $e');
      return [];
    }
  }

  Future<void> updateUsage(String packageName, int secondsToAdd) async {
    if (!_isInitialized && !_initFailed) {
      await initialize();
    }
    if (_prefs == null || !_isInitialized) {
      debugPrint('Cannot update usage: SharedPreferences not initialized');
      return; // SharedPreferences not available
    }
    final apps = await getMonitoredApps();
    final appIndex = apps.indexWhere((app) => app.packageName == packageName);
    
    if (appIndex != -1) {
      final app = apps[appIndex];
      final oldTotal = app.totalUsageSeconds;
      final newTotal = oldTotal + secondsToAdd;
      apps[appIndex] = app.copyWith(
        totalUsageSeconds: newTotal,
        lastUpdated: DateTime.now(),
      );
      await _saveMonitoredApps(apps);
      
      // Calculate total usage across ALL apps
      final totalUsage = apps.fold<int>(0, (sum, a) => sum + a.totalUsageSeconds);
      
      // Log every update to help debug
      debugPrint('✓ Usage updated for $packageName: ${oldTotal}s -> ${newTotal}s (+${secondsToAdd}s) | Total: ${totalUsage}s/${_combinedTimeLimit}s');
      
      // Check for combined milestones
      if (_combinedTimeLimit > 0) {
        await _checkCombinedMilestoneAndNotify(totalUsage);
      }
      
      // Update overlay service with new data
      await _updateOverlayService(totalUsage);
    } else {
      // Log missing app errors
      final now = DateTime.now();
      if (_lastMissingAppLog == null || now.difference(_lastMissingAppLog!).inSeconds > 30) {
        debugPrint('⚠ App not found in monitored list: $packageName');
        _lastMissingAppLog = now;
      }
    }
  }
  
  Future<void> _checkCombinedMilestoneAndNotify(int totalUsage) async {
    try {
      // Delegate milestone checking to native Kotlin code
      await _channel.invokeMethod('checkMilestone', {
        'totalUsage': totalUsage,
        'totalLimit': _combinedTimeLimit,
      });
    } catch (e) {
      debugPrint('Error checking milestone: $e');
    }
  }
  
  // Reset milestones in native Kotlin code
  Future<void> resetShownMilestones() async {
    try {
      await _channel.invokeMethod('resetMilestones');
      debugPrint('Milestones reset in native code');
    } catch (e) {
      debugPrint('Error resetting milestones: $e');
    }
  }

  Future<void> removeMonitoredApp(String packageName) async {
    if (!_isInitialized && !_initFailed) {
      await initialize();
    }
    if (_prefs == null || !_isInitialized) {
      return; // SharedPreferences not available
    }
    final apps = await getMonitoredApps();
    apps.removeWhere((app) => app.packageName == packageName);
    await _saveMonitoredApps(apps);
  }

  // Manually increment usage for an app (for testing or manual tracking)
  // In production, this would be called automatically by platform-specific tracking code
  Future<void> incrementUsageForApp(String packageName, {int seconds = 1}) async {
    await updateUsage(packageName, seconds);
  }
  
  // Track app usage when app comes to foreground
  // This should be called by platform-specific code when detecting app switch
  Future<void> trackAppUsage(String packageName, Duration usageDuration) async {
    await updateUsage(packageName, usageDuration.inSeconds);
  }

  Future<void> resetDailyUsage() async {
    if (!_isInitialized && !_initFailed) {
      await initialize();
    }
    if (_prefs == null || !_isInitialized) {
      return; // SharedPreferences not available
    }
    final apps = await getMonitoredApps();
    final resetApps = apps.map((app) => app.copyWith(
      totalUsageSeconds: 0,
      lastUpdated: DateTime.now(),
    )).toList();
    await _saveMonitoredApps(resetApps);
  }
}

