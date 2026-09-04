import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'screens/onboarding_screen.dart';
import 'screens/main_layout_screen.dart';
import 'services/notification_service.dart';
import 'services/auth_service.dart';
import 'models/user_profile.dart';
import 'providers/onboarding_provider.dart';
import 'package:provider/provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/habits_provider.dart';
import 'providers/friends_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/login_provider.dart';
import 'providers/theme_mode_provider.dart';
import 'providers/subscription_provider.dart';
import 'providers/mood_provider.dart';
import 'providers/achievement_provider.dart';
import 'package:trackly/theme/color_scheme.dart';
import 'services/avatar_cache.dart';
import 'web/web_main_layout_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) debugPrint('Trackly: App Starting...');

  Object? bootstrapError;
  final themeModeProvider = ThemeModeProvider();
  SubscriptionProvider? subscriptionProvider;

  try {
    if (kDebugMode) debugPrint('Trackly: Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) debugPrint('Trackly: Firebase Ready.');

    if (!kIsWeb) {
      FirebaseFirestore.instance.settings = const Settings(
        persistenceEnabled: true,
        cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
      );
    }

    if (!kIsWeb) {
      // NON-BLOCKING notification setup
      // We do NOT 'await' this so that the UI can boot immediately.
      if (kDebugMode) {
        debugPrint('Trackly: Warming up notifications (Background)...');
      }
      NotificationService().initialize().catchError((e, stack) {
        if (kDebugMode) debugPrint('Trackly: Notification Init Error: $e');
      });
    }
  } catch (error, stackTrace) {
    if (kDebugMode) debugPrint('Trackly: Bootstrap Error: $error');
    bootstrapError = error;
    FlutterError.reportError(
      FlutterErrorDetails(
        exception: error,
        stack: stackTrace,
        library: 'trackly bootstrap',
      ),
    );
  }

  await themeModeProvider.loadThemePreference();
  if (bootstrapError == null) {
    subscriptionProvider = SubscriptionProvider();
    try {
      await subscriptionProvider.configure();
    } catch (error) {
      if (kDebugMode) {
        debugPrint('Trackly: RevenueCat init warning: $error');
      }
    }
  }

  runApp(
    MyApp(
      bootstrapError: bootstrapError,
      themeModeProvider: themeModeProvider,
      subscriptionProvider: subscriptionProvider,
    ),
  );
}

class MyApp extends StatelessWidget {
  final Object? bootstrapError;
  final ThemeModeProvider themeModeProvider;
  final SubscriptionProvider? subscriptionProvider;

  const MyApp({
    super.key,
    this.bootstrapError,
    required this.themeModeProvider,
    required this.subscriptionProvider,
  });

  @override
  Widget build(BuildContext context) {
    if (bootstrapError != null) {
      return MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: ThemeData.dark(),
        home: _BootstrapErrorScreen(error: bootstrapError!),
      );
    }

    return MultiProvider(
      providers: [
        ChangeNotifierProvider<ThemeModeProvider>.value(
          value: themeModeProvider,
        ),
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => FriendsProvider()),
        ChangeNotifierProvider(create: (_) => HabitsProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => LoginProvider()),
        ChangeNotifierProvider(create: (_) => MoodProvider()),
        ChangeNotifierProvider(create: (_) => AchievementProvider()),
        if (subscriptionProvider != null)
          ChangeNotifierProvider<SubscriptionProvider>.value(
            value: subscriptionProvider!,
          ),
      ],
      child: Consumer<ThemeModeProvider>(
        builder: (context, themeProvider, child) {
          return MaterialApp(
            title: 'Trackly',
            debugShowCheckedModeBanner: false,
            themeMode: themeProvider.themeMode,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            home: const RootGate(),
          );
        },
      ),
    );
  }
}

class RootGate extends StatefulWidget {
  const RootGate({super.key});

  @override
  State<RootGate> createState() => _RootGateState();
}

class _RootGateState extends State<RootGate> {
  late Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    // Cache the stream so StreamBuilder doesn't reset when MaterialApp rebuilds
    _authStream = AuthService().user;
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF101010),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            ),
          );
        }
        if (snapshot.hasData && snapshot.data != null) {
          if (kDebugMode) {
            debugPrint('Trackly: Session Found. Routing to Main.');
          }
          return _AuthBootstrapGate(user: snapshot.data!);
        }
        if (kDebugMode) {
          debugPrint('Trackly: No Session. Routing to Onboarding.');
        }
        return const OnboardingScreen(startStep: OnboardingStep.welcome);
      },
    );
  }
}

class _BootstrapErrorScreen extends StatelessWidget {
  final Object error;

  const _BootstrapErrorScreen({required this.error});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF101010),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.error_outline_rounded,
                color: Colors.redAccent,
                size: 56,
              ),
              const SizedBox(height: 16),
              Text(
                'Trackly could not start',
                textAlign: TextAlign.center,
                style: GoogleFonts.outfit(
                  fontSize: 28,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Please verify Firebase configuration and try again.\n$error',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white70, height: 1.5),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AuthBootstrapGate extends StatefulWidget {
  final User user;

  const _AuthBootstrapGate({required this.user});

  @override
  State<_AuthBootstrapGate> createState() => _AuthBootstrapGateState();
}

class _AuthBootstrapGateState extends State<_AuthBootstrapGate> {
  Future<UserProfile>? _bootstrapFuture;

  @override
  void initState() {
    super.initState();
    _startBootstrap();
  }

  @override
  void didUpdateWidget(covariant _AuthBootstrapGate oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.user.uid != widget.user.uid) {
      _startBootstrap();
    }
  }

  void _startBootstrap() {
    _bootstrapFuture = _runBootstrap();
  }

  Future<UserProfile> _runBootstrap() async {
    await AuthService().syncUserToFirestore(widget.user);
    unawaited(AvatarCache.initialize(widget.user.uid));

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.user.uid)
        .get();

    final data = doc.data() ?? <String, dynamic>{};

    // Auto-complete onboarding for legacy users who already exist
    // but don't have the onboardingCompleted flag
    if (!data.containsKey('onboardingCompleted')) {
      await AuthService().completeOnboarding(widget.user.uid);
      data['onboardingCompleted'] = true;
    }

    return UserProfile.fromMap(data);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<UserProfile>(
      future: _bootstrapFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            backgroundColor: Color(0xFF101010),
            body: Center(
              child: CircularProgressIndicator(color: Color(0xFF00E676)),
            ),
          );
        }

        if (snapshot.hasError) {
          return Stack(
            children: [
              const Scaffold(backgroundColor: Color(0xFF101010)),
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Container(
                    margin: const EdgeInsets.all(16),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1C1C1C),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.redAccent.withValues(alpha: 0.4),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(
                          Icons.cloud_off_rounded,
                          color: Colors.redAccent,
                        ),
                        const SizedBox(width: 12),
                        Flexible(
                          child: Text(
                            'Profile sync failed. Tap retry.',
                            style: GoogleFonts.inter(color: Colors.white),
                          ),
                        ),
                        const SizedBox(width: 12),
                        TextButton(
                          onPressed: () {
                            setState(_startBootstrap);
                          },
                          child: const Text('Retry'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        }

        if (snapshot.hasData) {
          final profile = snapshot.data!;
          if (profile.onboardingCompleted) {
            unawaited(NotificationService().initialize());
            return kIsWeb ? const WebMainLayoutScreen() : MainLayoutScreen();
          } else {
            return const OnboardingScreen(
              startStep: OnboardingStep.chooseUsername,
            );
          }
        }

        return const Scaffold(backgroundColor: Color(0xFF101010));
      },
    );
  }
}
