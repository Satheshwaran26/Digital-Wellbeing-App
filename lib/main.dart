import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'login_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Don't initialize tracker here - let it initialize lazily when first used
  // This prevents errors during hot reload
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Digital Wellbeing',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        scaffoldBackgroundColor: const Color(0xFF000000),
        textTheme: GoogleFonts.montserratTextTheme(),
        fontFamily: GoogleFonts.montserrat().fontFamily,
      ),
      home: const LoginPage(),
      debugShowCheckedModeBanner: false,
    );
  }
}
