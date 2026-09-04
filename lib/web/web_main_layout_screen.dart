import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/navigation_provider.dart';
import '../services/social_service.dart';
import '../screens/calendar_screen.dart';
import '../screens/create_group_screen.dart';
import '../screens/create_habit_screen.dart';
import '../screens/dashboard_screen.dart';
import '../screens/friends_screen.dart';
import '../screens/groups_screen.dart';
import '../screens/profile_screen.dart';
import '../models/habit.dart';
import 'web_app_config.dart';

class WebMainLayoutScreen extends StatefulWidget {
  const WebMainLayoutScreen({super.key});

  @override
  State<WebMainLayoutScreen> createState() => _WebMainLayoutScreenState();
}

class _WebMainLayoutScreenState extends State<WebMainLayoutScreen> {
  int _selectedIndex = 0;

  final _screens = const <Widget>[
    DashboardScreen(),
    CalendarScreen(),
    GroupsScreen(),
    FriendsScreen(),
    ProfileScreen(),
  ];

  void _select(int index) {
    setState(() => _selectedIndex = index);
    if (index < 4) {
      context.read<NavigationProvider>().setIndex(index);
    }
  }

  Future<void> _createHabit(HabitSpaceType spaceType) async {
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => CreateHabitScreen(initialSpaceType: spaceType),
      ),
    );
  }

  Future<void> _createGroup() async {
    await Navigator.of(
      context,
    ).push(MaterialPageRoute(builder: (_) => const CreateGroupScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isWide = constraints.maxWidth >= WebAppConfig.wideBreakpoint;
        final isCompact = constraints.maxWidth < WebAppConfig.compactBreakpoint;

        return Scaffold(
          body: Row(
            children: [
              _WebSidebar(
                selectedIndex: _selectedIndex,
                isWide: isWide,
                isCompact: isCompact,
                onSelected: _select,
                onCreateHabit: _createHabit,
                onCreateGroup: _createGroup,
              ),
              Expanded(
                child: Column(
                  children: [
                    _WebTopBar(
                      selectedIndex: _selectedIndex,
                      onProfileTap: () => _select(4),
                    ),
                    Expanded(
                      child: Align(
                        alignment: Alignment.topCenter,
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            maxWidth: WebAppConfig.contentMaxWidth,
                          ),
                          child: IndexedStack(
                            index: _selectedIndex,
                            children: _screens,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _WebSidebar extends StatelessWidget {
  final int selectedIndex;
  final bool isWide;
  final bool isCompact;
  final ValueChanged<int> onSelected;
  final Future<void> Function(HabitSpaceType) onCreateHabit;
  final Future<void> Function() onCreateGroup;

  const _WebSidebar({
    required this.selectedIndex,
    required this.isWide,
    required this.isCompact,
    required this.onSelected,
    required this.onCreateHabit,
    required this.onCreateGroup,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final width = isWide
        ? WebAppConfig.sidebarWidth
        : WebAppConfig.compactRailWidth;

    return Material(
      color: scheme.surface,
      child: Container(
        width: width,
        padding: EdgeInsets.symmetric(
          horizontal: isWide ? 16 : 10,
          vertical: 24,
        ),
        decoration: BoxDecoration(
          border: Border(
            right: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
          ),
        ),
        child: Column(
          crossAxisAlignment: isWide
              ? CrossAxisAlignment.start
              : CrossAxisAlignment.center,
          children: [
            Row(
              mainAxisAlignment: isWide
                  ? MainAxisAlignment.start
                  : MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.track_changes_rounded,
                  color: scheme.primary,
                  size: 28,
                ),
                if (isWide) ...[
                  const SizedBox(width: 10),
                  Text(
                    'Trackly',
                    style: GoogleFonts.outfit(
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: 34),
            if (isWide)
              SizedBox(
                width: double.infinity,
                child: PopupMenuButton<String>(
                  tooltip: 'Create new',
                  onSelected: (value) {
                    switch (value) {
                      case 'individual':
                        onCreateHabit(HabitSpaceType.individual);
                      case 'shared':
                        onCreateHabit(HabitSpaceType.sharedTask);
                      case 'group':
                        onCreateGroup();
                    }
                  },
                  itemBuilder: (context) => const [
                    PopupMenuItem(
                      value: 'individual',
                      child: Text('Individual habit'),
                    ),
                    PopupMenuItem(value: 'shared', child: Text('Shared habit')),
                    PopupMenuItem(value: 'group', child: Text('Group')),
                  ],
                  child: FilledButton.icon(
                    onPressed: null,
                    icon: const Icon(Icons.add_rounded),
                    label: const Text('New'),
                  ),
                ),
              )
            else
              IconButton(
                tooltip: 'Create new',
                onPressed: () => onCreateHabit(HabitSpaceType.individual),
                icon: const Icon(Icons.add_rounded),
                color: scheme.primary,
              ),
            const SizedBox(height: 28),
            Expanded(
              child: Column(
                children: webNavigationItems
                    .map(
                      (item) => _WebNavItem(
                        item: item,
                        selected: item.index == selectedIndex,
                        showLabel: isWide,
                        onTap: () => onSelected(item.index),
                      ),
                    )
                    .toList(),
              ),
            ),
            if (!isCompact && isWide)
              Text(
                'Build better routines.',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  color: scheme.onSurface.withValues(alpha: 0.45),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _WebNavItem extends StatelessWidget {
  final WebNavigationItem item;
  final bool selected;
  final bool showLabel;
  final VoidCallback onTap;

  const _WebNavItem({
    required this.item,
    required this.selected,
    required this.showLabel,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final child = AnimatedContainer(
      duration: const Duration(milliseconds: 180),
      margin: const EdgeInsets.only(bottom: 6),
      padding: EdgeInsets.symmetric(
        horizontal: showLabel ? 14 : 10,
        vertical: 12,
      ),
      decoration: BoxDecoration(
        color: selected ? scheme.primary.withValues(alpha: 0.14) : null,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: showLabel
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          Icon(
            item.icon,
            size: 21,
            color: selected
                ? scheme.primary
                : scheme.onSurface.withValues(alpha: 0.62),
          ),
          if (showLabel) ...[
            const SizedBox(width: 12),
            Text(
              item.label,
              style: GoogleFonts.inter(
                fontSize: 13,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected
                    ? scheme.primary
                    : scheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
          ],
        ],
      ),
    );

    return Tooltip(
      message: item.label,
      child: InkWell(onTap: onTap, child: child),
    );
  }
}

class _WebTopBar extends StatelessWidget {
  final int selectedIndex;
  final VoidCallback onProfileTap;

  const _WebTopBar({required this.selectedIndex, required this.onProfileTap});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = webNavigationItems
        .firstWhere((item) => item.index == selectedIndex)
        .label;
    final social = SocialService();

    return Container(
      height: WebAppConfig.pageHeaderHeight,
      padding: const EdgeInsets.symmetric(
        horizontal: WebAppConfig.contentGutter,
      ),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(color: scheme.onSurface.withValues(alpha: 0.08)),
        ),
      ),
      child: Row(
        children: [
          Text(
            title,
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.w700,
            ),
          ),
          const Spacer(),
          StreamBuilder<QuerySnapshot>(
            stream: social.streamIncomingFriendRequests(),
            builder: (context, snapshot) {
              final count = snapshot.data?.docs.length ?? 0;
              return IconButton(
                tooltip: count == 0 ? 'Notifications' : '$count notifications',
                onPressed: onProfileTap,
                icon: Badge(
                  isLabelVisible: count > 0,
                  label: Text(count > 9 ? '9+' : '$count'),
                  child: const Icon(Icons.notifications_none_rounded),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
          IconButton(
            tooltip: 'Open profile',
            onPressed: onProfileTap,
            icon: const Icon(Icons.account_circle_outlined, size: 28),
          ),
        ],
      ),
    );
  }
}
