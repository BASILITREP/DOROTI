import 'dart:async';
import 'dart:convert';
import 'dart:ui';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_background_service/flutter_background_service.dart';
import 'package:location/location.dart' as loc;
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:geolocator/geolocator.dart' as geo;


@pragma('vm:entry-point')
Future<bool> onIosBackground(ServiceInstance service) async {
  WidgetsFlutterBinding.ensureInitialized();
  DartPluginRegistrant.ensureInitialized();
  return true;
}

@pragma('vm:entry-point')
void onStart(ServiceInstance service) async {
  DartPluginRegistrant.ensureInitialized();

  // ✅ Reapply TLS override for background isolate
  HttpOverrides.global = MyHttpOverrides();
  SecurityContext.defaultContext.allowLegacyUnsafeRenegotiation = true;
  print("⚙️ Background isolate: legacy TLS override applied.");



  List<Map<String, dynamic>> locationBuffer = [];
  Timer? batchTimer;
  Timer? liveUpdateTimer;
  int? fieldEngineerId;
  Map<String, dynamic>? lastLocation;

  Map<String, dynamic>? lastSentLocation;
  DateTime lastSentTime = DateTime.now();

  // --- CONFIG ---
  const double MIN_DISTANCE_METERS = 25; //25
  const Duration MIN_TIME_INTERVAL = Duration(seconds: 30); //30
  const int MAX_BATCH_SIZE = 20;



  // --- SEND LIVE LOCATION (every 10s for real-time admin map) ---
  Future<void> sendLiveLocationUpdate(Map<String, dynamic> locationData) async {
    if (fieldEngineerId == null) return;

    try {
      final url = Uri.parse(
          'https://sdstestwebservices.equicom.com/dorotiserver/api/FieldEngineer/updateLocation');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'id': fieldEngineerId,
          'currentLatitude': locationData['latitude'],
          'currentLongitude': locationData['longitude'],
          'isActive': true,
          'isMoving':
          locationData['speed'] != null && locationData['speed'] > 0.83, // 3 km/h = 0.83 m/s,
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
    // --- 1️⃣ Basic validation ---
    if (fieldEngineerId == null || fieldEngineerId == 0) {
      print("⚠️ [sendLocationHistory] No valid FieldEngineerId found — skipping batch send.");
      return;
    }

    if (locationBuffer.isEmpty) {
      print("⏸ [sendLocationHistory] Buffer empty — nothing to send.");
      return;
    }

    print("📦 Preparing to send ${locationBuffer.length} location points for FE #$fieldEngineerId...");

    // --- 2️⃣ Format the payload exactly as backend expects ---
    final List<Map<String, dynamic>> batchToSend = locationBuffer.map((point) => {
      'fieldEngineerId': fieldEngineerId,
      'latitude': point['latitude'],
      'longitude': point['longitude'],
      'speed': point['speed'] ?? 0.0,
      'accuracy': point['accuracy'] ?? 0.0,
      'timestamp': point['timestamp'],
    }).toList();

    // Clear buffer optimistically (we’ll restore if fail)
    locationBuffer.clear();

    // --- 3️⃣ Debug sample payload ---
    final sample = jsonEncode(batchToSend.take(1).toList());
    print("🔍 Sample payload: $sample");

    print("⏰ Current timestamp being sent: ${batchToSend.first['timestamp']}");
    print("📅 Expected format: ${DateTime.now().toUtc().toIso8601String()}");

    // --- 4️⃣ Attempt to send batch ---
    try {
      final url = Uri.parse(
          'https://sdstestwebservices.equicom.com/dorotiserver/api/Location');

      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(batchToSend),
      );

      // --- 5️⃣ Handle response codes cleanly ---
      if (response.statusCode == 200) {
        print("✅ [sendLocationHistory] Successfully sent ${batchToSend.length} points for FE #$fieldEngineerId");

        //print each point sent

      } else {
        print("❌ [sendLocationHistory] Failed with status ${response.statusCode}");
        print("🧾 Server response: ${response.body}");

        // --- Restore buffer for retry ---
        locationBuffer.insertAll(0, batchToSend);
        print("🔁 Restored ${batchToSend.length} points to buffer for retry.");
      }
    } catch (e) {
      // --- 6️⃣ Network or unexpected error ---
      print("🔥 [sendLocationHistory] Exception while sending batch: $e");

      // --- Reinsert points to buffer so they’re not lost ---
      locationBuffer.insertAll(0, batchToSend);
      print("💾 Buffered ${batchToSend.length} points for next retry.");
    }
  }

  //cache unsent location points when offline or API fails
  Future<void> _cacheUnsentPoint(Map<String, dynamic> point) async{
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList('unsent_points') ?? [];
    cached.add(jsonEncode(point));
    await prefs.setStringList('unsent_points', cached);
    print("💾 Cached unsent point. Total cached: ${cached.length}");
  }

  //Retry sending cached points if connection is back
  Future<void> _retryCachedPoints() async {
    final prefs = await SharedPreferences.getInstance();
    final cached = prefs.getStringList('unsent_points') ?? [];
    if (cached.isEmpty) return;
    print("🔄 Retrying ${cached.length} cached points...");
    print("🗂 Cached points: $cached");

    final stillFailed = <String>[];
    for (final raw in cached) {
      final point = jsonDecode(raw);

      // Validate and add FieldEngineerId
      if (fieldEngineerId == null || fieldEngineerId == 0) {
        print("⚠️ Skipping point — missing FieldEngineerId.");
        continue;
      }
      point['fieldEngineerId'] = fieldEngineerId;

      try {
        final res = await http.post(
          Uri.parse('https://sdstestwebservices.equicom.com/dorotiserver/api/Location'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode([point]),
        );

        if (res.statusCode == 200 || res.statusCode == 201) {
          print("✅ Cached point sent successfully.");
        } else {
          print("❌ Failed to send cached point: ${res.body}");
          stillFailed.add(raw);
        }
      } catch (e) {
        print("🔥 Error sending cached point: $e");
        stillFailed.add(raw);
      }
    }

    await prefs.setStringList('unsent_points', stillFailed);
    if (stillFailed.isEmpty) {
      print('🎉 All cached points synced successfully!');
    } else {
      print('🟠 ${stillFailed.length} points still pending retry.');
    }
  }


  // --- Handle new location updates from main isolate ---
  service.on('location_update').listen((event) async {
    final data = event!['data'] as Map<String, dynamic>;
    lastLocation = data;

    // --- Smart filtering ---
    if (lastSentLocation != null) {
      final distance = geo.Geolocator.distanceBetween(
        lastSentLocation!['latitude'],
        lastSentLocation!['longitude'],
        data['latitude'],
        data['longitude'],
      );
      final timeElapsed = DateTime.now().difference(lastSentTime);

      if (distance < MIN_DISTANCE_METERS && timeElapsed < MIN_TIME_INTERVAL) {
        print("⏸ Skipping point — moved only ${distance.toStringAsFixed(1)}m, ${timeElapsed.inSeconds}s elapsed.");
        return; // Too soon or too close — skip
      }
    }

    // --- Add to buffer ---
    locationBuffer.add(data);
    lastSentLocation = data;
    lastSentTime = DateTime.now();

    print("📍 Buffered point: ${data['latitude']?.toStringAsFixed(6)}, ${data['longitude']?.toStringAsFixed(6)} (Buffer: ${locationBuffer.length})");

    // --- Auto-send if batch full ---
    if (locationBuffer.length >= MAX_BATCH_SIZE) {
      await sendLocationHistory();
    }

    // --- Update foreground notification ---
    if (service is AndroidServiceInstance) {
      service.setForegroundNotificationInfo(
        title: "DOROTI",
        content: "Good day to you!",
      );
    }
  });

  // --- Handle service lifecycle events ---
  service.on('setAsForeground').listen((event) {
    if (service is AndroidServiceInstance) service.setAsForegroundService();
  });
  service.on('setAsBackground').listen((event) {
    if (service is AndroidServiceInstance) service.setAsBackgroundService();
  });
  service.on('stopService').listen((event) async {
    print("🛑 Stopping background service...");
    batchTimer?.cancel();
    liveUpdateTimer?.cancel();
    if (locationBuffer.isNotEmpty) {
      for (final point in locationBuffer) {
        await _cacheUnsentPoint(point);
      }
      locationBuffer.clear();
      print("💾 Merged buffer points into cache on stop.");
    }

    if (locationBuffer.isNotEmpty) await sendLocationHistory();
    service.stopSelf();
  });

  // --- Load saved FE ID ---
  final prefs = await SharedPreferences.getInstance();
  final isClockedIn = prefs.getBool('isClockedIn') ?? false;
  if (!isClockedIn) {
    print("🛑 Not clocked in — skipping background tracking startup.");
    service.stopSelf();
    return;
  }
  fieldEngineerId = prefs.getInt('fieldEngineerId');
  print("📂 Field Engineer ID: $fieldEngineerId");

  if (service is AndroidServiceInstance) service.setAsForegroundService();

  // --- Live updates every 10 seconds ---
  liveUpdateTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
    if (lastLocation != null) sendLiveLocationUpdate(lastLocation!);
  });

  // --- Force-send unsent batches every 2 minutes ---
  batchTimer = Timer.periodic(const Duration(minutes: 2), (timer) async {
    await _retryCachedPoints();
    await sendLocationHistory();
  });

  print("🚀 Dorothy background tracking started!");
  await _retryCachedPoints();

  print("📍 Live update: every 10s");
  print("📦 Batch upload: smart-filtered + every 2min");
}

class LocationService {
  final _backgroundService = FlutterBackgroundService();
  loc.Location? _location;
  StreamSubscription<loc.LocationData>? _locationSubscription;
  Timer? _heartbeatTimer;

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

    _location = loc.Location();

    // --- Permissions ---
    bool serviceEnabled = await _location!.serviceEnabled();
    if (!serviceEnabled) serviceEnabled = await _location!.requestService();
    if (!serviceEnabled) return;

    loc.PermissionStatus permissionGranted = await _location!.hasPermission();
    if (permissionGranted == loc.PermissionStatus.denied) {
      permissionGranted = await _location!.requestPermission();
      if (permissionGranted != loc.PermissionStatus.granted) return;
    }

    print("✅ Location permissions granted");
    await _backgroundService.startService();
    await _startLocationTracking();
    if (!await _location!.serviceEnabled()) {
      print("⚠️ Location service disabled — stopping tracking.");
      stop();
      return;
    }

    print("✅ Background tracking active!");
  }

  Future<void> _startLocationTracking() async {
    try {
      loc.LocationData? lastSentLocation;
      const double minMovementMeters = 25.0; // don't send if <10m moved

      await _location!.changeSettings(
        accuracy: loc.LocationAccuracy.high,
        interval: 10000, // 10 seconds between raw updates
        distanceFilter: 15, // let us handle movement filtering manually
      );

      _locationSubscription = _location!.onLocationChanged.listen(
            (loc.LocationData currentLocation) async {
          if (currentLocation.latitude == null || currentLocation.longitude == null) return;

          bool shouldSend = false;
          double movedDistance = 0;

          if (lastSentLocation == null) {
            shouldSend = true; // first point
          } else {
            movedDistance = geo.Geolocator.distanceBetween(
              lastSentLocation!.latitude!,
              lastSentLocation!.longitude!,
              currentLocation.latitude!,
              currentLocation.longitude!,
            );
            if (movedDistance >= minMovementMeters) {
              shouldSend = true;
            }
          }

          if (shouldSend) {

            //Normalize filter speed
            double rawSpeed = currentLocation.speed ?? 0.0; //m/s
            double speedKmh = rawSpeed * 3.6; // convert to km/h

            //treat small GPS noise (< kmh/5) as stationary
            if (speedKmh < 5) speedKmh = 0;

            //round to 1 decimal place
            speedKmh = double.parse(speedKmh.toStringAsFixed(1));
            final phtTime = DateTime.now().toUtc().add(Duration(hours: 8));
            final locationPoint = {
              'latitude': currentLocation.latitude,
              'longitude': currentLocation.longitude,
              'speed': speedKmh,
              'accuracy': currentLocation.accuracy ?? 0.0,
              'timestamp': phtTime.toIso8601String().replaceAll('Z', '+08:00'),
            };

            print("🟢 Sent (${movedDistance.toStringAsFixed(1)}m): "
                "${currentLocation.latitude?.toStringAsFixed(6)}, "
                "${currentLocation.longitude?.toStringAsFixed(6)}");

            _backgroundService.invoke('location_update', {'data': locationPoint});
            lastSentLocation = currentLocation;
          } else {
            print("⚪ Skipped (${movedDistance.toStringAsFixed(1)}m) — not enough movement");
          }
        },
        onError: (error) {
          print("🔥 Location stream error: $error");
        },
      );

      _heartbeatTimer = Timer.periodic(const Duration(minutes: 1), (timer) {
        print("💓 Service active - tracking for trip detection");
      });
    } catch (e) {
      print("🔥 Error starting location tracking: $e");
    }
  }


  void stop() async{
    print("=== Stopping Dorothy Location Service ===");
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isClockedIn', false);
    _locationSubscription?.cancel();
    _heartbeatTimer?.cancel();
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


