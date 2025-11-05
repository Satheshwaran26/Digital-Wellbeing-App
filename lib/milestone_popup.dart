import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class MilestonePopup extends StatelessWidget {
  final int milestoneValue; // 30, 70, or 100
  final int currentUsage;
  final int totalLimit;
  final VoidCallback onContinue;

  const MilestonePopup({
    super.key,
    required this.milestoneValue,
    required this.currentUsage,
    required this.totalLimit,
    required this.onContinue,
  });

  String _formatTime(int seconds) {
    final hours = seconds ~/ 3600;
    final minutes = (seconds % 3600) ~/ 60;
    final secs = seconds % 60;

    if (hours > 0) {
      return '${hours}h ${minutes}m';
    } else if (minutes > 0) {
      return '${minutes}m ${secs}s';
    } else {
      return '${secs}s';
    }
  }

  Color _getMilestoneColor() {
    switch (milestoneValue) {
      case 30:
        return const Color(0xFF2E7D32); // Green
      case 70:
        return const Color(0xFFF57C00); // Orange
      case 100:
        return const Color(0xFFCC3333); // Red
      default:
        return const Color(0xFF007BFF); // Blue
    }
  }

  String _getMilestoneTitle() {
    switch (milestoneValue) {
      case 30:
        return '🎯 30% Milestone Reached!';
      case 70:
        return '⚠️ 70% Warning!';
      case 100:
        return '🚫 Time Limit Reached!';
      default:
        return 'Milestone Reached!';
    }
  }

  String _getMilestoneMessage() {
    switch (milestoneValue) {
      case 30:
        return 'You\'ve used 30% of your daily limit.\nKeep going strong! 💪';
      case 70:
        return 'You\'re at 70% of your limit!\nTime to wrap things up soon. ⏰';
      case 100:
        return 'You\'ve reached your daily limit!\nTake a break and come back tomorrow. 🌟';
      default:
        return 'Keep track of your usage!';
    }
  }

  @override
  Widget build(BuildContext context) {
    final milestoneColor = _getMilestoneColor();
    
    return WillPopScope(
      onWillPop: () async => false, // Prevent back button
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Colors.black,
                milestoneColor.withOpacity(0.2),
                Colors.black,
              ],
            ),
          ),
          child: SafeArea(
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Add top padding for better centering
                  const SizedBox(height: 20),
                  
                  // Trophy Icon with animation
                TweenAnimationBuilder(
                  duration: const Duration(milliseconds: 800),
                  tween: Tween<double>(begin: 0.0, end: 1.0),
                  builder: (context, double value, child) {
                    return Transform.scale(
                      scale: value,
                      child: Container(
                        width: 150,
                        height: 150,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: milestoneColor.withOpacity(0.2),
                          boxShadow: [
                            BoxShadow(
                              color: milestoneColor.withOpacity(0.3),
                              blurRadius: 30,
                              spreadRadius: 10,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            '🏆',
                            style: TextStyle(fontSize: 80),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                
                const SizedBox(height: 40),
                
                // Milestone Title
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _getMilestoneTitle(),
                    style: GoogleFonts.montserrat(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: 1.2,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Percentage Display
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 20),
                  decoration: BoxDecoration(
                    color: milestoneColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: milestoneColor.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Text(
                    '$milestoneValue%',
                    style: GoogleFonts.montserrat(
                      fontSize: 72,
                      fontWeight: FontWeight.bold,
                      color: milestoneColor,
                      height: 1,
                    ),
                  ),
                ),
                
                const SizedBox(height: 24),
                
                // Message
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: Text(
                    _getMilestoneMessage(),
                    style: GoogleFonts.montserrat(
                      fontSize: 18,
                      color: Colors.white.withOpacity(0.9),
                      height: 1.5,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Usage Stats Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 32),
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withOpacity(0.2),
                      width: 1,
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(
                        'COMBINED USAGE',
                        style: GoogleFonts.montserrat(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: Colors.white.withOpacity(0.7),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        '${_formatTime(currentUsage)} / ${_formatTime(totalLimit)}',
                        style: GoogleFonts.montserrat(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: milestoneColor,
                        ),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 40),
                
                // Milestone Badges
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _buildBadge(30, milestoneValue >= 30),
                    const SizedBox(width: 24),
                    _buildBadge(70, milestoneValue >= 70),
                    const SizedBox(width: 24),
                    _buildBadge(100, milestoneValue >= 100),
                  ],
                ),
                
                const SizedBox(height: 60),
                
                // Continue Button
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: onContinue,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: milestoneColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 8,
                        shadowColor: milestoneColor.withOpacity(0.5),
                      ),
                      child: Text(
                        'Continue',
                        style: GoogleFonts.montserrat(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ),
                ),
                
                const SizedBox(height: 16),
                
                // Subtitle
                Text(
                  'Tap to dismiss and continue using your apps',
                  style: GoogleFonts.montserrat(
                    fontSize: 14,
                    color: Colors.white.withOpacity(0.5),
                  ),
                  textAlign: TextAlign.center,
                ),
                
                // Add bottom padding for better spacing
                const SizedBox(height: 20),
              ],
            ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildBadge(int value, bool achieved) {
    Color badgeColor;
    switch (value) {
      case 30:
        badgeColor = const Color(0xFF2E7D32);
        break;
      case 70:
        badgeColor = const Color(0xFFF57C00);
        break;
      case 100:
        badgeColor = const Color(0xFFCC3333);
        break;
      default:
        badgeColor = Colors.grey;
    }

    return Column(
      children: [
        Container(
          width: 60,
          height: 60,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: achieved
                ? badgeColor.withOpacity(0.3)
                : Colors.white.withOpacity(0.1),
            border: Border.all(
              color: achieved
                  ? badgeColor
                  : Colors.white.withOpacity(0.3),
              width: 2,
            ),
          ),
          child: Center(
            child: Text(
              achieved ? '✓' : '○',
              style: TextStyle(
                fontSize: 30,
                color: achieved ? badgeColor : Colors.white.withOpacity(0.3),
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$value%',
          style: GoogleFonts.montserrat(
            fontSize: 12,
            fontWeight: FontWeight.bold,
            color: achieved ? badgeColor : Colors.white.withOpacity(0.5),
          ),
        ),
      ],
    );
  }
}
