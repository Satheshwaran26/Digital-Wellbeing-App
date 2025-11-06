import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';
import 'focus_mode_page.dart';
import 'settings_page.dart';
import 'bottom_nav_bar.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GlobalKey<State<HomePage>> _homePageKey = GlobalKey<State<HomePage>>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }
  
  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    // Milestone tracking is now handled in native Kotlin code
  }

  Widget _getPage(int index) {
    switch (index) {
      case 0:
        return HomePage(key: _homePageKey);
      case 1:
        return const FocusModePage();
      case 2:
        return const SettingsPage();
      default:
        return HomePage(key: _homePageKey);
    }
  }

  void refreshHomePage() {
    (_homePageKey.currentState as dynamic)?.refreshData();
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
        systemNavigationBarColor: Colors.transparent,
      ),
      child: Scaffold(
        backgroundColor: const Color(0xFF000000),
        body: Stack(
          children: [
            _getPage(_currentIndex),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: BottomNavBar(
                currentIndex: _currentIndex,
                onTap: (index) {
                  if (index >= 0 && index <= 2) {
                    setState(() {
                      _currentIndex = index;
                    });
                    // Refresh home page when navigating back to it
                    if (index == 0) {
                      Future.delayed(const Duration(milliseconds: 300), () {
                        refreshHomePage();
                      });
                    }
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
