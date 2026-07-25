// ─────────────────────────────────────────────────────────────────────────────
// Trackly Pro — Category Colors
// Color palette for habit categories and time-of-day indicators.
// ─────────────────────────────────────────────────────────────────────────────

import 'package:flutter/material.dart';
import '../models/habit.dart';

class CategoryColors {
  const CategoryColors._();

  static const Color general = Color(0xFF6B7280);
  static const Color fitness = Color(0xFF3B82F6);
  static const Color health = Color(0xFF22C55E);
  static const Color learning = Color(0xFF8B5CF6);
  static const Color productivity = Color(0xFFF97316);
  static const Color mindfulness = Color(0xFF14B8A6);
  static const Color social = Color(0xFFEC4899);
  static const Color finance = Color(0xFFEAB308);
  static const Color creativity = Color(0xFFF43F5E);

  static Color forCategory(HabitCategory category) {
    return switch (category) {
      HabitCategory.general => general,
      HabitCategory.fitness => fitness,
      HabitCategory.health => health,
      HabitCategory.learning => learning,
      HabitCategory.productivity => productivity,
      HabitCategory.mindfulness => mindfulness,
      HabitCategory.social => social,
      HabitCategory.finance => finance,
      HabitCategory.creativity => creativity,
    };
  }

  static IconData iconForCategory(HabitCategory category) {
    return switch (category) {
      HabitCategory.general => Icons.circle_outlined,
      HabitCategory.fitness => Icons.fitness_center_rounded,
      HabitCategory.health => Icons.favorite_rounded,
      HabitCategory.learning => Icons.school_rounded,
      HabitCategory.productivity => Icons.bolt_rounded,
      HabitCategory.mindfulness => Icons.self_improvement_rounded,
      HabitCategory.social => Icons.people_rounded,
      HabitCategory.finance => Icons.savings_rounded,
      HabitCategory.creativity => Icons.palette_rounded,
    };
  }

  static IconData iconForTimeOfDay(HabitTimeOfDay timeOfDay) {
    return switch (timeOfDay) {
      HabitTimeOfDay.anytime => Icons.schedule_rounded,
      HabitTimeOfDay.morning => Icons.wb_sunny_rounded,
      HabitTimeOfDay.afternoon => Icons.wb_twilight_rounded,
      HabitTimeOfDay.evening => Icons.nightlight_rounded,
    };
  }

  static Color colorForTimeOfDay(HabitTimeOfDay timeOfDay) {
    return switch (timeOfDay) {
      HabitTimeOfDay.anytime => general,
      HabitTimeOfDay.morning => const Color(0xFFF97316),
      HabitTimeOfDay.afternoon => const Color(0xFF3B82F6),
      HabitTimeOfDay.evening => const Color(0xFF8B5CF6),
    };
  }
}
