import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:provider/provider.dart';

import '../providers/onboarding_provider.dart';
import '../providers/login_provider.dart';
import '../widgets/appearance_selector.dart';
import '../services/notification_service.dart';
import 'main_layout_screen.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/habit.dart';
import '../widgets/habit_card.dart';

class OnboardingScreen extends StatelessWidget {
  final OnboardingStep startStep;

  const OnboardingScreen({super.key, required this.startStep});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OnboardingProvider(startStep: startStep),
      child: const _OnboardingView(),
    );
  }
}

class _OnboardingView extends StatelessWidget {
  const _OnboardingView();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: Stack(
        children: [
          // Ambient background
          Positioned.fill(
            child: Opacity(
              opacity: 0.05,
              child: Image.network(
                'https://www.transparenttextures.com/patterns/cubes.png',
                repeat: ImageRepeat.repeat,
              ),
            ),
          ),

          SafeArea(
            child: Column(
              children: [
                // Custom Progress Indicator
                _buildProgressIndicator(context, provider.currentStep),

                // Page Content
                Expanded(
                  child: PageView(
                    controller: provider.pageController,
                    physics: const NeverScrollableScrollPhysics(),
                    children: [
                      const _WelcomeStep(),
                      const _WhyTracklyStep(),
                      const _AppPreviewStep(),
                      const _UsernameStep(),
                      const _AppearanceStep(),
                      const _PermissionsStep(),
                      const _ReadyStep(),
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

  Widget _buildProgressIndicator(
    BuildContext context,
    OnboardingStep currentStep,
  ) {
    if (currentStep == OnboardingStep.welcome ||
        currentStep == OnboardingStep.ready) {
      return const SizedBox.shrink();
    }

    // Map step to progress (1 to 5) out of 5 total meaningful steps
    int totalSteps = 5;
    int current = currentStep.index - 1; // offset welcome
    if (current < 0) current = 0;
    if (current > totalSteps) current = totalSteps;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: Row(
        children: List.generate(totalSteps, (index) {
          final isActive = index <= current;
          return Expanded(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.symmetric(horizontal: 4.0),
              height: 4,
              decoration: BoxDecoration(
                color: isActive
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          );
        }),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 1: Welcome
// ---------------------------------------------------------------------------
class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          Icon(
                Icons.track_changes_rounded,
                size: 80,
                color: Theme.of(context).colorScheme.primary,
              )
              .animate()
              .fade(duration: 800.ms)
              .scaleXY(begin: 0.8, curve: Curves.easeOutCubic),
          const SizedBox(height: 32),
          Text(
                'Build habits\nthat actually stick.',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 40,
                  fontWeight: FontWeight.w800,
                  height: 1.1,
                  letterSpacing: -1,
                ),
              )
              .animate()
              .fade(delay: 200.ms)
              .slideY(begin: 0.1, curve: Curves.easeOutCubic),
          const SizedBox(height: 16),
          Text(
                'Track progress, stay accountable and grow consistently.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 18,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                  height: 1.4,
                ),
              )
              .animate()
              .fade(delay: 400.ms)
              .slideY(begin: 0.1, curve: Curves.easeOutCubic),
          const Spacer(flex: 3),
          _PrimaryCTA(
            text: 'Continue',
            onPressed: () => context.read<OnboardingProvider>().nextStep(),
          ).animate().fade(delay: 600.ms).scaleXY(begin: 0.95),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () async {
              // Direct Google login from Screen 1
              try {
                await context.read<LoginProvider>().signInWithGoogle();
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Login failed: $e')));
                }
              }
            },
            child: Text(
              'Already have an account?',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ).animate().fade(delay: 700.ms),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 2: Why Trackly?
// ---------------------------------------------------------------------------
class _WhyTracklyStep extends StatelessWidget {
  const _WhyTracklyStep();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            'The Trackly difference.',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ).animate().fade().slideX(begin: -0.05),
          const SizedBox(height: 40),
          _buildFeatureCard(
            context,
            icon: Icons.show_chart_rounded,
            title: 'Build consistency',
            subtitle: 'Never lose sight of your goals with powerful analytics.',
            delay: 100,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.people_alt_rounded,
            title: 'Stay accountable',
            subtitle: 'Grow together with friends and competitive groups.',
            delay: 200,
          ),
          const SizedBox(height: 16),
          _buildFeatureCard(
            context,
            icon: Icons.emoji_events_rounded,
            title: 'Celebrate progress',
            subtitle:
                'Streaks, insights and milestones that keep you motivated.',
            delay: 300,
          ),
          const Spacer(),
          _PrimaryCTA(
            text: 'See it in action',
            onPressed: () => context.read<OnboardingProvider>().nextStep(),
          ).animate().fade(delay: 500.ms).slideY(begin: 0.2),
          const SizedBox(height: 48),
        ],
      ),
    );
  }

  Widget _buildFeatureCard(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required int delay,
  }) {
    return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Theme.of(
              context,
            ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.05),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: Theme.of(context).colorScheme.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.inter(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.6),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        )
        .animate()
        .fade(delay: delay.ms)
        .slideY(begin: 0.1, curve: Curves.easeOutQuad);
  }
}

// ---------------------------------------------------------------------------
// Screen 3: App Preview & Login
// ---------------------------------------------------------------------------
class _AppPreviewStep extends StatefulWidget {
  const _AppPreviewStep();

  @override
  State<_AppPreviewStep> createState() => _AppPreviewStepState();
}

class _AppPreviewStepState extends State<_AppPreviewStep> {
  bool _isCompleted = false;

  @override
  Widget build(BuildContext context) {
    final loginProvider = context.watch<LoginProvider>();

    final mockHabit = Habit(
      id: 'mock_water',
      title: 'Drink Water',
      createdAt: DateTime.now(),
      isQuantified: true,
      quantUnit: 'glasses',
      quantMin: 0,
      quantMax: 5,
      targetDaysPerWeek: 7,
    );
    if (_isCompleted) {
      mockHabit.completions['mock_user'] = [
        DateTime.now(),
        DateTime.now().subtract(const Duration(days: 1)),
        DateTime.now().subtract(const Duration(days: 2)),
        DateTime.now().subtract(const Duration(days: 3)),
        DateTime.now().subtract(const Duration(days: 4)),
      ];
      mockHabit.quantifiedValues['mock_user'] = {
        mockHabit.dateKeyFor(DateTime.now()): 5.0,
      };
    } else {
      mockHabit.completions['mock_user'] = [
        DateTime.now().subtract(const Duration(days: 1)),
        DateTime.now().subtract(const Duration(days: 2)),
        DateTime.now().subtract(const Duration(days: 3)),
        DateTime.now().subtract(const Duration(days: 4)),
      ];
      mockHabit.quantifiedValues['mock_user'] = {
        mockHabit.dateKeyFor(DateTime.now()): 3.0,
      };
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 24),
          Text(
            'Experience the flow.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 28,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ).animate().fade(),
          const SizedBox(height: 8),
          Text(
            'Swipe the habit below to complete it.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ).animate().fade(delay: 100.ms),
          const Spacer(),

          // Interactive Mockup Card
          ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: Slidable(
                  key: const ValueKey('mock_habit_slidable'),
                  closeOnScroll: true,
                  startActionPane: ActionPane(
                    motion: const DrawerMotion(),
                    extentRatio: 0.28,
                    children: [
                      CustomSlidableAction(
                        onPressed: (_) {
                          setState(() => _isCompleted = !_isCompleted);
                        },
                        backgroundColor: Theme.of(
                          context,
                        ).colorScheme.primary.withValues(alpha: 0.9),
                        foregroundColor: Colors.white,
                        borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(24),
                          bottomLeft: Radius.circular(24),
                        ),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              _isCompleted
                                  ? Icons.undo_rounded
                                  : Icons.check_circle_rounded,
                              color: Colors.black,
                              size: 28,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _isCompleted ? 'Undo' : 'Done',
                              style: GoogleFonts.inter(
                                color: Colors.black,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  child: HabitCard(
                    habit: mockHabit,
                    currentUserId: 'mock_user',
                    margin: EdgeInsets.zero,
                    showShadow: false,
                    onCheck: () {
                      setState(() => _isCompleted = !_isCompleted);
                    },
                  ),
                ),
              )
              .animate()
              .fade(delay: 200.ms)
              .slideY(begin: 0.2, curve: Curves.easeOutBack),

          const Spacer(),

          if (loginProvider.isLoading)
            const Center(child: CircularProgressIndicator())
          else
            AnimatedOpacity(
              opacity: _isCompleted ? 1.0 : 0.4,
              duration: const Duration(milliseconds: 300),
              child: _PrimaryCTA(
                text: 'Continue with Google',
                icon: Icons.login_rounded,
                onPressed: _isCompleted
                    ? () async {
                        try {
                          await context
                              .read<LoginProvider>()
                              .signInWithGoogle();
                          // AuthState changes will trigger main.dart router to jump to ChooseUsername
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text('Login failed: $e')),
                            );
                          }
                        }
                      }
                    : null,
              ),
            ).animate().fade(delay: 400.ms),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 4: Choose Username
// ---------------------------------------------------------------------------
class _UsernameStep extends StatelessWidget {
  const _UsernameStep();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            'Claim your identity.',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ).animate().fade().slideX(begin: -0.05),
          const SizedBox(height: 12),
          Text(
            'Your username is how friends find you and join your groups.',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ).animate().fade(delay: 100.ms),
          const SizedBox(height: 40),

          // Username Input
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.surfaceContainerHighest.withValues(alpha: 0.3),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: provider.isUsernameAvailable == true
                    ? Colors.green.withValues(alpha: 0.5)
                    : provider.isUsernameAvailable == false
                    ? Colors.red.withValues(alpha: 0.5)
                    : Theme.of(
                        context,
                      ).colorScheme.onSurface.withValues(alpha: 0.1),
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Text(
                  '@',
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextFormField(
                    initialValue: provider.username,
                    onChanged: provider.setUsername,
                    style: GoogleFonts.inter(
                      fontSize: 20,
                      fontWeight: FontWeight.w600,
                    ),
                    decoration: InputDecoration(
                      border: InputBorder.none,
                      hintText: 'username',
                      hintStyle: GoogleFonts.inter(
                        color: Theme.of(
                          context,
                        ).colorScheme.onSurface.withValues(alpha: 0.3),
                      ),
                    ),
                  ),
                ),
                if (provider.isCheckingUsername)
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else if (provider.isUsernameAvailable == true)
                  const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.green,
                  ).animate().scale(curve: Curves.elasticOut)
                else if (provider.isUsernameAvailable == false)
                  const Icon(
                    Icons.cancel_rounded,
                    color: Colors.red,
                  ).animate().scale(curve: Curves.elasticOut),
              ],
            ),
          ).animate().fade(delay: 200.ms).slideY(begin: 0.1),

          if (provider.isUsernameAvailable == false)
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Text(
                'Username is taken. Try one of these:',
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ).animate().fade(),

          if (provider.usernameSuggestions.isNotEmpty)
            Wrap(
              spacing: 8,
              children: provider.usernameSuggestions.map((suggestion) {
                return ActionChip(
                  label: Text('@$suggestion'),
                  onPressed: () => provider.selectSuggestion(suggestion),
                  backgroundColor: Theme.of(
                    context,
                  ).colorScheme.surfaceContainerHighest,
                  side: BorderSide.none,
                );
              }).toList(),
            ).animate().fade(delay: 100.ms),

          const Spacer(),
          _PrimaryCTA(
            text: 'Continue',
            onPressed:
                (provider.username.length >= 3 &&
                    provider.isUsernameAvailable == true)
                ? () => provider.saveUsernameAndContinue()
                : null,
          ).animate().fade(delay: 400.ms),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 5: Choose Appearance
// ---------------------------------------------------------------------------
class _AppearanceStep extends StatelessWidget {
  const _AppearanceStep();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            'Make it yours.',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ).animate().fade().slideX(begin: -0.05),
          const SizedBox(height: 12),
          Text(
            'Choose how Trackly looks. You can change this later.',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ).animate().fade(delay: 100.ms),
          const SizedBox(height: 40),

          const Expanded(child: AppearanceSelector(isBottomSheet: false)),

          _PrimaryCTA(
            text: 'Continue',
            onPressed: () => provider.nextStep(),
          ).animate().fade(delay: 500.ms),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 6: Permissions
// ---------------------------------------------------------------------------
class _PermissionsStep extends StatelessWidget {
  const _PermissionsStep();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 32),
          Text(
            'Stay on track.',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              letterSpacing: -0.5,
            ),
          ).animate().fade().slideX(begin: -0.05),
          const SizedBox(height: 12),
          Text(
            'Allow notifications to receive timely reminders, group challenge updates, and milestone celebrations.',
            style: GoogleFonts.inter(
              fontSize: 16,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.5,
            ),
          ).animate().fade(delay: 100.ms),
          const Spacer(),

          Container(
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.primary.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.notifications_active_rounded,
                  size: 80,
                  color: Theme.of(context).colorScheme.primary,
                ),
              )
              .animate()
              .fade(delay: 200.ms)
              .scaleXY(begin: 0.8, curve: Curves.easeOutBack),

          const Spacer(),

          _PrimaryCTA(
            text: 'Enable Notifications',
            onPressed: () async {
              // Trigger native permission
              await NotificationService().initialize();
              provider.nextStep();
            },
          ).animate().fade(delay: 400.ms),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => provider.nextStep(),
            child: Text(
              'Not now',
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Theme.of(
                  context,
                ).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ).animate().fade(delay: 500.ms),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Screen 7: Ready
// ---------------------------------------------------------------------------
class _ReadyStep extends StatelessWidget {
  const _ReadyStep();

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<OnboardingProvider>();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Spacer(flex: 2),
          const Icon(
                Icons.task_alt_rounded,
                size: 100,
                color: Color(0xFF00E676),
              )
              .animate()
              .fade(duration: 500.ms)
              .scaleXY(begin: 0.5, curve: Curves.elasticOut),
          const SizedBox(height: 32),
          Text(
            'You\'re ready.',
            textAlign: TextAlign.center,
            style: GoogleFonts.outfit(
              fontSize: 48,
              fontWeight: FontWeight.w800,
              letterSpacing: -1,
            ),
          ).animate().fade(delay: 200.ms).slideY(begin: 0.1),
          const SizedBox(height: 16),
          Text(
            'Your profile is set up. Let\'s start building better routines.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 18,
              color: Theme.of(
                context,
              ).colorScheme.onSurface.withValues(alpha: 0.6),
              height: 1.4,
            ),
          ).animate().fade(delay: 300.ms).slideY(begin: 0.1),
          const Spacer(flex: 3),
          _PrimaryCTA(
            text: 'Start Building Habits',
            onPressed: () async {
              await provider.completeOnboarding();
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (_) => MainLayoutScreen()),
                  (route) => false,
                );
              }
            },
          ).animate().fade(delay: 500.ms).scaleXY(begin: 0.95),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared Components
// ---------------------------------------------------------------------------
class _PrimaryCTA extends StatelessWidget {
  final String text;
  final IconData? icon;
  final VoidCallback? onPressed;

  const _PrimaryCTA({required this.text, this.icon, this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        disabledBackgroundColor: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.1),
        disabledForegroundColor: Theme.of(
          context,
        ).colorScheme.onSurface.withValues(alpha: 0.3),
        padding: const EdgeInsets.symmetric(vertical: 20),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        elevation: 0,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 24),
            const SizedBox(width: 12),
          ],
          Text(
            text,
            style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
