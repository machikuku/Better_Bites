// ignore_for_file: library_private_types_in_public_api, avoid_print, use_build_context_synchronously, unnecessary_to_list_in_spreads, unused_field, prefer_final_fields, prefer_const_constructors, use_full_hex_values_for_flutter_colors, unused_element, non_constant_identifier_names, unused_import

import 'package:betterbitees/screens/home.dart';
import 'package:betterbitees/screens/edit_profiling.dart';
import 'package:betterbitees/repositories/profiling_repo.dart';
import 'package:betterbitees/screens/profile.dart';
import 'package:betterbitees/services/profiling_service.dart';
import 'package:betterbitees/colors.dart';
import 'package:flutter/material.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SplashScreen(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  _SplashScreenState createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final ProfilingService _profilingService = ProfilingService(
    profilingRepo: ProfilingRepo(),
  );
  bool _isLoading = true;
  bool _hasProfile = false;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    try {
      final profile = await _profilingService.getProfile();
      setState(() {
        _hasProfile = profile != null;
        _isLoading = false;
      });

      // Add a small delay to show the splash screen
      await Future.delayed(const Duration(seconds: 2));

      // Navigate to appropriate screen
      if (_hasProfile) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => HomePage()),
        );
      } else {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (context) => const ProfilingWelcomePage()),
        );
      }
    } catch (e) {
      print('Error checking profile: $e');
      setState(() {
        _isLoading = false;
      });

      // If there's an error, still navigate to the welcome page
      await Future.delayed(const Duration(seconds: 2));
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const ProfilingWelcomePage()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: thrd,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset(
              'assets/bblogo.png',
              fit: BoxFit.contain,
              height: 220,
            ),
            const SizedBox(height: 30),
            if (_isLoading)
              const CircularProgressIndicator(
                color: prime,
                strokeWidth: 3,
              ),
          ],
        ),
      ),
    );
  }
}

class ProfilingWelcomePage extends StatelessWidget {
  const ProfilingWelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent back button from closing the app during onboarding
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: thrd,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/bblogo.png',
                  fit: BoxFit.contain,
                  height: 180,
                ),
                const SizedBox(height: 30),
                const Text(
                  'Welcome to Better Bites!',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: prime,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                const Text(
                  'To provide you with personalized food recommendations, we need some information about you.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 16,
                    color: Colors.black87,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 15),
                const Text(
                  'This information helps us analyze food ingredients based on your specific health needs.',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    color: Colors.black54,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const ProfilingQuestionsPage(),
                        ),
                      ).then((_) {
                        // Check if profile was created
                        _checkProfileAndNavigate(context);
                      });
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: prime,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                    ),
                    child: const Text(
                      'CREATE PROFILE',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _checkProfileAndNavigate(BuildContext context) async {
    final profilingService = ProfilingService(profilingRepo: ProfilingRepo());
    final profile = await profilingService.getProfile();

    if (profile != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => HomePage()),
      );
    }
  }
}
