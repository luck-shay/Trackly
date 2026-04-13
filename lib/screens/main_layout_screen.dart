import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/navigation_provider.dart';
import '../services/social_service.dart';
import 'dashboard_screen.dart';
import 'calendar_screen.dart';
import 'groups_screen.dart';
import 'friends_screen.dart';
import 'profile_screen.dart';

class MainLayoutScreen extends StatelessWidget {
  MainLayoutScreen({super.key});

  final List<Widget> _screens = [
    const DashboardScreen(),
    const CalendarScreen(),
    const GroupsScreen(),
    const FriendsScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    final currentIndex = context.watch<NavigationProvider>().currentIndex;
    final social = SocialService();

    return Scaffold(
      extendBody: true,
      body: Stack(
        children: [
          IndexedStack(index: currentIndex, children: _screens),

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
                        color: Colors.black.withValues(alpha: 0.3),
                        borderRadius: BorderRadius.circular(32),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.1),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          _buildNavItem(
                            context,
                            Icons.track_changes_rounded,
                            'Habits',
                            0,
                          ),
                          _buildNavItem(
                            context,
                            Icons.calendar_month_rounded,
                            'History',
                            1,
                          ),
                          StreamBuilder<QuerySnapshot>(
                            stream: social.streamGroupInvites(),
                            builder: (context, snapshot) {
                              final count = snapshot.data?.docs.length ?? 0;
                              return _buildNavItem(
                                context,
                                Icons.groups_rounded,
                                'Groups',
                                2,
                                badgeCount: count,
                              );
                            },
                          ),
                          StreamBuilder<QuerySnapshot>(
                            stream: social.streamIncomingFriendRequests(),
                            builder: (context, friendSnapshot) {
                              final friendCount =
                                  friendSnapshot.data?.docs.length ?? 0;
                              return StreamBuilder<QuerySnapshot>(
                                stream: social.streamHabitInvites(),
                                builder: (context, habitSnapshot) {
                                  final habitCount =
                                      habitSnapshot.data?.docs.length ?? 0;
                                  final total = friendCount + habitCount;
                                  return _buildNavItem(
                                    context,
                                    Icons.people_alt_rounded,
                                    'Friends',
                                    3,
                                    badgeCount: total,
                                  );
                                },
                              );
                            },
                          ),
                          _buildNavItem(
                            context,
                            Icons.person_rounded,
                            'Profile',
                            4,
                          ),
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

  Widget _buildNavItem(
    BuildContext context,
    IconData icon,
    String label,
    int index, {
    int badgeCount = 0,
  }) {
    final isSelected =
        context.watch<NavigationProvider>().currentIndex == index;
    final color = isSelected
        ? Theme.of(context).colorScheme.primary
        : Colors.white60;

    return GestureDetector(
      onTap: () {
        context.read<NavigationProvider>().setIndex(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        width: 70,
        height: double.infinity,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: color, size: isSelected ? 26 : 24),
                if (badgeCount > 0)
                  Positioned(
                    top: -5,
                    right: -10,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 5,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.redAccent,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      constraints: const BoxConstraints(minWidth: 16),
                      child: Text(
                        badgeCount > 9 ? '9+' : '$badgeCount',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.inter(
                          fontSize: 9,
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
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
