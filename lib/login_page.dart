import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'main_navigation.dart';

class GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    // Background color (black)
    final backgroundPaint = Paint()..color = const Color(0xFF000000);
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), backgroundPaint);

    // Grid line paint (light dark blue)
    final gridPaint = Paint()
      ..color = const Color(0xFF2D4A6E).withOpacity(0.4)
      ..strokeWidth = 1;

    const gridSize = 20.0;

    // Draw horizontal lines
    for (double y = 0; y < size.height; y += gridSize) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Draw vertical lines
    for (double x = 0; x < size.width; x += gridSize) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), gridPaint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.width / 48.0; // SVG viewBox is 48x48
    
    canvas.save();
    canvas.scale(scale);
    
    // Yellow path
    final yellowPath = Path()
      ..moveTo(43.611, 20.083)
      ..lineTo(42, 20.083)
      ..lineTo(42, 20)
      ..lineTo(24, 20)
      ..lineTo(24, 28)
      ..lineTo(35.303, 28)
      ..cubicTo(33.654, 32.657, 29.223, 36, 24, 36)
      ..cubicTo(17.373, 36, 12, 30.627, 12, 24)
      ..cubicTo(12, 17.373, 17.373, 12, 24, 12)
      ..cubicTo(27.059, 12, 29.842, 13.154, 31.961, 15.039)
      ..lineTo(37.618, 9.382)
      ..cubicTo(34.046, 6.053, 29.268, 4, 24, 4)
      ..cubicTo(12.955, 4, 4, 12.955, 4, 24)
      ..cubicTo(4, 35.045, 12.955, 44, 24, 44)
      ..cubicTo(35.045, 44, 44, 35.045, 44, 24)
      ..cubicTo(44, 22.659, 43.862, 21.35, 43.611, 20.083)
      ..close();
    
    canvas.drawPath(
      yellowPath,
      Paint()..color = const Color(0xFFFFC107),
    );
    
    // Red path
    final redPath = Path()
      ..moveTo(6.306, 14.691)
      ..lineTo(12.877, 19.51)
      ..cubicTo(14.655, 15.108, 18.961, 12, 24, 12)
      ..cubicTo(27.059, 12, 29.842, 13.154, 31.961, 15.039)
      ..lineTo(37.618, 9.382)
      ..cubicTo(34.046, 6.053, 29.268, 4, 24, 4)
      ..cubicTo(16.318, 4, 9.656, 8.337, 6.306, 14.691)
      ..close();
    
    canvas.drawPath(
      redPath,
      Paint()..color = const Color(0xFFFF3D00),
    );
    
    // Green path
    final greenPath = Path()
      ..moveTo(24, 44)
      ..cubicTo(29.166, 44, 33.86, 42.023, 37.409, 38.808)
      ..lineTo(31.219, 33.57)
      ..cubicTo(29.211, 35.091, 26.715, 36, 24, 36)
      ..cubicTo(18.798, 36, 14.381, 32.683, 12.717, 28.054)
      ..lineTo(6.195, 33.079)
      ..cubicTo(9.505, 39.556, 16.227, 44, 24, 44)
      ..close();
    
    canvas.drawPath(
      greenPath,
      Paint()..color = const Color(0xFF4CAF50),
    );
    
    // Blue path
    final bluePath = Path()
      ..moveTo(43.611, 20.083)
      ..lineTo(42, 20.083)
      ..lineTo(42, 20)
      ..lineTo(24, 20)
      ..lineTo(24, 28)
      ..lineTo(35.303, 28)
      ..cubicTo(34.511, 30.237, 33.072, 32.166, 31.216, 33.571)
      ..lineTo(31.219, 33.57)
      ..lineTo(37.409, 38.808)
      ..cubicTo(36.971, 39.205, 44, 34, 44, 24)
      ..cubicTo(44, 22.659, 43.862, 21.35, 43.611, 20.083)
      ..close();
    
    canvas.drawPath(
      bluePath,
      Paint()..color = const Color(0xFF1976D2),
    );
    
    canvas.restore();
  }
  
  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class LoginPage extends StatelessWidget {
  const LoginPage({super.key});

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
        systemNavigationBarIconBrightness: Brightness.light,
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Container(
            decoration: const BoxDecoration(
              color: Color(0xFF000000), // Black background
            ),
            child: Stack(
            children: [
              // Grid background
              CustomPaint(
                painter: GridPainter(),
                size: Size.infinite,
              ),
              // Main content
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      // Icon container with border
                      Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: const Color.fromARGB(255, 21, 104, 193),
                            width: 1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color.fromARGB(255, 8, 117, 226).withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.self_improvement,
                          color: Color(0xFF007BFF),
                          size: 48,
                        ),
                      ),
                      const SizedBox(height: 40),
                      // Title
                      const Text(
                        'Welcome To Digital Wellbeing',
                        style: TextStyle(
                          fontSize: 36,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                          letterSpacing: -0.8,
                          height: 1.2,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      // Subtitle
                      Text(
                        'Take control of your screen time and build healthier digital habits.',
                        style: GoogleFonts.montserrat(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                          color: const Color(0xFFB0BEC5),
                          height: 1.5,
                        ),
                        textAlign: TextAlign.center,
                      ),
                  
                      const SizedBox(height: 40),
                      // Google Sign In Button
                      SizedBox(
                        width: double.infinity,
                        height: 56,
                        child: ElevatedButton(
                          onPressed: () {
                            // Navigate to main navigation after login
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (context) => const MainNavigation(),
                              ),
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.black,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                              side: BorderSide(
                                color: const Color.fromARGB(255, 27, 100, 178),
                                width: 1,
                              ),
                            ),
                            elevation: 0,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ).copyWith(
                            overlayColor: WidgetStateProperty.all(
                              const Color(0xFF007BFF).withOpacity(0.2),
                            ),
                            shadowColor: WidgetStateProperty.all(
                              const Color(0xFF007BFF).withOpacity(0.5),
                            ),
                            elevation: WidgetStateProperty.all(4),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SizedBox(
                                width: 24,
                                height: 24,
                                child: CustomPaint(
                                  painter: GoogleLogoPainter(),
                                ),
                              ),
                              const SizedBox(width: 12),
                              const Text(
                                'Continue with Google',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: Colors.white,
                                  letterSpacing: 0.2,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),
                      
                      // Three points in one row with three columns
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          // Column 1
                          Expanded(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.verified_user,
                                  size: 20,
                                  color: const Color(0xFF007BFF),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Secure',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFB0BEC5),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          // Column 2
                          Expanded(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.access_time_filled,
                                  size: 20,
                                  color: const Color(0xFF007BFF),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Quick',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFB0BEC5),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                          // Column 3
                          Expanded(
                            child: Column(
                              children: [
                                Icon(
                                  Icons.track_changes,
                                  size: 20,
                                  color: const Color(0xFF007BFF),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  'Track',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Color(0xFFB0BEC5),
                                    fontWeight: FontWeight.w400,
                                  ),
                                  textAlign: TextAlign.center,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      // Terms and Privacy
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20.0),
                        child: RichText(
                          textAlign: TextAlign.center,
                          text: const TextSpan(
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFF90A4AE),
                              height: 1.5,
                            ),
                            children: [
                              TextSpan(text: 'By continuing, you agree to our '),
                              TextSpan(
                                text: 'Terms of Service',
                                style: TextStyle(
                                  color: Color(0xFF007BFF),
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              TextSpan(text: ' and '),
                              TextSpan(
                                text: 'Privacy Policy',
                                style: TextStyle(
                                  color: Color(0xFF007BFF),
                                  decoration: TextDecoration.underline,
                                  fontWeight: FontWeight.w500,
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
        ),
      ),
      ),
    );
  }

}
