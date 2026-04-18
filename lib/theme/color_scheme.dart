import 'package:flutter/material.dart';

class AppTheme {
  static const _primary = Color(0xFF22C55E);

  static ThemeData dark() {
    return ThemeData(
      brightness: Brightness.dark,
      scaffoldBackgroundColor: const Color(0xFF0B0F0C),
      colorScheme: const ColorScheme.dark(
        primary: Color.from(alpha: 1, red: 0.133, green: 0.773, blue: 0.369),
        secondary: _primary,
        surface: Color(0xFF121816),
        onPrimary: Colors.black,
        onSurface: Color(0xFFE5E7EB),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFF0B0F0C),
        elevation: 0,
        foregroundColor: Color(0xFFE5E7EB),
      ),
      cardColor: const Color(0xFF121816),
      dividerColor: Colors.white10,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFFE5E7EB)),
        bodyMedium: TextStyle(color: Color(0xFF9CA3AF)),
        bodySmall: TextStyle(color: Color(0xFF6B7280)),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFFE5E7EB),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.white10,
        selectedColor: _primary.withValues(alpha: 0.15),
        labelStyle: const TextStyle(color: Color(0xFFE5E7EB)),
        secondaryLabelStyle: const TextStyle(color: Colors.black),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: Colors.black,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: const Color(0xFF1C1F24),
        contentTextStyle: const TextStyle(
          color: Color(0xFFE5E7EB),
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
        ),
        actionTextColor: _primary,
        dismissDirection: DismissDirection.horizontal,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Color(0xFF121816),
        selectedItemColor: _primary,
        unselectedItemColor: Color(0xFF6B7280),
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFF121816),
        hintStyle: const TextStyle(color: Color(0xFF6B7280)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.white.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primary),
        ),
      ),
      useMaterial3: true,
    );
  }

  static ThemeData light() {
    return ThemeData(
      brightness: Brightness.light,
      scaffoldBackgroundColor: const Color(0xFFF8FAF9),
      colorScheme: const ColorScheme.light(
        primary: _primary,
        secondary: _primary,
        surface: Colors.white,
        onPrimary: Colors.black,
        onSurface: Color(0xFF111827),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Color(0xFFF8FAF9),
        elevation: 0,
        foregroundColor: Color(0xFF111827),
      ),
      cardColor: Colors.white,
      dividerColor: Colors.black12,
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: Color(0xFF111827)),
        bodyMedium: TextStyle(color: Color(0xFF4B5563)),
        bodySmall: TextStyle(color: Color(0xFF9CA3AF)),
      ),
      iconTheme: const IconThemeData(
        color: Color(0xFF111827),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: Colors.black.withValues(alpha: 0.05),
        selectedColor: _primary.withValues(alpha: 0.1),
        labelStyle: const TextStyle(color: Color(0xFF111827)),
        secondaryLabelStyle: const TextStyle(color: Colors.black),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: Colors.black,
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        backgroundColor: const Color(0xFF111827),
        contentTextStyle: const TextStyle(
          color: Color(0xFFF9FAFB),
          fontWeight: FontWeight.w600,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(color: Colors.black.withValues(alpha: 0.08)),
        ),
        actionTextColor: _primary,
        dismissDirection: DismissDirection.horizontal,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: Colors.white,
        selectedItemColor: _primary,
        unselectedItemColor: Color(0xFF9CA3AF),
        type: BottomNavigationBarType.fixed,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F3),
        hintStyle: const TextStyle(color: Color(0xFF9CA3AF)),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: Colors.black.withValues(alpha: 0.05)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: _primary),
        ),
      ),
      useMaterial3: true,
    );
  }
}