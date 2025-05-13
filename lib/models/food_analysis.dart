/// Represents the analysis of a single ingredient.
class IngredientAnalysis {
  final String name; // Name of the ingredient
  final String impact; // Health impact of the ingredient
  final String?
      consumptionGuidance; // Guidance on how to consume the ingredient
  final String? alternatives; // Suggested alternatives for the ingredient
  final String? source; // Source of the information
  final String? volume; // Quantity or volume of the ingredient

  IngredientAnalysis({
    required this.name,
    required this.impact,
    this.consumptionGuidance,
    this.alternatives,
    this.source,
    this.volume,
  });

  /// Creates an `IngredientAnalysis` object from a JSON map.
  factory IngredientAnalysis.fromJson(Map<String, dynamic> json) {
    return IngredientAnalysis(
      name: json['name'] as String,
      impact:
          json['impact'] as String? ?? json['description'] as String? ?? 'N/A',
      consumptionGuidance: json['consumption_guidance'] as String? ??
          json['recommended_intake'] as String?,
      alternatives: json['alternatives'] as String?,
      source: json['source'] as String?,
      volume: json['volume'] as String? ?? 'N/A',
    );
  }

  /// Converts the `IngredientAnalysis` object into a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'impact': impact,
      'consumption_guidance': consumptionGuidance,
      'alternatives': alternatives,
      'source': source,
      'volume': volume,
    };
  }
}

/// Represents an allergen and its associated details.
class Allergen {
  final String name; // Name of the allergen
  final String description; // Description of the allergen
  final String impact; // Health impact of the allergen
  final String? potentialReaction; // Potential reactions caused by the allergen
  final String? source; // Source of the information

  Allergen({
    required this.name,
    required this.description,
    required this.impact,
    this.potentialReaction,
    this.source,
  });

  /// Creates an `Allergen` object from a JSON map.
  factory Allergen.fromJson(Map<String, dynamic> json) {
    final name = json['name'] as String;
    final impact = json['impact'] as String?;

    // Generate a specific impact if none is provided
    String finalImpact = impact ?? '';
    if (finalImpact.isEmpty ||
        finalImpact ==
            'May cause adverse reactions in sensitive individuals.') {
      // Generate specific impact based on allergen name
      if (name.toLowerCase().contains('gluten') ||
          name.toLowerCase().contains('wheat')) {
        finalImpact =
            'Gluten can trigger digestive issues, inflammation, and autoimmune responses in sensitive individuals, particularly those with celiac disease or gluten sensitivity.';
      } else if (name.toLowerCase().contains('dairy') ||
          name.toLowerCase().contains('milk')) {
        finalImpact =
            'Dairy allergens can cause digestive discomfort, inflammation, and immune responses in sensitive individuals, particularly those with lactose intolerance or milk protein allergies.';
      } else if (name.toLowerCase().contains('nut') ||
          name.toLowerCase().contains('peanut')) {
        finalImpact =
            'Nut allergies can cause severe reactions including skin rashes, swelling, respiratory issues, and potentially life-threatening anaphylaxis in allergic individuals.';
      } else if (name.toLowerCase().contains('soy')) {
        finalImpact =
            'Soy allergens can trigger immune responses causing skin reactions, digestive issues, and respiratory symptoms in sensitive individuals.';
      } else if (name.toLowerCase().contains('egg')) {
        finalImpact =
            'Egg allergies can cause immune reactions ranging from skin issues to digestive problems and respiratory symptoms in sensitive individuals.';
      } else if (name.toLowerCase().contains('fish') ||
          name.toLowerCase().contains('shellfish')) {
        finalImpact =
            'Seafood allergies often cause severe reactions including skin rashes, swelling, digestive issues, and potentially life-threatening anaphylaxis in sensitive individuals.';
      } else {
        finalImpact =
            'This allergen may cause various adverse reactions including skin issues, digestive problems, or respiratory symptoms depending on individual sensitivity.';
      }
    }

    return Allergen(
      name: name,
      description: json['description'] as String? ?? 'N/A',
      impact: finalImpact,
      potentialReaction: json['potential_reaction'] as String?,
      source: json['source'] as String?,
    );
  }

  /// Converts the `Allergen` object into a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'impact': impact,
      'potential_reaction': potentialReaction,
      'source': source,
    };
  }
}

/// Represents a health tip related to food analysis.
class HealthTip {
  final String name; // Title of the health tip
  final String description; // Description of the health tip
  final String? suggestion; // Suggested action based on the tip
  final String? source; // Source of the information

  HealthTip({
    required this.name,
    required this.description,
    this.suggestion,
    this.source,
  });

  /// Creates a `HealthTip` object from a JSON map.
  factory HealthTip.fromJson(Map<String, dynamic> json) {
    return HealthTip(
      name: json['name'] as String,
      description: json['description'] as String? ?? 'N/A',
      suggestion: json['suggestion'] as String?,
      source: json['source'] as String?,
    );
  }

  /// Converts the `HealthTip` object into a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'suggestion': suggestion,
      'source': source,
    };
  }
}

/// Represents the overall food analysis, including ingredients, allergens, and health tips.
class FoodAnalysis {
  int? id; // Unique identifier for the food analysis
  String title; // Title of the analysis
  String? imagePath; // Path to the image used for analysis
  String? recognizedText; // Text recognized from the image
  DateTime createdAt; // Timestamp when the analysis was created
  List<IngredientAnalysis> ingredientsAnalysis; // List of ingredient analyses
  List<Allergen> allergens; // List of allergens
  List<HealthTip> healthTips; // List of health tips

  FoodAnalysis({
    this.id,
    required this.title,
    this.imagePath,
    this.recognizedText,
    required this.createdAt,
    required this.ingredientsAnalysis,
    required this.allergens,
    required this.healthTips,
  });

  /// Creates a `FoodAnalysis` object from a JSON map.
  factory FoodAnalysis.fromJson(Map<String, dynamic> json) {
    return FoodAnalysis(
      id: json['id'] as int?,
      title: json['title'] as String? ?? 'Personalized Ingredient Analysis',
      imagePath: json['image_path'] as String?,
      recognizedText: json['recognized_text'] as String?,
      createdAt: DateTime.parse(
          json['created_at'] as String? ?? DateTime.now().toIso8601String()),
      ingredientsAnalysis: (json['ingredients_analysis'] as List<dynamic>?)
              ?.map((item) =>
                  IngredientAnalysis.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      allergens: (json['allergens'] as List<dynamic>?)
              ?.map((item) => Allergen.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
      healthTips: (json['health_tips'] as List<dynamic>?)
              ?.map((item) => HealthTip.fromJson(item as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }

  /// Converts the `FoodAnalysis` object into a JSON map.
  Map<String, dynamic> toJson() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'image_path': imagePath,
      'recognized_text': recognizedText,
      'created_at': createdAt.toIso8601String(),
      'ingredients_analysis':
          ingredientsAnalysis.map((item) => item.toJson()).toList(),
      'allergens': allergens.map((item) => item.toJson()).toList(),
      'health_tips': healthTips.map((item) => item.toJson()).toList(),
    };
  }
}
