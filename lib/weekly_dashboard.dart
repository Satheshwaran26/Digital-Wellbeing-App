import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_usage_tracker.dart';
import 'weekly_storage_service.dart';
import 'dart:typed_data';

class WeeklyDashboardPage extends StatefulWidget {
  const WeeklyDashboardPage({super.key});

  @override
  State<WeeklyDashboardPage> createState() => _WeeklyDashboardPageState();
}

class _WeeklyDashboardPageState extends State<WeeklyDashboardPage> {
  List<Map<String, dynamic>> _weeklyAppData = [];
  bool _isLoading = true;

  final List<Color> _colors = [
    const Color(0xFF007BFF),
    const Color(0xFFFF5252),
    const Color(0xFF4CAF50),
    const Color(0xFFFF9800),
    const Color(0xFF9C27B0),
    const Color(0xFF00BCD4),
    const Color(0xFFFFEB3B),
    const Color(0xFFE91E63),
  ];

  @override
  void initState() {
    super.initState();
    _loadWeeklyData();
    _startPeriodicSave();
  }

  void _startPeriodicSave() {
    Future.delayed(const Duration(seconds: 30), () async {
      if (!mounted) return;
      await _saveCurrentDayUsage();
      await _loadWeeklyData();
      _startPeriodicSave();
    });
  }

  Future<void> _saveCurrentDayUsage() async {
    try {
      await AppUsageTracker.instance.pullUsageSnapshotAndMerge();
      final apps = await AppUsageTracker.instance.getMonitoredApps();

      Map<String, int> dailyUsage = {};
      for (var app in apps) {
        dailyUsage[app.packageName] = app.totalUsageSeconds;
      }

      await WeeklyStorageService.saveDailyUsage(dailyUsage);
      debugPrint('💾 Saved usage for ${dailyUsage.length} apps');
    } catch (e) {
      debugPrint('❌ Error saving daily usage: $e');
    }
  }

  Future<void> _loadWeeklyData() async {
    if (!mounted) return;

    setState(() => _isLoading = true);

    try {
      await WeeklyStorageService.clearIfNewWeek();
      final weeklyData = await WeeklyStorageService.getWeeklyData();

      debugPrint('📊 Loading weekly data: ${weeklyData.length} apps');

      // Get current monitored apps
      final monitoredApps = await AppUsageTracker.instance.getMonitoredApps();

      // Create a map for quick lookup
      Map<String, MonitoredApp> appMap = {};
      for (var app in monitoredApps) {
        appMap[app.packageName] = app;
      }

      List<Map<String, dynamic>> displayData = [];

      for (var entry in weeklyData.entries) {
        final packageName = entry.key;
        final data = entry.value as Map<String, dynamic>;
        final seconds = data['totalSeconds'] as int;

        if (seconds == 0) continue;

        String appName;
        Uint8List? iconData;

        // Try to get from current monitored apps first
        if (appMap.containsKey(packageName)) {
          appName = appMap[packageName]!.appName;
          iconData = appMap[packageName]!.iconData;
        } else {
          // If not currently monitored, try to get app name from package manager
          try {
            final pm = await AppUsageTracker.instance.getInstalledApps();
            final matchingApp = pm.firstWhere(
                  (app) => app.packageName == packageName,
              orElse: () => MonitoredApp(packageName: packageName, appName: ''),
            );

            if (matchingApp.appName.isNotEmpty) {
              appName = matchingApp.appName;
              iconData = matchingApp.iconData;
            } else {
              // Fallback: clean package name
              final parts = packageName.split('.');
              appName = parts.isNotEmpty ? parts.last : packageName;
              // Capitalize first letter
              if (appName.isNotEmpty) {
                appName = appName[0].toUpperCase() + appName.substring(1);
              }
            }
          } catch (e) {
            // Final fallback
            final parts = packageName.split('.');
            appName = parts.isNotEmpty ? parts.last : packageName;
            if (appName.isNotEmpty) {
              appName = appName[0].toUpperCase() + appName.substring(1);
            }
          }
        }

        // Format time properly
        final hours = seconds / 3600.0;
        final minutes = (seconds % 3600) / 60.0;

        // Use hours if >= 1 hour, otherwise use minutes
        final displayTime = hours >= 1.0 ? hours : minutes;
        final displayUnit = hours >= 1.0 ? 'h' : 'm';

        displayData.add({
          'packageName': packageName,
          'app': appName,
          'iconData': iconData,
          'totalSeconds': seconds,
          'hours': hours,
          'displayTime': displayTime,
          'displayUnit': displayUnit,
        });

        debugPrint('  $appName: ${displayTime.toStringAsFixed(1)}$displayUnit');
      }

      displayData.sort((a, b) =>
          (b['totalSeconds'] as int).compareTo(a['totalSeconds'] as int)
      );

      if (mounted) {
        setState(() {
          _weeklyAppData = displayData;
          _isLoading = false;
        });
      }

      debugPrint('✅ Loaded ${displayData.length} apps for display');
    } catch (e, stackTrace) {
      debugPrint('❌ Error loading weekly data: $e');
      debugPrint('Stack trace: $stackTrace');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    double maxHours = _weeklyAppData.isNotEmpty
        ? _weeklyAppData.map((e) => e['hours'] as double).reduce((a, b) => a > b ? a : b)
        : 5.0;

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      appBar: AppBar(
        backgroundColor: const Color(0xFF000000),
        elevation: 0,
        title: Text(
          'Weekly Dashboard',
          style: GoogleFonts.montserrat(
            fontSize: 20,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.blue),
            onPressed: () async {
              await _saveCurrentDayUsage();
              await _loadWeeklyData();
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
        child: CircularProgressIndicator(color: Color(0xFF007BFF)),
      )
          : _weeklyAppData.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today_outlined,
                size: 64,
                color: Colors.white.withOpacity(0.3),
              ),
              const SizedBox(height: 16),
              Text(
                'No weekly data yet',
                style: GoogleFonts.montserrat(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Colors.white.withOpacity(0.7),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Start monitoring apps to see weekly statistics',
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.white.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: () async {
                  await _saveCurrentDayUsage();
                  await _loadWeeklyData();
                },
                icon: const Icon(Icons.refresh),
                label: Text(
                  'Refresh Data',
                  style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF007BFF),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
              ),
            ],
          ),
        ),
      )
          : SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'App Usage',
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 16),
            Container(
              height: 250,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: _weeklyAppData.asMap().entries.map((entry) {
                    final index = entry.key;
                    final data = entry.value;
                    return _buildSimpleBar(
                      data['app'],
                      data['displayTime'],
                      data['displayUnit'],
                      maxHours,
                      _colors[index % _colors.length],
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'App Details',
                  style: GoogleFonts.montserrat(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                Text(
                  '${_weeklyAppData.length} apps',
                  style: GoogleFonts.montserrat(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Colors.white.withOpacity(0.5),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            ..._weeklyAppData.asMap().entries.map((entry) {
              final index = entry.key;
              final data = entry.value;
              return _buildSimpleListItem(
                data['app'],
                data['displayTime'],
                data['displayUnit'],
                _colors[index % _colors.length],
                data['iconData'],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildSimpleBar(
      String appName,
      double displayTime,
      String displayUnit,
      double maxHours,
      Color barColor,
      ) {
    // Calculate height based on actual hours for proper scaling
    final hours = displayUnit == 'h' ? displayTime : displayTime / 60;
    double heightPercentage = (hours / maxHours).clamp(0.0, 1.0);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            '${displayTime.toStringAsFixed(1)}$displayUnit',
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: const Color(0xFF888888),
            ),
          ),
          const SizedBox(height: 6),
          Container(
            width: 30,
            height: 180 * heightPercentage,
            decoration: BoxDecoration(
              color: barColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(4),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            appName.length > 6 ? '${appName.substring(0, 5)}..' : appName,
            style: GoogleFonts.montserrat(
              fontSize: 10,
              fontWeight: FontWeight.w800,
              color: const Color(0xFF888888),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildSimpleListItem(
      String appName,
      double displayTime,
      String displayUnit,
      Color appColor,
      dynamic iconData,
      ) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: appColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: iconData != null
                    ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    iconData,
                    width: 36,
                    height: 36,
                    fit: BoxFit.cover,
                  ),
                )
                    : Icon(
                  Icons.apps,
                  color: appColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                appName,
                style: GoogleFonts.montserrat(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: Colors.white,
                ),
              ),
            ],
          ),
          Text(
            '${displayTime.toStringAsFixed(1)}$displayUnit',
            style: GoogleFonts.montserrat(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: appColor,
            ),
          ),
        ],
      ),
    );
  }
}