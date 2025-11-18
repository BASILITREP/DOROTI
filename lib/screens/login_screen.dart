import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'home_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';


class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  bool isLoading = false;
  bool _isDeviceSupported = false;
  bool _hasQuickLoginData = false;
  bool _isPasswordVisible = false;
  final apiUrl = dotenv.env['API_URL'];


  @override
  void initState() {
    super.initState();

    // ✅ Add this token refresher
    FirebaseMessaging.instance.onTokenRefresh.listen((newToken) async {
      print('🔄 FCM token refreshed: $newToken');

      // Optional: You can save the latest token locally if you need it later
      final storage = const FlutterSecureStorage();
      await storage.write(key: 'latest_fcm_token', value: newToken);

      // If user already logged in (has stored ID), update backend automatically
      final savedId = await storage.read(key: 'field_engineer_id');
      if (savedId != null) {
        try {
          final response = await http.post(
            Uri.parse('$apiUrl/FieldEngineer/loginsync'),
            headers: {'Content-Type': 'application/json'},
            body: jsonEncode({
              'userId': int.parse(savedId),
              'fcmToken': newToken,
            }),
          );
          print('✅ Token refreshed & synced: ${response.statusCode}');
        } catch (e) {
          print('⚠️ Failed to sync refreshed token: $e');
        }
      }
    });

    _initializeLoginPage(); // keep this here
  }


  Future<void> _initializeLoginPage() async {
    await _checkDeviceSupported();
    final storage = const FlutterSecureStorage();
    final savedEmail = await storage.read(key: 'last_email');
    final savedPassword = await storage.read(key: 'last_password');

    if (savedEmail != null) {
      _emailController.text = savedEmail;
    }

    if (savedPassword != null) {
      _passwordController.text = savedPassword;
    }

    if (savedEmail != null && savedPassword != null) {
      setState(() {
        _hasQuickLoginData = true;
      });
    }
  }


  Future<void> _login() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter both email and password')),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // 🔹 Step 1: Get all engineers and find the matching email
      final engineerRes = await http.get(
        Uri.parse(
          '$apiUrl/FieldEngineer',
        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (engineerRes.statusCode != 200) {
        throw Exception('Failed to fetch Field Engineers');
      }

      final List<dynamic> engineers = json.decode(engineerRes.body);
      final engineer = engineers.firstWhere(
            (eng) => eng['email'].toLowerCase() == email.toLowerCase(),
        orElse: () => null,
      );

      if (engineer == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No account found with this email')),
        );
        setState(() => isLoading = false);
        return;
      }

      final userId = engineer['id'];
      final firstName = engineer['firstName'] ?? engineer['name']?.split(' ')?.first ?? '';
      final lastName = engineer['lastName'] ?? engineer['name']?.split(' ')?.last ?? '';

      print('👤 Found engineer: ID=$userId, Name=$firstName $lastName');

      // 🔹 Step 2: Get device FCM token
      final fcmToken = await FirebaseMessaging.instance.getToken();
      print('📲 Current FCM token: $fcmToken');

      // 🔹 Step 3: POST to backend login-sync with password
      final response = await http.post(
        Uri.parse(
          '$apiUrl/FieldEngineer/$userId/login-sync',
        ),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': userId,
          'email': email,
          'password': password,
          'firstName': firstName,
          'lastName': lastName,
          'fcmToken': fcmToken ?? '',
        }),
      );

      print('🛰️ Response: ${response.statusCode}');
      print('📦 Body: ${response.body}');

      if (response.statusCode == 200) {
        // ✅ Step 4: Optional biometric auth after login success
        bool authenticated = false;
        try {
          authenticated = await auth.authenticate(
            localizedReason: 'Authenticate to access DOROTI',
            options: const AuthenticationOptions(
              biometricOnly: false,
              useErrorDialogs: true,
              stickyAuth: true,
            ),
          );
        } on PlatformException catch (e) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Biometric error: ${e.message}')),
          );
        }

        if (!authenticated) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Authentication failed.')),
          );
          setState(() => isLoading = false);
          return;
        }

        // ✅ Step 5: Save last login details for quick access
        const storage = FlutterSecureStorage();
        await storage.write(key: 'last_email', value: email);
        await storage.write(key: 'last_userId', value: userId.toString());
        await storage.write(key: 'last_password', value: password);

        final data = json.decode(response.body);
        final fieldEngineer = data['fieldEngineer'];

        // >>> SAVE SESSION FOR AUTO LOGIN <<<
        final prefs = await SharedPreferences.getInstance();
        await prefs.setBool("isLoggedIn", true);
        await prefs.setInt("fieldEngineerId", userId);
        await prefs.setString("fieldEngineerName", "$firstName $lastName");
        await prefs.setString("savedFieldEngineer", jsonEncode(fieldEngineer));

        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => MyHomePage(
              title: 'Hello, ${fieldEngineer['firstName']}',
              fieldEngineer: fieldEngineer,
            ),
          ),
        );
      } else if (response.statusCode == 401) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Invalid email or password')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('🔥 Login error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }

    setState(() => isLoading = false);
  }



  Future<void> _checkDeviceSupported() async {
    try {
      final isSupported = await auth.isDeviceSupported();
      setState(() {
        _isDeviceSupported = isSupported;
      });
    } catch (e) {
      debugPrint('Device support check failed: $e');
      setState(() {
        _isDeviceSupported = false;
      });
    }
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface, // This will be your purple #6760F6
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    children: [
                      SizedBox(height: 16),
                      Text(
                        'DOROTI',
                        style: GoogleFonts.libreBaskerville(
                          // Beautiful serif font
                          fontSize: 60,
                          fontWeight: FontWeight.w600, // Light weight
                          fontStyle: FontStyle.italic, // Italic style
                          color: Color.fromARGB(
                            255,
                            246,
                            255,
                            168,
                          ), // Black text on white card
                        ),
                        textAlign: TextAlign.center,
                      ),
                      SizedBox(height: 8),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            'Powered by ',
                            style: GoogleFonts.outfit(
                              // Modern sans-serif font
                              fontSize: 15,
                              fontWeight: FontWeight.w400, // Regular weight
                              color: Colors.white70, // Subtle white text
                            ),
                          ),
                          Image(
                            image: AssetImage('assets/equicomLogo.png'),
                            height: 20,
                            fit: BoxFit.contain,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 35),

                // Email Input Section - WHITE BACKGROUND
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  style: const TextStyle(color: Colors.black87), // Black text
                  decoration: InputDecoration(
                    labelText: 'Email Address',
                    hintText: 'Enter your email',
                    labelStyle: TextStyle(color: Colors.grey[700]),
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(
                      Icons.email_outlined,
                      color: Colors.grey[600],
                    ),
                    filled: true,
                    fillColor: Colors.white, // White background
                  ),
                ),

                const SizedBox(height: 24),

                TextFormField(
                  controller: _passwordController,
                  obscureText: !_isPasswordVisible, // 👈 toggles visibility
                  style: const TextStyle(color: Colors.black87),
                  textInputAction: TextInputAction.done, // 👈 makes "Enter" key act as done
                  onFieldSubmitted: (_) => _login(), // 👈 press Enter = login
                  decoration: InputDecoration(
                    labelText: 'Password',
                    hintText: 'Enter your password',
                    labelStyle: TextStyle(color: Colors.grey[700]),
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.lock_outline, color: Colors.grey[600]),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isPasswordVisible ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey[600],
                      ),
                      onPressed: () {
                        setState(() {
                          _isPasswordVisible = !_isPasswordVisible;
                        });
                      },
                    ),
                    filled: true,
                    fillColor: Colors.white,
                  ),
                ),



                const SizedBox(height: 24),

                // Login Button - Your yellow accent color

                if (_isDeviceSupported) ...[
                  FilledButton.icon(
                    onPressed: isLoading ? null : _login,
                    icon: isLoading
                        ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black87,
                      ),
                    )
                        : null,
                    label: Text(
                      isLoading ? 'Authenticating...' : 'Login with Biometrics or PIN',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.black87,
                      ),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: colorScheme.primary,
                      foregroundColor: Colors.black87,
                      padding: const EdgeInsets.symmetric(vertical: 20),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                  ),
                ] else ...[
                  Text(
                    'Your device does not support quick login.\nPlease use password instead.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70),
                  ),
                ],


                const SizedBox(height: 24),

                // Optional: Add app version or footer text
                Text(
                  'Version 1.0.0',
                  style: TextStyle(color: Colors.white70, fontSize: 12),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }


  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
