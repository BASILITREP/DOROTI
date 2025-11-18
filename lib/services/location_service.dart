import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart' as geo;
import '../database/location_db.dart';

@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();

  await LocationDB.instance();

  // ✅ TLS override
  HttpOverrides.global = MyHttpOverrides();
  SecurityContext.defaultContext.allowLegacyUnsafeRenegotiation = true;
  print("⚙️ Background isolate: legacy TLS override applied.");

  List<Map<String, dynamic>> locationBuffer = [];
  Timer? batchTimer;
  Timer? liveUpdateTimer;
  Timer? heartbeatTimer;
  int? fieldEngineerId;
  Map<String, dynamic>? lastLocation;

  Map<String, dynamic>? lastSentLocation;
  DateTime lastSentTime = DateTime.now();

  // --- CONFIG ---
  const double minDistanceMeters = 10;  //25
  const Duration minTimeInterval = Duration(seconds: 10);//30
  const int maxBatchSize = 8; //20

  final prefs = await SharedPreferences.getInstance();
  final apiUrl = prefs.getString("API_URL")!;
  print("🌍 Loaded API_URL inside isolate: $apiUrl");

  // --- Load saved FE ID ---
  final isClockedIn = prefs.getBool('isClockedIn') ?? false;
  if (!isClockedIn) {
    print("🛑 Not clocked in — skipping background tracking startup.");
    service.stopSelf();
    return;
  }
  fieldEngineerId = prefs.getInt('fieldEngineerId');
  print("📂 Field Engineer ID: $fieldEngineerId");

  if (service is AndroidServiceInstance) {
    service.setAsForegroundService();
    service.setForegroundNotificationInfo(
      title: "DOROTI",
      content: "Tracking active for trip detection.",
    );
  }

  // --- SEND LIVE LOCATION (every 10s for real-time admin map) ---
  Future<void> sendLiveLocationUpdate(Map<String, dynamic> locationData) async {
    if (fieldEngineerId == null) return;

    try {
      final url = Uri.parse('$apiUrl/FieldEngineer/updateLocation');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': fieldEngineerId,
          'currentLatitude': locationData['latitude'],
          'currentLongitude': locationData['longitude'],
          'isActive': true,
          'isMoving':
          locationData['speed'] != null && locationData['speed'] > 0.83,
        }),
      );
      if (response.statusCode == 200) {
        print('📍 LIVE location update sent successfully.');
      } else {
        print('❌ Live location failed: ${response.statusCode}');
      }
    } catch (e) {
      print('🔥 Error sending live location: $e');
    }
  }

  // --- SEND BATCHED LOCATION POINTS (for trip detection) ---
  Future<void> sendLocationHistory() async {
    if (fieldEngineerId == null || fieldEngineerId == 0) {
      print("⚠️ [sendLocationHistory] No valid FieldEngineerId found — skipping batch send.");
      return;
    }

    if (locationBuffer.isEmpty) {
      print("⏸ [sendLocationHistory] Buffer empty — nothing to send.");
      return;
    }

    print("📦 Preparing to send ${locationBuffer.length} location points for FE #$fieldEngineerId...");

    final List<Map<String, dynamic>> batchToSend = locationBuffer.map((point) => {
      'fieldEngineerId': fieldEngineerId,
      'latitude': point['latitude'],
      'longitude': point['longitude'],
      'speed': point['speed'] ?? 0.0,
      'accuracy': point['accuracy'] ?? 0.0,
      'timestamp': point['timestamp'],
    }).toList();

    locationBuffer.clear();

    final sample = jsonEncode(batchToSend.take(1).toList());
    print("🔍 Sample payload: $sample");

    try {
      final url = Uri.parse('$apiUrl/Location');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(batchToSend),
      );

      if (response.statusCode == 200) {
        print("✅ [sendLocationHistory] Successfully sent ${batchToSend.length} points for FE #$fieldEngineerId");
      } else {
        print("❌ [sendLocationHistory] Failed with status ${response.statusCode}");
        print("🧾 Server response: ${response.body}");

        for (final point in batchToSend) {
          await LocationDB.insertPoint({
            'latitude': point['latitude'],
            'longitude': point['longitude'],
            'speed': point['speed'],
            'accuracy': point['accuracy'],
            'timestamp': point['timestamp'],
          });
        }
        print("💾 Saved failed batch (${batchToSend.length}) → SQLite");
      }
    } catch (e) {
      print("🔥 [sendLocationHistory] Exception while sending batch: $e");
      for (final point in batchToSend) {
        await LocationDB.insertPoint({
          'latitude': point['latitude'],
          'longitude': point['longitude'],
          'speed': point['speed'],
          'accuracy': point['accuracy'],
          'timestamp': point['timestamp'],
        });
      }
      print("🔥 Batch send failed — saved ${batchToSend.length} points → SQLite");
    }
  }

  // Retry sending cached points
  Future<void> resendCachedPoints() async {
    final cached = await LocationDB.getAllPoints();
    if (cached.isEmpty) {
      print("🟩 No cached points to resend.");
      return;
    }

    print("🔄 Retrying ${cached.length} cached points...");

    final failedIds = <int>[];

    for (var row in cached) {
      try {
        final res = await http.post(
          Uri.parse('$apiUrl/Location'),
          headers: {"Content-Type": "application/json"},
          body: jsonEncode([
            {
              'fieldEngineerId': fieldEngineerId,
              'latitude': row['latitude'],
              'longitude': row['longitude'],
              'speed': row['speed'],
              'accuracy': row['accuracy'],
              'timestamp': row['timestamp'],
            }
          ]),
        );

        if (res.statusCode != 200 && res.statusCode != 201) {
          failedIds.add(row['id']);
        }
      } catch (_) {
        failedIds.add(row['id']);
      }
    }

    final idsToDelete =
    cached.map<int>((row) => row['id']).where((id) => !failedIds.contains(id)).toList();

    await LocationDB.deletePoints(idsToDelete);

    print("✨ Resend complete. Remaining (failed): ${failedIds.length}");
  }

  // 🟢 REAL FIX: Geolocator stream running INSIDE background isolate
  geo.Position? lastGeoPosition;
  StreamSubscription<geo.Position>? positionSub;

  // Check service + permission (assume granted from foreground)
  final serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
  if (!serviceEnabled) {
    print("🛑 Location services are disabled. Stopping background service.");
    service.stopSelf();
    return;
  }

  var permission = await geo.Geolocator.checkPermission();
  if (permission == geo.LocationPermission.denied ||
      permission == geo.LocationPermission.deniedForever) {
    print("🛑 Location permission denied in isolate. Stopping service.");
    service.stopSelf();
    return;
  }

  final locationSettings = geo.AndroidSettings(
    accuracy: geo.LocationAccuracy.bestForNavigation,
    intervalDuration: const Duration(seconds: 5), //10
    distanceFilter: 5, //15
    forceLocationManager: true, // recommended for background
  );


  positionSub = geo.Geolocator.getPositionStream(
    locationSettings: locationSettings,
  ).listen((geo.Position pos) async {
    try {
      // basic filtering based on distance+time (same concept as before)
      if (lastSentLocation != null) {
        final distance = geo.Geolocator.distanceBetween(
          lastSentLocation!['latitude'],
          lastSentLocation!['longitude'],
          pos.latitude,
          pos.longitude,
        );
        final timeElapsed = DateTime.now().difference(lastSentTime);

        if (distance < minDistanceMeters && timeElapsed < minTimeInterval) {
          print(
              "⏸ Skipping point — moved only ${distance.toStringAsFixed(1)}m, ${timeElapsed.inSeconds}s elapsed.");
          return;
        }
      }

      // normalize speed (m/s → km/h, noise filter)
      double speedKmh = (pos.speed ?? 0.0) * 3.6;
      if (speedKmh < 5) speedKmh = 0;
      speedKmh = double.parse(speedKmh.toStringAsFixed(1));

      final phtTime = DateTime.now().toUtc().add(const Duration(hours: 8));
      final point = {
        'latitude': pos.latitude,
        'longitude': pos.longitude,
        'speed': speedKmh,
        'accuracy': pos.accuracy ?? 0.0,
        'timestamp': phtTime.toIso8601String().replaceAll('Z', '+08:00'),
      };

      lastLocation = point;
      lastSentLocation = point;
      lastSentTime = DateTime.now();
      lastGeoPosition = pos;

      locationBuffer.add(point);

      print(
          "🟢 [BG] New point: ${pos.latitude.toStringAsFixed(6)}, ${pos.longitude.toStringAsFixed(6)} (buffer: ${locationBuffer.length})");

      if (locationBuffer.length >= maxBatchSize) {
        await sendLocationHistory();
      }
    } catch (e) {
      print("🔥 Error processing position in isolate: $e");
    }
  }, onError: (e) {
    print("🔥 Geolocator stream error in isolate: $e");
  });

  // --- Foreground/background events ---
  service.on('setAsForeground').listen((event) {
    if (service is AndroidServiceInstance) service.setAsForegroundService();
  });
  service.on('setAsBackground').listen((event) {
    if (service is AndroidServiceInstance) service.setAsBackgroundService();
  });
  service.on('stopService').listen((event) async {
    print("🛑 Stopping background service (manual stop)...");
    batchTimer?.cancel();
    liveUpdateTimer?.cancel();
    heartbeatTimer?.cancel();
    await positionSub?.cancel();

    if (locationBuffer.isNotEmpty) {
      for (final point in locationBuffer) {
        await LocationDB.insertPoint({
          'latitude': point['latitude'],
          'longitude': point['longitude'],
          'speed': point['speed'],
          'accuracy': point['accuracy'],
          'timestamp': point['timestamp'],
        });
        print("💾 Cached point → SQLite");
      }
      locationBuffer.clear();
      print("💾 Merged buffer points into cache on stop.");
    }

    if (locationBuffer.isNotEmpty) await sendLocationHistory();
    service.stopSelf();
  });

  // --- Live updates every 10 seconds ---
  liveUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
    if (lastLocation != null) sendLiveLocationUpdate(lastLocation!);
  });

  // --- Force-send unsent batches every 2 minutes ---
  batchTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
    await resendCachedPoints();
    await sendLocationHistory();
  });

  // Heartbeat logs
  heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
    print("💓 BG service alive - tracking for trip detection");
  });

  print("🚀 Dorothy background tracking started (Geolocator in isolate)!");
  await resendCachedPoints();

  print("📍 Live update: every 10s");
  print("📦 Batch upload: smart-filtered + every 2min");
}

class LocationService {
  final _backgroundService = FlutterBackgroundService();

  Future<void> initialize() async {
    await _backgroundService.configure(
      androidConfiguration: AndroidConfiguration(
        onStart: onStart,
        isForegroundMode: true,
        autoStart: true,
        autoStartOnBoot: true,
        notificationChannelId: 'dorothy_location_service',
        initialNotificationTitle: 'Dorothy Location Service',
        initialNotificationContent: 'Tracking active for trip detection.',
        foregroundServiceNotificationId: 888,
        foregroundServiceTypes: [AndroidForegroundType.location],
      ),
      iosConfiguration: IosConfiguration(
        onForeground: onStart,
        onBackground: onIosBackground,
        autoStart: false,
      ),
    );
  }

  Future<void> start(int fieldEngineerId) async {
    print("=== Starting Location Service for FE ID: $fieldEngineerId ===");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('fieldEngineerId', fieldEngineerId);
    await prefs.setBool('isClockedIn', true);

    // Permissions handled in foreground (UI)
    bool serviceEnabled = await geo.Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      print("🛑 Location service disabled.");
      return;
    }

    var permission = await geo.Geolocator.checkPermission();
    if (permission == geo.LocationPermission.denied) {
      permission = await geo.Geolocator.requestPermission();
    }
    if (permission == geo.LocationPermission.denied ||
        permission == geo.LocationPermission.deniedForever) {
      print("🛑 Location permission denied.");
      return;
    }

    print("✅ Location permissions granted (foreground)");
    await _backgroundService.startService();
    print("✅ Background tracking active (service started)!");
  }

  void stop() async {
    print("=== Stopping Dorothy Location Service ===");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isClockedIn', false);
    _backgroundService.invoke('stopService');
  }
}

class MyHttpOverrides extends HttpOverrides {
  @override
  HttpClient createHttpClient(SecurityContext? context) {
    final client = super.createHttpClient(context);
    client.badCertificateCallback =
        (X509Certificate cert, String host, int port) {
      print("⚠️ Accepting certificate from $host (background isolate)");
      return true;
    };
    return client;
  }
}
