import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MonitoredApp {
  final String packageName;
  final String appName;
  final Uint8List? iconData;
  final int totalUsageSeconds;
  final int timeLimitSeconds; // Per-app limit
  final bool isBlocked;
  final DateTime lastUpdated;

  MonitoredApp({
    required this.packageName,
    required this.appName,
    this.iconData,
    this.totalUsageSeconds = 0,
    this.timeLimitSeconds = 0,
    this.isBlocked = false,
    DateTime? lastUpdated,
  }) : lastUpdated = lastUpdated ?? DateTime.now();

  Map<String, dynamic> toJson() {
    return {
      'packageName': packageName,
      'appName': appName,
      'iconData': iconData != null ? base64Encode(iconData!) : null,
      'totalUsageSeconds': totalUsageSeconds,
      'timeLimitSeconds': timeLimitSeconds,
      'isBlocked': isBlocked,
      'lastUpdated': lastUpdated.toIso8601String(),
    };
  }

  factory MonitoredApp.fromJson(Map<String, dynamic> json) {
    return MonitoredApp(
      packageName: json['packageName'] as String,
      appName: json['appName'] as String,
      iconData: json['iconData'] != null ? base64Decode(json['iconData'] as String) : null,
      totalUsageSeconds: json['totalUsageSeconds'] as int? ?? 0,
      timeLimitSeconds: json['timeLimitSeconds'] as int? ?? 0,
      isBlocked: json['isBlocked'] as bool? ?? false,
      lastUpdated: json['lastUpdated'] != null
          ? DateTime.parse(json['lastUpdated'] as String)
          : DateTime.now(),
    );
  }

  String get formattedUsage {
    final h = totalUsageSeconds ~/ 3600;
    final m = (totalUsageSeconds % 3600) ~/ 60;
    final s = totalUsageSeconds % 60;
    if (h > 0) {
      return m > 0 ? '${h}h ${m}m' : '${h}h';
    } else if (m > 0) {
      return '${m}m';
    } else {
      return '${s}s';
    }
  }

  MonitoredApp copyWith({
    String? packageName,
    String? appName,
    Uint8List? iconData,
    int? totalUsageSeconds,
    int? timeLimitSeconds,
    bool? isBlocked,
    DateTime? lastUpdated,
  }) {
    return MonitoredApp(
      packageName: packageName ?? this.packageName,
      appName: appName ?? this.appName,
      iconData: iconData ?? this.iconData,
      totalUsageSeconds: totalUsageSeconds ?? this.totalUsageSeconds,
      timeLimitSeconds: timeLimitSeconds ?? this.timeLimitSeconds,
      isBlocked: isBlocked ?? this.isBlocked,
      lastUpdated: lastUpdated ?? this.lastUpdated,
    );
  }
}

class AppUsageTracker {
  static const String _monitoredAppsKey = 'monitored_apps_v2';
  static AppUsageTracker? _instance;
  SharedPreferences? _prefs;

  static const MethodChannel _channel = MethodChannel('app_usage_tracker');
  MethodChannel get channel => _channel;

  bool _isInitialized = false;
  bool _isInitializing = false;
  bool _initFailed = false;

  AppUsageTracker._();

  static AppUsageTracker get instance {
    _instance ??= AppUsageTracker._();
    return _instance!;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    if (_isInitializing) return;
    _isInitializing = true;
    try {
      _prefs = await SharedPreferences.getInstance();
      _isInitialized = true;
      _initFailed = false;
    } catch (e) {
      _initFailed = true;
      _prefs = null;
      debugPrint('Initialization failed: $e');
    } finally {
      _isInitializing = false;
    }
  }

  Future<List<MonitoredApp>> getMonitoredApps() async {
    if (!_isInitialized && !_initFailed) {
      await initialize();
    }
    if (_prefs == null) return [];
    final jsonString = _prefs!.getString(_monitoredAppsKey);
    if (jsonString == null) return [];
    try {
      final list = jsonDecode(jsonString) as List<dynamic>;
      return list.map((e) => MonitoredApp.fromJson(e as Map<String, dynamic>)).toList();
    } catch (e) {
      debugPrint('Parsing error: $e');
      return [];
    }
  }

  Future<void> _saveMonitoredApps(List<MonitoredApp> apps) async {
    if (!_isInitialized) await initialize();
    if (_prefs == null) return;
    try {
      final data = jsonEncode(apps.map((e) => e.toJson()).toList());
      await _prefs!.setString(_monitoredAppsKey, data);
    } catch (e) {
      debugPrint('Save error: $e');
    }
  }

  Future<void> addMonitoredAppsWithLimit(List<Map<String, dynamic>> apps, int timeLimitSeconds) async {
    final existing = await getMonitoredApps();
    final map = {for (var e in existing) e.packageName: e};
    for (var app in apps) {
      final pkg = app['packageName'] as String;
      final name = app['name'] as String;
      final icon = app['iconData'] as Uint8List?;
      final prev = map[pkg];
      map[pkg] = MonitoredApp(
        packageName: pkg,
        appName: name,
        iconData: icon ?? prev?.iconData,
        totalUsageSeconds: prev?.totalUsageSeconds ?? 0,
        timeLimitSeconds: timeLimitSeconds,
        isBlocked: prev?.isBlocked ?? false,
      );
    }
    await _saveMonitoredApps(map.values.toList());
  }

// Replace your unblockApp method with this:

// Replace your unblockApp method with this:

// Replace your unblockApp method with this:

  Future<void> unblockApp(String packageName) async {
    debugPrint('🔓 FLUTTER UNBLOCK (REMOVE): $packageName');

    try {
      // 1. REMOVE from Flutter monitored apps list completely
      final apps = await getMonitoredApps();
      final idx = apps.indexWhere((e) => e.packageName == packageName);

      if (idx != -1) {
        debugPrint('   Found at index $idx');
        // Remove the app completely
        apps.removeAt(idx);
        await _saveMonitoredApps(apps);
        debugPrint('   ✓ Removed from Flutter monitored list');
        debugPrint('   ✓ Remaining monitored apps: ${apps.length}');
      } else {
        debugPrint('   ⚠ App not found in monitored list');
      }

      // 2. Clear from Flutter cache
      if (_prefs != null) {
        final data = jsonEncode(apps.map((e) => e.toJson()).toList());
        await _prefs!.setString(_monitoredAppsKey, data);
        debugPrint('   ✓ Flutter cache updated');
      }

      // 3. Tell native to remove completely
      debugPrint('   → Calling native unblockApp (remove)...');
      await _channel.invokeMethod('unblockApp', {
        'packageName': packageName,
      });
      debugPrint('   ✓ Native removal completed');

      // 4. Wait for native to process
      await Future.delayed(const Duration(milliseconds: 500));

      // 5. Verify removal
      final verifyApps = await getMonitoredApps();
      final stillExists = verifyApps.any((e) => e.packageName == packageName);

      debugPrint('✅ UNBLOCK (REMOVAL) VERIFICATION:');
      debugPrint('   - Package: $packageName');
      debugPrint('   - Still in list: $stillExists');
      debugPrint('   - Total monitored: ${verifyApps.length}');

      if (stillExists) {
        throw Exception('Removal verification failed: app still in monitored list');
      }

      debugPrint('✅ FLUTTER UNBLOCK (REMOVAL) SUCCESS');
    } catch (e, stackTrace) {
      debugPrint('❌ FLUTTER UNBLOCK ERROR: $e');
      debugPrint('Stack: $stackTrace');
      rethrow;
    }
  }

  Future<List<String>> getBlockedPackagesNative() async {
    try {
      final List<dynamic>? result = await _channel.invokeMethod<List<dynamic>>('getBlockedApps');
      return result?.map((e) => e.toString()).toList() ?? [];
    } catch (_) {
      return [];
    }
  }



  Future<List<MonitoredApp>> getInstalledApps() async {
    try {
      final result = await _channel.invokeMethod('getInstalledApps');
      if (result is List) {
        return result.map((item) {
          final map = Map<String, dynamic>.from(item as Map);
          return MonitoredApp(
            packageName: map['packageName'] as String,
            appName: map['appName'] as String,
            iconData: map['iconData'] as Uint8List?,
          );
        }).toList();
      }
      return [];
    } catch (e) {
      debugPrint('Error getting installed apps: $e');
      return [];
    }
  }


  Future<void> requestOverlayPermission() async {
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } catch (e) {
      debugPrint('Error requesting overlay permission: $e');
    }
  }



  Future<void> restartNativeMonitoring() async {
    final apps = await getMonitoredApps();
    final payload = apps.map((e) {
      return {
        'packageName': e.packageName,
        'limitSeconds': e.timeLimitSeconds,
        'blocked': e.isBlocked,
        'usageSeconds': e.totalUsageSeconds,
      };
    }).toList();
    try {
      // Ensure FGS is started from foreground
      await _channel.invokeMethod('startMonitoringService');
      await _channel.invokeMethod('restartMonitoring', {'apps': payload});
    } catch (e) {
      debugPrint('Restart monitoring error: $e');
    }
  }

  // Native snapshot -> merge into Flutter state so UI updates
  Future<void> pullUsageSnapshotAndMerge() async {
    try {
      final List<dynamic>? list =
      await _channel.invokeMethod<List<dynamic>>('getUsageSnapshot');
      if (list == null) return;

      final apps = await getMonitoredApps();
      final map = {for (var e in apps) e.packageName: e};

      for (final item in list) {
        final m = Map<String, dynamic>.from(item as Map);
        final pkg = m['packageName'] as String;
        final usage = m['usageSeconds'] as int? ?? 0;
        final limit = m['limitSeconds'] as int? ?? (map[pkg]?.timeLimitSeconds ?? 0);
        final blocked = m['blocked'] as bool? ?? false;

        final existing = map[pkg];
        if (existing != null) {
          map[pkg] = existing.copyWith(
            totalUsageSeconds: usage,
            timeLimitSeconds: limit,
            isBlocked: blocked,
            lastUpdated: DateTime.now(),
          );
        }
      }
      await _saveMonitoredApps(map.values.toList());
    } catch (e) {
      debugPrint('pullUsageSnapshot error: $e');
    }
  }

  // Permissions
  Future<bool> checkUsageStatsPermission() async {
    try {
      final bool? result = await _channel.invokeMethod<bool>('checkUsageStatsPermission');
      return result ?? false;
    } catch (_) {
      return false;
    }
  }

  Future<void> openUsageStatsSettings() async {
    try {
      await _channel.invokeMethod('openUsageStatsSettings');
    } catch (_) {}
  }

  Future<void> requestNotificationPermission() async {
    try {
      await _channel.invokeMethod('requestNotificationPermission');
    } catch (_) {}
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _channel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (_) {}
  }

  Future<void> startMonitoringService() async {
    try {
      await _channel.invokeMethod('startMonitoringService');
    } catch (_) {}
  }

  Future<void> stopMonitoringService() async {
    try {
      await _channel.invokeMethod('stopMonitoringService');
    } catch (_) {}
  }
}