import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:typed_data';
import 'app_usage_tracker.dart';
import 'package:device_apps/device_apps.dart';

class SetTimerPage extends StatefulWidget {
  final List<Map<String, dynamic>>? selectedApps;

  const SetTimerPage({
    super.key,
    this.selectedApps,
  });

  @override
  State<SetTimerPage> createState() => _SetTimerPageState();
}

class _SetTimerPageState extends State<SetTimerPage> {
  final Map<String, Uint8List?> _iconCache = {};
  bool _isSaving = false;
  int _selectedHours = 0;
  int _selectedMinutes = 30;

  @override
  void initState() {
    super.initState();
    _loadIcons();
  }

  Future<void> _loadIcons() async {
    if (widget.selectedApps == null) return;

    for (var app in widget.selectedApps!) {
      final packageName = app['packageName'] as String?;
      final iconData = app['iconData'];
      if (packageName == null) continue;
      if (iconData != null && iconData is Uint8List) {
        _iconCache[packageName] = iconData;
      } else {
        try {
          final info = await DeviceApps.getApp(packageName, true);
          if (info is ApplicationWithIcon) {
            _iconCache[packageName] = info.icon;
          }
        } catch (_) {}
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _quickSetTimer(int seconds) async {
    if (widget.selectedApps == null || widget.selectedApps!.isEmpty) return;
    await _saveLimits(seconds);
  }

  Future<void> _saveLimits(int totalSeconds) async {
    setState(() {
      _isSaving = true;
    });

    try {
      final apps = widget.selectedApps!;
      // Add monitored apps with per-app limit
      await AppUsageTracker.instance.addMonitoredAppsWithLimit(apps, totalSeconds);

      // (Optional) start native monitoring service
      await AppUsageTracker.instance.restartNativeMonitoring();

      if (mounted) {
        Navigator.of(context).pop(true);
        final hours = totalSeconds ~/ 3600;
        final minutes = (totalSeconds % 3600) ~/ 60;
        final timeStr = hours > 0 ? '${hours}h ${minutes}m' : '${minutes}m';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Monitoring ${apps.length} app(s) with $timeStr limit each',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: const Color(0xFF007BFF),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Error: $e',
              style: GoogleFonts.montserrat(),
            ),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final apps = widget.selectedApps ?? [];
    final count = apps.length;
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
                  icon: const Icon(Icons.arrow_back, color: Color(0xFF007BFF), size: 24),
                  onPressed: () => Navigator.of(context).pop(),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Set Time Limit ($count App${count > 1 ? 's' : ''})',
                    style: GoogleFonts.montserrat(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  if (count > 0)
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 0.8,
                      ),
                      itemCount: apps.length,
                      itemBuilder: (context, index) {
                        final app = apps[index];
                        final packageName = app['packageName'] as String? ?? '';
                        final iconData = _iconCache[packageName];
                        return Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(14),
                              child: iconData != null
                                  ? Image.memory(
                                iconData,
                                width: 56,
                                height: 56,
                                fit: BoxFit.cover,
                              )
                                  : Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(14),
                                ),
                                child: const Icon(Icons.apps, color: Colors.white, size: 28),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              app['name'] as String? ?? '',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                            ),
                          ],
                        );
                      },
                    ),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: const Color(0xFF007BFF).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF007BFF).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.info_outline, color: Color(0xFF007BFF), size: 24),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Each selected app will share the SAME time limit you set below. After exceeding the limit the app will be blocked.',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.white.withOpacity(0.9),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),
                  Text(
                    'Per-App Time Limit',
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                      color: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Set how long each app may be used before it is blocked',
                    style: GoogleFonts.montserrat(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: Colors.white.withOpacity(0.6),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF007BFF).withOpacity(0.15),
                          const Color(0xFF00BFFF).withOpacity(0.15),
                        ],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF007BFF).withOpacity(0.3),
                        width: 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Column(
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedHours = (_selectedHours + 1) % 24;
                                });
                              },
                              icon: const Icon(Icons.keyboard_arrow_up, color: Color(0xFF007BFF), size: 32),
                            ),
                            Container(
                              width: 80,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _selectedHours.toString().padLeft(2, '0'),
                                style: GoogleFonts.montserrat(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedHours = (_selectedHours - 1) % 24;
                                  if (_selectedHours < 0) _selectedHours = 23;
                                });
                              },
                              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF007BFF), size: 32),
                            ),
                            Text(
                              'Hours',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          child: Text(
                            ':',
                            style: GoogleFonts.montserrat(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        Column(
                          children: [
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedMinutes = (_selectedMinutes + 5) % 60;
                                });
                              },
                              icon: const Icon(Icons.keyboard_arrow_up, color: Color(0xFF007BFF), size: 32),
                            ),
                            Container(
                              width: 80,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(
                                _selectedMinutes.toString().padLeft(2, '0'),
                                style: GoogleFonts.montserrat(
                                  fontSize: 40,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() {
                                  _selectedMinutes = (_selectedMinutes - 5) % 60;
                                  if (_selectedMinutes < 0) _selectedMinutes = 55;
                                });
                              },
                              icon: const Icon(Icons.keyboard_arrow_down, color: Color(0xFF007BFF), size: 32),
                            ),
                            Text(
                              'Minutes',
                              style: GoogleFonts.montserrat(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  InkWell(
                    onTap: _isSaving ? null : () => _quickSetTimer(60),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            const Color(0xFF2E7D32).withOpacity(0.2),
                            const Color(0xFF4CAF50).withOpacity(0.2),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFF4CAF50), width: 2),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF4CAF50),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.flash_on, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Quick Start: 1 Minute',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '1 min limit per app',
                                  style: GoogleFonts.montserrat(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.white.withOpacity(0.7),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios, color: Color(0xFF4CAF50), size: 20),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 40),
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving
                          ? null
                          : () async {
                        final totalSeconds = (_selectedHours * 3600) + (_selectedMinutes * 60);
                        if (totalSeconds <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Select a time > 0',
                                style: GoogleFonts.montserrat(),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }
                        await _saveLimits(totalSeconds);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007BFF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child: _isSaving
                          ? const SizedBox(
                        width: 24,
                        height: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                        ),
                      )
                          : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.play_arrow, size: 24),
                          const SizedBox(width: 8),
                          Text(
                            'Start with ${_selectedHours > 0 ? '${_selectedHours}h ' : ''}${_selectedMinutes}m each',
                            style: GoogleFonts.montserrat(
                              fontSize: 18,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}