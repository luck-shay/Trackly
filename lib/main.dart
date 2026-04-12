import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'screens/main_layout_screen.dart';
import 'package:provider/provider.dart';
import 'providers/navigation_provider.dart';
import 'providers/calendar_provider.dart';
import 'providers/friends_provider.dart';
import 'providers/create_habit_provider.dart';
import 'providers/profile_provider.dart';
import 'providers/login_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);

  if (!kIsWeb) {
    await GoogleSignIn.instance.initialize(
      serverClientId:
          '852142844109-k39c43icuhgd4nqheh3j33rird17a2bu.apps.googleusercontent.com',
    );
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => NavigationProvider()),
        ChangeNotifierProvider(create: (_) => CalendarProvider()),
        ChangeNotifierProvider(create: (_) => FriendsProvider()),
        ChangeNotifierProvider(create: (_) => CreateHabitProvider()),
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
              return MainLayoutScreen();
            }
            return const LoginScreen();
          },
        ),
      ),
    );
  }
}

