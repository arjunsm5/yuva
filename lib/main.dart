import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart'; // Import Firebase Core
import 'package:yuva/screens/ui/splash_screen.dart'; // Import the SplashScreen
import 'package:yuva/utils/app_theme.dart'; // Import AppTheme for colors
import 'package:yuva/utils/theme_provider.dart'; // Import ThemeProvider for theme state
import 'package:firebase_app_check/firebase_app_check.dart'; // Import Firebase App Check
import 'firebase_options.dart'; // Import generated Firebase options

void main() async {
  // Ensure Flutter bindings are initialized before Firebase
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Firebase
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform, // Load Firebase configuration
  );

  // Initialize Firebase App Check for SafetyNet/Play Integrity (removes CAPTCHA)
  await FirebaseAppCheck.instance.activate(
    androidProvider: AndroidProvider.playIntegrity, // Use Play Integrity (modern replacement for SafetyNet)
    // Fallback to SafetyNet if Play Integrity is unavailable
    // androidProvider: AndroidProvider.safetyNet,
    // appleProvider: AppleProvider.appAttest, // Uncomment for iOS if needed
  );

  runApp(
    // 🌟 Wrap the app with ThemeProvider for global theme management
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

// 📄 Main app widget
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // 📡 Access the ThemeProvider to get the current theme mode
    final themeProvider = Provider.of<ThemeProvider>(context);

    return MaterialApp(
      debugShowCheckedModeBanner: false, // Hide debug banner
      theme: ThemeData(
        brightness: Brightness.light,
        primaryColor: AppTheme.primaryLight, // Light theme primary color (Violet)
        scaffoldBackgroundColor: AppTheme.backgroundLight, // Light background (White)
        appBarTheme: AppBarTheme(
          backgroundColor: AppTheme.backgroundLight,
          foregroundColor: AppTheme.textPrimaryLight, // Almost Black for icons/text
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: AppTheme.textPrimaryLight), // Almost Black for text
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.all(AppTheme.primaryLight), // Violet for radio buttons
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryLight, // Violet button background
            foregroundColor: AppTheme.textPrimaryLight, // Almost Black button text
          ),
        ),
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        primaryColor: AppTheme.primaryDark, // Dark theme primary color (Lilac)
        scaffoldBackgroundColor: AppTheme.backgroundDark, // Dark background (Charcoal)
        appBarTheme: AppBarTheme(
          backgroundColor: AppTheme.backgroundDark,
          foregroundColor: AppTheme.textPrimaryDark, // Soft White for icons/text
        ),
        textTheme: TextTheme(
          bodyMedium: TextStyle(color: AppTheme.textPrimaryDark), // Soft White for text
        ),
        radioTheme: RadioThemeData(
          fillColor: WidgetStateProperty.all(AppTheme.primaryDark), // Lilac for radio buttons
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.primaryDark, // Lilac button background
            foregroundColor: AppTheme.textPrimaryDark, // Soft White button text
          ),
        ),
      ),
      themeMode: themeProvider.themeMode, // 📅 Dynamically apply theme mode
      home: const SplashScreen(), // Start with the SplashScreen
    );
  }
}