import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/habit.dart';
import '../providers/navigation_provider.dart';
import '../services/social_service.dart';
import 'dashboard_screen.dart';
import 'calendar_screen.dart';
import 'create_habit_screen.dart';
import 'create_group_screen.dart';
import 'groups_screen.dart';
import 'friends_screen.dart';

enum _CreateEntryAction { individualHabit, sharedHabit, group }

class MainLayoutScreen extends StatelessWidget {
  MainLayoutScreen({super.key});

  final List<Widget> _screens = [
    const DashboardScreen(),
    const CalendarScreen(),
    const GroupsScreen(),
    const FriendsScreen(),
  ];

  Future<_CreateEntryAction?> _showCreateChooser(BuildContext context) {
    return showModalBottomSheet<_CreateEntryAction>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(26)),
      ),
      builder: (sheetContext) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Create New',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Choose what you want to create.',
                  style: GoogleFonts.inter(color: Colors.grey[400]),
                ),
                const SizedBox(height: 14),
                _CreateOptionTile(
                  icon: Icons.person_outline_rounded,
                  title: 'Individual Habit',
                  subtitle: 'A private task for just you.',
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _CreateEntryAction.individualHabit,
                  ),
                ),
                const SizedBox(height: 8),
                _CreateOptionTile(
                  icon: Icons.people_alt_outlined,
                  title: 'Shared Habit',
                  subtitle: 'One task shared with selected friends.',
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _CreateEntryAction.sharedHabit,
                  ),
                ),
                const SizedBox(height: 8),
                _CreateOptionTile(
                  icon: Icons.groups_rounded,
                  title: 'Group',
                  subtitle: 'Create a group where members can add many tasks.',
                  onTap: () => Navigator.pop(
                    sheetContext,
                    _CreateEntryAction.group,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>?> _openCreateFlow(BuildContext context) async {
    final action = await _showCreateChooser(context);
    if (action == null || !context.mounted) {
      return null;
    }

    final destination = switch (action) {
      _CreateEntryAction.individualHabit => const CreateHabitScreen(
        initialSpaceType: HabitSpaceType.individual,
      ),
      _CreateEntryAction.sharedHabit => const CreateHabitScreen(
        initialSpaceType: HabitSpaceType.sharedTask,
      ),
      _CreateEntryAction.group => const CreateGroupScreen(),
    };

    final result = await Navigator.push<dynamic>(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => destination,
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(0.0, 1.0);
          const end = Offset.zero;
          const curve = Curves.easeOutCubic;
          final tween = Tween(begin: begin, end: end).chain(
            CurveTween(curve: curve),
          );
          return SlideTransition(
            position: animation.drive(tween),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 400),
      ),
    );

    return result is Map<String, dynamic>
        ? result
        : (result is Map ? Map<String, dynamic>.from(result) : null);
  }

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
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: ClipRRect(
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
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            final compact = constraints.maxWidth / 4 < 68;
                            return Row(
                              children: [
                                Expanded(
                                  child: _buildNavItem(
                                    context,
                                    Icons.track_changes_rounded,
                                    'Habits',
                                    0,
                                    compact: compact,
                                  ),
                                ),
                                Expanded(
                                  child: _buildNavItem(
                                    context,
                                    Icons.calendar_month_rounded,
                                    'History',
                                    1,
                                    compact: compact,
                                  ),
                                ),
                                Expanded(
                                  child: StreamBuilder<QuerySnapshot>(
                                    stream: social.streamGroupInvites(),
                                    builder: (context, snapshot) {
                                      final count = snapshot.data?.docs.length ?? 0;
                                      return _buildNavItem(
                                        context,
                                        Icons.groups_rounded,
                                        'Groups',
                                        2,
                                        badgeCount: count,
                                        compact: compact,
                                      );
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: StreamBuilder<QuerySnapshot>(
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
                                            compact: compact,
                                          );
                                        },
                                      );
                                    },
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ).animate().slideY(
                  begin: 1.0,
                  duration: 800.ms,
                  curve: Curves.easeOutBack,
                ),
                const SizedBox(width: 16),
                SizedBox(
                  width: 60,
                  height: 60,
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
                      child: FloatingActionButton(
                        heroTag: 'main_layout_add_fab',
                        shape: const CircleBorder(),
                        elevation: 0,
                        backgroundColor: Colors.black.withValues(alpha: 0.22),
                        foregroundColor: Theme.of(context).colorScheme.primary,
                        onPressed: () async {
                          final result = await _openCreateFlow(context);
                          if (!context.mounted || result == null) {
                            return;
                          }

                          final targetTab = result['targetTab'];
                          if (targetTab is int) {
                            context.read<NavigationProvider>().setIndex(targetTab);
                          } else {
                            context.read<NavigationProvider>().setIndex(0);
                          }

                          final snackbarMessage = result['snackbarMessage'];
                          if (snackbarMessage is String && snackbarMessage.isNotEmpty) {
                            ScaffoldMessenger.of(
                              context,
                            ).showSnackBar(SnackBar(content: Text(snackbarMessage)));
                          }
                        },
                        child: const Icon(Icons.add, size: 38),
                      ),
                    ),
                  ),
                ).animate().scale(delay: 350.ms, curve: Curves.easeOutBack),
              ],
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
    required bool compact,
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
        width: double.infinity,
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
              if (isSelected && !compact) ...[
              const SizedBox(height: 4),
                SizedBox(
                  width: double.infinity,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      label,
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        color: color,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                ),
              ).animate().fade().scaleXY(),
            ],
          ],
        ),
      ),
    );
  }
}

class _CreateOptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _CreateOptionTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.16),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: Theme.of(context).colorScheme.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.outfit(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(fontSize: 12, color: Colors.grey[400]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: Colors.grey[500]),
            ],
          ),
        ),
      ),
    );
  }
}
