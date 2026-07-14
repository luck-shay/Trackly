import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

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

    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;

    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          colors: [primary, primary.withValues(alpha: 0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: 0.3),
            blurRadius: 8,
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
                horizontal: radius > 30 ? 6 : 4,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [primary, primary.withValues(alpha: 0.7)],
                ),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 1.5,
                ),
              ),
              child: Text(
                'PRO',
                style: GoogleFonts.outfit(
                  fontSize: radius > 30 ? 10 : 8,
                  fontWeight: FontWeight.w900,
                  color: onPrimary,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
