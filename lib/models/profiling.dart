class Profiling {
  int? id; // Unique identifier for the profile (nullable)
  int age; // User's age
  String sex; // User's sex (e.g., Male or Female)
  double height; // User's height in cm
  double weight; // User's weight in kg
  List<String> healthConditions; // List of user's health conditions
  String? createdAt; // Timestamp when the profile was created (nullable)

  Profiling({
    this.id,
    required this.age,
    required this.sex,
    required this.height,
    required this.weight,
    required this.healthConditions,
    this.createdAt,
  });

  /// Converts height from ft/inches or cm to cm.
  /// - Handles inputs like "5'10" or "175cm".
  /// - Returns the height in cm or `null` if the format is invalid.
  static double? convertHeight(String input) {
    String cleanedInput = input.trim().replaceAll(RegExp(r'\s+'), '');
    final regexFeetInches = RegExp(r"(\d+)'(\d*)");
    final regexCm = RegExp(r"(\d+(?:\.\d+)?)cm?");

    // Handle ft/inches format
    final matchFeetInches = regexFeetInches.firstMatch(cleanedInput);
    if (matchFeetInches != null) {
      final feet = int.parse(matchFeetInches.group(1)!);
      final inchesStr = matchFeetInches.group(2);
      final inches =
          inchesStr != null && inchesStr.isNotEmpty ? int.parse(inchesStr) : 0;
      final heightInCm = (feet * 30.48) + (inches * 2.54);
      return heightInCm;
    }

    // Handle cm format
    final matchCm = regexCm.firstMatch(cleanedInput);
    if (matchCm != null) {
      return double.parse(matchCm.group(1)!);
    }

    return null; // Invalid format
  }

  /// Converts weight from lbs to kg or parses kg directly.
  /// - Handles inputs like "150lbs" or "70kg".
  /// - Returns the weight in kg or `null` if the format is invalid.
  static double? convertWeight(String input) {
    String cleanedInput = input.trim().replaceAll(RegExp(r'\s+'), '');
    final regexLbs = RegExp(r"(\d+(?:\.\d+)?)lbs?");
    final matchLbs = regexLbs.firstMatch(cleanedInput);

    if (matchLbs != null) {
      final lbs = double.parse(matchLbs.group(1)!);
      return lbs * 0.453592; // Convert to kg
    }

    try {
      return double.parse(
          cleanedInput.replaceAll('kg', '')); // Return kg directly
    } catch (e) {
      return null; // Invalid weight format
    }
  }

  /// Factory method to create a `Profiling` object from a JSON map.
  /// - Parses health conditions from a comma-separated string.
  factory Profiling.fromJson(Map<String, dynamic> json) {
    final healthConditionsString = json['health_conditions'] as String?;
    return Profiling(
      id: json['id'] as int?,
      age: int.tryParse(json['age']?.toString() ?? '0') ?? 0,
      sex: json['sex'] != null
          ? (json['sex'].toString().trim().toLowerCase() == 'male'
              ? 'Male'
              : 'Female')
          : '',
      height: double.tryParse(json['height']?.toString() ?? '0') ?? 0.0,
      weight: double.tryParse(json['weight']?.toString() ?? '0') ?? 0.0,
      healthConditions: healthConditionsString != null
          ? healthConditionsString.split(',').map((e) => e.trim()).toList()
          : [],
      createdAt: json['created_at'] as String?,
    );
  }

  /// Converts the `Profiling` object into a JSON map for database storage.
  /// - Joins health conditions into a comma-separated string.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'age': age,
      'sex': sex,
      'height': height,
      'weight': weight,
      'health_conditions': healthConditions.join(','),
      if (createdAt != null) 'created_at': createdAt,
    };
  }

  /// Prepares the profile data for sending to the backend.
  /// - Converts the `Profiling` object into a user-friendly JSON map.
  Map<String, dynamic> toUserProfile() {
    return {
      'age': age,
      'sex': sex.toLowerCase(),
      'height': height,
      'weight': weight,
      'health_conditions': healthConditions,
    };
  }

  /// Creates a copy of the `Profiling` object with updated fields.
  /// - Allows modifying specific fields while keeping others unchanged.
  Profiling copyWith({
    int? id,
    int? age,
    String? sex,
    double? height,
    double? weight,
    List<String>? healthConditions,
    String? createdAt,
  }) {
    return Profiling(
      id: id ?? this.id,
      age: age ?? this.age,
      sex: sex ?? this.sex,
      height: height ?? this.height,
      weight: weight ?? this.weight,
      healthConditions: healthConditions ?? this.healthConditions,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
