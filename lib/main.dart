// lib/main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:mapbox_maps_flutter/mapbox_maps_flutter.dart';
import 'screens/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart'; // ⭐ Needed for clocked-in check

// Top-level function for background message handling
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print('Handling a background message: ${message.messageId}');
}

Future<void> initializeNotifications() async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'dorothy_location_service',
    'DOROTHY Location Service',
    description: 'Notification channel for location tracking service.',
    importance: Importance.low, // Use low importance to avoid sound
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await setup();
  await Firebase.initializeApp();
  await initializeNotifications();
  await LocationService().initialize(); // ✅ Prepare background service

  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // ⭐ NEW: Auto-resume tracking if still clocked in
  final prefs = await SharedPreferences.getInstance();
  final isClockedIn = prefs.getBool('isClockedIn') ?? false;
  final fieldEngineerId = prefs.getInt('fieldEngineerId');

  if (isClockedIn && fieldEngineerId != null) {
    print("🔄 Auto-starting background tracking after app relaunch");
    await LocationService().start(fieldEngineerId);
  } else {
    print("🛑 Not clocked in — skipping auto-start of background service");
  }

  runApp(const MyApp());
}

Future<void> setup() async {
  await dotenv.load(fileName: ".env");
  MapboxOptions.setAccessToken(dotenv.env['MAPBOX_ACCESS_TOKEN']!);
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Custom colors - UPDATED
    const primaryColor = Color.fromARGB(255, 116, 109, 241); // Deep purple
    const accentColor = Color.fromARGB(255, 245, 255, 140); // Yellow-green

    return MaterialApp(
      title: 'Dorothy',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: primaryColor,
          brightness: Brightness.light,
          surface: primaryColor,
          onSurface: Colors.white,
          primary: accentColor,
          onPrimary: Colors.black87,
          primaryContainer: accentColor,
          onPrimaryContainer: Colors.black87,
          secondary: accentColor.withOpacity(0.8),
          tertiary: accentColor.withOpacity(0.6),
        ),
        filledButtonTheme: FilledButtonThemeData(
          style: FilledButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.black87,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: accentColor,
            foregroundColor: Colors.black87,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: accentColor,
          foregroundColor: Colors.black87,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 0,
        ),
        cardTheme: CardThemeData(
          color: Colors.white,
          elevation: 4,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        scaffoldBackgroundColor: primaryColor,
        textTheme: GoogleFonts.outfitTextTheme(
          ThemeData(brightness: Brightness.light).textTheme,
        ).apply(bodyColor: Colors.white, displayColor: Colors.white),
      ),
      home: const LoginPage(),
    );
  }
}
