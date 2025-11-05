import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:device_apps/device_apps.dart';
import 'dart:typed_data';
import 'app_usage_tracker.dart';

class SetTimerPage extends StatefulWidget {
  final List<Map<String, dynamic>>? selectedApps;
  final String? appName;
  final String? iconUrl;
  final String? currentTimer;

  const SetTimerPage({
    super.key,
    this.selectedApps,
    this.appName,
    this.iconUrl,
    this.currentTimer,
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
  
  Future<void> _quickSetTimer(int totalSeconds) async {
    if (widget.selectedApps == null || widget.selectedApps!.isEmpty) {
      return;
    }

    setState(() {
      _isSaving = true;
    });

    try {
      // Add apps to monitoring
      await AppUsageTracker.instance.addMonitoredApps(widget.selectedApps!);
      
      // Set combined time limit for ALL apps
      await AppUsageTracker.instance.setCombinedTimeLimit(totalSeconds);
      
      if (mounted) {
        Navigator.of(context).pop(true);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Started monitoring ${widget.selectedApps!.length} app(s) with ${totalSeconds}s combined limit',
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
            duration: const Duration(seconds: 3),
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
  
  Future<void> _loadIcons() async {
    if (widget.selectedApps == null) return;
    
    // First, try to use iconData if it was passed
    for (var app in widget.selectedApps!) {
      final packageName = app['packageName'] as String?;
      final iconData = app['iconData'];
      
      if (iconData != null && iconData is Uint8List) {
        setState(() {
          _iconCache[packageName ?? ''] = iconData;
        });
      }
    }
    
    // Then, load any missing icons by package name
    for (var app in widget.selectedApps!) {
      final packageName = app['packageName'] as String?;
      if (packageName != null && !_iconCache.containsKey(packageName)) {
        try {
          final appInfo = await DeviceApps.getApp(packageName, true);
          if (appInfo != null && appInfo is ApplicationWithIcon) {
            setState(() {
              _iconCache[packageName] = appInfo.icon;
            });
          }
        } catch (e) {
          print('Error loading icon for $packageName: $e');
        }
      }
    }
  }

  Future<Uint8List?> _getIconForPackage(String packageName) async {
    if (packageName.isEmpty) return null;
    
    try {
      final appInfo = await DeviceApps.getApp(packageName, true);
      if (appInfo != null && appInfo is ApplicationWithIcon) {
        setState(() {
          _iconCache[packageName] = appInfo.icon;
        });
        return appInfo.icon;
      }
    } catch (e) {
      print('Error loading icon for $packageName: $e');
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final isMultipleApps = widget.selectedApps != null && widget.selectedApps!.isNotEmpty;
    final appCount = isMultipleApps ? widget.selectedApps!.length : 1;

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
                    isMultipleApps ? 'Start Monitoring $appCount Apps' : 'Start Monitoring',
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
          // Main Content
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
              child: Column(
                children: [
                  // Selected Apps List (if multiple) or Single App Icon
                  if (isMultipleApps) ...[
                    // Selected Apps Grid
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 4, bottom: 16),
                          child: Text(
                            '$appCount App${appCount > 1 ? 's' : ''} Selected',
                            style: GoogleFonts.montserrat(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFF9E9E9E),
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 3,
                            mainAxisSpacing: 16,
                            crossAxisSpacing: 16,
                            childAspectRatio: 0.8,
                          ),
                          itemCount: widget.selectedApps!.length,
                          itemBuilder: (context, index) {
                            final app = widget.selectedApps![index];
                            final packageName = app['packageName'] as String? ?? '';
                            final iconData = _iconCache[packageName];
                            
                            return Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  width: 56,
                                  height: 56,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(14),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF007BFF).withOpacity(0.2),
                                        blurRadius: 8,
                                        spreadRadius: 0,
                                      ),
                                    ],
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: iconData != null
                                        ? Image.memory(
                                            iconData,
                                            width: 56,
                                            height: 56,
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              print('Error displaying icon for $packageName: $error');
                                              return Container(
                                                width: 56,
                                                height: 56,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                child: const Icon(
                                                  Icons.apps,
                                                  color: Colors.white,
                                                  size: 28,
                                                ),
                                              );
                                            },
                                          )
                                        : FutureBuilder<Uint8List?>(
                                            future: _getIconForPackage(packageName),
                                            builder: (context, snapshot) {
                                              if (snapshot.hasData && snapshot.data != null) {
                                                return Image.memory(
                                                  snapshot.data!,
                                                  width: 56,
                                                  height: 56,
                                                  fit: BoxFit.cover,
                                                );
                                              }
                                              return Container(
                                                width: 56,
                                                height: 56,
                                                decoration: BoxDecoration(
                                                  color: Colors.grey.withOpacity(0.2),
                                                  borderRadius: BorderRadius.circular(14),
                                                ),
                                                child: const Icon(
                                                  Icons.apps,
                                                  color: Colors.white,
                                                  size: 28,
                                                ),
                                              );
                                            },
                                          ),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  app['name'] as String,
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
                      ],
                    ),
                  ] else ...[
                    // Single App Icon and Name
                    Column(
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: Image.network(
                            widget.iconUrl!,
                            width: 100,
                            height: 100,
                            errorBuilder: (context, error, stackTrace) {
                              return Container(
                                width: 100,
                                height: 100,
                                decoration: BoxDecoration(
                                  color: Colors.grey.withOpacity(0.3),
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: const Icon(Icons.apps, color: Colors.white, size: 50),
                              );
                            },
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          widget.appName!,
                          style: GoogleFonts.montserrat(
                            fontSize: 24,
                            fontWeight: FontWeight.w700,
                            color: Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ],
                  const SizedBox(height: 40),
                  // Info Text
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
                        const Icon(
                          Icons.info_outline,
                          color: Color(0xFF007BFF),
                          size: 24,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Monitoring will start automatically. Usage time will be tracked and displayed on the home screen.',
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
                  // Set Combined Time Limit Section
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Set Combined Time Limit',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Total time limit for ALL selected apps combined',
                        style: GoogleFonts.montserrat(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Time Picker
                      Container(
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF007BFF).withOpacity(0.15),
                              const Color(0xFF00BFFF).withOpacity(0.15),
                            ],
                          ),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: const Color(0xFF007BFF).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                // Hours Picker
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
                                
                                // Minutes Picker
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
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      
                      // Quick Action - 1 Minute Button
                      InkWell(
                        onTap: _isSaving ? null : () => _quickSetTimer(60),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFF2E7D32).withOpacity(0.2),
                                const Color(0xFF4CAF50).withOpacity(0.2),
                              ],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: const Color(0xFF4CAF50),
                              width: 2,
                            ),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF4CAF50),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.flash_on,
                                  color: Colors.white,
                                  size: 24,
                                ),
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
                                      '1 min total for all $appCount app${appCount > 1 ? 's' : ''}',
                                      style: GoogleFonts.montserrat(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                        color: Colors.white.withOpacity(0.7),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.arrow_forward_ios,
                                color: Color(0xFF4CAF50),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),
                  // Save Button with Custom Time
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: _isSaving ? null : () async {
                        if (widget.selectedApps == null || widget.selectedApps!.isEmpty) {
                          return;
                        }

                        // Calculate total seconds from hours and minutes
                        final totalSeconds = (_selectedHours * 3600) + (_selectedMinutes * 60);
                        
                        if (totalSeconds <= 0) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Please select a time limit greater than 0',
                                style: GoogleFonts.montserrat(),
                              ),
                              backgroundColor: Colors.red,
                            ),
                          );
                          return;
                        }

                        setState(() {
                          _isSaving = true;
                        });

                        try {
                          // Add apps to monitoring
                          await AppUsageTracker.instance.addMonitoredApps(widget.selectedApps!);
                          
                          // Set combined time limit for ALL apps
                          await AppUsageTracker.instance.setCombinedTimeLimit(totalSeconds);
                          
                          if (mounted) {
                            Navigator.of(context).pop(true); // Return true to indicate success
                            
                            final hours = totalSeconds ~/ 3600;
                            final minutes = (totalSeconds % 3600) ~/ 60;
                            String timeStr = '';
                            if (hours > 0) {
                              timeStr = '${hours}h ${minutes}m';
                            } else {
                              timeStr = '${minutes}m';
                            }
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'Monitoring $appCount app${appCount > 1 ? 's' : ''} with $timeStr total limit',
                                  style: GoogleFonts.montserrat(),
                                ),
                                backgroundColor: const Color(0xFF007BFF),
                                duration: const Duration(seconds: 3),
                              ),
                            );
                          }
                        } catch (e) {
                          if (mounted) {
                            final errorMessage = e.toString().contains('MissingPluginException')
                                ? 'Please restart the app completely (not hot reload). Native plugins require a full restart.'
                                : 'Error starting monitoring: $e';
                            
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  errorMessage,
                                  style: GoogleFonts.montserrat(),
                                ),
                                backgroundColor: Colors.red,
                                duration: const Duration(seconds: 5),
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
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007BFF),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        elevation: 2,
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
                                  'Start with ${_selectedHours > 0 ? '${_selectedHours}h ' : ''}${_selectedMinutes}m',
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
