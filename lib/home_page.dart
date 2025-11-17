import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:my_app/weekly_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_usage_tracker.dart';
import 'dart:typed_data';

class PieChartPainter extends CustomPainter {
  final List<AppUsageData> appData;

  PieChartPainter({required this.appData});

  @override
  void paint(Canvas canvas, Size size) {
    if (appData.isEmpty) {
      // Draw empty circle
      final emptyPaint = Paint()
        ..color = Colors.white.withOpacity(0.05)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 20;

      canvas.drawCircle(
        Offset(size.width / 2, size.height / 2),
        size.width / 2 - 40,
        emptyPaint,
      );
      return;
    }

    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 40;
    final strokeWidth = 20.0; // Thin stroke like reference

    // Draw subtle background circle
    final bgPaint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    canvas.drawCircle(center, radius, bgPaint);

    // Calculate total
    final totalSeconds = appData.fold<double>(0.0, (sum, data) => sum + data.usageSeconds.toDouble());

    // Gap between segments (in radians)
    final gapAngle = 0.05; // Small gap like reference image
    final totalGapAngle = gapAngle * appData.length;
    final usableAngle = (2 * math.pi) - totalGapAngle;

    double startAngle = -math.pi / 2; // Start from top

    for (int i = 0; i < appData.length; i++) {
      final data = appData[i];
      final sweepAngle = (data.usageSeconds / totalSeconds) * usableAngle;

      if (sweepAngle <= 0) continue;

      // Draw arc with rounded caps
      final paint = Paint()
        ..color = data.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.round;

      final rect = Rect.fromCircle(center: center, radius: radius);
      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);

      // Draw usage label outside the arc (like reference image)
      final midAngle = startAngle + (sweepAngle / 2);
      final labelRadius = radius + 35; // Position outside the ring
      final labelX = center.dx + labelRadius * math.cos(midAngle);
      final labelY = center.dy + labelRadius * math.sin(midAngle);

      // Format time for label
      final hours = data.usageSeconds / 3600;
      final minutes = (data.usageSeconds % 3600) / 60;
      final labelText = hours >= 1
          ? '${hours.toStringAsFixed(1)}h'
          : '${minutes.toInt()}m';

      final textPainter = TextPainter(
        text: TextSpan(
          text: labelText,
          style: TextStyle(
            color: data.color,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        textDirection: TextDirection.ltr,
      );

      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(labelX - textPainter.width / 2, labelY - textPainter.height / 2),
      );

      startAngle += sweepAngle + gapAngle; // Add gap after each segment
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

  final List<Color> _colors = [
    const Color(0xFF9C27B0), // Purple
    const Color(0xFF00BCD4), // Cyan
    const Color(0xFFFF5252), // Red
    const Color(0xFFFF9800), // Orange
    const Color(0xFF2196F3), // Blue
    const Color(0xFF4CAF50), // Green
    const Color(0xFFFFEB3B), // Yellow
    const Color(0xFFE91E63), // Pink
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

    _requestPermissions();

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


  Future<void> _requestPermissions() async {
    // Request overlay permission for better blocking
    await AppUsageTracker.instance.requestOverlayPermission();
  }


  Future<void> _saveToWeeklyStorage() async {
    try {
      Map<String, int> dailyUsage = {};
      for (var app in _monitoredApps) {
        if (app.totalUsageSeconds > 0) {
          dailyUsage[app.packageName] = app.totalUsageSeconds;
        }
      }

      if (dailyUsage.isNotEmpty) {
        await WeeklyStorageService.saveDailyUsage(dailyUsage);
      }
    } catch (e) {
      debugPrint('Error saving to weekly storage: $e');
    }
  }

// Update _startPeriodicRefresh method
  void _startPeriodicRefresh() {
    Future.delayed(const Duration(seconds: 3), () async {
      if (!mounted) return;
      await _loadMonitoredApps();
      await _saveToWeeklyStorage(); // Add this line
      _startPeriodicRefresh();
    });
  }



  Future<void> _loadMonitoredApps() async {
    try {
      await AppUsageTracker.instance.initialize();
      await AppUsageTracker.instance.pullUsageSnapshotAndMerge();
      final apps = await AppUsageTracker.instance.getMonitoredApps();

      // Sort by usage time
      apps.sort((a, b) => b.totalUsageSeconds.compareTo(a.totalUsageSeconds));

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






  @override
  Widget build(BuildContext context) {
    // Calculate total for MONITORED APPS ONLY
    final totalSeconds = _monitoredApps.fold<int>(0, (sum, app) => sum + app.totalUsageSeconds);
    final totalHours = totalSeconds ~/ 3600;
    final totalMinutes = (totalSeconds % 3600) ~/ 60;

    final totalUsage = totalHours > 0
        ? '${totalHours}h ${totalMinutes}m'
        : totalMinutes > 0
        ? '${totalMinutes}m'
        : '${totalSeconds}s';

    // Chart data - MONITORED APPS with usage > 0
    final appsWithUsage = _monitoredApps.where((app) => app.totalUsageSeconds > 0).toList();
    final appUsageData = appsWithUsage.take(8).map((app) {
      final index = appsWithUsage.indexOf(app);
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
                            'Usage access is required for tracking apps.',
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

                  // Clean Donut Chart - Like Reference Image
                  Column(
                    children: [
                      Container(
                        width: 300,
                        height: 300,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Colors.white.withOpacity(0.01),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(300, 300),
                              painter: PieChartPainter(appData: appUsageData),
                            ),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  totalUsage,
                                  style: GoogleFonts.montserrat(
                                    fontSize: 42,
                                    fontWeight: FontWeight.w800,
                                    color: Colors.white,
                                    letterSpacing: -1,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Total Today',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600,
                                    color: const Color(0xFF9E9E9E),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Compact Legend
                      if (appUsageData.isNotEmpty)
                        Wrap(
                          spacing: 10,
                          runSpacing: 8,
                          alignment: WrapAlignment.center,
                          children: appUsageData.take(4).map((data) {
                            return Container(
                              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                              decoration: BoxDecoration(
                                color: data.color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: data.color.withOpacity(0.3), width: 1),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color: data.color,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    data.appName.length > 10
                                        ? '${data.appName.substring(0, 10)}...'
                                        : data.appName,
                                    style: GoogleFonts.montserrat(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Colors.white.withOpacity(0.85),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }).toList(),
                        )
                      else
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Text(
                            'No monitored apps with usage yet',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.5),
                            ),
                          ),
                        ),
                    ],
                  ),

                  const SizedBox(height: 32),

                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Monitored Apps',
                        style: GoogleFonts.montserrat(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      Text(
                        '${_monitoredApps.length} apps',
                        style: GoogleFonts.montserrat(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  _isLoading
                      ? const Center(child: CircularProgressIndicator(color: Color(0xFF007BFF)))
                      : _monitoredApps.isEmpty
                      ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(32.0),
                      child: Column(
                        children: [
                          Icon(Icons.apps_outlined, size: 64, color: Colors.white.withOpacity(0.3)),
                          const SizedBox(height: 16),
                          Text(
                            'No apps being monitored',
                            style: GoogleFonts.montserrat(
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.6),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Select apps from Manage Apps page',
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
                    children: _monitoredApps.map((app) {
                      final usage = app.formattedUsage;
                      final limit = _formatSeconds(app.timeLimitSeconds);
                      final percentage = app.timeLimitSeconds > 0
                          ? ((app.totalUsageSeconds / app.timeLimitSeconds) * 100).clamp(0, 100).toInt()
                          : 0;
                      final isLimitReached = percentage >= 100;

                      return Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1A1A1A),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: isLimitReached
                                ? const Color(0xFFFF5252).withOpacity(0.5)
                                : const Color(0xFF007BFF).withOpacity(0.3),
                            width: 2,
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
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
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

  String _formatSeconds(int seconds) {
    final h = seconds ~/ 3600;
    final m = (seconds % 3600) ~/ 60;
    if (h > 0) {
      return '${h}h ${m}m';
    } else if (m > 0) {
      return '${m}m';
    } else {
      return '${seconds}s';
    }
  }
}