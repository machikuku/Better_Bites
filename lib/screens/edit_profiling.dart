// ignore_for_file: unnecessary_string_escapes

import 'package:betterbitees/repositories/profiling_repo.dart';
import 'package:betterbitees/services/profiling_service.dart';
import 'package:betterbitees/helpers/health_conditions.dart';
import 'package:flutter/material.dart';
import 'package:betterbitees/colors.dart';
import 'package:betterbitees/models/profiling.dart';

class EditProfiling extends StatefulWidget {
  const EditProfiling({super.key});

  @override
  _EditProfilingState createState() => _EditProfilingState();
}

class _EditProfilingState extends State<EditProfiling> {
  final ProfilingService profilingService =
  ProfilingService(profilingRepo: ProfilingRepo());
  final _formKey = GlobalKey<FormState>();

  final TextEditingController _ageController = TextEditingController();
  String _sex = '';
  final TextEditingController _heightController = TextEditingController();
  final TextEditingController _weightController = TextEditingController();
  String _heightUnit = 'cm';
  String _weightUnit = 'kg';
  String _hasHealthConditions = 'No';

  // New: Selected health conditions
  Set<String> _selectedHealthConditions = {};

  bool isEditMode = false;
  late Future<Map<String, dynamic>?> _profileFuture;
  Map<String, dynamic>? _currentProfile;
  bool _isProfileLoaded = false;

  @override
  void initState() {
    super.initState();
    _profileFuture = profilingService.getProfile().then((profile) {
      final profileJson = profile?.toJson();
      debugPrint('Fetched profile for editing: $profileJson');
      return profileJson;
    });
  }

  void _loadProfileData(Map<String, dynamic>? profile) {
    if (_isProfileLoaded) return;

    if (profile != null && profile.isNotEmpty) {
      _currentProfile = profile;
      final initialProfile = Profiling.fromJson(profile);
      _sex = initialProfile.sex.isNotEmpty ? initialProfile.sex : '';
      _ageController.text =
      initialProfile.age > 0 ? initialProfile.age.toString() : '';
      _heightController.text = initialProfile.height > 0
          ? (initialProfile.height.round()).toString()
          : '';
      _weightController.text =
      initialProfile.weight > 0 ? initialProfile.weight.toString() : '';

      // Fix for health conditions - properly check if there are any conditions
      List<String> conditions = [];
      if (initialProfile.healthConditions != null) {
        if (initialProfile.healthConditions is String) {
          String healthCondStr = initialProfile.healthConditions as String;
          if (healthCondStr.isNotEmpty) {
            if (healthCondStr.contains(',')) {
              conditions = healthCondStr.split(',').map((e) => e.trim()).toList();
            } else {
              conditions = [healthCondStr];
            }
          }
        } else if (initialProfile.healthConditions is List) {
          conditions = List<String>.from(initialProfile.healthConditions);
        }
      }

      // Fix: Check if the only condition is "None" - if so, set hasHealthConditions to "No"
      if (conditions.isEmpty || conditions.length == 1 && conditions[0] == "None") {
        _hasHealthConditions = 'No';
        _selectedHealthConditions = {};
      } else {
        _hasHealthConditions = 'Yes';
        // Filter out "None" from the conditions if it exists
        _selectedHealthConditions = Set<String>.from(
            conditions.where((condition) => condition != "None")
        );
      }

      _heightUnit = 'cm';
      _weightUnit = 'kg';
      debugPrint('Loaded profile: sex=$_sex, age=${_ageController.text}, '
          'height=${_heightController.text} ($_heightUnit), '
          'weight=${_weightController.text} ($_weightUnit), '
          'hasHealthConditions=$_hasHealthConditions, '
          'healthConditions=${_selectedHealthConditions.toList()}');
    } else {
      debugPrint('No profile data available, using defaults.');
      _currentProfile = null;
      _sex = '';
      _ageController.text = '';
      _heightController.text = '';
      _weightController.text = '';
      _hasHealthConditions = 'No';
      _selectedHealthConditions = {};
      _heightUnit = 'cm';
      _weightUnit = 'kg';
    }
    _isProfileLoaded = true;
  }

  void toggleEditMode() {
    setState(() {
      isEditMode = !isEditMode;
    });
    if (isEditMode) {
      _showEditModeDialog();
    }
  }

  Future<void> _showEditModeDialog() async {
    await showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.edit, color: Colors.blue, size: 50.0),
                const SizedBox(height: 12.0),
                const Text('Edit Mode',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 12.0),
                const Text(
                    'You are now in edit mode. Make your changes and save when done.',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.black54),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20.0),
                ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: prime,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10.0)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20.0, vertical: 10.0),
                  ),
                  child: const Text('OK',
                      style: TextStyle(
                          fontFamily: 'Poppins',
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white)),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _submit() async {
    if (_formKey.currentState!.validate()) {
      try {
        double height;
        if (_heightUnit == 'ft/in') {
          final heightInCm = Profiling.convertHeight(_heightController.text);
          debugPrint(
              'Height input: ${_heightController.text}, Converted to cm: $heightInCm');
          if (heightInCm == null) {
            _showErrorDialog(
                'Invalid height format. Use e.g., "5\'7\", 5\'7, 5ft7in".');
            return;
          }
          height = heightInCm;
        } else {
          height = double.parse(_heightController.text);
        }

        double weight;
        if (_weightUnit == 'lbs') {
          final weightInKg = Profiling.convertWeight(_weightController.text);
          debugPrint(
              'Weight input: ${_weightController.text}, Converted to kg: $weightInKg');
          if (weightInKg == null) {
            _showErrorDialog(
                'Invalid weight format. Use e.g., "154 lbs, 154, 154.5 lbs".');
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

        int profileId =
        _currentProfile != null && _currentProfile!['id'] != null
            ? _currentProfile!['id'] as int
            : -1;

        final profiling = Profiling(
          id: profileId,
          age: int.parse(_ageController.text),
          sex: _sex,
          height: height,
          weight: weight,
          healthConditions: healthConditions,
        );

        debugPrint('Saving edited profile: ${profiling.toJson()}');
        await profilingService.saveProfile(profiling);
        debugPrint('Profile saved successfully');

        final updatedProfile = profiling.toJson();
        _currentProfile = updatedProfile;

        setState(() {
          isEditMode = false;
          _profileFuture = Future.value(updatedProfile);
          _isProfileLoaded = false;
        });

        _showSuccessDialog();
      } catch (e) {
        debugPrint('Error saving profile: $e');
        _showErrorDialog('Failed to save profile: $e');
      }
    } else {
      debugPrint('Form validation failed');
      _showErrorDialog('Please correct the errors in the form.');
    }
  }

  Future<void> _showErrorDialog(String message) async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error, color: Colors.red, size: 50.0),
              const SizedBox(height: 12.0),
              const Text('Error',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const SizedBox(height: 12.0),
              Text(message,
                  style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.black54),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20.0),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: prime,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 10.0),
                ),
                child: const Text('OK',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _showSuccessDialog() async {
    await showDialog(
      context: context,
      builder: (context) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 50.0),
              const SizedBox(height: 12.0),
              const Text('Success',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const SizedBox(height: 12.0),
              const Text('Profile updated successfully!',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.black54),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20.0),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pop(),
                style: ElevatedButton.styleFrom(
                  backgroundColor: prime,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10.0)),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 20.0, vertical: 10.0),
                ),
                child: const Text('OK',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void showSaveConfirmationDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    offset: const Offset(0, 5))
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Save Changes?',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87)),
                const SizedBox(height: 12.0),
                const Text('Are you sure you want to save your changes?',
                    style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w400,
                        color: Colors.black54),
                    textAlign: TextAlign.center),
                const SizedBox(height: 20.0),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                              color: Colors.grey)),
                    ),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _submit();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: prime,
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10.0)),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 20.0, vertical: 10.0),
                      ),
                      child: const Text('Save',
                          style: TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: Colors.white)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showExitConfirmationDialog() async {
    final bool? shouldExit = await showDialog<bool>(
      context: context,
      builder: (context) => Dialog(
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16.0)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(20.0),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16.0),
            boxShadow: [
              BoxShadow(
                  color: Colors.black.withOpacity(0.1),
                  blurRadius: 10,
                  offset: const Offset(0, 5))
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Exit Editing Mode?',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87)),
              const SizedBox(height: 12.0),
              const Text(
                  'Are you sure you want to exit editing mode? Unsaved changes will be lost.',
                  style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      fontWeight: FontWeight.w400,
                      color: Colors.black54),
                  textAlign: TextAlign.center),
              const SizedBox(height: 20.0),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.grey)),
                  ),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: prime,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10.0)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20.0, vertical: 10.0),
                    ),
                    child: const Text('Exit',
                        style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    return shouldExit ?? false;
  }

  @override
  Widget build(BuildContext context) {
    final double screenWidth = MediaQuery.of(context).size.width;

    return WillPopScope(
      onWillPop: () async {
        if (isEditMode) {
          return await _showExitConfirmationDialog();
        }
        return true;
      },
      child: Scaffold(
        backgroundColor: const Color(0xFFD6EFD8),
        appBar: AppBar(
          title: const Text(
            "Profile",
            style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 16,
                fontWeight: FontWeight.w500),
          ),
          foregroundColor: prime,
          backgroundColor: const Color(0xFFD6EFD8),
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () async {
              if (isEditMode) {
                final shouldExit = await _showExitConfirmationDialog();
                if (shouldExit) {
                  setState(() {
                    isEditMode = false;
                    _isProfileLoaded = false;
                  });
                }
              } else {
                Navigator.of(context).pop();
              }
            },
          ),
          actions: [
            IconButton(
              icon: Icon(isEditMode ? Icons.save : Icons.edit),
              onPressed: () =>
              isEditMode ? showSaveConfirmationDialog() : toggleEditMode(),
            ),
          ],
        ),
        body: FutureBuilder<Map<String, dynamic>?>(
          future: _profileFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            } else if (snapshot.hasError) {
              return Center(
                  child: Padding(
                      padding: EdgeInsets.all(screenWidth * 0.04),
                      child: Text('Error loading profile: ${snapshot.error}',
                          style: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 14,
                              fontWeight: FontWeight.w400))));
            } else {
              _loadProfileData(snapshot.data);
              return SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.06,
                  vertical: screenWidth * 0.04,
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (snapshot.data == null || snapshot.data!.isEmpty) ...[
                        Padding(
                          padding: EdgeInsets.symmetric(
                              vertical: screenWidth * 0.04),
                          child: const Text(
                            "No profile data available. Click 'Edit' to add your details.",
                            style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w400,
                                color: Colors.grey),
                            textAlign: TextAlign.center,
                          ),
                        ),
                      ],
                      // Sex Question
                      const SizedBox(height: 8.0),
                      Text(
                        "*What is your sex?",
                        style: TextStyle(
                          fontSize: 14.0,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          color: prime,
                        ),
                      ),
                      const SizedBox(height: 10.0),
                      DropdownButtonFormField<String>(
                        value: _sex.isNotEmpty ? _sex : null,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: "Sex",
                          labelStyle: TextStyle(
                              color: prime,
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w400),
                          border: const OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: prime)),
                          filled: true,
                          fillColor:
                          isEditMode ? Colors.white : Colors.grey.shade200,
                          errorStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              color: Colors.red),
                        ),
                        items: ['Male', 'Female'].map((String sex) {
                          return DropdownMenuItem<String>(
                              value: sex, child: Text(sex));
                        }).toList(),
                        onChanged: isEditMode
                            ? (value) => setState(() => _sex = value!)
                            : null,
                        validator: (value) => value == null && isEditMode
                            ? "*Please select your sex."
                            : null,
                      ),
                      // Age Question
                      const SizedBox(height: 25.0),
                      Text(
                        "*What is your age?",
                        style: TextStyle(
                          fontSize: 14.0,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          color: prime,
                        ),
                      ),
                      const SizedBox(height: 10.0),
                      TextFormField(
                        controller: _ageController,
                        keyboardType: TextInputType.number,
                        readOnly: !isEditMode,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: "Age (e.g., 30 years)",
                          labelStyle: TextStyle(
                              color: prime,
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w400),
                          border: const OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: prime)),
                          filled: true,
                          fillColor:
                          isEditMode ? Colors.white : Colors.grey.shade200,
                          errorStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              color: Colors.red),
                        ),
                        validator: (value) {
                          if (!isEditMode) return null;
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
                      // Height Question
                      const SizedBox(height: 25.0),
                      Text(
                        "*What is your height?",
                        style: TextStyle(
                          fontSize: 14.0,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          color: prime,
                        ),
                      ),
                      const SizedBox(height: 10.0),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _heightController,
                              keyboardType: TextInputType.text,
                              readOnly: !isEditMode,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: _heightUnit == 'ft/in'
                                    ? "Height (e.g., 5'7\")"
                                    : "Height (e.g., 170 cm)",
                                labelStyle: TextStyle(
                                    color: prime,
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400),
                                hintText:
                                _heightUnit == 'ft/in' ? "5'7\"" : "170",
                                border: const OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: prime)),
                                filled: true,
                                fillColor: isEditMode
                                    ? Colors.white
                                    : Colors.grey.shade200,
                                errorStyle: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10,
                                    color: Colors.red),
                              ),
                              validator: (value) {
                                if (!isEditMode) return null;
                                if (value == null || value.isEmpty) {
                                  return "*Please enter your height.";
                                }
                                if (_heightUnit == 'ft/in') {
                                  final heightInCm =
                                  Profiling.convertHeight(value);
                                  debugPrint(
                                      'Height validation: input="$value", converted=$heightInCm');
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
                          DropdownButton<String>(
                            value: _heightUnit,
                            items: ['cm', 'ft/in'].map((String unit) {
                              return DropdownMenuItem<String>(
                                  value: unit,
                                  child: Text(unit,
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400)));
                            }).toList(),
                            onChanged: isEditMode
                                ? (value) {
                              setState(() {
                                final previousUnit = _heightUnit;
                                _heightUnit = value!;
                                if (_heightController.text.isNotEmpty) {
                                  try {
                                    double currentHeight;
                                    if (previousUnit == 'ft/in') {
                                      currentHeight =
                                          Profiling.convertHeight(
                                              _heightController
                                                  .text) ??
                                              0;
                                    } else {
                                      currentHeight = double.parse(
                                          _heightController.text);
                                    }
                                    if (_heightUnit == 'ft/in') {
                                      final feet =
                                      (currentHeight / 30.48).floor();
                                      final inches =
                                      ((currentHeight % 30.48) / 2.54)
                                          .round();
                                      _heightController.text =
                                      "$feet'$inches\"";
                                    } else {
                                      _heightController.text =
                                          currentHeight
                                              .toStringAsFixed(0);
                                    }
                                  } catch (e) {
                                    _heightController.clear();
                                    _showErrorDialog(
                                        'Invalid height format. Please re-enter your height.');
                                  }
                                }
                              });
                            }
                                : null,
                          ),
                        ],
                      ),
                      // Weight Question
                      const SizedBox(height: 25.0),
                      Text(
                        "*What is your weight?",
                        style: TextStyle(
                          fontSize: 14.0,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          color: prime,
                        ),
                      ),
                      const SizedBox(height: 10.0),
                      Row(
                        children: [
                          Expanded(
                            child: TextFormField(
                              controller: _weightController,
                              keyboardType: TextInputType.number,
                              readOnly: !isEditMode,
                              style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 13,
                                  fontWeight: FontWeight.w400,
                                  color: Colors.black87),
                              decoration: InputDecoration(
                                labelText: _weightUnit == 'lbs'
                                    ? "Weight (e.g., 154 lbs)"
                                    : "Weight (e.g., 70 kg)",
                                labelStyle: TextStyle(
                                    color: prime,
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400),
                                hintText: _weightUnit == 'lbs' ? "154" : "70",
                                border: const OutlineInputBorder(),
                                focusedBorder: OutlineInputBorder(
                                    borderSide: BorderSide(color: prime)),
                                filled: true,
                                fillColor: isEditMode
                                    ? Colors.white
                                    : Colors.grey.shade200,
                                errorStyle: const TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 10,
                                    color: Colors.red),
                              ),
                              validator: (value) {
                                if (!isEditMode) return null;
                                if (value == null || value.isEmpty) {
                                  return "*Please enter your weight.";
                                }
                                double weightInKg;
                                if (_weightUnit == 'lbs') {
                                  final weightInKgValue =
                                  Profiling.convertWeight(value);
                                  debugPrint(
                                      'Weight validation: input=$value, converted=$weightInKgValue');
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
                          DropdownButton<String>(
                            value: _weightUnit,
                            items: ['kg', 'lbs'].map((String unit) {
                              return DropdownMenuItem<String>(
                                  value: unit,
                                  child: Text(unit,
                                      style: const TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w400)));
                            }).toList(),
                            onChanged: isEditMode
                                ? (value) {
                              setState(() {
                                final previousUnit = _weightUnit;
                                _weightUnit = value!;
                                if (_weightController.text.isNotEmpty) {
                                  try {
                                    double currentWeight;
                                    if (previousUnit == 'lbs') {
                                      currentWeight =
                                          Profiling.convertWeight(
                                              _weightController
                                                  .text) ??
                                              0;
                                    } else {
                                      currentWeight = double.parse(
                                          _weightController.text);
                                    }
                                    if (_weightUnit == 'lbs') {
                                      final lbs =
                                      (currentWeight / 0.453592)
                                          .roundToDouble();
                                      _weightController.text =
                                          lbs.toStringAsFixed(1);
                                    } else {
                                      _weightController.text =
                                          currentWeight
                                              .toStringAsFixed(1);
                                    }
                                  } catch (e) {
                                    _weightController.clear();
                                  }
                                }
                              });
                            }
                                : null,
                          ),
                        ],
                      ),
                      const SizedBox(height: 25.0),
                      Text(
                        "*Do you have any health conditions?",
                        style: TextStyle(
                          fontSize: 14.0,
                          fontFamily: 'Poppins',
                          fontWeight: FontWeight.w500,
                          color: prime,
                        ),
                      ),
                      const SizedBox(height: 10.0),
                      DropdownButtonFormField<String>(
                        value: _hasHealthConditions,
                        style: const TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            fontWeight: FontWeight.w400,
                            color: Colors.black87),
                        decoration: InputDecoration(
                          labelText: "Health Conditions",
                          labelStyle: TextStyle(
                              color: prime,
                              fontFamily: 'Poppins',
                              fontSize: 13,
                              fontWeight: FontWeight.w400),
                          border: const OutlineInputBorder(),
                          focusedBorder: OutlineInputBorder(
                              borderSide: BorderSide(color: prime)),
                          filled: true,
                          fillColor:
                          isEditMode ? Colors.white : Colors.grey.shade200,
                          errorStyle: const TextStyle(
                              fontFamily: 'Poppins',
                              fontSize: 10,
                              color: Colors.red),
                        ),
                        items: ['No', 'Yes'].map((String value) {
                          return DropdownMenuItem<String>(
                              value: value, child: Text(value));
                        }).toList(),
                        onChanged: isEditMode
                            ? (value) => setState(() {
                          _hasHealthConditions = value!;
                          // Clear selected conditions when "No" is selected
                          if (value == 'No') {
                            _selectedHealthConditions.clear();
                          }
                        })
                            : null,
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
                                const SizedBox(height: 10.0),
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
                                    onChanged: isEditMode
                                        ? (bool? value) {
                                      setState(() {
                                        if (value == true) {
                                          _selectedHealthConditions.add(condition);
                                        } else {
                                          _selectedHealthConditions.remove(condition);
                                        }
                                      });
                                    }
                                        : null,
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
                            color: _selectedHealthConditions.isEmpty && isEditMode ? Colors.red : prime,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                      const SizedBox(height: 30.0),
                    ],
                  ),
                ),
              );
            }
          },
        ),
      ),
    );
  }

  @override
  void dispose() {
    _ageController.dispose();
    _heightController.dispose();
    _weightController.dispose();
    super.dispose();
  }
}
