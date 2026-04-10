import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import 'dashboard_screen.dart';
import 'calendar_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';

class MainLayoutScreen extends StatefulWidget {
  const MainLayoutScreen({super.key});

  @override
  State<MainLayoutScreen> createState() => _MainLayoutScreenState();
}

class _MainLayoutScreenState extends State<MainLayoutScreen> {
  int _currentIndex = 0;

  final List<Widget> _screens = [
    const DashboardScreen(),
    const CalendarScreen(),
    const FriendsScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: _currentIndex, children: _screens),

          Positioned(
            left: 24,
            right: 24,
            bottom: 32,
            child:
                ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
                    child: Container(
                      height: 72,
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.3),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withOpacity(0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItem(
                            Icons.track_changes_rounded,
                            'Habits',
                            0,
                          ),
                          _buildNavItem(
                            Icons.calendar_month_rounded,
                            'History',
                            1,
                          ),
                          _buildNavItem(Icons.people_alt_rounded, 'Friends', 2),
                          _buildNavItem(Icons.person_rounded, 'Profile', 3),
                        ],
                      ),
                    ),
                  ),
                ).animate().slideY(
                  begin: 1.0,
                  duration: 800.ms,
                  curve: Curves.easeOutBack,
                ),
          ),
        ],
      ),
    );
  }

  Widget _buildNavItem(IconData icon, String label, int index) {
    final isSelected = _currentIndex == index;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Colors.white60;

    return GestureDetector(
      onTap: () {
        setState(() {
          _currentIndex = index;
        });
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 70,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: isSelected ? 26 : 24),
            if (isSelected) ...[
              const SizedBox(height: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  color: color,
                  fontWeight: FontWeight.bold,
                ),
              ).animate().fade().scaleXY(),
            ],
          ],
        ),
      ),
    );
  }
}
