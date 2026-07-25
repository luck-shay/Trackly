import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/color_scheme.dart';

class ProBadgeAvatar extends StatelessWidget {
  final Widget child;
  final bool isPro;
  final double radius;

  const ProBadgeAvatar({
    super.key,
    required this.child,
    required this.isPro,
    this.radius = 22,
  });

  @override
  Widget build(BuildContext context) {
    if (!isPro) return child;

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: AppTheme.proBadgeGradient,
        boxShadow: [
          BoxShadow(
            color: AppTheme.proAmber.withValues(alpha: 0.4),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          child,
          Positioned(
            bottom: -(radius * 0.25),
            child: Container(
              padding: EdgeInsets.symmetric(
                horizontal: radius > 30 ? 7 : 5,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                gradient: AppTheme.proBadgeGradient,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: Text(
                'PRO',
                style: GoogleFonts.outfit(
                  fontSize: radius > 30 ? 10 : 8,
                  fontWeight: FontWeight.w900,
                  color: Colors.black,
                  letterSpacing: 0.6,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
