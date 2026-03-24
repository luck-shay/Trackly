import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../services/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final AuthService _authService = AuthService();
  bool _isLoading = false;

  void _handleGoogleSignIn() async {
    setState(() => _isLoading = true);
    await _authService.signInWithGoogle();
    
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
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
              ).animate().fade(duration: 500.ms).scaleXY(begin: 0.8, curve: Curves.easeOutBack),
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
              
              if (_isLoading)
                const Center(child: CircularProgressIndicator(color: Color(0xFF00E676)))
              else
                ElevatedButton(
                  onPressed: _handleGoogleSignIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    elevation: 0,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('G', style: GoogleFonts.outfit(fontSize: 24, fontWeight: FontWeight.w900, color: Colors.black)),
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
