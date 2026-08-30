import 'dart:ui';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../models/habit.dart';
import '../providers/navigation_provider.dart';
import '../services/premium_feature_guard.dart';
import '../services/subscription_constants.dart';
import '../services/social_service.dart';
import 'calendar_screen.dart';
import 'create_group_screen.dart';
import 'create_habit_screen.dart';
import 'dashboard_screen.dart';
import 'friends_screen.dart';
import 'groups_screen.dart';

enum _CreateEntryAction { individualHabit, sharedHabit, group }

class MainLayoutScreen extends StatelessWidget {
  MainLayoutScreen({super.key});

  static const double _navShellRadius = 36;
  static const double _navItemRadius = 32;
  static const double _addButtonSize = 60;

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
                  style: GoogleFonts.inter(
                    color: Theme.of(
                      context,
                    ).colorScheme.onSurface.withValues(alpha: 0.68),
                  ),
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
                  onTap: () =>
                      Navigator.pop(sheetContext, _CreateEntryAction.group),
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

    if (action == _CreateEntryAction.group) {
      final canCreate = await requirePremiumFeatureAccess(
        context,
        feature: PremiumFeature.unlimitedGroups,
      );
      if (!context.mounted || !canCreate) {
        return null;
      }
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
          final tween = Tween(
            begin: begin,
            end: end,
          ).chain(CurveTween(curve: curve));
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

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
                    borderRadius: BorderRadius.circular(_navShellRadius),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
                      child: Container(
                        height: 72,
                        decoration: BoxDecoration(
                          color: scheme.surface.withValues(
                            alpha: isDark ? 0.34 : 0.7,
                          ),
                          borderRadius: BorderRadius.circular(_navShellRadius),
                          border: Border.all(
                            color: scheme.onSurface.withValues(
                              alpha: isDark ? 0.2 : 0.12,
                            ),
                            width: 1.1,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(
                                alpha: isDark ? 0.34 : 0.12,
                              ),
                              blurRadius: 24,
                              offset: const Offset(0, 10),
                            ),
                            BoxShadow(
                              color: Colors.white.withValues(
                                alpha: isDark ? 0.03 : 0.35,
                              ),
                              blurRadius: 1,
                              offset: const Offset(0, -1),
                            ),
                          ],
                        ),
                        child: LayoutBuilder(
                          builder: (context, constraints) {
                            return Row(
                              children: [
                                Expanded(
                                  child: _buildNavItem(
                                    context,
                                    Icons.track_changes_rounded,
                                    0,
                                  ),
                                ),
                                Expanded(
                                  child: _buildNavItem(
                                    context,
                                    Icons.calendar_month_rounded,
                                    1,
                                  ),
                                ),
                                Expanded(
                                  child: StreamBuilder<QuerySnapshot>(
                                    stream: social.streamGroupInvites(),
                                    builder: (context, snapshot) {
                                      final count =
                                          snapshot.data?.docs.length ?? 0;
                                      return _buildNavItem(
                                        context,
                                        Icons.groups_rounded,
                                        2,
                                        badgeCount: count,
                                      );
                                    },
                                  ),
                                ),
                                Expanded(
                                  child: StreamBuilder<QuerySnapshot>(
                                    stream: social
                                        .streamIncomingFriendRequests(),
                                    builder: (context, friendSnapshot) {
                                      final friendCount =
                                          friendSnapshot.data?.docs.length ?? 0;
                                      return StreamBuilder<QuerySnapshot>(
                                        stream: social.streamHabitInvites(),
                                        builder: (context, habitSnapshot) {
                                          final habitCount =
                                              habitSnapshot.data?.docs.length ??
                                              0;
                                          return StreamBuilder<QuerySnapshot>(
                                            stream: social
                                                .streamChallengeInvites(),
                                            builder:
                                                (context, challengeSnapshot) {
                                                  final challengeCount =
                                                      challengeSnapshot
                                                          .data
                                                          ?.docs
                                                          .length ??
                                                      0;
                                                  final total =
                                                      friendCount +
                                                      habitCount +
                                                      challengeCount;
                                                  return _buildNavItem(
                                                    context,
                                                    Icons.people_alt_rounded,
                                                    3,
                                                    badgeCount: total,
                                                  );
                                                },
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
                  width: _addButtonSize,
                  height: _addButtonSize,
                  child: ClipOval(
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                      child: FloatingActionButton(
                        heroTag: 'main_layout_add_fab',
                        shape: CircleBorder(
                          side: BorderSide(
                            color: scheme.onSurface.withValues(
                              alpha: isDark ? 0.22 : 0.14,
                            ),
                            width: 1.1,
                          ),
                        ),
                        elevation: 0,
                        backgroundColor: scheme.surface.withValues(
                          alpha: isDark ? 0.4 : 0.74,
                        ),
                        foregroundColor: scheme.primary,
                        onPressed: () async {
                          final result = await _openCreateFlow(context);
                          if (!context.mounted || result == null) {
                            return;
                          }

                          final targetTab = result['targetTab'];
                          if (targetTab is int) {
                            context.read<NavigationProvider>().setIndex(
                              targetTab,
                            );
                          } else {
                            context.read<NavigationProvider>().setIndex(0);
                          }

                          final snackbarMessage = result['snackbarMessage'];
                          if (snackbarMessage is String &&
                              snackbarMessage.isNotEmpty) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(snackbarMessage)),
                            );
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
    int index, {
    int badgeCount = 0,
  }) {
    final isSelected =
        context.watch<NavigationProvider>().currentIndex == index;
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final iconColor = isSelected
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: isDark ? 0.72 : 0.62);

    return GestureDetector(
      onTap: () {
        context.read<NavigationProvider>().setIndex(index);
      },
      behavior: HitTestBehavior.opaque,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOutCubic,
        width: double.infinity,
        height: double.infinity,
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_navItemRadius),
          color: isSelected
              ? scheme.primary.withValues(alpha: isDark ? 0.12 : 0.16)
              : Colors.transparent,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(icon, color: iconColor, size: isSelected ? 27 : 24),
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
    final scheme = Theme.of(context).colorScheme;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Ink(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: scheme.onSurface.withValues(alpha: isDark ? 0.14 : 0.06),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: scheme.onSurface.withValues(alpha: isDark ? 0.12 : 0.1),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.primary.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: scheme.primary),
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
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        color: scheme.onSurface.withValues(alpha: 0.62),
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                color: scheme.onSurface.withValues(alpha: 0.58),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
