import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FocusModePage extends StatefulWidget {
  const FocusModePage({super.key});

  @override
  State<FocusModePage> createState() => _FocusModePageState();
}

class _FocusModePageState extends State<FocusModePage> {
  double _duration = 45.0;
  bool _blockApps = true;
  bool _muteNotifications = true;

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      backgroundColor: const Color(0xFF000000),
      body: Stack(
        children: [
          // Background glow effect
          Positioned.fill(
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.5,
                  colors: [
                    const Color(0xFF007BFF).withOpacity(0.1),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
          // Main content - Column layout
          Column(
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
                      Icons.shield_rounded,
                      color: const Color(0xFF007BFF),
                      size: 28,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Focus Mode',
                      style: GoogleFonts.montserrat(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
              ),
              // Main content
              Expanded(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const SizedBox(height: 40),
                          // Circular Timer Display
                          Container(
                            width: 256,
                            height: 256,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: const Color(0xFF007BFF).withOpacity(0.2),
                                width: 4,
                              ),
                            ),
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                // Glow effect
                                Container(
                                  width: 256,
                                  height: 256,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF007BFF).withOpacity(0.3),
                                        blurRadius: 40,
                                        spreadRadius: 20,
                                      ),
                                    ],
                                  ),
                                ),
                                // Inner circle
                                Container(
                                  width: 224,
                                  height: 224,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: const Color(0xFF007BFF).withOpacity(0.5),
                                      width: 2,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFF007BFF).withOpacity(0.5),
                                        blurRadius: 20,
                                        spreadRadius: -10,
                                      ),
                                    ],
                                  ),
                                  child: Center(
                                    child: Row(
                                      mainAxisAlignment: MainAxisAlignment.center,
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text(
                                          _duration.toInt().toString(),
                                          style: GoogleFonts.montserrat(
                                            fontSize: 72,
                                            fontWeight: FontWeight.w900,
                                            color: Colors.white,
                                            height: 1,
                                          ),
                                        ),
                                        Padding(
                                          padding: const EdgeInsets.only(bottom: 8, left: 4),
                                          child: Text(
                                            'min',
                                            style: GoogleFonts.montserrat(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w600,
                                              color: const Color(0xFF9E9E9E),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 40),
                          // Duration Slider
                          Column(
                            children: [
                              Text(
                                'Set Duration',
                                style: GoogleFonts.montserrat(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Row(
                                children: [
                                  Text(
                                    '0',
                                    style: GoogleFonts.montserrat(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                      color: const Color(0xFF9E9E9E),
                                    ),
                                  ),
                                  Expanded(
                                    child: Slider(
                                      value: _duration,
                                      min: 0,
                                      max: 90,
                                      activeColor: const Color(0xFF007BFF),
                                      inactiveColor: const Color(0xFF1F2937),
                                      onChanged: (value) {
                                        setState(() {
                                          _duration = value;
                                        });
                                      },
                                    ),
                                  ),
                                  Text(
                                    '90',
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
                          const SizedBox(height: 48),
                          // Toggle Options
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.05),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              children: [
                                _buildToggleOption(
                                  Icons.apps_outage,
                                  'Block Apps',
                                  _blockApps,
                                  (value) {
                                    setState(() {
                                      _blockApps = value;
                                    });
                                  },
                                ),
                                const SizedBox(height: 16),
                                _buildToggleOption(
                                  Icons.notifications_off,
                                  'Mute Notifications',
                                  _muteNotifications,
                                  (value) {
                                    setState(() {
                                      _muteNotifications = value;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 48),
                          // Start Focus Button
                          SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: () {
                                // Handle start focus
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF007BFF),
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                                elevation: 0,
                                shadowColor: const Color(0xFF007BFF).withOpacity(0.6),
                              ).copyWith(
                                overlayColor: WidgetStateProperty.all(
                                  Colors.white.withOpacity(0.1),
                                ),
                              ),
                              child: Text(
                                'Start Focus',
                                style: GoogleFonts.montserrat(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                  ],
                ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildToggleOption(
    IconData icon,
    String label,
    bool value,
    ValueChanged<bool> onChanged,
  ) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF007BFF),
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.montserrat(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ],
        ),
        Switch(
          value: value,
          onChanged: onChanged,
          activeThumbColor: const Color(0xFF007BFF),
          activeTrackColor: const Color(0xFF007BFF).withOpacity(0.5),
          inactiveThumbColor: Colors.white,
          inactiveTrackColor: const Color(0xFF374151),
        ),
      ],
    );
  }
}

