// ignore_for_file: unnecessary_brace_in_string_interps, unnecessary_string_escapes

import 'package:betterbitees/repositories/profiling_repo.dart';
import 'package:betterbitees/services/profiling_service.dart';
import 'package:betterbitees/helpers/health_conditions.dart';
import 'package:flutter/material.dart';
import 'package:betterbitees/colors.dart';
import 'package:betterbitees/models/profiling.dart';
import 'package:betterbitees/screens/home.dart';

class ProfilingQuestionsPage extends StatefulWidget {
  const ProfilingQuestionsPage({super.key});

  @override
  _ProfilingQuestionsPageState createState() => _ProfilingQuestionsPageState();
}

class _ProfilingQuestionsPageState extends State<ProfilingQuestionsPage> {
  final ProfilingService profilingService =
  ProfilingService(profilingRepo: ProfilingRepo());

  // Page controller for the step wizard
  final PageController _pageController = PageController();

  // Current page index
  int _currentPageIndex = 0;

  // Form keys for each step
  final _sexFormKey = GlobalKey<FormState>();
  final _ageFormKey = GlobalKey<FormState>();
  final _heightFormKey = GlobalKey<FormState>();
  final _weightFormKey = GlobalKey<FormState>();
  final _healthConditionsFormKey = GlobalKey<FormState>();

  // User data
  String _sex = '';
  final TextEditingController _ageController = TextEditingController();
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String _heightUnit = 'cm';
  String _weightUnit = 'kg';
  String _hasHealthConditions = 'No';
  Set<String> _selectedHealthConditions = {};

  bool _isLoading = false;

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

  // Helper method to convert ft/in to cm
  double? convertFtInToCm(String ftIn) {
    return Profiling.convertHeight(ftIn);
  }

  // Helper method to convert lbs to kg
  double? convertLbsToKg(String lbs) {
    return Profiling.convertWeight(lbs);
  }

  @override
  void initState() {
    super.initState();
  }

  void _nextPage() {
    // Validate current page before proceeding
    bool isValid = false;

    switch (_currentPageIndex) {
      case 0: // Sex page
        isValid = _sexFormKey.currentState?.validate() ?? false;
        break;
      case 1: // Age page
        isValid = _ageFormKey.currentState?.validate() ?? false;
        break;
      case 2: // Height page
        isValid = _heightFormKey.currentState?.validate() ?? false;
        break;
      case 3: // Weight page
        isValid = _weightFormKey.currentState?.validate() ?? false;
        break;
      case 4: // Health conditions page
        isValid = _healthConditionsFormKey.currentState?.validate() ?? false;
        // If "Yes" is selected but no conditions are selected, show error
        if (_hasHealthConditions == 'Yes' && _selectedHealthConditions.isEmpty) {
          _showErrorDialog('Please select at least one health condition or change your answer to "No".');
          return;
        }
        break;
    }

    if (isValid) {
      if (_currentPageIndex < 4) {
        setState(() {
          _currentPageIndex++;
        });
        _pageController.animateToPage(
          _currentPageIndex,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeInOut,
        );
      } else {
        _submit();
      }
    }
  }

  void _previousPage() {
    if (_currentPageIndex > 0) {
      setState(() {
        _currentPageIndex--;
      });
      _pageController.animateToPage(
        _currentPageIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _submit() async {
    setState(() => _isLoading = true);

    try {
      double height;
      if (_heightUnit == 'ft/in') {
        final heightInCm = convertFtInToCm(_heightController.text);
        if (heightInCm == null) {
          _showErrorDialog(
              'Invalid height format. Use e.g., "5\'7\"", 5\'7, 5ft7in.');
          setState(() => _isLoading = false);
          return;
        }
        height = heightInCm;
      } else {
        height = double.parse(_heightController.text);
      }

      double weight;
      if (_weightUnit == 'lbs') {
        final weightInKg = convertLbsToKg(_weightController.text);
        if (weightInKg == null) {
          _showErrorDialog(
              'Invalid weight format. Use e.g., "154 lbs, 154, 154.5 lbs".');
          setState(() => _isLoading = false);
          return;
        }
        weight = weightInKg;
      } else {
        weight = double.parse(_weightController.text);
      }

      // Fix: Automatically set to 'No' if no conditions are selected
      if (_hasHealthConditions == 'Yes' && _selectedHealthConditions.isEmpty) {
        _hasHealthConditions = 'No';
      }

      // Fix: Ensure health conditions are properly handled
      final List<String> healthConditions;
      if (_hasHealthConditions == 'No') {
        healthConditions = ["None"];
      } else {
        healthConditions = _selectedHealthConditions.toList();
      }

      final profiling = Profiling(
        age: int.parse(_ageController.text),
        sex: _sex,
        height: height,
        weight: weight,
        healthConditions: healthConditions,
      );

      await profilingService.saveProfile(profiling);

      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const HomePage()),
        );
      }
    } catch (e) {
      setState(() => _isLoading = false);
      _showErrorDialog('Failed to save profile: $e');
    }
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error',
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 18,
                fontWeight: FontWeight.w600)),
        content: Text(message,
            style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400)),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK',
                style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: prime)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      // Prevent back button from closing the app during onboarding
      onWillPop: () async => false,
      child: Scaffold(
        backgroundColor: const Color(0xFFD6EFD8),
        appBar: AppBar(
          title: const Text(
            "Create Your Profile",
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
          foregroundColor: prime,
          backgroundColor: const Color(0xFFD6EFD8),
          elevation: 0,
          automaticallyImplyLeading: false,
        ),
        body: _isLoading
            ? const Center(
          child: CircularProgressIndicator(
            color: prime,
          ),
        )
            : Column(
          children: [
            // Progress indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 10.0),
              child: LinearProgressIndicator(
                value: (_currentPageIndex + 1) / 5,
                backgroundColor: Colors.grey.shade300,
                valueColor: AlwaysStoppedAnimation<Color>(prime),
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),

            // Step indicator
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20.0),
              child: Text(
                "Step ${_currentPageIndex + 1} of 5",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: prime,
                ),
              ),
            ),

            // Page content
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(), // Disable swiping
                onPageChanged: (index) {
                  setState(() {
                    _currentPageIndex = index;
                  });
                },
                children: [
                  _buildSexPage(),
                  _buildAgePage(),
                  _buildHeightPage(),
                  _buildWeightPage(),
                  _buildHealthConditionsPage(),
                ],
              ),
            ),

            // Navigation buttons
            Padding(
              padding: const EdgeInsets.all(20.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Back button (hidden on first page)
                  _currentPageIndex > 0
                      ? ElevatedButton(
                    onPressed: _previousPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.grey.shade200,
                      foregroundColor: prime,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: const Text(
                      'BACK',
                      style: TextStyle(
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  )
                      : const SizedBox(width: 80), // Placeholder for alignment

                  // Next/Submit button
                  ElevatedButton(
                    onPressed: _nextPage,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: prime,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14.0),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    ),
                    child: Text(
                      _currentPageIndex == 4 ? 'SUBMIT' : 'NEXT',
                      style: const TextStyle(
                        fontSize: 14,
                        fontFamily: 'Poppins',
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Sex selection page
  Widget _buildSexPage() {
    double containerSize = 120.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _sexFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              "Please answer these questions to help us provide personalized food recommendations.",
              style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87),
            ),
            const SizedBox(height: 30.0),
            Text(
              "*What is your sex?",
              style: TextStyle(
                fontSize: 16.0,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                color: prime,
              ),
            ),
            const SizedBox(height: 15.0),
            // Visual selection for sex
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _sex = 'Male';
                    });
                  },
                  child: Container(
                    width: containerSize,
                    height: containerSize,
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: _sex == 'Male' ? prime : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: prime, width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.male,
                          size: 30,
                          color: _sex == 'Male' ? Colors.white : Colors.grey,
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Male',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: _sex == 'Male' ? Colors.white : Colors.black87,
                            fontWeight: _sex == 'Male'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20.0),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _sex = 'Female';
                    });
                  },
                  child: Container(
                    width: containerSize,
                    height: containerSize,
                    padding: const EdgeInsets.all(10.0),
                    decoration: BoxDecoration(
                      color: _sex == 'Female' ? prime : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: prime, width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.female,
                          size: 30,
                          color: _sex == 'Female' ? Colors.white : Colors.grey,
                        ),
                        const SizedBox(height: 8.0),
                        Text(
                          'Female',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            color: _sex == 'Female' ? Colors.white : Colors.black87,
                            fontWeight: _sex == 'Female'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Hidden validator field
            Opacity(
              opacity: 0,
              child: DropdownButtonFormField<String>(
                value: _sex.isNotEmpty ? _sex : null,
                items: const [],
                onChanged: (value) {},
                validator: (value) =>
                _sex.isEmpty ? "*Please select your sex." : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Age input page
  Widget _buildAgePage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _ageFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "*What is your age?",
              style: TextStyle(
                fontSize: 16.0,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                color: prime,
              ),
            ),
            const SizedBox(height: 15.0),
            TextFormField(
              controller: _ageController,
              keyboardType: TextInputType.number,
              style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  fontWeight: FontWeight.w400,
                  color: Colors.black87),
              decoration: InputDecoration(
                labelText: "Age (e.g., 30 years)",
                labelStyle: TextStyle(
                    color: prime,
                    fontFamily: 'Poppins',
                    fontSize: 14,
                    fontWeight: FontWeight.w400),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10.0),
                ),
                focusedBorder: OutlineInputBorder(
                    borderSide: BorderSide(color: prime),
                    borderRadius: BorderRadius.circular(10.0)),
                filled: true,
                fillColor: Colors.white,
                errorStyle: const TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 12,
                    color: Colors.red),
              ),
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return "*Please enter your age.";
                }
                final age = int.tryParse(value);
                if (age == null || age < 1 || age > 120) {
                  return "*Enter a valid age (1-120).";
                }
                return null;
              },
            ),
          ],
        ),
      ),
    );
  }

  // Height input page
  Widget _buildHeightPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _heightFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "*What is your height?",
              style: TextStyle(
                fontSize: 16.0,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                color: prime,
              ),
            ),
            const SizedBox(height: 15.0),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _heightController,
                    keyboardType: _heightUnit == 'cm'
                        ? TextInputType.numberWithOptions(decimal: true)
                        : TextInputType.text,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: _heightUnit == 'ft/in'
                          ? "Height (e.g., 5'7\")"
                          : "Height (e.g., 170 cm)",
                      labelStyle: TextStyle(
                          color: prime,
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w400),
                      hintText:
                      _heightUnit == 'ft/in' ? "5'7\"" : "170",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: prime),
                          borderRadius: BorderRadius.circular(10.0)),
                      filled: true,
                      fillColor: Colors.white,
                      errorStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.red),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "*Please enter your height.";
                      }
                      if (_heightUnit == 'ft/in') {
                        final heightInCm = convertFtInToCm(value);
                        if (heightInCm == null) {
                          return "*Invalid format. Use e.g., 5'7\", 5'7, 5ft7in.";
                        }
                        if (heightInCm < 50 || heightInCm > 250) {
                          return "*Height must be between 50-250 cm (e.g., 4'1\" to 8'2\").";
                        }
                      } else {
                        final height = double.tryParse(value);
                        if (height == null) {
                          return "*Invalid number format. Use e.g., 170.";
                        }
                        if (height < 50 || height > 250) {
                          return "*Height must be between 50-250 cm (e.g., 170).";
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: prime),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _heightUnit,
                      items: ['cm', 'ft/in'].map((String unit) {
                        return DropdownMenuItem<String>(
                            value: unit,
                            child: Text(unit,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400)));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          final previousUnit = _heightUnit;
                          _heightUnit = value!;
                          if (_heightController.text.isNotEmpty) {
                            try {
                              double currentHeight;
                              if (previousUnit == 'ft/in') {
                                currentHeight = convertFtInToCm(
                                    _heightController.text) ??
                                    0;
                              } else {
                                currentHeight = double.parse(
                                    _heightController.text);
                              }
                              if (_heightUnit == 'ft/in') {
                                _heightController.text = convertCmToFtIn(currentHeight);
                              } else {
                                _heightController.text =
                                    currentHeight.toStringAsFixed(0);
                              }
                            } catch (e) {
                              _heightController.clear();
                              _showErrorDialog(
                                  'Invalid height format. Please re-enter your height.');
                            }
                          }
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Weight input page
  Widget _buildWeightPage() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _weightFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "*What is your weight?",
              style: TextStyle(
                fontSize: 16.0,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                color: prime,
              ),
            ),
            const SizedBox(height: 15.0),
            Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: _weightController,
                    keyboardType: TextInputType.number,
                    style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.black87),
                    decoration: InputDecoration(
                      labelText: _weightUnit == 'lbs'
                          ? "Weight (e.g., 154 lbs)"
                          : "Weight (e.g., 70 kg)",
                      labelStyle: TextStyle(
                          color: prime,
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w400),
                      hintText: _weightUnit == 'lbs' ? "154" : "70",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(10.0),
                      ),
                      focusedBorder: OutlineInputBorder(
                          borderSide: BorderSide(color: prime),
                          borderRadius: BorderRadius.circular(10.0)),
                      filled: true,
                      fillColor: Colors.white,
                      errorStyle: const TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          color: Colors.red),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return "*Please enter your weight.";
                      }
                      double weightInKg;
                      if (_weightUnit == 'lbs') {
                        final weightInKgValue = convertLbsToKg(value);
                        if (weightInKgValue == null) {
                          return "*Invalid format. Use e.g., 154 lbs, 154, 154.5 lbs.";
                        }
                        weightInKg = weightInKgValue;
                        if (weightInKg < 20 || weightInKg > 300) {
                          return "*Weight must be between 20-300 kg (e.g., 154 lbs).";
                        }
                      } else {
                        weightInKg = double.tryParse(value) ?? 0;
                        if (weightInKg == 0) {
                          return "*Invalid number format. Use e.g., 70.";
                        }
                        if (weightInKg < 20 || weightInKg > 300) {
                          return "*Weight must be between 20-300 kg (e.g., 70).";
                        }
                      }
                      return null;
                    },
                  ),
                ),
                const SizedBox(width: 10.0),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                  decoration: BoxDecoration(
                    border: Border.all(color: prime),
                    borderRadius: BorderRadius.circular(8.0),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _weightUnit,
                      items: ['kg', 'lbs'].map((String unit) {
                        return DropdownMenuItem<String>(
                            value: unit,
                            child: Text(unit,
                                style: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 14,
                                    fontWeight: FontWeight.w400)));
                      }).toList(),
                      onChanged: (value) {
                        setState(() {
                          final previousUnit = _weightUnit;
                          _weightUnit = value!;
                          if (_weightController.text.isNotEmpty) {
                            try {
                              double currentWeight;
                              if (previousUnit == 'lbs') {
                                currentWeight = convertLbsToKg(
                                    _weightController.text) ??
                                    0;
                              } else {
                                currentWeight = double.parse(
                                    _weightController.text);
                              }
                              if (_weightUnit == 'lbs') {
                                _weightController.text = convertKgToLbs(currentWeight);
                              } else {
                                _weightController.text =
                                    currentWeight.toStringAsFixed(1);
                              }
                            } catch (e) {
                              _weightController.clear();
                            }
                          }
                        });
                      },
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  // Health conditions page
  Widget _buildHealthConditionsPage() {
    double smallButtonSize = 80.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20.0),
      child: Form(
        key: _healthConditionsFormKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "*Do you have any health conditions?",
              style: TextStyle(
                fontSize: 16.0,
                fontFamily: 'Poppins',
                fontWeight: FontWeight.w500,
                color: prime,
              ),
            ),
            const SizedBox(height: 15.0),
            // Visual Yes/No selection
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _hasHealthConditions = 'Yes';
                    });
                  },
                  child: Container(
                    width: smallButtonSize,
                    height: smallButtonSize,
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: _hasHealthConditions == 'Yes'
                          ? prime
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: prime, width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.check,
                          size: 20,
                          color: _hasHealthConditions == 'Yes'
                              ? Colors.white
                              : Colors.grey,
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'Yes',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: _hasHealthConditions == 'Yes'
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: _hasHealthConditions == 'Yes'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20.0),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _hasHealthConditions = 'No';
                      _selectedHealthConditions.clear();
                    });
                  },
                  child: Container(
                    width: smallButtonSize,
                    height: smallButtonSize,
                    padding: const EdgeInsets.all(8.0),
                    decoration: BoxDecoration(
                      color: _hasHealthConditions == 'No'
                          ? prime
                          : Colors.grey[200],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: prime, width: 1),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.close,
                          size: 20,
                          color: _hasHealthConditions == 'No'
                              ? Colors.white
                              : Colors.grey,
                        ),
                        const SizedBox(height: 4.0),
                        Text(
                          'No',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 12,
                            color: _hasHealthConditions == 'No'
                                ? Colors.white
                                : Colors.black87,
                            fontWeight: _hasHealthConditions == 'No'
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            // Hidden validator field for form validation
            Opacity(
              opacity: 0,
              child: DropdownButtonFormField<String>(
                value: _hasHealthConditions,
                items: const [],
                onChanged: (value) {},
                validator: (value) => value == null ? "*Please select an option." : null,
              ),
            ),
            if (_hasHealthConditions == 'Yes') ...[
              const SizedBox(height: 20.0),
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.7),
                  border: Border.all(color: prime),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Please select all that apply:",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: prime,
                        ),
                      ),
                      const SizedBox(height: 5.0),
                      const Text(
                        "Your selections will help us provide more accurate food recommendations.",
                        style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10.0),
              Container(
                height: 200, // Fixed height for scrollable container
                decoration: BoxDecoration(
                  border: Border.all(color: prime),
                  borderRadius: BorderRadius.circular(10.0),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(10.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ...HealthConditions.conditionMap.keys.map((condition) {
                        return CheckboxListTile(
                          title: Text(
                            condition,
                            style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 13,
                            ),
                          ),
                          value: _selectedHealthConditions.contains(condition),
                          onChanged: (bool? value) {
                            setState(() {
                              if (value == true) {
                                _selectedHealthConditions.add(condition);
                              } else {
                                _selectedHealthConditions.remove(condition);
                              }
                            });
                          },
                          activeColor: prime,
                          checkColor: Colors.white,
                          controlAffinity: ListTileControlAffinity.leading,
                          dense: true,
                        );
                      }).toList(),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10.0),
              Text(
                "Selected: ${_selectedHealthConditions.length} condition(s)",
                style: TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 12,
                  color: _selectedHealthConditions.isEmpty ? Colors.red : prime,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _pageController.dispose();
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }
}