import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';

import '../providers/theme_mode_provider.dart';

class AppearanceSelector extends StatelessWidget {
  final bool isBottomSheet;

  const AppearanceSelector({super.key, this.isBottomSheet = false});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeModeProvider>();
    final currentMode = themeProvider.themeMode;

    Widget content = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (isBottomSheet) ...[
          Center(
            child: Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 24),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          Text(
            'Appearance',
            style: GoogleFonts.outfit(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.onSurface,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            'Make Trackly your own.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
        ],
        Expanded(
          flex: isBottomSheet ? 0 : 1,
          child: SingleChildScrollView(
            child: Column(
              children: [
                _AppearanceCard(
                  mode: ThemeMode.light,
                  title: 'Light',
                  description: 'Clean and bright.',
                  icon: Icons.light_mode_rounded,
                  isSelected: currentMode == ThemeMode.light,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    themeProvider.setThemeMode(ThemeMode.light);
                  },
                ),
                const SizedBox(height: 16),
                _AppearanceCard(
                  mode: ThemeMode.dark,
                  title: 'Dark',
                  description: 'Easy on the eyes.',
                  icon: Icons.dark_mode_rounded,
                  isSelected: currentMode == ThemeMode.dark,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    themeProvider.setThemeMode(ThemeMode.dark);
                  },
                ),
                const SizedBox(height: 16),
                _AppearanceCard(
                  mode: ThemeMode.system,
                  title: 'System',
                  description: 'Matches your device.',
                  icon: Icons.settings_suggest_rounded,
                  isSelected: currentMode == ThemeMode.system,
                  onTap: () {
                    HapticFeedback.lightImpact();
                    themeProvider.setThemeMode(ThemeMode.system);
                  },
                ),
              ],
            ),
          ),
        ),
      ],
    );

    if (isBottomSheet) {
      final scheme = Theme.of(context).colorScheme;
      return Container(
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: content,
          ),
        ),
      );
    }

    return content;
  }
}

class _AppearanceCard extends StatelessWidget {
  final ThemeMode mode;
  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _AppearanceCard({
    required this.mode,
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bool isDark = mode == ThemeMode.dark || (mode == ThemeMode.system && MediaQuery.platformBrightnessOf(context) == Brightness.dark);
    
    // Hardcode preview colors based on mode so the preview accurately depicts the mode,
    // regardless of the current app theme.
    final Color previewBg = isDark ? const Color(0xFF1A1A1D) : const Color(0xFFF8F9FA);
    final Color previewCard = isDark ? const Color(0xFF2C2C30) : const Color(0xFFFFFFFF);
    final Color previewPrimary = isDark ? const Color(0xFFB39DDB) : const Color(0xFF6750A4);
    final Color previewText = isDark ? const Color(0xFFE6E1E5) : const Color(0xFF1C1B1F);
    final Color previewSubtext = isDark ? const Color(0xFFCAC4D0) : const Color(0xFF49454F);

    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected ? scheme.primaryContainer : scheme.surfaceContainerHighest.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? scheme.primary : scheme.outline.withValues(alpha: 0.1),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: scheme.primary.withValues(alpha: 0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  )
                ]
              : null,
        ),
        child: Row(
          children: [
            // Miniature Preview
            Container(
              width: 60,
              height: 80,
              decoration: BoxDecoration(
                color: previewBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.black12,
                ),
              ),
              child: mode == ThemeMode.system
                  ? Row(
                      children: [
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFF8F9FA),
                              borderRadius: BorderRadius.horizontal(left: Radius.circular(11)),
                            ),
                            child: _buildPreviewContent(
                              const Color(0xFFFFFFFF),
                              const Color(0xFF6750A4),
                              const Color(0xFF1C1B1F),
                              const Color(0xFF49454F),
                              isSplit: true,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFF1A1A1D),
                              borderRadius: BorderRadius.horizontal(right: Radius.circular(11)),
                            ),
                            child: _buildPreviewContent(
                              const Color(0xFF2C2C30),
                              const Color(0xFFB39DDB),
                              const Color(0xFFE6E1E5),
                              const Color(0xFFCAC4D0),
                              isSplit: true,
                            ),
                          ),
                        ),
                      ],
                    )
                  : _buildPreviewContent(previewCard, previewPrimary, previewText, previewSubtext),
            ),
            const SizedBox(width: 20),
            // Details
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        icon,
                        size: 20,
                        color: isSelected ? scheme.primary : scheme.onSurface,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        title,
                        style: GoogleFonts.outfit(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: isSelected ? scheme.onPrimaryContainer : scheme.onSurface,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      color: isSelected
                          ? scheme.onPrimaryContainer.withValues(alpha: 0.7)
                          : scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            // Selection Check
            if (isSelected)
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: scheme.primary,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.check_rounded,
                  size: 16,
                  color: scheme.onPrimary,
                ),
              ).animate().scale(curve: Curves.elasticOut, duration: 400.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewContent(Color card, Color primary, Color text, Color subtext, {bool isSplit = false}) {
    final double outerPadding = isSplit ? 3.0 : 6.0;
    final double headerWidth = isSplit ? 12.0 : 24.0;
    final double headerHeight = isSplit ? 3.0 : 6.0;
    final double cardHeight = isSplit ? 12.0 : 20.0;
    final double cardPadding = isSplit ? 2.0 : 4.0;
    final double circleSize = isSplit ? 6.0 : 12.0;
    final double spacing1 = isSplit ? 4.0 : 8.0;
    final double spacing2 = isSplit ? 3.0 : 6.0;
    final double line1Height = isSplit ? 1.5 : 3.0;

    return Padding(
      padding: EdgeInsets.all(outerPadding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: headerWidth,
            height: headerHeight,
            decoration: BoxDecoration(
              color: text,
              borderRadius: BorderRadius.circular(isSplit ? 2 : 4),
            ),
          ),
          SizedBox(height: spacing1),
          Container(
            width: double.infinity,
            height: cardHeight,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(isSplit ? 3 : 6),
            ),
            padding: EdgeInsets.all(cardPadding),
            child: Row(
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    color: primary,
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: isSplit ? 2 : 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: double.infinity,
                        height: line1Height,
                        decoration: BoxDecoration(
                          color: text,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                      if (!isSplit) ...[
                        const SizedBox(height: 2),
                        Container(
                          width: 16,
                          height: 2,
                          decoration: BoxDecoration(
                            color: subtext,
                            borderRadius: BorderRadius.circular(1),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: spacing2),
          Container(
            width: double.infinity,
            height: cardHeight,
            decoration: BoxDecoration(
              color: card,
              borderRadius: BorderRadius.circular(isSplit ? 3 : 6),
            ),
            padding: EdgeInsets.all(cardPadding),
            child: Row(
              children: [
                Container(
                  width: circleSize,
                  height: circleSize,
                  decoration: BoxDecoration(
                    color: subtext.withValues(alpha: 0.3),
                    shape: BoxShape.circle,
                  ),
                ),
                SizedBox(width: isSplit ? 2 : 4),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        width: double.infinity,
                        height: line1Height,
                        decoration: BoxDecoration(
                          color: text,
                          borderRadius: BorderRadius.circular(1),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
