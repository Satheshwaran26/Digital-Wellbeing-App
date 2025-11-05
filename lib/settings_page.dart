import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_page.dart';
import 'manage_apps_page.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

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
                Icon(
                  Icons.settings_rounded,
                  color: const Color(0xFF007BFF),
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Settings',
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
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
              child: Column(
                children: [
                  // Profile Section
                  Column(
                    children: [
                      // Profile Picture Circle
                      Container(
                        width: 120,
                        height: 120,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF007BFF),
                              const Color(0xFF00BFFF),
                            ],
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF007BFF).withOpacity(0.4),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Center(
                          child: Icon(
                            Icons.person,
                            size: 60,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      // User Name
                      Text(
                        'John Doe',
                        style: GoogleFonts.montserrat(
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 32),
                    ],
                  ),
                  // Manage Apps Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (context) => const ManageAppsPage(),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.settings_applications,
                        color: Color(0xFF007BFF),
                      ),
                      label: Text(
                        'Manage Apps',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFF007BFF),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF007BFF).withOpacity(0.1),
                        foregroundColor: const Color(0xFF007BFF),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: const Color(0xFF007BFF).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ).copyWith(
                        overlayColor: WidgetStateProperty.all(
                          const Color(0xFF007BFF).withOpacity(0.2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),
                  // Privacy Policy and Terms
                  Column(
                    children: [
                      _buildLinkButton(
                        icon: Icons.privacy_tip,
                        label: 'Privacy Policy',
                        onTap: () {},
                      ),
                      const SizedBox(height: 12),
                      _buildLinkButton(
                        icon: Icons.description,
                        label: 'Terms of Service',
                        onTap: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  // Logout Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        // Navigate to login page and clear navigation stack
                        Navigator.of(context).pushAndRemoveUntil(
                          MaterialPageRoute(
                            builder: (context) => const LoginPage(),
                          ),
                          (route) => false, // Remove all previous routes
                        );
                      },
                      icon: const Icon(
                        Icons.logout,
                        color: Color(0xFFFF3B30),
                      ),
                      label: Text(
                        'Logout',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFF3B30),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFF3B30).withOpacity(0.1),
                        foregroundColor: const Color(0xFFFF3B30),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: const Color(0xFFFF3B30).withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                      ).copyWith(
                        overlayColor: WidgetStateProperty.all(
                          const Color(0xFFFF3B30).withOpacity(0.2),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Delete Account Button
                 
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.white.withOpacity(0.1),
            width: 1,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: const Color(0xFF007BFF),
              size: 20,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.montserrat(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
            Icon(
              Icons.chevron_right,
              color: const Color(0xFF9E9E9E),
              size: 20,
            ),
          ],
        ),
      ),
    );
  }
}

