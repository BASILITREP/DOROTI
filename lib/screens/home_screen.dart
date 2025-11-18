import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/location_service.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/profile_screen.dart';
import '../screens/dtr_screen.dart';
import '../screens/task_screen.dart';
import '../screens/login_screen.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

// Model para sa ating attendance log
class AttendanceLog {
  final DateTime time;
  final String status; // 'Timed In' or 'Timed Out'

  AttendanceLog({required this.time, required this.status});
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({
    super.key,
    required this.title,
    required this.fieldEngineer,
  });

  final String title;
  final Map<String, dynamic> fieldEngineer;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> with TickerProviderStateMixin {
  final LocationService _locationService = LocationService();

  // State variables para sa attendance
  bool _isTimedIn = false;
  DateTime? _timeInTimestamp;
  final List<AttendanceLog> _attendanceLogs = [];

  // ADD THESE FOR FAB ANIMATION
  bool _isFabExpanded = false;
  late AnimationController _fabAnimationController;
  late Animation<double> _fabScaleAnimation;
  Duration _elapsedTime = Duration.zero;
  Timer? _timer;
  final apiUrl = dotenv.env['API_URL'];

  DateTime parseServerTime(String dateString) {
    final parsed = DateTime.parse(dateString);
    // Backend sends UTC but without 'Z', so manually correct it
    final corrected = parsed.subtract(const Duration(hours: 8));
    return corrected;
  }


  @override
  void initState() {
    super.initState();

    // Initialize FAB animation
    _fabAnimationController = AnimationController(
      duration: const Duration(milliseconds: 200),
      vsync: this,
    );
    _fabScaleAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _fabAnimationController, curve: Curves.easeOut),
    );
    _fetchAttendanceLogs();
    _checkClockInStatus();
    _saveAutoLoginState();

  }

  @override
  void dispose() {
    _timer?.cancel();
    //_locationService.stop();
    _fabAnimationController.dispose(); // Don't forget this!
    super.dispose();
  }

  //timer
  void _startTimer() {
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_timeInTimestamp != null) {
        setState(() {
          _elapsedTime = DateTime.now().difference(_timeInTimestamp!);
        });
      }
    });
  }

  //stop timer
  void _stopTimer(){
    _timer?.cancel();
    setState(() {
      _elapsedTime = Duration.zero;
    });
  }

  // ADD THESE METHODS
  void _toggleFab() {
    setState(() {
      _isFabExpanded = !_isFabExpanded;
      if (_isFabExpanded) {
        _fabAnimationController.forward();
      } else {
        _fabAnimationController.reverse();
      }
    });
  }

  void _showTasks() {
    _toggleFab(); // Close FAB first
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TasksScreen()),
    );
  }

  void _showTermsAndCondition() {
    _toggleFab(); // Close FAB first
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Terms and Conditions', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              Text(
                '1. Acceptance of Terms: By using this app, you agree to comply with these terms and conditions.', style: TextStyle(color: Colors.black),
              ),
              SizedBox(height: 8),
              Text(
                '2. User Responsibilities: You are responsible for maintaining the confidentiality of your account information and for all activities that occur under your account.', style: TextStyle(color: Colors.black),
              ),
              SizedBox(height: 8),
              Text(
                '3. Attendance Accuracy: You must ensure that your time-in and time-out entries are accurate and truthful.', style: TextStyle(color: Colors.black),
              ),
              SizedBox(height: 8),
              Text(
                '4. Location Tracking: By timing in, you consent to the app tracking your location for attendance purposes.', style: TextStyle(color: Colors.black),
              ),
              SizedBox(height: 8),
              Text(
                '5. Data Privacy: Your personal data will be handled in accordance with our privacy policy.', style: TextStyle(color: Colors.black),
              ),
              SizedBox(height: 8),
              Text(
                  '6. App Usage: You agree to use the app only for its intended purpose and not for any unlawful activities.', style: TextStyle(color: Colors.black)
              ),
              SizedBox(height: 8),
              Text(
                  '7. Modifications to Terms: We reserve the right to modify these terms at any time. Continued use of the app constitutes acceptance of the revised terms.', style: TextStyle(color: Colors.black)
              ),
            ],
          ),
        ),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );


  }

  void _showDTR() {
    _toggleFab(); // Close FAB first
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DtrScreen(
          fieldEngineerId: widget.fieldEngineer['id'],
        ),
      ),
    );
  }

  void _logout() {
    _toggleFab(); // Close FAB first

    // Prevent logout if user is still clocked in
    if (_isTimedIn) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Cannot Logout', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
          content: const Text(
            'You are currently clocked in. Please clock out before logging out.',
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            FilledButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('OK'),
            ),
          ],
        ),
      );
      return;
    }

    // Existing logout confirmation dialog (unchanged)
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Logout', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        content: const Text('Are you sure you want to logout?', style: TextStyle(color: Colors.black)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.black)),
          ),
          FilledButton(
            onPressed: () async {
              // Stop location service if running
              if (_isTimedIn) {
                _locationService.stop();
              }

              // Clear local storage
              final prefs = await SharedPreferences.getInstance();
              await prefs.setBool('isClockedIn', false);
              await prefs.remove('fieldEngineerId');
              await prefs.setBool('isLoggedIn', false);


              // Notify backend (optional)
              try {
                await http.post(
                  Uri.parse(
                    '$apiUrl/FieldEngineer/${widget.fieldEngineer['id']}/logout',
                  ),
                );
              } catch (e) {
                debugPrint('Logout error: $e');
              }

              // ✅ Close dialog and navigate safely back to login
              if (context.mounted) {
                Navigator.of(context).pushAndRemoveUntil(
                  MaterialPageRoute(builder: (context) => const LoginPage()),
                      (Route<dynamic> route) => false,
                );
              }
            },
            child: const Text('Logout'),
          ),
        ],
      ),
    );
  }

  Future<void> _saveAutoLoginState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedIn', true);
    await prefs.setInt('fieldEngineerId', widget.fieldEngineer['id']);
  }



  Future<void> _toggleTimeIn() async {
    final int engineerId = widget.fieldEngineer['id'];
    final bool isClockingIn = !_isTimedIn;
    final now = DateTime.now();

    // If user is trying to clock OUT, ask for confirmation first
    if (!isClockingIn) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text(
            'Confirm',
            style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
          ),
          content: const Text(
            'Are you sure you want to clock out?',
            style: TextStyle(color: Colors.black),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel', style: TextStyle(color: Colors.black)),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Yes'),
            ),
          ],
        ),
      );

      if (confirmed != true) {
        return; // user cancelled clock out
      }
    }

    final url = isClockingIn
        ? '$apiUrl/FieldEngineer/$engineerId/clockin'
        : '$apiUrl/FieldEngineer/$engineerId/clockout';

    try {
      final response = await http.post(Uri.parse(url));

      if (response.statusCode == 200) {
        setState(() {
          _isTimedIn = isClockingIn;
          if (isClockingIn) {
            _timeInTimestamp = now;
            _startTimer();
            _locationService.start(engineerId);
          } else {
            _timeInTimestamp = null;
            _stopTimer();
            _locationService.stop();
          }
        });

        // Persist clock-in status for resume logic
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool('isClockedIn', isClockingIn);

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isClockingIn
                ? 'You have successfully clocked in!'
                : 'You have successfully clocked out.'),
            backgroundColor: isClockingIn ? Colors.green : Colors.orange,
          ),
        );

        await _fetchAttendanceLogs(); // refresh logs from backend
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${response.body}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Network error: $e')),
      );
    }
  }


  Future<void> _fetchAttendanceLogs() async {
    final int engineerId = widget.fieldEngineer['id'];
    final url =
        '$apiUrl/FieldEngineer/$engineerId/attendance';

    try {
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);

        setState(() {
          _attendanceLogs.clear();

          for (var log in data) {
            // Parse and convert to PH time (UTC+8)
            DateTime? timeIn;
            DateTime? timeOut;

            if (log['timeIn'] != null) {
              timeIn = parseServerTime(log['timeIn']);
              _attendanceLogs.add(
                AttendanceLog(time: timeIn, status: 'Timed In'),
              );
            }

            if (log['timeOut'] != null) {
              timeOut = parseServerTime(log['timeOut']);
              _attendanceLogs.add(
                AttendanceLog(time: timeOut, status: 'Timed Out'),
              );
            }


          }

          _attendanceLogs.sort((a, b) => b.time.compareTo(a.time));
        });
      } else {
        print('Failed to load logs: ${response.statusCode}');
      }
    } catch (e) {
      print('Error fetching logs: $e');
    }
  }


  Future<void> _checkClockInStatus() async {
    final prefs = await SharedPreferences.getInstance();
    final isClockedIn = prefs.getBool('isClockedIn') ?? false;
    final fieldEngineerId = widget.fieldEngineer['id'];

    if (isClockedIn) {
      try {
        final url =
            '$apiUrl/FieldEngineer/$fieldEngineerId/attendance';
        final response = await http.get(Uri.parse(url));

        if (response.statusCode == 200) {
          final List<dynamic> logs = json.decode(response.body);

          DateTime? lastTimeIn;
          for (var log in logs) {
            if (log['timeIn'] != null && log['timeOut'] == null) {
              lastTimeIn = parseServerTime(log['timeIn']); // ✅ FIX HERE

              break;
            }
          }

          if (lastTimeIn != null) {
            setState(() {
              _isTimedIn = true;
              _timeInTimestamp = lastTimeIn;
            });
            _startTimer();
            await _locationService.start(fieldEngineerId);
            print("🔄 Resumed background tracking since $lastTimeIn");
          } else {
            print("⚠️ No active time-in found — user may have already clocked out.");
          }
        } else {
          print("❌ Failed to fetch attendance: ${response.statusCode}");
        }
      } catch (e) {
        print("🔥 Error checking clock-in status: $e");
      }
    } else {
      print("🛑 FE not clocked in — no background tracking resumed");
    }
  }



  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'DOROTI',
              style: GoogleFonts.libreBaskerville(
                fontSize: 25,
                fontWeight: FontWeight.w300, // Light weight
                fontStyle: FontStyle.italic,
                color: const Color.fromARGB(255, 246, 255, 168), // Yellow accent
              ),
              textAlign: TextAlign.center,
            ),
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  PageRouteBuilder(
                    pageBuilder: (context, animation, secondaryAnimation) => ProfileScreen(
                      fieldEngineer: widget.fieldEngineer, // Pass the data here
                    ),
                    transitionsBuilder: (context, animation, secondaryAnimation, child) {
                      const curve = Curves.easeInOut;

                      var scaleTween = Tween(begin: 0.8, end: 1.0).chain(
                        CurveTween(curve: curve),
                      );

                      var fadeTween = Tween(begin: 0.0, end: 1.0);

                      return ScaleTransition(
                        scale: animation.drive(scaleTween),
                        child: FadeTransition(
                          opacity: animation.drive(fadeTween),
                          child: child,
                        ),
                      );
                    },
                  ),
                );
              },
              child: Hero(
                tag: 'profile_avatar',
                child: Material(
                  color: Colors.transparent,
                  child: CircleAvatar(
                      backgroundColor: Color.fromARGB(
                        255,
                        245,
                        255,
                        140,
                      ),
                      radius: 20,
                      child: Text(
                        (widget.fieldEngineer['firstName'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.black,
                          fontWeight: FontWeight.bold,
                          fontSize: 20,
                        ),
                      )
                  ),
                ),
              ),
            )


          ],
        ),
      ),
      body: Stack(
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Text(
                  widget.title,
                  style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                SizedBox(height: 12),
                Card(
                  elevation: 4,
                  color: Colors.white,
                  child: Padding(
                    padding: const EdgeInsets.all(25.0),
                    child: Column(
                      children: [
                        if (_isTimedIn && _timeInTimestamp != null)
                          _buildStatusDisplay(
                            'You are currently timed in since:',

                            DateFormat('hh:mm a').format(_timeInTimestamp!),

                            Colors.black,
                          ),
                        if (_isTimedIn && _timeInTimestamp != null)
                          Padding(
                            padding: const EdgeInsets.only(top: 8.0),
                            child: Text(
                              'Elapsed Time: ${_formatDuration(_elapsedTime)}',
                              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                color: Colors.grey[700],
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        const SizedBox(height: 16),
                        if (!_isTimedIn)
                          _buildStatusDisplay(
                            'You are currently timed out.',
                            'Please clock in to start.',
                            Colors.grey[600]!,
                          )
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // MATERIAL 3 SEGMENTED BUTTON
                Row(
                  children: [
                    Expanded(
                      child: SizedBox(
                        height: 60,
                        child: FilledButton.icon(
                          onPressed: _toggleTimeIn,
                          icon: Icon(
                            _isTimedIn ? Icons.logout : Icons.login,
                            color: _isTimedIn ? Colors.white : Colors.black87,
                          ),
                          label: Text(
                            _isTimedIn ? 'Clock Out' : 'Clock In',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: _isTimedIn ? Colors.white : Colors.black87,
                            ),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _isTimedIn ? Colors.redAccent : colorScheme.primary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(50),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),


                const SizedBox(height: 28),
                Text(
                  'Attendance Logs',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const Divider(color: Colors.white70),

                // Attendance Logs List
                Expanded(
                  child: _attendanceLogs.isEmpty
                      ? const Center(
                    child: Text(
                      'No attendance logs yet.',
                      style: TextStyle(color: Colors.white70),
                    ),
                  )
                      : ListView.builder(
                    itemCount: _attendanceLogs.length,
                    itemBuilder: (context, index) {
                      final log = _attendanceLogs[index];
                      final isTimeIn = log.status == 'Timed In';
                      return Card(
                        color: Colors.white,
                        margin: const EdgeInsets.only(bottom: 8),
                        child: ListTile(
                          leading: Icon(
                            isTimeIn ? Icons.login : Icons.logout,
                            color: isTimeIn ? Colors.green : Colors.redAccent,
                          ),
                          title: Text(
                            log.status,
                            style: const TextStyle(color: Colors.black87),
                          ),
                          subtitle: Text(
                              DateFormat('MMMM dd, yyyy - hh:mm:ss a').format(log.time),

                              style: TextStyle(color: Colors.grey[600]),
                          ),
                        ),
                      );
                    },
                  ),
                ),

              ],
            ),
          ),

          // FAB OVERLAY
          if (_isFabExpanded)
            GestureDetector(
              onTap: _toggleFab,
              child: Container(
                color: Colors.black26,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
        ],
      ),

      // CUSTOM FAB MENU with orange theme
      floatingActionButton: _isFabExpanded
          ? Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [

          // Terms and Conditions Button
          _buildFabMenuItem(
            onPressed: _showTermsAndCondition,
            icon: Icons.newspaper,
            label: 'Terms and Conditions',
            color: colorScheme.secondary.withOpacity(0.8),
            textColor: Colors.black87,
          ),
          const SizedBox(height: 12),
          _buildFabMenuItem(
            onPressed: _showTasks,
            icon: Icons.checklist_rtl_rounded,
            label: 'Daily Tasks',
            color: colorScheme.secondary.withOpacity(0.9),
            textColor: Colors.black87,
          ),
          const SizedBox(height: 12),
          // DTR Button
          _buildFabMenuItem(
            onPressed: _showDTR,
            icon: Icons.access_time,
            label: 'DTR',
            color: colorScheme.secondary,
            textColor: Colors.black87,
          ),
          const SizedBox(height: 12),

          // Logout Button
          _buildFabMenuItem(
            onPressed: _logout,
            icon: Icons.logout,
            label: 'Logout',
            color: Colors.red[600]!,
            textColor: Colors.white,
          ),
          const SizedBox(height: 16),

          // Main FAB
          FloatingActionButton.large(
            onPressed: _toggleFab,
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF5e49e4),
            child: const Icon(Icons.close, color: Colors.black,size:32),
          ),
        ],
      )
          : FloatingActionButton.large(
        onPressed: _toggleFab,
        shape: const CircleBorder(),
        backgroundColor: colorScheme.primaryContainer,
        foregroundColor: Colors.white,
        child: const Icon(Icons.menu, color: Colors.black,size:32),
      ),
    );
  }

  // Update status display for better contrast
  Widget _buildStatusDisplay(String title, String subtitle, Color color) {
    return Column(
      children: [
        Text(
          title,
          style: Theme.of(
            context,
          ).textTheme.titleMedium?.copyWith(color: Colors.black87),
        ),
        const SizedBox(height: 8),
        Text(
          subtitle,
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(
            color: color,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }

  //helper function to format duration
  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(duration.inHours);
    final minutes = twoDigits(duration.inMinutes.remainder(60));
    final seconds = twoDigits(duration.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  // Custom FAB menu item widget
  Widget _buildFabMenuItem({

    required VoidCallback onPressed,
    required IconData icon,
    required String label,
    required Color color,
    required Color textColor,
  }) {
    return ScaleTransition(
      scale: _fabScaleAnimation,
      child: ElevatedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon, color: textColor),
        label: Text(label, style: TextStyle(color: textColor)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        ),
      ),
    );
  }
}
