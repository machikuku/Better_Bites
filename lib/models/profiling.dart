class Profiling {
  int? id;
  int age;
  String sex;
  double height; // Stored in cm
  double weight; // Stored in kg
  List<String> healthConditions;
  String? createdAt;

  Profiling({
    this.id,
    required this.age,
    required this.sex,
    required this.height,
    required this.weight,
    required this.healthConditions,
    this.createdAt,
  });

  // Convert height (ft/inches) to cm if needed
  static double? convertHeight(String input) {
    String cleanedInput = input.trim().replaceAll(RegExp(r'\s+'), '');
    final regexFeetInches = RegExp(r"(\d+)'(\d*)");
    final regexCm = RegExp(r"(\d+(?:\.\d+)?)cm?");

    // Handle ft/inches format
    final matchFeetInches = regexFeetInches.firstMatch(cleanedInput);
    if (matchFeetInches != null) {
      final feet = int.parse(matchFeetInches.group(1)!);
      final inchesStr = matchFeetInches.group(2);
      final inches = inchesStr != null && inchesStr.isNotEmpty ? int.parse(inchesStr) : 0;
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

  static double? convertWeight(String input) {
    String cleanedInput = input.trim().replaceAll(RegExp(r'\s+'), '');
    final regexLbs = RegExp(r"(\d+(?:\.\d+)?)lbs?");
    final matchLbs = regexLbs.firstMatch(cleanedInput);

    if (matchLbs != null) {
      final lbs = double.parse(matchLbs.group(1)!);
      return lbs * 0.453592; // Convert to kg
    }

    try {
      return double.parse(cleanedInput.replaceAll('kg', '')); // Return kg directly
    } catch (e) {
      return null; // Invalid weight format
    }
  }

  // Factory method to convert JSON to Profiling model
  factory Profiling.fromJson(Map<String, dynamic> json) {
    final healthConditionsString = json['health_conditions'] as String?;
    return Profiling(
      id: json['id'] as int?,
      age: int.tryParse(json['age']?.toString() ?? '0') ?? 0,
      sex: json['sex'] != null ? (json['sex'].toString().trim().toLowerCase() == 'male' ? 'Male' : 'Female') : '',
      height: double.tryParse(json['height']?.toString() ?? '0') ?? 0.0,
      weight: double.tryParse(json['weight']?.toString() ?? '0') ?? 0.0,
      healthConditions: healthConditionsString != null ? healthConditionsString.split(',').map((e) => e.trim()).toList() : [],
      createdAt: json['created_at'] as String?,
    );
  }

  // Convert the Profiling object into a map for saving into the database
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

  // Prepare the profile data for sending to the backend
  Map<String, dynamic> toUserProfile() {
    return {
      'age': age,
      'sex': sex.toLowerCase(),
      'height': height,
      'weight': weight,
      'health_conditions': healthConditions,
    };
  }

  // To create a copy of the Profiling object with new or modified fields
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