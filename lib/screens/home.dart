import 'package:betterbitees/repositories/profiling_repo.dart';
import 'package:betterbitees/screens/camera.dart';
import 'package:betterbitees/screens/info.dart';
import 'package:betterbitees/screens/profile.dart';
import 'package:betterbitees/screens/history.dart';
import 'package:betterbitees/services/profiling_service.dart';
import 'package:flutter/material.dart';
import 'package:betterbitees/colors.dart';
import 'package:betterbitees/models/profiling.dart';
import 'package:betterbitees/screens/edit_profiling.dart';
import 'package:shared_preferences/shared_preferences.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  _HomePageState createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final ProfilingService profilingService = ProfilingService(
    profilingRepo: ProfilingRepo(),
  );
  Profiling? _profile;

  @override
  void initState() {
    super.initState();
    _loadProfile();
    _showFirstTimeUserAlert();
  }

  Future<void> _loadProfile() async {
    final profile = await profilingService.getProfile();
    setState(() {
      _profile = profile;
    });
  }

  Future<void> _showFirstTimeUserAlert() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstTimeUser = prefs.getBool('isFirstTimeUser') ?? true;

    if (isFirstTimeUser) {
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              contentPadding: const EdgeInsets.all(20.0),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8.0),
              ),
              title: Row(
                children: [
                  const Text(
                    'Welcome to BetterBites!',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: prime,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
              content: Text(
                'BetterBites is your personal food companion, designed to help you make informed dietary choices by analyzing food packages ingredients label based on your unique needs and preferences.\n\n'
                'Here’s how to get started:\n\n'
                '1. Create your profile: Click the "SCAN" or "HISTORY" button.\n'
                '2. Scan food items: Use the "SCAN" button to capture ingredient labels. Ensure good lighting and a clear image for accurate results.\n'
                '3. Review your history: Check past scans using the "HISTORY" button to track your choices.\n\n'
                'Once your profile is set, you’ll be ready to scan food packages and receive personalized insights. Enjoy your journey with BetterBites!',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                ),
                textAlign: TextAlign.justify,
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text(
                    'Got it!',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: prime,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ],
            );
          },
        );
      });

      await prefs.setBool('isFirstTimeUser', false);
    }
  }

  Future<bool> _onWillPop() async {
    return await showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text(
              'Exit App',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: prime,
              ),
            ),
            content: const Text(
              'Are you sure you want to exit?',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text(
                  'No',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: prime,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text(
                  'Yes',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: prime,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: _onWillPop,
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: thrd,
          actions: [
            IconButton(
              icon: const Icon(Icons.info, color: prime, size: 32),
              onPressed: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => const InfoPage()),
                );
              },
            ),
          ],
        ),
        backgroundColor: thrd,
        body: Container(
          alignment: Alignment.topCenter,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image.asset(
                'assets/bblogo.png',
                fit: BoxFit.contain,
                height: 220,
              ),
              const SizedBox(height: 35),
              SizedBox(
                width: 160.0,
                height: 45.0,
                child: OutlinedButton(
                  onPressed: () async {
                    final profile = await profilingService.getProfile();
                    if (profile == null) {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) =>
                                const ProfilingQuestionsPage()),
                      );
                    } else {
                      final userProfile = profile.toJson();
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              Camera(userProfile: userProfile),
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: prime,
                    side: const BorderSide(color: sec, width: 1),
                    padding: const EdgeInsets.all(0.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                  ),
                  child: const Text(
                    'SCAN',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 18),
              SizedBox(
                width: 160.0,
                height: 45.0,
                child: OutlinedButton(
                  onPressed: () async {
                    final profile = await profilingService.getProfile();
                    if (profile == null) {
                      showDialog(
                        context: context,
                        builder: (BuildContext context) {
                          return AlertDialog(
                            title: const Text(
                              'Profile Required',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: prime,
                              ),
                            ),
                            content: const Text(
                              'You need to complete your profile to view scan history. Would you like to do it now?',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                              ),
                            ),
                            actions: [
                              TextButton(
                                onPressed: () => Navigator.pop(context),
                                child: const Text(
                                  'Cancel',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: prime,
                                  ),
                                ),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (context) =>
                                            const ProfilingQuestionsPage()),
                                  );
                                },
                                child: const Text(
                                  'Yes',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    color: prime,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      );
                    } else {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const HistoryStackedCarousel(),
                        ),
                      );
                    }
                  },
                  style: OutlinedButton.styleFrom(
                    backgroundColor: prime,
                    side: const BorderSide(color: sec, width: 1),
                    padding: const EdgeInsets.all(0.0),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14.0),
                    ),
                  ),
                  child: const Text(
                    'HISTORY',
                    style: TextStyle(
                      fontSize: 18,
                      fontFamily: 'Poppins',
                      fontWeight: FontWeight.w400,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
              if (_profile != null) ...[
                const SizedBox(height: 18),
                SizedBox(
                  width: 160.0,
                  height: 45.0,
                  child: OutlinedButton(
                    onPressed: () async {
                      final result = await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const EditProfiling(),
                        ),
                      );
                      if (result == true) {
                        await _loadProfile();
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      backgroundColor: prime,
                      side: const BorderSide(color: sec, width: 1),
                      padding: const EdgeInsets.all(0.0),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                    ),
                    child: const Text(
                      'PROFILE',
                      style: TextStyle(
                        fontSize: 18,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w400,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}