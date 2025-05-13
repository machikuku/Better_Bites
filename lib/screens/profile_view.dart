import 'package:betterbitees/repositories/profiling_repo.dart';
import 'package:betterbitees/services/profiling_service.dart';
import 'package:flutter/material.dart';
import 'package:betterbitees/colors.dart';
import 'package:betterbitees/models/profiling.dart';
import 'package:intl/intl.dart' as intl;

// Helper method to convert cm to ft/in
String convertCmToFtIn(double cm) {
  final feet = (cm / 30.48).floor();
  final inches = ((cm % 30.48) / 2.54).round();
  return "$feet'${inches}\"";
}

// Helper method to convert kg to lbs
String convertKgToLbs(double kg) {
  final lbs = (kg / 0.453592).roundToDouble();
  return lbs.toStringAsFixed(1); // One decimal place for lbs
}

class ViewProfiling extends StatefulWidget {
  final Map<String, dynamic>? profile;
  final DateTime? scanTime;

  const ViewProfiling({
    super.key,
    this.profile,
    this.scanTime,
  });

  @override
  _ViewProfilingState createState() => _ViewProfilingState();
}

class _ViewProfilingState extends State<ViewProfiling> {
  final ProfilingService profilingService =
      ProfilingService(profilingRepo: ProfilingRepo());

  // BMI calculation properties
  double? _userBmi;
  String _bmiCategory = '';
  Color _bmiColor = Colors.green;

  @override
  void initState() {
    super.initState();
    if (widget.profile != null) {
      _calculateBmi(Profiling.fromJson(widget.profile!));
    }
  }

  void _calculateBmi(Profiling profile) {
    if (profile.height > 0 && profile.weight > 0) {
      final heightInMeters = profile.height / 100;
      final bmi = profile.weight / (heightInMeters * heightInMeters);

      String category;
      Color color;

      if (bmi < 18.5) {
        category = 'Underweight';
        color = Colors.blue;
      } else if (bmi >= 18.5 && bmi < 25) {
        category = 'Normal';
        color = Colors.green;
      } else if (bmi >= 25 && bmi < 30) {
        category = 'Overweight';
        color = Colors.orange;
      } else {
        category = 'Obese';
        color = Colors.red;
      }

      setState(() {
        _userBmi = bmi;
        _bmiCategory = category;
        _bmiColor = color;
      });
    }
  }

  Widget _buildProfileView() {
    const Color prime = Color(0xFF0d522c);

    if (widget.profile == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.person_off, size: 48, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No profile data available for this scan',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                color: Colors.grey,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Extract profile data
    final age = widget.profile!['age'] ?? 'N/A';
    final sex = widget.profile!['sex'] ?? 'N/A';
    final height = widget.profile!['height'] ?? 'N/A';
    final weight = widget.profile!['weight'] ?? 'N/A';

    // Handle health conditions which could be a list or a string
    List<String> healthConditions = [];
    if (widget.profile!['health_conditions'] != null) {
      if (widget.profile!['health_conditions'] is List) {
        healthConditions = List<String>.from(widget.profile!['health_conditions']);
      } else if (widget.profile!['health_conditions'] is String) {
        final String healthStr = widget.profile!['health_conditions'] as String;
        if (healthStr.contains(',')) {
          healthConditions = healthStr.split(',').map((e) => e.trim()).toList();
        } else if (healthStr.isNotEmpty) {
          healthConditions = [healthStr];
        }
      }
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.2),
                  blurRadius: 5,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  widget.scanTime != null ? 'Profile at Time Scan' : 'Profile at Time Scan',
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: prime,
                  ),
                ),
                const SizedBox(height: 4),
                if (widget.scanTime != null)
                  Text(
                    'Scanned on: ${intl.DateFormat('yyyy-MM-dd HH:mm:ss').format(widget.scanTime!.toLocal())}',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                const SizedBox(height: 24),

                // Profile details in a grid layout
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildProfileDetailTile('Age', '$age years', Icons.cake),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileDetailTile('Sex', sex.toString(), Icons.person),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: _buildProfileDetailTile('Height', '$height cm (${convertCmToFtIn(double.tryParse(height.toString()) ?? 0)})', Icons.height),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _buildProfileDetailTile('Weight', '$weight kg (${convertKgToLbs(double.tryParse(weight.toString()) ?? 0)} lbs)', Icons.monitor_weight),
                        ),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                // BMI information
                if (_userBmi != null)
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _bmiColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: _bmiColor.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          'BMI: ${_userBmi!.toStringAsFixed(1)}',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: _bmiColor,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _bmiCategory,
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: _bmiColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _buildBmiIndicator(_userBmi!),
                      ],
                    ),
                  ),

                const SizedBox(height: 24),

                // Health conditions
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Row(
                        children: [
                          Icon(Icons.medical_information, color: prime, size: 20),
                          SizedBox(width: 8),
                          Text(
                            'Health Conditions',
                            style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              color: prime,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      healthConditions.isEmpty
                          ? const Text(
                        'No health conditions reported',
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontStyle: FontStyle.italic,
                          color: Colors.grey,
                        ),
                      )
                          : Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: healthConditions
                            .map((condition) => Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Icon(Icons.circle, size: 8, color: prime),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  condition,
                                  style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ))
                            .toList(),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildProfileDetailTile(String label, String value, IconData icon) {
    const Color prime = Color(0xFF0d522c);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(8),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Icon(icon, size: 20, color: prime),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 12,
                      color: Colors.grey[600],
                    ),
                  ),
                  Text(
                    value,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: prime,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.visible,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBmiIndicator(double bmi) {
    const double minBmi = 15.0;
    const double maxBmi = 35.0;

    double position = (bmi - minBmi) / (maxBmi - minBmi);
    position = position.clamp(0.0, 1.0);

    return Column(
      children: [
        Container(
          height: 24,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: const LinearGradient(
              colors: [Colors.blue, Colors.green, Colors.orange, Colors.red],
              stops: [0.2, 0.4, 0.6, 0.8],
            ),
          ),
          child: Stack(
            children: [
              Positioned(
                left: position * MediaQuery.of(context).size.width * 0.7,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.3),
                        blurRadius: 2,
                        offset: const Offset(0, 1),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildBmiCategoryLabel('Underweight'),
              _buildBmiCategoryLabel('Normal'),
              _buildBmiCategoryLabel('Overweight'),
              _buildBmiCategoryLabel('Obese'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildBmiCategoryLabel(String label) {
    Color textColor;
    switch (label) {
      case 'Underweight':
        textColor = Colors.blue;
        break;
      case 'Normal':
        textColor = Colors.green;
        break;
      case 'Overweight':
        textColor = Colors.orange;
        break;
      case 'Obese':
        textColor = Colors.red;
        break;
      default:
        textColor = Colors.black;
    }
    
    return Text(
      label,
      style: TextStyle(
        fontFamily: 'Poppins',
        fontSize: 10,
        color: textColor,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.green.shade50,
      appBar: AppBar(
        title: Text(
          widget.scanTime != null ? "Profile at Time Scan" : "Profile at Time Scan",
          style: const TextStyle(
              fontFamily: 'Poppins', fontSize: 16, fontWeight: FontWeight.w500),
        ),
        foregroundColor: prime,
        backgroundColor: Colors.green.shade50,
        elevation: 0,
      ),
      body: _buildProfileView(),
    );
  }
}
