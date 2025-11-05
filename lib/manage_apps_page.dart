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
  // Installed apps list
  List<Application> _apps = [];
  final Map<String, Uint8List?> _appIcons = {};
  bool _isLoading = true;

  // Track selected apps
  final Set<int> _selectedApps = {};
  
  // Track already monitored apps
  final Set<String> _monitoredPackages = {};

  @override
  void initState() {
    super.initState();
    _loadMonitoredApps();
    _loadInstalledApps();
  }
  
  Future<void> _loadMonitoredApps() async {
    try {
      final monitoredApps = await AppUsageTracker.instance.getMonitoredApps();
      setState(() {
        _monitoredPackages.clear();
        _monitoredPackages.addAll(monitoredApps.map((app) => app.packageName));
      });
    } catch (e) {
      print('Error loading monitored apps: $e');
    }
  }

  Future<void> _loadInstalledApps() async {
    try {
      // Get only user-installed apps with launch intent
      List<Application> apps = await DeviceApps.getInstalledApplications(
        includeAppIcons: true,
        includeSystemApps: false, // Exclude system apps
        onlyAppsWithLaunchIntent: true, // Only apps that can be launched
      );

      print('Loaded ${apps.length} apps'); // Debug output

      // Additional filtering to exclude system/default apps that might slip through
      apps = apps.where((app) {
        final packageName = app.packageName.toLowerCase();
        
        // Filter out system packages - these are definitely system apps
        final isSystemPackage = packageName.startsWith('com.android.') ||
            packageName.startsWith('android.') ||
            packageName.startsWith('com.google.android.gms') ||
            packageName.startsWith('com.qualcomm') ||
            packageName.startsWith('com.samsung.android') ||
            packageName.startsWith('com.miui.system') ||
            packageName.startsWith('com.huawei.system') ||
            packageName.startsWith('com.oppo.system') ||
            packageName.startsWith('com.vivo.system') ||
            packageName.startsWith('com.oneplus.system') ||
            packageName == 'com.android.settings' ||
            packageName == 'com.android.launcher' ||
            packageName == 'com.android.launcher2' ||
            packageName == 'com.android.launcher3' ||
            packageName == 'com.android.calculator2' ||
            packageName == 'com.android.deskclock' ||
            packageName == 'com.android.calendar' ||
            packageName == 'com.android.contacts' ||
            packageName == 'com.android.dialer' ||
            packageName == 'com.android.mms' ||
            packageName == 'com.android.camera2' ||
            packageName == 'com.android.gallery3d' ||
            packageName == 'com.android.documentsui' ||
            // Google Play Services and core system apps
            packageName == 'com.google.android.gsf' ||
            packageName == 'com.google.android.gsf.login' ||
            packageName == 'com.google.android.partnersetup' ||
            // Device manufacturer system apps
            packageName.contains('.system.') ||
            packageName.contains('.systemui.') ||
            packageName.contains('.launcher.');
        
        return !isSystemPackage;
      }).toList();

      print('Filtered to ${apps.length} user-installed apps'); // Debug output

      // Extract icons and cache them
      final Map<String, Uint8List?> iconCache = {};
      for (var app in apps) {
        if (app is ApplicationWithIcon) {
          iconCache[app.packageName] = app.icon;
        }
      }

      // Sort apps by name
      apps.sort((a, b) => a.appName.compareTo(b.appName));

      print('Final apps count: ${apps.length}'); // Debug output

      setState(() {
        _apps = apps;
        _appIcons.clear();
        _appIcons.addAll(iconCache);
        _isLoading = false;
        
        // Auto-select already monitored apps
        _selectedApps.clear();
        for (int i = 0; i < _apps.length; i++) {
          if (_monitoredPackages.contains(_apps[i].packageName)) {
            _selectedApps.add(i);
          }
        }
      });
    } catch (e, stackTrace) {
      print('Error loading apps: $e'); // Debug output
      print('Stack trace: $stackTrace'); // Debug output
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
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
                if (_selectedApps.isNotEmpty)
                  Text(
                    '${_selectedApps.length} selected',
                    style: GoogleFonts.montserrat(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFF007BFF),
                    ),
                  ),
              ],
            ),
          ),
          // Main Content
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
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        itemCount: _apps.length,
                        itemBuilder: (context, index) {
                          final app = _apps[index];
                          final isMonitored = _monitoredPackages.contains(app.packageName);
                          return _buildAppItem(
                            index,
                            app.appName,
                            app.packageName,
                            _appIcons[app.packageName],
                            isMonitored,
                          );
                        },
                      ),
          ),
          // Set Timer Button (shown when apps are selected)
          if (_selectedApps.isNotEmpty)
            Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              decoration: BoxDecoration(
                color: Colors.black,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.5),
                    blurRadius: 20,
                    spreadRadius: 0,
                    offset: const Offset(0, -5),
                  ),
                ],
              ),
              child: SafeArea(
                child: SizedBox(
                  width: double.infinity,
                  height: 56,
                    child: ElevatedButton.icon(
                    onPressed: () async {
                      final selectedAppsList = _selectedApps.map((index) {
                        final app = _apps[index];
                        return {
                          'name': app.appName,
                          'packageName': app.packageName,
                          'iconData': _appIcons[app.packageName], // Pass icon data
                        };
                      }).toList();
                      
                      final result = await Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => SetTimerPage(
                            selectedApps: selectedAppsList,
                          ),
                        ),
                      );
                      
                      // If monitoring was started successfully, clear selection
                      if (result == true) {
                        setState(() {
                          _selectedApps.clear();
                        });
                      }
                    },
                    icon: const Icon(
                      Icons.timer,
                      color: Colors.white,
                    ),
                    label: Text(
                      'Start Monitoring ${_selectedApps.length} App${_selectedApps.length > 1 ? 's' : ''}',
                      style: GoogleFonts.montserrat(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF007BFF),
                      foregroundColor: Colors.white,
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

  Widget _buildAppItem(
    int index,
    String appName,
    String packageName,
    Uint8List? iconData,
    bool isMonitored,
  ) {
    final isSelected = _selectedApps.contains(index);

    return InkWell(
      onTap: () {
        setState(() {
          if (_selectedApps.contains(index)) {
            _selectedApps.remove(index);
          } else {
            _selectedApps.add(index);
          }
        });
      },
      borderRadius: BorderRadius.circular(16),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: isSelected
              ? const Color(0xFF007BFF).withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            // App Icon
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                boxShadow: isSelected
                    ? [
                        BoxShadow(
                          color: const Color(0xFF007BFF).withOpacity(0.3),
                          blurRadius: 8,
                          spreadRadius: 0,
                        ),
                      ]
                    : null,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(14),
                child: iconData != null
                    ? Image.memory(
                        iconData,
                        width: 52,
                        height: 52,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: 52,
                            height: 52,
                            decoration: BoxDecoration(
                              color: Colors.grey.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: const Icon(Icons.apps, color: Colors.white, size: 28),
                          );
                        },
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
            ),
            const SizedBox(width: 16),
            // App Info
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
                  if (isMonitored) ...[
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 14,
                          color: const Color(0xFF4CAF50),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          'Monitoring',
                          style: GoogleFonts.montserrat(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFF4CAF50),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
            // Checkbox
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
}
