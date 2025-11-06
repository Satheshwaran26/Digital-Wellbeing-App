import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'app_usage_tracker.dart';
import 'dart:typed_data';


class PieChartPainter extends CustomPainter {
  final List<AppUsageData> appData;

  PieChartPainter({
    required this.appData,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 3;
    final cornerRadius = 10.0; // Border radius for rounded corners
    
    // Add gap between segments only if there are multiple apps
    final gapAngle = appData.length > 1 ? (2.5 * math.pi / 180.0) : 0.0; // 2.5 degrees gap
    final totalGapAngle = gapAngle * appData.length;
    
    // Calculate available angle for segments (subtract total gaps)
    final availableAngle = (2 * math.pi) - totalGapAngle;

    double startAngle = -math.pi / 2; // Start from top

    for (int i = 0; i < appData.length; i++) {
      final data = appData[i];
      // Calculate sweep angle proportionally, accounting for gaps
      final sweepAngle = (data.percentage / 100) * availableAngle;

      // Create path for rounded segment
      final path = Path();
      
      // Calculate start and end angles (with gap consideration)
      final startRadians = startAngle;
      final endRadians = startAngle + sweepAngle;
      
      // Calculate points on the outer circle
      final startOuterX = center.dx + radius * math.cos(startRadians);
      final startOuterY = center.dy + radius * math.sin(startRadians);
      final endOuterX = center.dx + radius * math.cos(endRadians);
      final endOuterY = center.dy + radius * math.sin(endRadians);
      
      // Move to center
      path.moveTo(center.dx, center.dy);
      
      // Line to start point (with rounded corner offset)
      final startInnerX = center.dx + (radius - cornerRadius) * math.cos(startRadians);
      final startInnerY = center.dy + (radius - cornerRadius) * math.sin(startRadians);
      path.lineTo(startInnerX, startInnerY);
      
      // Rounded corner at start (outer edge)
      path.quadraticBezierTo(
        startOuterX,
        startOuterY,
        center.dx + (radius - cornerRadius * 0.5) * math.cos(startRadians + sweepAngle * 0.05),
        center.dy + (radius - cornerRadius * 0.5) * math.sin(startRadians + sweepAngle * 0.05),
      );
      
      // Arc along outer edge
      final rect = Rect.fromCircle(center: center, radius: radius);
      path.arcTo(
        rect,
        startRadians,
        sweepAngle,
        false,
      );
      
      // Rounded corner at end (outer edge)
      final endInnerX = center.dx + (radius - cornerRadius) * math.cos(endRadians);
      final endInnerY = center.dy + (radius - cornerRadius) * math.sin(endRadians);
      path.quadraticBezierTo(
        endOuterX,
        endOuterY,
        endInnerX,
        endInnerY,
      );
      
      // Arc back to center along inner edge
      final innerRect = Rect.fromCircle(center: center, radius: radius - cornerRadius);
      path.arcTo(
        innerRect,
        endRadians,
        -sweepAngle,
        false,
      );
      
      // Close path
      path.close();

      final paint = Paint()
        ..color = data.color
        ..style = PaintingStyle.fill;

      canvas.drawPath(path, paint);

      // Move to next segment position (add sweep angle + gap)
      startAngle += sweepAngle + gapAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class AppUsageData {
  final String appName;
  final double percentage;
  final Color color;

  AppUsageData({
    required this.appName,
    required this.percentage,
    required this.color,
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
  bool _hasOverlayPermission = false;
  bool _overlayServiceRunning = false;
  final List<Color> _colors = [
    const Color(0xFF007BFF), // Blue
    const Color(0xFFCC3333), // Red
    const Color(0xFFAD1457), // Pink
    const Color(0xFF1565C0), // Dark Blue
    const Color(0xFF00695C), // Teal
    const Color(0xFF2E7D32), // Green
    const Color(0xFFF57C00), // Orange
    const Color(0xFF7B1FA2), // Purple
    const Color(0xFFC62828), // Dark Red
    const Color(0xFF0277BD), // Light Blue
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
    _loadMonitoredApps();
    _loadOverlayServiceState();
    // Refresh data periodically
    _startPeriodicRefresh();
  }
  
  Future<void> _loadOverlayServiceState() async {
    // Load saved state from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    if (mounted) {
      setState(() {
        _overlayServiceRunning = prefs.getBool('overlay_service_running') ?? false;
      });
    }
  }
  
  Future<void> _saveOverlayServiceState(bool running) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('overlay_service_running', running);
  }
  
  Future<void> _checkPermission() async {
    setState(() {
      _checkingPermission = true;
    });
    
    final hasPermission = await AppUsageTracker.instance.checkUsageStatsPermission();
    final hasOverlay = await AppUsageTracker.instance.checkOverlayPermission();
    
    if (mounted) {
      setState(() {
        _hasPermission = hasPermission;
        _hasOverlayPermission = hasOverlay;
        _checkingPermission = false;
      });
    }
  }
  
  Future<void> _toggleOverlayService() async {
    if (!_hasOverlayPermission) {
      // Request overlay permission
      await AppUsageTracker.instance.requestOverlayPermission();
      // Re-check after delay
      await Future.delayed(const Duration(seconds: 2));
      _checkPermission();
      return;
    }
    
    if (_overlayServiceRunning) {
      // Stop service
      await AppUsageTracker.instance.stopMonitoringService();
      await _saveOverlayServiceState(false);
      setState(() {
        _overlayServiceRunning = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Overlay monitoring OFF', style: GoogleFonts.montserrat()),
            backgroundColor: const Color(0xFFCC3333),
          ),
        );
      }
    } else {
      // Start service
      await AppUsageTracker.instance.startMonitoringService();
      await _saveOverlayServiceState(true);
      setState(() {
        _overlayServiceRunning = true;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Overlay monitoring ON! Milestones will show when using other apps.', style: GoogleFonts.montserrat()),
            backgroundColor: const Color(0xFF007BFF),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Re-check permission when app resumes
      _checkPermission();
      // Refresh when app comes back to foreground
      _loadMonitoredApps();
      // Also refresh after delays to ensure usage data is updated
      Future.delayed(const Duration(milliseconds: 500), () {
        if (mounted) {
          _loadMonitoredApps();
        }
      });
      Future.delayed(const Duration(seconds: 2), () {
        if (mounted) {
          _loadMonitoredApps();
        }
      });
    }
  }

  void refreshData() {
    _loadMonitoredApps();
  }

  void _startPeriodicRefresh() {
    // Refresh every 3 seconds to update usage times more frequently
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        _loadMonitoredApps();
        _startPeriodicRefresh();
      }
    });
  }

  Future<void> _loadMonitoredApps() async {
    try {
      // Ensure tracker is initialized
      await AppUsageTracker.instance.initialize();
      
      final apps = await AppUsageTracker.instance.getMonitoredApps();
      
      // Update debug info
      final totalUsage = apps.fold<int>(0, (sum, app) => sum + app.totalUsageSeconds);
      
      // Sort by usage time (descending) - apps with usage first, then apps with no usage
      apps.sort((a, b) {
        // If both have usage, sort by usage descending
        if (a.totalUsageSeconds > 0 && b.totalUsageSeconds > 0) {
          return b.totalUsageSeconds.compareTo(a.totalUsageSeconds);
        }
        // If one has usage and one doesn't, put the one with usage first
        if (a.totalUsageSeconds > 0 && b.totalUsageSeconds == 0) {
          return -1;
        }
        if (a.totalUsageSeconds == 0 && b.totalUsageSeconds > 0) {
          return 1;
        }
        // If both have no usage, sort alphabetically
        return a.appName.compareTo(b.appName);
      });
      
      if (mounted) {
        setState(() {
          _monitoredApps = apps;
          _isLoading = false;
        });
      }
    } catch (e) {
      print('Error loading monitored apps: $e');
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }
  


  @override
  Widget build(BuildContext context) {
    // Calculate total usage
    final totalSeconds = _monitoredApps.fold<int>(
      0,
      (sum, app) => sum + app.totalUsageSeconds,
    );
    final totalHours = totalSeconds ~/ 3600;
    final totalMinutes = (totalSeconds % 3600) ~/ 60;
    final totalUsage = totalHours > 0 
        ? '${totalHours}h ${totalMinutes}m'
        : '${totalMinutes}m';
    
    // Convert monitored apps to AppUsageData for pie chart
    final appUsageData = _monitoredApps.asMap().entries.map((entry) {
      final index = entry.key;
      final app = entry.value;
      final percentage = totalSeconds > 0
          ? (app.totalUsageSeconds / totalSeconds) * 100.0
          : 0.0;
      
      return AppUsageData(
        appName: app.appName,
        percentage: percentage,
        color: _colors[index % _colors.length],
      );
    }).toList();
    
    // Normalize percentages to always sum to 100%
    final totalPercentage = appUsageData.fold<double>(
      0.0,
      (sum, data) => sum + data.percentage,
    );
    
    final normalizedAppData = totalPercentage > 0
        ? appUsageData.map((data) {
            return AppUsageData(
              appName: data.appName,
              percentage: (data.percentage / totalPercentage) * 100.0,
              color: data.color,
            );
          }).toList()
        : <AppUsageData>[];

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Column(
        children: [
          // Top App Bar
          Container(
            padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 12,
              bottom: 16,
              left: 20,
              right: 20,
            ),
            child: Row(
              children: [
                Icon(
                 Icons.home_rounded,
                  color: const Color(0xFF007BFF),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Text(
                  'Home',
                  style: GoogleFonts.montserrat(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                
                // Test Milestone Button
                IconButton(
                  icon: const Icon(
                    Icons.emoji_events,
                    color: Color(0xFFFFD700),
                    size: 24,
                  ),
                  onPressed: () async {
                    await AppUsageTracker.instance.testOverlay();
                  },
                ),
                
                // Request Permissions Button
                IconButton(
                  icon: const Icon(
                    Icons.security,
                    color: Colors.blue,
                    size: 24,
                  ),
                  onPressed: () async {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Requesting permissions...'),
                        duration: Duration(seconds: 2),
                      ),
                    );
                    
                    final result = await AppUsageTracker.instance.requestAllPermissions();
                    
                    if (result['allGranted'] == true) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('✅ All permissions granted!'),
                          backgroundColor: Colors.green,
                          duration: Duration(seconds: 3),
                        ),
                      );
                      // Refresh the permission status
                      _checkPermission();
                    } else {
                      String message = '⚠️ Permissions needed:\n';
                      if (result['usageStats'] != true) message += '• Usage Stats\n';
                      if (result['overlay'] != true) message += '• Overlay Permission';
                      
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(message),
                          backgroundColor: Colors.orange,
                          duration: const Duration(seconds: 5),
                        ),
                      );
                    }
                  },
                ),
                
              ],
            ),
          ),
            // Main Content
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              child: Column(
                children: [
                  // Permission Warning (always show if no permission)
                  if (!_hasPermission && !_checkingPermission)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [
                            const Color(0xFFCC3333).withOpacity(0.2),
                            const Color(0xFFAD1457).withOpacity(0.2),
                          ],
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: const Color(0xFFCC3333),
                          width: 2,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.warning_rounded,
                                color: Color(0xFFCC3333),
                                size: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Permission Required',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFCC3333),
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Automatic app tracking requires Usage Stats permission. Without it, tracking will NOT work.',
                            style: GoogleFonts.montserrat(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                          const SizedBox(height: 16),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton.icon(
                              onPressed: () async {
                                await AppUsageTracker.instance.openUsageStatsSettings();
                                // Re-check permission after a delay
                                Future.delayed(const Duration(seconds: 2), () {
                                  if (mounted) {
                                    _checkPermission();
                                  }
                                });
                              },
                              icon: const Icon(Icons.settings, size: 18),
                              label: Text(
                                'Open Settings & Grant Permission',
                                style: GoogleFonts.montserrat(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFFCC3333),
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                  // App Usage Summary Chart
                  Column(
                    children: [
                      SizedBox(
                        width: 256,
                        height: 256,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            CustomPaint(
                              size: const Size(256, 256),
                              painter: PieChartPainter(
                                appData: normalizedAppData,
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
                  // App List Section
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
                      ? const Center(
                          child: CircularProgressIndicator(
                            color: Color(0xFF007BFF),
                          ),
                        )
                      : _monitoredApps.isEmpty
                          ? Center(
                              child: Padding(
                                padding: const EdgeInsets.all(32.0),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.apps_outlined,
                                      size: 64,
                                      color: Colors.white.withOpacity(0.3),
                                    ),
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
                              children: _monitoredApps.map((app) {
                                return _buildAppListItem(
                                  app.appName,
                                  app.formattedUsage,
                                  app.iconData,
                                  app.packageName,
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

  Widget _buildAppListItem(String appName, String usage, Uint8List? iconData, String packageName) {
    // Parse usage to check if it's 0
    final isZeroUsage = usage == '0s' || usage == '0m' || usage == '0h';
    
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(
            color: const Color(0xFF004C99).withOpacity(0.3),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: iconData != null
                  ? Image.memory(
                      iconData,
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          width: 40,
                          height: 40,
                          color: Colors.grey.withOpacity(0.2),
                          child: const Icon(Icons.apps, color: Colors.white, size: 24),
                        );
                      },
                    )
                  : Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(Icons.apps, color: Colors.white, size: 24),
                    ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              appName,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),

          const SizedBox(width: 8),
          Text(
            usage,
            style: GoogleFonts.montserrat(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: isZeroUsage 
                  ? Colors.white.withOpacity(0.5)
                  : const Color(0xFF007BFF),
            ),
          ),
        ],
      ),
    );
  }
}

