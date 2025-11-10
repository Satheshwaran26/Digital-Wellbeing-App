import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_apps/device_apps.dart';
import 'dart:typed_data';
import 'set_timer_page.dart';
import 'app_usage_tracker.dart';

class ManageAppsPage extends StatefulWidget {
  const ManageAppsPage({super.key});

  @override
  State<ManageAppsPage> createState() => _ManageAppsPageState();
}

class _ManageAppsPageState extends State<ManageAppsPage> {
  List<Application> _apps = [];
  final Map<String, Uint8List?> _appIcons = {};
  bool _isLoading = true;

  final Set<int> _selectedApps = {};
  final Map<String, MonitoredApp> _monitoredMap = {};
  final Set<String> _blockedPackages = {};

  @override
  void initState() {
    super.initState();
    _loadMonitoredApps();
    _loadInstalledApps();
    _loadBlockedAppsNative();
  }

  Future<void> _loadBlockedAppsNative() async {
    try {
      final blocked = await AppUsageTracker.instance.getBlockedPackagesNative();
      setState(() {
        _blockedPackages
          ..clear()
          ..addAll(blocked);
      });
    } catch (e) {
      debugPrint('Error loading blocked packages (native): $e');
    }
  }

  Future<void> _loadMonitoredApps() async {
    try {
      final monitoredApps = await AppUsageTracker.instance.getMonitoredApps();
      setState(() {
        _monitoredMap.clear();
        for (final m in monitoredApps) {
          _monitoredMap[m.packageName] = m;
        }
      });
    } catch (e) {
      debugPrint('Error loading monitored apps: $e');
    }
  }

  Future<void> _refreshAll() async {
    await _loadMonitoredApps();
    await _loadBlockedAppsNative();
    setState(() {});
  }

  Future<void> _loadInstalledApps() async {
    try {
      List<Application> apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: false,
        onlyAppsWithLaunchIntent: true,
      );

      apps = apps.where((app) {
        final packageName = app.packageName.toLowerCase();
        final isSystemPackage = packageName.startsWith('com.android.') ||
            packageName.startsWith('android.') ||
            packageName.startsWith('com.google.android.gms') ||
            packageName.contains('.system.') ||
            packageName.contains('.systemui.') ||
            packageName.contains('.launcher.');
        return !isSystemPackage;
      }).toList();

      final Map<String, Uint8List?> iconCache = {};
      for (var app in apps) {
        if (app is ApplicationWithIcon) {
          iconCache[app.packageName] = app.icon;
        }
      }

      apps.sort((a, b) => a.appName.compareTo(b.appName));

      setState(() {
        _apps = apps;
        _appIcons
          ..clear()
          ..addAll(iconCache);
        _isLoading = false;
        _selectedApps.clear();
        for (int i = 0; i < _apps.length; i++) {
          if (_monitoredMap.containsKey(_apps[i].packageName)) {
            _selectedApps.add(i);
          }
        }
      });
    } catch (e, stackTrace) {
      debugPrint('Error loading apps: $e');
      debugPrint('Stack trace: $stackTrace');
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _openSetTimer() async {
    final selectedAppsList = _selectedApps.map((index) {
      final app = _apps[index];
      return {
        'name': app.appName,
        'packageName': app.packageName,
        'iconData': _appIcons[app.packageName],
      };
    }).toList();

    final result = await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SetTimerPage(
          selectedApps: selectedAppsList,
        ),
      ),
    );

    if (result == true) {
      await _refreshAll();
      setState(() {
        _selectedApps.clear();
      });
    }
  }

// In your _unblockApp function, replace with this:

  // Replace your _unblockApp function with this:
// Replace your _unblockApp function with this:

  Future<void> _unblockApp(String packageName) async {
    final appName = _monitoredMap[packageName]?.appName ?? packageName;

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Unblock $appName?',
          style: GoogleFonts.montserrat(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'This will remove $appName from monitoring completely. You can add it again later.',
          style: GoogleFonts.montserrat(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.montserrat(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF007BFF),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: Text(
              'Unblock',
              style: GoogleFonts.montserrat(
                color: Colors.white,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Show loading
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFF007BFF)),
      ),
    );

    try {
      debugPrint('🔓 UI: Starting unblock (removal) for $packageName');

      // Call unblock (which removes the app)
      await AppUsageTracker.instance.unblockApp(packageName);

      // Wait to ensure everything is processed
      await Future.delayed(const Duration(milliseconds: 800));

      // Refresh UI
      await _loadMonitoredApps();
      await _loadBlockedAppsNative();

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Clear selection if app was selected
      setState(() {
        final appIndex = _apps.indexWhere((app) => app.packageName == packageName);
        if (appIndex != -1) {
          _selectedApps.remove(appIndex);
        }
      });

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '$appName removed from monitoring',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF4CAF50),
            duration: const Duration(seconds: 3),
            behavior: SnackBarBehavior.floating,
          ),
        );

        debugPrint('✅ UI: Unblock (removal) complete for $packageName');
      }
    } catch (e, stackTrace) {
      debugPrint('❌ UI: Unblock error: $e');
      debugPrint('Stack: $stackTrace');

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show error
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.error, color: Colors.white),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Failed to unblock: $e',
                    style: GoogleFonts.montserrat(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 5),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedCount = _selectedApps.length;
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
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back,
                    color: Color(0xFF007BFF),
                    size: 24,
                  ),
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Manage Apps',
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                if (selectedCount > 0)
                  Text(
                    '$selectedCount selected',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF007BFF),
                    ),
                  ),
              ],
            ),
          ),
          Expanded(
            child: _isLoading
                ? const Center(
              child: CircularProgressIndicator(
                color: Color(0xFF007BFF),
              ),
            )
                : _apps.isEmpty
                ? Center(
              child: Text(
                'No apps found',
                style: GoogleFonts.montserrat(
                  fontSize: 16,
                  color: Colors.white.withOpacity(0.6),
                ),
              ),
            )
                : RefreshIndicator(
              onRefresh: _refreshAll,
              color: const Color(0xFF007BFF),
              child: ListView.builder(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                itemCount: _apps.length,
                itemBuilder: (context, index) {
                  final app = _apps[index];
                  final monitored = _monitoredMap[app.packageName];
                  final isBlocked = monitored?.isBlocked == true || _blockedPackages.contains(app.packageName);
                  return _buildAppItem(
                    index: index,
                    appName: app.appName,
                    packageName: app.packageName,
                    iconData: _appIcons[app.packageName],
                    monitoredApp: monitored,
                    isBlocked: isBlocked,
                  );
                },
              ),
            ),
          ),
          if (selectedCount > 0)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: Colors.black,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                  child: ElevatedButton.icon(
                    onPressed: _openSetTimer,
                    icon: const Icon(Icons.timer, color: Colors.white),
                    label: Text(
                      'Set Time Limit for $selectedCount App${selectedCount > 1 ? 's' : ''}',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007BFF),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      elevation: 2,
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildAppItem({
    required int index,
    required String appName,
    required String packageName,
    required Uint8List? iconData,
    required MonitoredApp? monitoredApp,
    required bool isBlocked,
  }) {
    final isSelected = _selectedApps.contains(index);
    final timeLimit = monitoredApp?.timeLimitSeconds;
    final usage = monitoredApp?.totalUsageSeconds ?? 0;
    final limitStr = timeLimit != null
        ? _formatDuration(timeLimit)
        : '-';
    final usageStr = _formatDuration(usage);

    return InkWell(
      onTap: () {
        setState(() {
          if (isSelected) {
            _selectedApps.remove(index);
          } else {
            _selectedApps.add(index);
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF007BFF).withOpacity(0.12)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isBlocked
                ? Colors.redAccent.withOpacity(0.7)
                : Colors.white.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: iconData != null
                  ? Image.memory(
                iconData,
                width: 52,
                height: 52,
                fit: BoxFit.cover,
              )
                  : Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: Colors.grey.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(Icons.apps, color: Colors.white, size: 28),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    appName,
                    style: GoogleFonts.montserrat(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (monitoredApp != null)
                    Row(
                      children: [
                        Icon(
                          Icons.watch_later_outlined,
                          size: 14,
                          color: Colors.white.withOpacity(0.7),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '$usageStr / $limitStr',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: Colors.white.withOpacity(0.7),
                          ),
                        ),
                      ],
                    ),
                  if (isBlocked) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.block, size: 14, color: Colors.redAccent),
                        const SizedBox(width: 4),
                        Text(
                          'Blocked',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.redAccent,
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            if (isBlocked)
              TextButton(
                onPressed: () => _unblockApp(packageName),
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  backgroundColor: Colors.redAccent.withOpacity(0.2),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  'UNBLOCK',
                  style: GoogleFonts.montserrat(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.8,
                  ),
                ),
              )
            else
              Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: isSelected
                        ? const Color(0xFF007BFF)
                        : Colors.white.withOpacity(0.3),
                    width: 2,
                  ),
                  color: isSelected
                      ? const Color(0xFF007BFF)
                      : Colors.transparent,
                ),
                child: isSelected
                    ? const Icon(
                  Icons.check,
                  size: 14,
                  color: Colors.white,
                )
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  String _formatDuration(int totalSeconds) {
    final h = totalSeconds ~/ 3600;
    final m = (totalSeconds % 3600) ~/ 60;
    final s = totalSeconds % 60;
    if (h > 0) {
      return '${h}h ${m}m';
    } else if (m > 0) {
      return '${m}m';
    } else {
      return '${s}s';
    }
  }
}