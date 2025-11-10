import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_usage_tracker.dart';
import 'dart:typed_data';

class PieChartPainter extends CustomPainter {
  final List<AppUsageData> appData;

  PieChartPainter({required this.appData});

  @override
  void paint(Canvas canvas, Size size) {
    if (appData.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    final cornerRadius = 10.0;

    final gapAngle = appData.length > 1 ? (2.5 * math.pi / 180.0) : 0.0;
    final totalGapAngle = gapAngle * appData.length;
    final availableAngle = (2 * math.pi) - totalGapAngle;

    double startAngle = -math.pi / 2;

    for (int i = 0; i < appData.length; i++) {
      final data = appData[i];
      final sweepAngle = (data.percentage / 100) * availableAngle;

      if (sweepAngle <= 0) continue;

      final path = Path();
      final startRadians = startAngle;
      final endRadians = startAngle + sweepAngle;

      final startOuterX = center.dx + radius * math.cos(startRadians);
      final startOuterY = center.dy + radius * math.sin(startRadians);
      final endOuterX = center.dx + radius * math.cos(endRadians);
      final endOuterY = center.dy + radius * math.sin(endRadians);

      path.moveTo(center.dx, center.dy);

      final startInnerX = center.dx + (radius - cornerRadius) * math.cos(startRadians);
      final startInnerY = center.dy + (radius - cornerRadius) * math.sin(startRadians);
      path.lineTo(startInnerX, startInnerY);

      path.quadraticBezierTo(
        startOuterX,
        startOuterY,
        center.dx + (radius - cornerRadius * 0.5) * math.cos(startRadians + sweepAngle * 0.05),
        center.dy + (radius - cornerRadius * 0.5) * math.sin(startRadians + sweepAngle * 0.05),
      );

      final rect = Rect.fromCircle(center: center, radius: radius);
      path.arcTo(rect, startRadians, sweepAngle, false);

      final endInnerX = center.dx + (radius - cornerRadius) * math.cos(endRadians);
      final endInnerY = center.dy + (radius - cornerRadius) * math.sin(endRadians);
      path.quadraticBezierTo(endOuterX, endOuterY, endInnerX, endInnerY);

      final innerRect = Rect.fromCircle(center: center, radius: radius - cornerRadius);
      path.arcTo(innerRect, endRadians, -sweepAngle, false);

      path.close();

      final paint = Paint()
        ..color = data.color
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);

      startAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class AppUsageData {
  final String appName;
  final double percentage;
  final Color color;
  final int usageSeconds;

  AppUsageData({
    required this.appName,
    required this.percentage,
    required this.color,
    required this.usageSeconds,
  });
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  List<MonitoredApp> _monitoredApps = [];
  bool _isLoading = true;
  bool _hasPermission = false;
  bool _checkingPermission = false;
  String _filterMode = 'all'; // 'all', 'monitoring', 'completed'

  final List<Color> _colors = [
    const Color(0xFF007BFF),
    const Color(0xFFCC3333),
    const Color(0xFFAD1457),
    const Color(0xFF1565C0),
    const Color(0xFF00695C),
    const Color(0xFF2E7D32),
    const Color(0xFFF57C00),
    const Color(0xFF7B1FA2),
    const Color(0xFFC62828),
    const Color(0xFF0277BD),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
    _loadMonitoredApps();
    _startPeriodicRefresh();
    AppUsageTracker.instance.requestNotificationPermission();
    AppUsageTracker.instance.requestIgnoreBatteryOptimizations();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _checkPermission() async {
    setState(() => _checkingPermission = true);
    final hasPermission = await AppUsageTracker.instance.checkUsageStatsPermission();
    if (mounted) {
      setState(() {
        _hasPermission = hasPermission;
        _checkingPermission = false;
      });
    }
  }

  void _startPeriodicRefresh() {
    Future.delayed(const Duration(seconds: 2), () async {
      if (!mounted) return;
      await AppUsageTracker.instance.pullUsageSnapshotAndMerge();
      await _loadMonitoredApps(noInit: true);
      _startPeriodicRefresh();
    });
  }

  Future<void> _loadMonitoredApps({bool noInit = false}) async {
    try {
      if (!noInit) {
        await AppUsageTracker.instance.initialize();
      }
      final apps = await AppUsageTracker.instance.getMonitoredApps();

      // Sort by usage time (descending)
      apps.sort((a, b) {
        if (a.totalUsageSeconds != b.totalUsageSeconds) {
          return b.totalUsageSeconds.compareTo(a.totalUsageSeconds);
        }
        return a.appName.compareTo(b.appName);
      });

      if (mounted) {
        setState(() {
          _monitoredApps = apps;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('Error loading monitored apps: $e');
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
      _loadMonitoredApps();
    }
  }

  List<MonitoredApp> _getFilteredApps() {
    switch (_filterMode) {
      case 'monitoring':
        return _monitoredApps.where((app) =>
        app.totalUsageSeconds > 0 &&
            app.totalUsageSeconds < app.timeLimitSeconds
        ).toList();
      case 'completed':
        return _monitoredApps.where((app) =>
        app.totalUsageSeconds >= app.timeLimitSeconds &&
            app.timeLimitSeconds > 0
        ).toList();
      case 'all':
      default:
        return _monitoredApps;
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredApps = _getFilteredApps();

    // Calculate total usage from filtered apps ONLY
    final totalSeconds = filteredApps.fold<int>(0, (sum, app) => sum + app.totalUsageSeconds);
    final totalHours = totalSeconds ~/ 3600;
    final totalMinutes = (totalSeconds % 3600) ~/ 60;
    final totalSeconds_remaining = totalSeconds % 60;

    final totalUsage = totalHours > 0
        ? '${totalHours}h ${totalMinutes}m'
        : totalMinutes > 0
        ? '${totalMinutes}m ${totalSeconds_remaining}s'
        : '${totalSeconds_remaining}s';

    // Create pie chart data from FILTERED apps with actual usage
    final appUsageData = filteredApps.where((app) => app.totalUsageSeconds > 0).map((app) {
      final index = _monitoredApps.indexOf(app);
      final percentage = totalSeconds > 0
          ? (app.totalUsageSeconds / totalSeconds) * 100.0
          : 0.0;

      return AppUsageData(
        appName: app.appName,
        percentage: percentage,
        color: _colors[index % _colors.length],
        usageSeconds: app.totalUsageSeconds,
      );
    }).toList();

    // Sort by usage for better visualization
    appUsageData.sort((a, b) => b.usageSeconds.compareTo(a.usageSeconds));

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Column(
        children: [
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 16,
              left: 20,
              right: 20,
            ),
            child: Row(
              children: [
                const Icon(Icons.home_rounded, color: Color(0xFF007BFF), size: 28),
                const SizedBox(width: 12),
                Text('Home', style: GoogleFonts.montserrat(fontSize: 24, fontWeight: FontWeight.w700, color: Colors.white)),
                const Spacer(),
                IconButton(
                  icon: const Icon(Icons.security, color: Colors.blue, size: 24),
                  onPressed: () async {
                    await AppUsageTracker.instance.openUsageStatsSettings();
                    Future.delayed(const Duration(seconds: 2), () {
                      if (mounted) _checkPermission();
                    });
                  },
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                children: [
                  if (!_hasPermission && !_checkingPermission)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [const Color(0xFFCC3333).withOpacity(0.2), const Color(0xFFAD1457).withOpacity(0.2)],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFCC3333), width: 2),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(children: [
                            const Icon(Icons.warning_rounded, color: Color(0xFFCC3333), size: 24),
                            const SizedBox(width: 12),
                            Expanded(child: Text('Permission Required', style: GoogleFonts.montserrat(fontSize: 16, fontWeight: FontWeight.w700, color: const Color(0xFFCC3333)))),
                          ]),
                          const SizedBox(height: 12),
                          Text(
                            'Usage access is required for automatic tracking. You can also enable the Accessibility service for best accuracy.',
                            style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w500, color: Colors.white.withOpacity(0.9)),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await AppUsageTracker.instance.openUsageStatsSettings();
                                Future.delayed(const Duration(seconds: 2), () {
                                  if (mounted) _checkPermission();
                                });
                              },
                              icon: const Icon(Icons.settings, size: 18),
                              label: Text('Open Settings & Grant Permission', style: GoogleFonts.montserrat(fontSize: 13, fontWeight: FontWeight.w700)),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCC3333),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // Pie Chart
                  Column(
                    children: [
                      SizedBox(
                        width: 256,
                        height: 256,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            if (appUsageData.isNotEmpty)
                              CustomPaint(
                                size: const Size(256, 256),
                                painter: PieChartPainter(appData: appUsageData),
                              )
                            else
                              Container(
                                width: 256,
                                height: 256,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: Colors.white.withOpacity(0.1), width: 3),
                                ),
                              ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  totalUsage,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 40,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  'Total Usage Today',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: const Color(0xFF9E9E9E),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        'Your App Usage Summary',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  // Filter Chips
                  Row(
                    children: [
                      Expanded(
                        child: _buildFilterChip(
                          'All Apps',
                          'all',
                          _monitoredApps.length,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFilterChip(
                          'Active',
                          'monitoring',
                          _monitoredApps.where((app) =>
                          app.totalUsageSeconds > 0 &&
                              app.totalUsageSeconds < app.timeLimitSeconds
                          ).length,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildFilterChip(
                          'Limit Reached',
                          'completed',
                          _monitoredApps.where((app) =>
                          app.totalUsageSeconds >= app.timeLimitSeconds &&
                              app.timeLimitSeconds > 0
                          ).length,
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'App List',
                      style: GoogleFonts.montserrat(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF007BFF)))
                      : filteredApps.isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.apps_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            _filterMode == 'all'
                                ? 'No apps being monitored'
                                : 'No apps in this category',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select apps to monitor from the Manage Apps page',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w400,
                              color: Colors.white.withOpacity(0.4),
                            ),
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    ),
                  )
                      : Column(
                    children: filteredApps.map((app) {
                      final usage = app.formattedUsage;
                      final limit = _formatSeconds(app.timeLimitSeconds);
                      final percentage = app.timeLimitSeconds > 0
                          ? (app.totalUsageSeconds / app.timeLimitSeconds * 100).clamp(0, 100).toInt()
                          : 0;
                      final isLimitReached = app.totalUsageSeconds >= app.timeLimitSeconds && app.timeLimitSeconds > 0;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isLimitReached
                                ? const Color(0xFFFF5252).withOpacity(0.5)
                                : Colors.white.withOpacity(0.1),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(borderRadius: BorderRadius.circular(12)),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(12),
                                    child: app.iconData != null
                                        ? Image.memory(app.iconData!, width: 48, height: 48, fit: BoxFit.cover)
                                        : Container(
                                      width: 48,
                                      height: 48,
                                      decoration: BoxDecoration(
                                        color: Colors.grey.withOpacity(0.2),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: const Icon(Icons.apps, color: Colors.white, size: 28),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        app.appName,
                                        style: GoogleFonts.montserrat(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w700,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '$usage / $limit',
                                        style: GoogleFonts.montserrat(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white.withOpacity(0.6),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isLimitReached
                                        ? const Color(0xFFFF5252).withOpacity(0.2)
                                        : const Color(0xFF007BFF).withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    '$percentage%',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: isLimitReached
                                          ? const Color(0xFFFF5252)
                                          : const Color(0xFF007BFF),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            if (app.timeLimitSeconds > 0) ...[
                              const SizedBox(height: 12),
                              ClipRRect(
                                borderRadius: BorderRadius.circular(4),
                                child: LinearProgressIndicator(
                                  value: (app.totalUsageSeconds / app.timeLimitSeconds).clamp(0.0, 1.0),
                                  backgroundColor: Colors.white.withOpacity(0.1),
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    percentage < 30
                                        ? const Color(0xFF4CAF50)
                                        : percentage < 70
                                        ? const Color(0xFFFF9800)
                                        : const Color(0xFFFF5252),
                                  ),
                                  minHeight: 6,
                                ),
                              ),
                            ],
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String mode, int count) {
    final isSelected = _filterMode == mode;
    return InkWell(
      onTap: () {
        setState(() {
          _filterMode = mode;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF007BFF) : const Color(0xFF1A1A1A),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF007BFF) : Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Column(
          children: [
            Text(
              '$count',
              style: GoogleFonts.montserrat(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: Colors.white.withOpacity(0.8),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatSeconds(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    final s = seconds % 60;
    if (h > 0) {
      return '${h}h ${m}m';
    } else if (m > 0) {
      return '${m}m';
    } else {
      return '${s}s';
    }
  }
}