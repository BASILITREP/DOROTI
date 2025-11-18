import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'firebase_options.dart';
import 'screens/login_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'services/location_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'screens/home_screen.dart';


@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  print('📩 Background message: ${message.messageId}');
}

Future<void> initializeNotifications() async {
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
  FlutterLocalNotificationsPlugin();

  const AndroidNotificationChannel channel = AndroidNotificationChannel(
    'dorothy_location_service',
    'DOROTHY Location Service',
    description: 'Notification channel for location tracking service.',
    importance: Importance.low,
  );

  await flutterLocalNotificationsPlugin
      .resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>()
      ?.createNotificationChannel(channel);
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();


  // 🧩 Enable legacy TLS renegotiation (for old Equicom servers)
  final context = SecurityContext.defaultContext;
  context.allowLegacyUnsafeRenegotiation = true;
  HttpOverrides.global = MyHttpOverrides(); // 👈 applies globally
  print("⚠️ Legacy TLS renegotiation enabled — internal build mode.");


  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await initializeNotifications();
  await LocationService().initialize();
  await dotenv.load(fileName: ".env");
  // Save API_URL for background isolate
  final prefs = await SharedPreferences.getInstance();
  await prefs.setString("API_URL", dotenv.env["API_URL"]!);
  print("🌍 Saved API_URL for background isolate: ${dotenv.env["API_URL"]}");


  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

  // 🔔 Ask permission and get token
  final messaging = FirebaseMessaging.instance;
  NotificationSettings settings = await messaging.requestPermission(
    alert: true,
    badge: true,
    sound: true,
  );
  print('🔔 Notification permission: ${settings.authorizationStatus}');
  final token = await messaging.getToken();
  print('📱 Device FCM Token: $token');

  // 🔁 Automatically handle token refresh
  FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
    print('🔄 FCM token refreshed: $newToken');

    // Optionally, store it locally so you can send it to the backend again on next login
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('latestFcmToken', newToken);
  });


  // Foreground notification listener
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    print('📲 Foreground message: ${message.notification?.title}');
    final notification = message.notification;
    if (notification != null) {
      final flutterLocalNotificationsPlugin = FlutterLocalNotificationsPlugin();
      flutterLocalNotificationsPlugin.show(
        notification.hashCode,
        notification.title,
        notification.body,
        const NotificationDetails(
          android: AndroidNotificationDetails(
            'dorothy_channel',
            'Dorothy Notifications',
            icon: '@mipmap/equicom',
            importance: Importance.max,
            priority: Priority.high,
          ),
        ),
      );
    }
  });

  // Auto resume background service
  final isClockedIn = prefs.getBool('isClockedIn') ?? false;
  final fieldEngineerId = prefs.getInt('fieldEngineerId');
  final isLoggedIn = prefs.getBool("isLoggedIn") ?? false;
  final savedFEJson = prefs.getString("savedFieldEngineer");

  Map<String, dynamic>? savedFE;
  if (savedFEJson != null) {
    savedFE = jsonDecode(savedFEJson);
  }


  if (isClockedIn && fieldEngineerId != null) {
    print("🔄 Auto-starting background tracking after app relaunch");
    await LocationService().start(fieldEngineerId);
  } else {
    print("🛑 Not clocked in — skipping auto-start of background service");
  }



  runApp(MyApp(
    isLoggedIn: isLoggedIn,
    savedFE: savedFE,
  ));


}


class MyApp extends StatelessWidget {
  final bool isLoggedIn;
  final Map<String, dynamic>? savedFE;
  const MyApp({
    super.key,
    required this.isLoggedIn,
    required this.savedFE,
  });

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color.fromARGB(255, 116, 109, 241);
    const accentColor = Color.fromARGB(255, 245, 255, 140);

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
        textTheme: GoogleFonts.outfitTextTheme().apply(
          bodyColor: Colors.white,
          displayColor: Colors.white,
        ),
        scaffoldBackgroundColor: primaryColor,
      ),
      home: isLoggedIn && savedFE != null
          ? MyHomePage(
        title: "Hello, ${savedFE!['firstName']}",
        fieldEngineer: savedFE!,
      )
          : const LoginPage(),

    );
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      // Allow self-signed or legacy certs — but still log them
      print("⚠️ Accepting certificate from $host");
      return true;
    };
    return client;
  }
}
