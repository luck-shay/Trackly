// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Insight Model
// Data model for smart insights generated from analytics data.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';

/// The category of insight.
enum InsightType {
  streak,
  weekdayPattern,
  trendImprovement,
  trendDecline,
  completionRate,
  bestHabit,
  worstHabit,
  consistency,
  milestone,
  suggestion,
  aiCoaching,
  moodCorrelation,
  habitStacking,
  weeklyRecap,
}

/// A single human-readable insight derived from analytics data.
class Insight {
  final InsightType type;
  final String title;
  final String message;
  final IconData icon;
  final int priority; // Lower number = higher priority.

  const Insight({
    required this.type,
    required this.title,
    required this.message,
    required this.icon,
    this.priority = 50,
  });
}
