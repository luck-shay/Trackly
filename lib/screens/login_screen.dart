import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';
import '../providers/login_provider.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final loginProvider = context.watch<LoginProvider>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Spacer(),
              Icon(
                    Icons.track_changes_rounded,
                    size: 100,
                    color: Theme.of(context).colorScheme.primary,
                  )
                  .animate()
                  .fade(duration: 500.ms)
                  .scaleXY(begin: 0.8, curve: Curves.easeOutBack),
              const SizedBox(height: 32),
              Text(
                'Trackly',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 48,
                  fontWeight: FontWeight.w800,
                  letterSpacing: -1.5,
                  height: 1.0,
                ),
              ).animate().fade(delay: 100.ms).slideY(begin: 0.1),
              const SizedBox(height: 12),
              Text(
                'Build better routines.\nConnect with friends.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: Colors.grey[400],
                  height: 1.4,
                ),
              ).animate().fade(delay: 200.ms).slideY(begin: 0.1),
              const Spacer(),

              if (loginProvider.isLoading)
                const Center(
                  child: CircularProgressIndicator(color: Color(0xFF00E676)),
                )
              else
                ElevatedButton(
                  onPressed: () async {
                    try {
                      await context.read<LoginProvider>().signInWithGoogle();
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              'Sign in failed. Error: ${e.toString().split('\n').first}',
                              style: const TextStyle(color: Colors.white),
                            ),
                            backgroundColor: Colors.red.shade800,
                            duration: const Duration(seconds: 4),
                          ),
                        );
                      }
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.22),
                      width: 1.2,
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        'G',
                        style: GoogleFonts.outfit(
                          fontSize: 24,
                          fontWeight: FontWeight.w900,
                          color: Colors.black,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Continue with Google',
                        style: GoogleFonts.inter(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ).animate().fade(delay: 400.ms).scaleXY(begin: 0.95),
              const SizedBox(height: 48),
            ],
          ),
        ),
      ),
    );
  }
}
