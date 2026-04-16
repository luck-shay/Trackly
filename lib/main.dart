import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout_screen.dart';
import 'services/notification_service.dart';
import 'package:provider/provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/habits_provider.dart';
import 'providers/friends_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/login_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (kDebugMode) debugPrint('Trackly: App Starting...');
  
  Object? bootstrapError;

  try {
    if (kDebugMode) debugPrint('Trackly: Initializing Firebase...');
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    if (kDebugMode) debugPrint('Trackly: Firebase Ready.');

    if (!kIsWeb) {
      // NON-BLOCKING notification setup
      // We do NOT 'await' this so that the UI can boot immediately.
      if (kDebugMode) debugPrint('Trackly: Warming up notifications (Background)...');
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

  runApp(MyApp(bootstrapError: bootstrapError));
}

class MyApp extends StatelessWidget {
  final Object? bootstrapError;

  const MyApp({super.key, this.bootstrapError});

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
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => FriendsProvider()),
        ChangeNotifierProvider(create: (_) => HabitsProvider()),
        ChangeNotifierProvider(create: (_) => ProfileProvider()),
        ChangeNotifierProvider(create: (_) => LoginProvider()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'Trackly',
        themeMode: ThemeMode.dark,
        darkTheme: ThemeData(
          brightness: Brightness.dark,
          scaffoldBackgroundColor: const Color(0xFF101010),
          colorScheme: const ColorScheme.dark(
            primary: Color(0xFF00E676),
            secondary: Color(0xFF2979FF),
            surface: Color(0xFF1A1A1A),
            onSurface: Colors.white,
          ),
          textTheme: GoogleFonts.outfitTextTheme(ThemeData.dark().textTheme)
              .copyWith(
                titleLarge: GoogleFonts.outfit(fontWeight: FontWeight.bold),
                bodyMedium: GoogleFonts.inter(),
              ),
          appBarTheme: const AppBarTheme(
            backgroundColor: Colors.transparent,
            elevation: 0,
            centerTitle: false,
          ),
          floatingActionButtonTheme: const FloatingActionButtonThemeData(
            backgroundColor: Color(0xFF00E676),
            foregroundColor: Colors.black,
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.all(Radius.circular(20)),
            ),
          ),
          useMaterial3: true,
        ),
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
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
              if (kDebugMode) debugPrint('Trackly: Session Found. Routing to Main.');
              return MainLayoutScreen();
            }
            if (kDebugMode) debugPrint('Trackly: No Session. Routing to Login.');
            return const LoginScreen();
          },
        ),
      ),
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
