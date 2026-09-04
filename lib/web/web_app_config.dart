import 'package:flutter/material.dart';

class WebAppConfig {
  static const double wideBreakpoint = 1180;
  static const double compactBreakpoint = 760;
  static const double sidebarWidth = 248;
  static const double compactRailWidth = 84;
  static const double contentMaxWidth = 1280;
  static const double contentGutter = 32;
  static const double pageHeaderHeight = 72;
}

class WebNavigationItem {
  final String label;
  final IconData icon;
  final int index;

  const WebNavigationItem({
    required this.label,
    required this.icon,
    required this.index,
  });
}

const webNavigationItems = <WebNavigationItem>[
  WebNavigationItem(
    label: 'Habits',
    icon: Icons.track_changes_rounded,
    index: 0,
  ),
  WebNavigationItem(
    label: 'History',
    icon: Icons.calendar_month_rounded,
    index: 1,
  ),
  WebNavigationItem(label: 'Groups', icon: Icons.groups_rounded, index: 2),
  WebNavigationItem(label: 'Friends', icon: Icons.people_alt_rounded, index: 3),
  WebNavigationItem(label: 'Profile', icon: Icons.person_rounded, index: 4),
];
