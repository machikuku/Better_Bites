import 'package:flutter/material.dart';
import 'package:betterbitees/colors.dart';

class InfoPage extends StatelessWidget {
  const InfoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        appBar: AppBar(
          backgroundColor: thrd,
          title: const Text(
            'Information',
            style: TextStyle(
              fontFamily: 'Poppins',
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: prime,
            ),
          ),
          leading: IconButton(
            icon: const Icon(
              Icons.arrow_back,
              size: 20,
            ),
            color: prime,
            onPressed: () {
              Navigator.pop(context);
            },
          ),
        ),
        backgroundColor: thrd,
        body: Padding(
          padding: const EdgeInsets.all(24.0),
          child: SingleChildScrollView(
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'BetterBites is your personal food companion, designed to help you make informed dietary choices by analyzing food packages ingredients label based on your unique needs and preferences.',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: prime),
                    textAlign: TextAlign.justify,
                  ),
                  const SizedBox(height: 16.0),
                  Text(
                    'Here’s how to get started:\n\n'
                    '1. Create your profile: Click the "SCAN" or "HISTORY" button.\n\n'
                    '2. Scan food items: Use the "SCAN" button to capture ingredient labels. Ensure good lighting and a clear image for accurate results.\n\n'
                    '3. Review your history: Check past scans using the "HISTORY" button to track your choices.\n\n'
                    'Once your profile is set, you’ll be ready to scan food packages and receive personalized insights. Enjoy your journey with BetterBites!',
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: prime),
                    textAlign: TextAlign.justify,
                  ),
                ],
              ),
            ),
          ),
        ));
  }
}