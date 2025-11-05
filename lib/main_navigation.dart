import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'home_page.dart';
import 'focus_mode_page.dart';
import 'settings_page.dart';
import 'bottom_nav_bar.dart';
import 'app_usage_tracker.dart';
import 'milestone_popup.dart';

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> with WidgetsBindingObserver {
  int _currentIndex = 0;
  final GlobalKey<State<HomePage>> _homePageKey = GlobalKey<State<HomePage>>();
  bool _isShowingMilestone = false; // Add flag to track milestone popup

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setupMilestoneCallback();
    // Check for any pending milestones when app starts
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) {
        AppUsageTracker.instance.checkPendingMilestone();
      }
    });
  }
  
  @override
  void dispose() {
    _isShowingMilestone = false; // Reset flag on dispose
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    
    // Check for pending milestones when app comes to foreground
    if (state == AppLifecycleState.resumed && mounted) {
      debugPrint('App resumed - checking for pending milestones...');
      Future.delayed(const Duration(milliseconds: 300), () {
        if (mounted) {
          AppUsageTracker.instance.checkPendingMilestone();
        }
      });
    }
  }
  
  void _setupMilestoneCallback() {
    // Set up milestone callback to show full-page popup
    AppUsageTracker.instance.onMilestoneReached = (milestoneValue, currentUsage, totalLimit) {
      if (mounted) {
        _showMilestonePopup(milestoneValue, currentUsage, totalLimit);
      }
    };
  }
  
  void _showMilestonePopup(int milestoneValue, int currentUsage, int totalLimit) {
    // Prevent showing multiple popups
    if (_isShowingMilestone) return;
    _isShowingMilestone = true;

    // Navigate to full-page milestone popup
    Navigator.of(context).push(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (context) => MilestonePopup(
          milestoneValue: milestoneValue,
          currentUsage: currentUsage,
          totalLimit: totalLimit,
          onContinue: () {
            _isShowingMilestone = false; // Reset flag when popup is dismissed
            // Dismiss popup and return to previous screen
            Navigator.of(context).pop();
          },
        ),
      ),
    );
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
