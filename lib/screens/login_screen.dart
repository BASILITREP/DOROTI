

import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:local_auth/local_auth.dart';
import 'home_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final TextEditingController _emailController = TextEditingController();
  final LocalAuthentication auth = LocalAuthentication();
  bool isLoading = false;
  bool _isDeviceSupported = false;
  bool _hasQuickLoginData = false;

  @override
  void initState() {
    super.initState();

    _initializeLoginPage();

  }

  Future<void> _initializeLoginPage() async {
    await _checkDeviceSupported();
    final storage = const FlutterSecureStorage();
    final savedEmail = await storage.read(key: 'last_email');
    if (savedEmail != null) {
      _emailController.text = savedEmail;
      setState(() {
        _hasQuickLoginData = true;
      });
    }
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please enter an email')));
      return;
    }

    setState(() {
      isLoading = true;
    });

    try {
      final response = await http.get(
        Uri.parse(
            'https://ecsmapappwebadminbackend-production.up.railway.app/api/FieldEngineer'
          //     'http://192.168.1.2:5242/api/FieldEngineer',

        ),
        headers: {'Content-Type': 'application/json'},
      );

      if (!mounted) return;

      if (response.statusCode == 200) {
        final List<dynamic> engineers = json.decode(response.body);
        final engineer = engineers.firstWhere(
              (eng) =>
          eng['email'].toLowerCase() == _emailController.text.toLowerCase(),
          orElse: () => null,
        );

        if (engineer != null) {
          bool authenticated = false;
          try {
            authenticated = await auth.authenticate(
              localizedReason: 'Please authenticate to log in to DOROTI',
              options: const AuthenticationOptions(
                  biometricOnly: false,
                  useErrorDialogs: true,
                  stickyAuth: true
              ),

            );
          } on PlatformException catch (e) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Error with biometrics: ${e.message}')),
              );
            }
            setState(() => isLoading = false);
            return;
          }

          if (!mounted) return;

          if (authenticated) {
            final storage = const FlutterSecureStorage();
            await storage.write(key: 'last_email', value: _emailController.text);

            Navigator.pushReplacement(
              context,
              MaterialPageRoute(
                builder: (context) => MyHomePage(
                  title: 'Hello, ${engineer['name']}',
                  fieldEngineer: engineer,
                ),
              ),
            );

          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Authentication failed. Please try again.'),
              ),
            );
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Field Engineer with this email not found'),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Server Error: ${response.statusCode}')),
        );
      }
    } catch (e) {
      print('Error during login: $e');
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('An error occurred: $e')));
      }
    }

    if (mounted) {
      setState(() {
        isLoading = false;
      });
    }
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
                      // Image.asset(
                      //   'assets/equicomLogo.png',
                      //   height: 80,
                      //   fit: BoxFit.contain,
                      // ),
                      SizedBox(height: 16),
                      Text(
                        'DOROTI',
                        style: GoogleFonts.libreBaskerville(
                          // Beautiful serif font
                          fontSize: 64,
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

  void _showNotImplemented(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('$feature not implemented'),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
}
