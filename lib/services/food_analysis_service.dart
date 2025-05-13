import 'dart:io';
import 'package:flutter/widgets.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'dart:convert';
import 'package:betterbitees/models/food_analysis.dart';
import 'package:betterbitees/repositories/food_analysis_repo.dart';
import 'package:betterbitees/repositories/profiling_repo.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class FoodAnalysisService {
  final FoodAnalysisRepo foodAnalysisRepo;
  final ProfilingRepo profilingRepo;

  // IMPORTANT: Be careful with hardcoded API keys in production apps
  // This key will be visible in your app's binary and could be extracted
  static const String _apiKey =
      "AIzaSyBomw7nWLyhb8uAPDhast7TtaLH-DSUw7Y"; // Replace with your actual API key
  static const String _modelName = 'gemini-1.5-pro';

  FoodAnalysisService({
    required this.foodAnalysisRepo,
    required this.profilingRepo,
  });

  /// Analyzes an image directly using the Gemini model.
  /// - Detects if the image contains food.
  /// - Extracts ingredient information and performs a detailed analysis.
  /// - Saves the analysis to the database and invokes a callback with the result.
  Future<void> analyzeImageDirectly(
    File imageFile,
    Map<String, dynamic> userProfile,
    Function(FoodAnalysis) onAnalysisComplete, {
    DateTime? timestamp,
  }) async {
    try {
      debugPrint('Starting direct image analysis with Gemini...');
      debugPrint('User profile: $userProfile');

      // Initialize the Gemini model
      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
      );

      // Add non-food item detection to the prompt
      final nonFoodDetectionPrompt = '''
You are a food ingredient analyzer. First, determine if the image shows a food product with an ingredient label.

If the image does NOT show a food product or ingredient label (e.g., it shows electronics, people, scenery, or any non-food item), respond with EXACTLY:
{
  "is_food": false,
  "explanation": "Brief explanation of what the image shows instead of food"
}

If the image DOES show a food product or ingredient label, respond with EXACTLY:
{
  "is_food": true
}

Respond ONLY with this JSON format and nothing else.
''';

      // Read the image file as bytes
      final bytes = await imageFile.readAsBytes();

      // Create content parts for non-food detection
      final nonFoodImagePart = DataPart('image/jpeg', bytes);
      final nonFoodTextPart = TextPart(nonFoodDetectionPrompt);
      final nonFoodContent = [
        Content.multi([nonFoodTextPart, nonFoodImagePart])
      ];

      // Check if the image contains food
      final nonFoodResponse = await model.generateContent(nonFoodContent);
      final nonFoodResponseText = nonFoodResponse.text ?? '';

      debugPrint('Non-food detection response: $nonFoodResponseText');

      try {
        // Extract JSON from the response text
        final jsonRegExp = RegExp(r'{[\s\S]*}');
        final match = jsonRegExp.firstMatch(nonFoodResponseText);

        if (match != null) {
          final jsonStr = match.group(0);
          if (jsonStr != null) {
            final Map<String, dynamic> detectionResult = jsonDecode(jsonStr);

            // Fix: Handle the case where is_food might be a string instead of a boolean
            bool isFood;
            if (detectionResult.containsKey('is_food')) {
              var isFoodValue = detectionResult['is_food'];
              if (isFoodValue is bool) {
                isFood = isFoodValue;
              } else if (isFoodValue is String) {
                isFood = isFoodValue.toLowerCase() == 'true';
              } else {
                isFood =
                    true; // Default to true if value is neither bool nor string
              }
            } else {
              isFood = true; // Default to true if key doesn't exist
            }

            if (!isFood) {
              final String explanation =
                  detectionResult['explanation'] as String? ??
                      'This does not appear to be a food item';

              // Create a special food analysis for non-food items
              final nonFoodAnalysis = FoodAnalysis(
                title: 'Not a Food Item',
                ingredientsAnalysis: [
                  IngredientAnalysis(
                    name: 'Error: Non-Food Item Detected',
                    impact: explanation,
                    consumptionGuidance:
                        'This appears to be a non-food item. Please scan a food product with an ingredient label.',
                    alternatives:
                        'Try scanning a packaged food item with an ingredient list.',
                    source: 'Better Bites Analysis System',
                  )
                ],
                allergens: [
                  Allergen(
                    name: 'Not Applicable',
                    description:
                        'No allergen information available for non-food items.',
                    impact: 'Not applicable as this is not a food item.',
                    source: 'Better Bites Analysis System',
                  )
                ],
                healthTips: [
                  HealthTip(
                    name: 'Scan Food Items Only',
                    description:
                        'Better Bites is designed to analyze food products and their ingredients.',
                    suggestion:
                        'Please scan a food product with an ingredient label for accurate analysis.',
                    source: 'Better Bites Analysis System',
                  )
                ],
                createdAt: timestamp ?? DateTime.now(),
              );

              // Save to database
              final savedId = await foodAnalysisRepo.create(nonFoodAnalysis);
              final savedAnalysis =
                  await foodAnalysisRepo.getFoodAnalysis(savedId);

              onAnalysisComplete(savedAnalysis);
              return;
            }
          }
        }
      } catch (e) {
        debugPrint('Error in non-food detection: $e');
        // Continue with normal analysis if detection fails
      }

      // Save image to app directory for persistence
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImagePath = path.join(appDir.path, fileName);
      await File(savedImagePath).writeAsBytes(bytes);

      // Extract health conditions from user profile - handle both string and list formats
      List<String> healthConditions = [];
      final healthConditionsData = userProfile['health_conditions'];
      if (healthConditionsData is List) {
        healthConditions = List<String>.from(healthConditionsData);
      } else if (healthConditionsData is String) {
        // If it's a comma-separated string, split it
        if (healthConditionsData.contains(',')) {
          healthConditions =
              healthConditionsData.split(',').map((e) => e.trim()).toList();
        } else if (healthConditionsData.isNotEmpty) {
          // If it's a single condition as string
          healthConditions = [healthConditionsData];
        }
      }

      // Create a prompt for food analysis
      final prompt = '''
You are a nutritional expert analyzing food ingredient labels for the Better Bites app.

USER PROFILE:
- Age: ${userProfile['age']}
- Sex: ${userProfile['sex']}
- Height: ${userProfile['height']} cm
- Weight: ${userProfile['weight']} kg
- Health Conditions: ${healthConditions.isEmpty ? 'None' : healthConditions.join(', ')}

TASK:
Analyze the food ingredient label in the image. Look for the ingredient list and nutritional information, including any volume or quantity information (e.g., %, g, mg, ml) for each ingredient where available.

Provide a comprehensive analysis in JSON format with these sections:
1. Ingredient analysis (identify key ingredients with amount, their health impacts, and their quantities)
2. Allergens (identify potential allergens based on the ingredients)
3. Health tips (provide personalized recommendations based on the user profile)

Format your response ONLY as a valid JSON object with this structure:
{
  "title": "Ingredient Analysis",
  "ingredients_analysis": [
    {
      "name": "Ingredient Name",
      "volume": "Quantity of the ingredient (e.g., '5g', '10%', '20mg', '15ml', or 'N/A' if not specified)",
      "impact": "Health impact description specifically tailored to this ingredient, its quantity, and the user's health conditions",
      "consumption_guidance": "Personalized guidance on consumption based on the ingredient's quantity and the user's profile",
      "alternatives": "Healthier alternatives specifically relevant to this ingredient, its quantity, and user's health needs",
      "source": "Specific and relevant source for this information"
    }
  ],
  "allergens": [
    {
      "name": "Allergen Name",
      "description": "Detailed description of what this allergen is",
      "impact": "Specific health impact of this allergen, especially considering the user's health conditions",
      "potential_reaction": "Detailed description of potential reactions specific to this allergen",
      "source": "Specific and relevant source for this information"
    }
  ],
  "health_tips": [
    {
      "name": "Tip Title",
      "description": "Detailed description tailored to the user's profile",
      "suggestion": "Actionable suggestion personalized for the user",
      "source": "Specific and relevant source for this information"
    }
  ]
}

IMPORTANT CLASSIFICATION GUIDELINES:
- For each ingredient, provide detailed health impacts that specifically mention if the ingredient should be limited or avoided based on its quantity
- Make sure to classify at least 30% of ingredients with concerning health impacts (e.g., using keywords like harmful, avoid, caution, negative, adverse, unhealthy, dangerous, toxic, risk, limit, excessive, problematic, concern, warning) to provide balanced information
- For ingredients with concerning health impacts, always provide specific alternatives
- Common ingredients that may have concerning health impacts include: added sugars, high fructose corn syrup, trans fats, artificial colors/flavors, MSG, sodium nitrate/nitrite, partially hydrogenated oils
- If an ingredient has both positive and negative effects, clearly state the concerns in the impact field
- When volume is available (e.g., '5g of sugar'), tailor the impact and consumption guidance to reflect the specific quantity, e.g., compare to daily recommended limits
- If volume is not specified, use 'N/A' for the volume field and provide general guidance

IMPORTANT SOURCE REQUIREMENTS:
- CRITICAL: For EVERY ingredient, allergen, and health tip, provide a SPECIFIC and CREDIBLE source
- Source information MUST be detailed and specific to each item, NOT generic placeholders
- Include the full name of the organization, study, or database (e.g., "Journal of Nutrition 2023 Study on Artificial Sweeteners" instead of just "Research Study")
- When possible, include a website URL or DOI for the source (e.g., "Mayo Clinic: www.mayoclinic.org/healthy-lifestyle/nutrition-and-healthy-eating")
- Sources should be relevant to the specific claim being made about each ingredient, allergen, or health tip
- Never use generic placeholders like "Nutritional Database Reference" or "FDA, USDA"
- Each source must be included in the dedicated "source" field for each item
''';

      // Create content parts with the image and prompt
      final imagePart = DataPart('image/jpeg', bytes);
      final textPart = TextPart(prompt);
      final content = [
        Content.multi([textPart, imagePart])
      ];

      // Generate content
      final response = await model.generateContent(content);
      final responseText = response.text ?? '';

      debugPrint('Received response from Gemini');

      // Extract the recognized text from the image (if available)
      String? recognizedText;
      try {
        // Try to extract the recognized text from Gemini's response
        final textRegExp = RegExp(r'"recognized_text"\s*:\s*"([^"]*)"');
        final textMatch = textRegExp.firstMatch(responseText);
        if (textMatch != null && textMatch.groupCount >= 1) {
          recognizedText = textMatch.group(1);
        }
      } catch (e) {
        debugPrint('Error extracting recognized text: $e');
      }

      // Parse the JSON response
      try {
        // Extract JSON from the response text
        final jsonRegExp = RegExp(r'{[\s\S]*}');
        final match = jsonRegExp.firstMatch(responseText);

        if (match != null) {
          final jsonStr = match.group(0);
          if (jsonStr != null) {
            final Map<String, dynamic> jsonData = jsonDecode(jsonStr);

            // Create FoodAnalysis object
            final foodAnalysis = await _createFoodAnalysisFromJson(
              jsonData,
              savedImagePath,
              recognizedText ?? "Image analyzed directly by Gemini",
              timestamp ?? DateTime.now(),
              userProfile,
            );

            // Save to database
            final savedId = await foodAnalysisRepo.create(foodAnalysis);
            debugPrint('Food analysis saved with ID: $savedId');

            // Get the saved analysis with the ID
            final savedAnalysis =
                await foodAnalysisRepo.getFoodAnalysis(savedId);

            // Call the callback with the result
            onAnalysisComplete(savedAnalysis);
          } else {
            throw Exception('Could not extract JSON from response');
          }
        } else {
          throw Exception('Could not extract JSON from response');
        }
      } catch (e) {
        debugPrint('Error parsing JSON: $e');
        debugPrint('Response text: $responseText');

        // Create a fallback food analysis
        final fallbackAnalysis = _createFallbackFoodAnalysis(
          savedImagePath,
          "Image analyzed directly by Gemini",
          timestamp ?? DateTime.now(),
          userProfile,
        );

        // Save fallback analysis
        final savedId = await foodAnalysisRepo.create(fallbackAnalysis);
        final savedAnalysis = await foodAnalysisRepo.getFoodAnalysis(savedId);

        onAnalysisComplete(savedAnalysis);
      }
    } catch (e) {
      debugPrint('Error in analyzeImageDirectly: $e');

      // Create a fallback food analysis for error case
      final fallbackAnalysis = _createFallbackFoodAnalysis(
        '',
        "Error analyzing image",
        timestamp ?? DateTime.now(),
        userProfile,
      );

      try {
        // Save fallback analysis
        final savedId = await foodAnalysisRepo.create(fallbackAnalysis);
        final savedAnalysis = await foodAnalysisRepo.getFoodAnalysis(savedId);
        onAnalysisComplete(savedAnalysis);
      } catch (dbError) {
        debugPrint('Error saving fallback analysis: $dbError');
        onAnalysisComplete(fallbackAnalysis);
      }
    }
  }

  Future<void> analyzeFood(
    String ingredientText,
    File imageFile,
    Map<String, dynamic> userProfile,
    Function(FoodAnalysis) onAnalysisComplete, {
    DateTime? timestamp,
  }) async {
    try {
      debugPrint('Starting food analysis with Gemini...');
      debugPrint('User profile: $userProfile');

      // Initialize the Gemini model
      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
      );

      // Add non-food item detection to the prompt if we have an image
      if (imageFile.existsSync()) {
        final nonFoodDetectionPrompt = '''
You are a food ingredient analyzer. First, determine if the image shows a food product with an ingredient label.

If the image does NOT show a food product or ingredient label (e.g., it shows electronics, people, scenery, or any non-food item), respond with EXACTLY:
{
  "is_food": false,
  "explanation": "Brief explanation of what the image shows instead of food"
}

If the image DOES show a food product or ingredient label, respond with EXACTLY:
{
  "is_food": true
}

Respond ONLY with this JSON format and nothing else.
''';

        // Create content parts for non-food detection
        final bytes = await imageFile.readAsBytes();
        final nonFoodImagePart = DataPart('image/jpeg', bytes);
        final nonFoodTextPart = TextPart(nonFoodDetectionPrompt);
        final nonFoodContent = [
          Content.multi([nonFoodTextPart, nonFoodImagePart])
        ];

        // Check if the image contains food
        final nonFoodResponse = await model.generateContent(nonFoodContent);
        final nonFoodResponseText = nonFoodResponse.text ?? '';

        debugPrint('Non-food detection response: $nonFoodResponseText');

        try {
          // Extract JSON from the response text
          final jsonRegExp = RegExp(r'{[\s\S]*}');
          final match = jsonRegExp.firstMatch(nonFoodResponseText);

          if (match != null) {
            final jsonStr = match.group(0);
            if (jsonStr != null) {
              final Map<String, dynamic> detectionResult = jsonDecode(jsonStr);

              // Fix: Handle the case where is_food might be a string instead of a boolean
              bool isFood;
              if (detectionResult.containsKey('is_food')) {
                var isFoodValue = detectionResult['is_food'];
                if (isFoodValue is bool) {
                  isFood = isFoodValue;
                } else if (isFoodValue is String) {
                  isFood = isFoodValue.toLowerCase() == 'true';
                } else {
                  isFood =
                      true; // Default to true if value is neither bool nor string
                }
              } else {
                isFood = true; // Default to true if key doesn't exist
              }

              if (!isFood) {
                final String explanation =
                    detectionResult['explanation'] as String? ??
                        'This does not appear to be a food item';

                // Create a special food analysis for non-food items
                final nonFoodAnalysis = FoodAnalysis(
                  title: 'Not a Food Item',
                  ingredientsAnalysis: [
                    IngredientAnalysis(
                      name: 'Error: Non-Food Item Detected',
                      impact: explanation,
                      consumptionGuidance:
                          'This appears to be a non-food item. Please scan a food product with an ingredient label.',
                      alternatives:
                          'Try scanning a packaged food item with an ingredient list.',
                      source: 'Better Bites Analysis System',
                    )
                  ],
                  allergens: [
                    Allergen(
                      name: 'Not Applicable',
                      description:
                          'No allergen information available for non-food items.',
                      impact: 'Not applicable as this is not a food item.',
                      source: 'Better Bites Analysis System',
                    )
                  ],
                  healthTips: [
                    HealthTip(
                      name: 'Scan Food Items Only',
                      description:
                          'Better Bites is designed to analyze food products and their ingredients.',
                      suggestion:
                          'Please scan a food product with an ingredient label for accurate analysis.',
                      source: 'Better Bites Analysis System',
                    )
                  ],
                  createdAt: timestamp ?? DateTime.now(),
                );

                // Save to database
                final savedId = await foodAnalysisRepo.create(nonFoodAnalysis);
                final savedAnalysis =
                    await foodAnalysisRepo.getFoodAnalysis(savedId);

                onAnalysisComplete(savedAnalysis);
                return;
              }
            }
          }
        } catch (e) {
          debugPrint('Error in non-food detection: $e');
          // Continue with normal analysis if detection fails
        }
      }

      // Read the image file as bytes
      final bytes = await imageFile.readAsBytes();

      // Save image to app directory for persistence
      final appDir = await getApplicationDocumentsDirectory();
      final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
      final savedImagePath = path.join(appDir.path, fileName);
      await File(savedImagePath).writeAsBytes(bytes);

      // Extract health conditions from user profile - handle both string and list formats
      List<String> healthConditions = [];
      final healthConditionsData = userProfile['health_conditions'];
      if (healthConditionsData is List) {
        healthConditions = List<String>.from(healthConditionsData);
      } else if (healthConditionsData is String) {
        // If it's a comma-separated string, split it
        if (healthConditionsData.contains(',')) {
          healthConditions =
              healthConditionsData.split(',').map((e) => e.trim()).toList();
        } else if (healthConditionsData.isNotEmpty) {
          // If it's a single condition as string
          healthConditions = [healthConditionsData];
        }
      }

      // Create a prompt for food analysis
      final prompt = '''
You are a nutritional expert analyzing food ingredient labels for the Better Bites app.

USER PROFILE:
- Age: ${userProfile['age']}
- Sex: ${userProfile['sex']}
- Height: ${userProfile['height']} cm
- Weight: ${userProfile['weight']} kg
- Health Conditions: ${healthConditions.isEmpty ? 'None' : healthConditions.join(', ')}

TASK:
Analyze the following ingredient list from a food package. The text was extracted from an image using OCR, so there might be some errors. Identify any volume or quantity information (e.g., %, g, mg, ml) for each ingredient where available.

INGREDIENT TEXT:
$ingredientText

Provide a comprehensive analysis in JSON format with these sections:
1. A title for this food item (infer from ingredients)
2. Ingredient analysis (identify key ingredients, their health impacts, and their quantities)
3. Allergens (identify potential allergens based on the ingredients)
4. Health tips (provide personalized recommendations based on the user profile)

Format your response ONLY as a valid JSON object with this structure:
{
  "title": "Ingredient Analysis",
  "ingredients_analysis": [
    {
      "name": "Ingredient Name",
      "volume": "Quantity of the ingredient (e.g., '5g', '10%', '20mg', '15ml', or 'N/A' if not specified)",
      "impact": "Health impact description specifically tailored to this ingredient, its quantity, and the user's health conditions",
      "consumption_guidance": "Personalized guidance on consumption based on the ingredient's quantity and the user's profile",
      "alternatives": "Healthier alternatives specifically relevant to this ingredient, its quantity, and user's health needs",
      "source": "Specific and relevant source for this information"
    }
  ],
  "allergens": [
    {
      "name": "Allergen Name",
      "description": "Detailed description of what this allergen is",
      "impact": "Specific health impact of this allergen, especially considering the user's health conditions",
      "potential_reaction": "Detailed description of potential reactions specific to this allergen",
      "source": "Specific and relevant source for this information"
    }
  ],
  "health_tips": [
    {
      "name": "Tip Title",
      "description": "Detailed description tailored to the user's profile",
      "suggestion": "Actionable suggestion personalized for the user",
      "source": "Specific and relevant source for this information"
    }
  ]
}

IMPORTANT CLASSIFICATION GUIDELINES:
- For each ingredient, provide detailed health impacts that specifically mention if the ingredient should be limited or avoided based on its quantity
- Make sure to classify at least 30% of ingredients with concerning health impacts (e.g., using keywords like harmful, avoid, caution, negative, adverse, unhealthy, dangerous, toxic, risk, limit, excessive, problematic, concern, warning) to provide balanced information
- For ingredients with concerning health impacts, always provide specific alternatives
- Common ingredients that may have concerning health impacts include: added sugars, high fructose corn syrup, trans fats, artificial colors/flavors, MSG, sodium nitrate/nitrite, partially hydrogenated oils
- If an ingredient has both positive and negative effects, clearly state the concerns in the impact field
- When volume is available (e.g., '5g of sugar'), tailor the impact and consumption guidance to reflect the specific quantity, e.g., compare to daily recommended limits
- If volume is not specified, use 'N/A' for the volume field and provide general guidance

IMPORTANT SOURCE REQUIREMENTS:
- CRITICAL: For EVERY ingredient, allergen, and health tip, provide a SPECIFIC and CREDIBLE source
- Source information MUST be detailed and specific to each item, NOT generic placeholders
- Include the full name of the organization, study, or database (e.g., "Journal of Nutrition 2023 Study on Artificial Sweeteners" instead of just "Research Study")
- When possible, include a website URL or DOI for the source (e.g., "Mayo Clinic: www.mayoclinic.org/healthy-lifestyle/nutrition-and-healthy-eating")
- Sources should be relevant to the specific claim being made about each ingredient, allergen, or health tip
- Never use generic placeholders like "Nutritional Database Reference" or "FDA, USDA"
- Each source must be included in the dedicated "source" field for each item
''';

      // Create content parts with the image and prompt
      final imagePart = DataPart('image/jpeg', bytes);
      final textPart = TextPart(prompt);
      final content = [
        Content.multi([textPart, imagePart])
      ];

      // Generate content
      final response = await model.generateContent(content);
      final responseText = response.text ?? '';

      debugPrint('Received response from Gemini');

      // Parse the JSON response
      try {
        // Extract JSON from the response text
        final jsonRegExp = RegExp(r'{[\s\S]*}');
        final match = jsonRegExp.firstMatch(responseText);

        if (match != null) {
          final jsonStr = match.group(0);
          if (jsonStr != null) {
            final Map<String, dynamic> jsonData = jsonDecode(jsonStr);

            // Create FoodAnalysis object
            final foodAnalysis = await _createFoodAnalysisFromJson(
              jsonData,
              savedImagePath,
              ingredientText,
              timestamp ?? DateTime.now(),
              userProfile,
            );

            // Save to database
            final savedId = await foodAnalysisRepo.create(foodAnalysis);
            debugPrint('Food analysis saved with ID: $savedId');

            // Get the saved analysis with the ID
            final savedAnalysis =
                await foodAnalysisRepo.getFoodAnalysis(savedId);

            // Call the callback with the result
            onAnalysisComplete(savedAnalysis);
          } else {
            throw Exception('Could not extract JSON from response');
          }
        } else {
          throw Exception('Could not extract JSON from response');
        }
      } catch (e) {
        debugPrint('Error parsing JSON: $e');
        debugPrint('Response text: $responseText');

        // Create a fallback food analysis
        final fallbackAnalysis = _createFallbackFoodAnalysis(
          savedImagePath,
          ingredientText,
          timestamp ?? DateTime.now(),
          userProfile,
        );

        // Save fallback analysis
        final savedId = await foodAnalysisRepo.create(fallbackAnalysis);
        final savedAnalysis = await foodAnalysisRepo.getFoodAnalysis(savedId);

        onAnalysisComplete(savedAnalysis);
      }
    } catch (e) {
      debugPrint('Error in analyzeFood: $e');

      // Create a fallback food analysis for error case
      final fallbackAnalysis = _createFallbackFoodAnalysis(
        '',
        ingredientText,
        timestamp ?? DateTime.now(),
        userProfile,
      );

      try {
        // Save fallback analysis
        final savedId = await foodAnalysisRepo.create(fallbackAnalysis);
        final savedAnalysis = await foodAnalysisRepo.getFoodAnalysis(savedId);
        onAnalysisComplete(savedAnalysis);
      } catch (dbError) {
        debugPrint('Error saving fallback analysis: $dbError');
        onAnalysisComplete(fallbackAnalysis);
      }
    }
  }

  // Update the reanalyzeFood method to better handle missing OCR text and preserve original food identity
  Future<FoodAnalysis> reanalyzeFood(
    String ingredientText,
    Map<String, dynamic> currentUserProfile,
    DateTime timestamp, {
    String? originalTitle,
    File? imageFile,
  }) async {
    try {
      debugPrint('Starting food reanalysis with Gemini...');
      debugPrint('Current user profile: $currentUserProfile');
      debugPrint('Ingredient text for reanalysis: $ingredientText');
      debugPrint('Original food title: $originalTitle');
      debugPrint('Image file available: ${imageFile != null}');

      // Initialize the Gemini model
      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
      );

      // Extract health conditions from user profile - handle both string and list formats
      List<String> healthConditions = [];
      final healthConditionsData = currentUserProfile['health_conditions'];
      if (healthConditionsData is List) {
        healthConditions = List<String>.from(healthConditionsData);
      } else if (healthConditionsData is String) {
        // If it's a comma-separated string, split it
        if (healthConditionsData.contains(',')) {
          healthConditions =
              healthConditionsData.split(',').map((e) => e.trim()).toList();
        } else if (healthConditionsData.isNotEmpty) {
          // If it's a single condition as string
          healthConditions = [healthConditionsData];
        }
      }

      // Check if the ingredient text is meaningful
      bool hasMinimalText = ingredientText.length > 10;

      // Save image to app directory for persistence if available
      String? savedImagePath;
      if (imageFile != null && await imageFile.exists()) {
        final bytes = await imageFile.readAsBytes();
        final appDir = await getApplicationDocumentsDirectory();
        final fileName =
            '${DateTime.now().millisecondsSinceEpoch}_reanalysis.jpg';
        savedImagePath = path.join(appDir.path, fileName);
        await File(savedImagePath).writeAsBytes(bytes);
        debugPrint('Saved image for reanalysis: $savedImagePath');
      }

      // Create a prompt for food analysis with strong emphasis on preserving the original food identity
      // and using the CURRENT user profile
      final prompt = '''
You are a nutritional expert analyzing food ingredient labels for the Better Bites app.

CURRENT USER PROFILE:
- Age: ${currentUserProfile['age']}
- Sex: ${currentUserProfile['sex']}
- Height: ${currentUserProfile['height']} cm
- Weight: ${currentUserProfile['weight']} kg
- Health Conditions: ${healthConditions.isEmpty ? 'None' : healthConditions.join(', ')}

TASK:
${originalTitle != null ? 'IMPORTANT: This is a reanalysis of "$originalTitle". You MUST maintain this food identity in your analysis.' : ''}
${hasMinimalText ? 'Analyze the following ingredient list from a food package, including any volume or quantity information (e.g., %, g, mg, ml) for each ingredient where available:' : 'Analyze a food item based on the user profile, including any volume or quantity information (e.g., %, g, mg, ml) where available:'}

${hasMinimalText ? 'INGREDIENT TEXT:\n$ingredientText' : 'Limited ingredient information available.'}

Provide a comprehensive analysis in JSON format with these sections:
1. A title for this food item ${originalTitle != null ? '(MUST use "$originalTitle" or a very similar name)' : '(infer from ingredients)'}
2. Ingredient analysis (identify key ingredients, their health impacts, and their quantities)
3. Allergens (identify potential allergens based on the ingredients)
4. Health tips (provide personalized recommendations based on the user profile)

Format your response ONLY as a valid JSON object with this structure:
{
  "title": "${originalTitle ?? 'Ingredient Analysis'} (Reanalyzed)",
  "ingredients_analysis": [
    {
      "name": "Ingredient Name",
      "volume": "Quantity of the ingredient (e.g., '5g', '10%', '20mg', '15ml', or 'N/A' if not specified)",
      "impact": "Health impact description specifically tailored to this ingredient, its quantity, and the user's CURRENT health conditions",
      "consumption_guidance": "Personalized guidance on consumption based on the ingredient's quantity and the user's CURRENT profile",
      "alternatives": "Healthier alternatives specifically relevant to this ingredient, its quantity, and user's CURRENT health needs",
      "source": "Specific and relevant source for this information"
    }
  ],
  "allergens": [
    {
      "name": "Allergen Name",
      "description": "Detailed description of what this allergen is",
      "impact": "Specific health impact of this allergen, especially considering the user's CURRENT health conditions",
      "potential_reaction": "Detailed description of potential reactions specific to this allergen",
      "source": "Specific and relevant source for this information"
    }
  ],
  "health_tips": [
    {
      "name": "Tip Title",
      "description": "Detailed description tailored to the user's CURRENT profile",
      "suggestion": "Actionable suggestion personalized for the user's CURRENT health status",
      "source": "Specific and relevant source for this information"
    }
  ]
}

IMPORTANT CLASSIFICATION GUIDELINES:
- For each ingredient, provide detailed health impacts that specifically mention if the ingredient should be limited or avoided based on its quantity
- Make sure to classify at least 30% of ingredients with concerning health impacts (e.g., using keywords like harmful, avoid, caution, negative, adverse, unhealthy, dangerous, toxic, risk, limit, excessive, problematic, concern, warning) to provide balanced information
- For ingredients with concerning health impacts, always provide specific alternatives
- Common ingredients that may have concerning health impacts include: added sugars, high fructose corn syrup, trans fats, artificial colors/flavors, MSG, sodium nitrate/nitrite, partially hydrogenated oils
- If an ingredient has both positive and negative effects, clearly state the concerns in the impact field
- When volume is available (e.g., '5g of sugar'), tailor the impact and consumption guidance to reflect the specific quantity, e.g., compare to daily recommended limits
- If volume is not specified, use 'N/A' for the volume field and provide general guidance

IMPORTANT USER PROFILE CONSIDERATIONS:
- If the user's BMI is low (underweight), focus on nutrients that can help with healthy weight gain
- If the user's BMI is high (overweight/obese), focus on ingredients that may contribute to weight issues
- If the user is female, consider specific nutritional needs like iron and calcium
- If the user is male, consider specific nutritional needs like protein and zinc
- If the user is younger, focus on growth and development nutrients
- If the user is older, consider age-related nutritional needs and potential health concerns
- Always consider the user's specific health conditions when analyzing ingredients and providing recommendations
- Be specific and detailed rather than generic in all descriptions
- CRITICAL: For EVERY ingredient, allergen, and health tip, provide a SPECIFIC and CREDIBLE source
- Source information MUST be detailed and specific to each item, NOT generic placeholders
- Include the full name of the organization, study, or database (e.g., "Journal of Nutrition 2023 Study on Artificial Sweeteners" instead of just "Research Study")
- When possible, include a website URL or DOI for the source (e.g., "Mayo Clinic: www.mayoclinic.org/healthy-lifestyle/nutrition-and-healthy-eating")
- Sources should be relevant to the specific claim being made about each ingredient, allergen, or health tip
- Never use generic placeholders like "Nutritional Database Reference" or "FDA, USDA"
- Each source must be included in the dedicated "source" field for each item
${originalTitle != null ? '\n\nCRITICAL: Your analysis MUST be about "$originalTitle". DO NOT change the food type or identity.' : ''}
''';

      // Generate content - use image if available
      late List<Content> content;
      if (imageFile != null && await imageFile.exists()) {
        final bytes = await imageFile.readAsBytes();
        final imagePart = DataPart('image/jpeg', bytes);
        final textPart = TextPart(prompt);
        content = [
          Content.multi([textPart, imagePart])
        ];
        debugPrint('Using image for reanalysis');
      } else {
        content = [Content.text(prompt)];
        debugPrint('Using text-only for reanalysis');
      }

      final response = await model.generateContent(content);
      final responseText = response.text ?? '';

      debugPrint('Received response from Gemini for reanalysis');

      // Parse the JSON response
      try {
        // Extract JSON from the response text
        final jsonRegExp = RegExp(r'{[\s\S]*}');
        final match = jsonRegExp.firstMatch(responseText);

        if (match != null) {
          final jsonStr = match.group(0);
          if (jsonStr != null) {
            final Map<String, dynamic> jsonData = jsonDecode(jsonStr);

            // Ensure the title contains the original title if provided
            if (originalTitle != null && jsonData.containsKey('title')) {
              final String currentTitle = jsonData['title'] as String;
              if (!currentTitle
                  .toLowerCase()
                  .contains(originalTitle.toLowerCase())) {
                jsonData['title'] = '$originalTitle (Reanalyzed)';
              }
            }

            // Create FoodAnalysis object
            final foodAnalysis = await _createFoodAnalysisFromJson(
              jsonData,
              savedImagePath ?? '', // Use saved image path if available
              ingredientText,
              DateTime.now(), // Use current time for reanalysis
              currentUserProfile,
            );

            // Save to database
            final savedId = await foodAnalysisRepo.create(foodAnalysis);
            debugPrint('Food reanalysis saved with ID: $savedId');

            // Get the saved analysis with the ID
            final savedAnalysis =
                await foodAnalysisRepo.getFoodAnalysis(savedId);
            return savedAnalysis;
          } else {
            throw Exception('Could not extract JSON from response');
          }
        } else {
          throw Exception('Could not extract JSON from response');
        }
      } catch (e) {
        debugPrint('Error parsing JSON in reanalysis: $e');
        debugPrint('Response text: $responseText');

        // Create a fallback food analysis
        final fallbackAnalysis = _createFallbackFoodAnalysis(
          savedImagePath ?? '', // Use saved image path if available
          ingredientText,
          DateTime.now(), // Use current time for reanalysis
          currentUserProfile,
          originalTitle: originalTitle,
        );

        // Save fallback analysis
        final savedId = await foodAnalysisRepo.create(fallbackAnalysis);
        final savedAnalysis = await foodAnalysisRepo.getFoodAnalysis(savedId);
        return savedAnalysis;
      }
    } catch (e) {
      debugPrint('Error in reanalyzeFood: $e');

      // Create a fallback food analysis for error case
      final fallbackAnalysis = _createFallbackFoodAnalysis(
        '',
        ingredientText,
        DateTime.now(),
        currentUserProfile,
        originalTitle: originalTitle,
      );

      try {
        // Save fallback analysis
        final savedId = await foodAnalysisRepo.create(fallbackAnalysis);
        return await foodAnalysisRepo.getFoodAnalysis(savedId);
      } catch (dbError) {
        debugPrint('Error saving fallback analysis: $dbError');
        return fallbackAnalysis;
      }
    }
  }

  // Method to generate allergen impact using Gemini
  Future<String> _generateAllergenImpactWithGemini(
      String allergenName, Map<String, dynamic> userProfile) async {
    try {
      // Extract health conditions from user profile - handle both string and list formats
      List<String> healthConditions = [];
      final healthConditionsData = userProfile['health_conditions'];
      if (healthConditionsData is List) {
        healthConditions = List<String>.from(healthConditionsData);
      } else if (healthConditionsData is String) {
        // If it's a comma-separated string, split it
        if (healthConditionsData.contains(',')) {
          healthConditions =
              healthConditionsData.split(',').map((e) => e.trim()).toList();
        } else if (healthConditionsData.isNotEmpty) {
          // If it's a single condition as string
          healthConditions = [healthConditionsData];
        }
      }

      // Initialize the Gemini model
      final model = GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
      );

      // Create a prompt specifically for allergen impact
      final prompt = '''
You are a nutritional expert providing information about allergens for the Better Bites app.

USER PROFILE:
- Age: ${userProfile['age']}
- Sex: ${userProfile['sex']}
- Height: ${userProfile['height']} cm
- Weight: ${userProfile['weight']} kg
- Health Conditions: ${healthConditions.isEmpty ? 'None' : healthConditions.join(', ')}

TASK:
Provide a detailed and specific health impact description for the allergen "$allergenName", considering the user's health profile.

Your response should:
- Be factual and evidence-based
- Be specific to this particular allergen, not generic
- Consider how this allergen might specifically affect someone with the user's health conditions
- Be 1-3 sentences long
- Focus only on the health impact, not on recommendations or reactions
- Include words like "caution", "avoid", or "risk" to clearly indicate this is an allergen to be careful with

RESPOND WITH THE IMPACT DESCRIPTION TEXT ONLY, NO ADDITIONAL FORMATTING OR EXPLANATIONS.
''';

      // Generate content
      final response = await model.generateContent([Content.text(prompt)]);
      final impactText = response.text?.trim() ?? '';

      if (impactText.isNotEmpty) {
        return impactText;
      } else {
        throw Exception('Empty response from Gemini');
      }
    } catch (e) {
      debugPrint('Error generating allergen impact with Gemini: $e');
      // Fall back to the basic impact generation
      return _generateBasicAllergenImpact(allergenName, userProfile);
    }
  }

  // Fallback method for generating basic allergen impact
  String _generateBasicAllergenImpact(
      String allergenName, Map<String, dynamic>? userProfile) {
    // Extract health conditions if available
    List<String> healthConditions = [];
    if (userProfile != null && userProfile['health_conditions'] != null) {
      final healthConditionsData = userProfile['health_conditions'];
      if (healthConditionsData is List) {
        healthConditions = List<String>.from(healthConditionsData);
      } else if (healthConditionsData is String) {
        // If it's a comma-separated string, split it
        if (healthConditionsData.contains(',')) {
          healthConditions =
              healthConditionsData.split(',').map((e) => e.trim()).toList();
        } else if (healthConditionsData.isNotEmpty) {
          // If it's a single condition as string
          healthConditions = [healthConditionsData];
        }
      }
    }

    // Extract BMI information if available
    double? bmi;
    String bmiCategory = '';
    if (userProfile != null &&
        userProfile['height'] != null &&
        userProfile['weight'] != null) {
      try {
        double height =
            double.parse(userProfile['height'].toString()) / 100; // cm to m
        double weight = double.parse(userProfile['weight'].toString());
        bmi = weight / (height * height);

        if (bmi < 18.5) {
          bmiCategory = 'underweight';
        } else if (bmi >= 18.5 && bmi < 25) {
          bmiCategory = 'normal weight';
        } else if (bmi >= 25 && bmi < 30) {
          bmiCategory = 'overweight';
        } else {
          bmiCategory = 'obese';
        }
      } catch (e) {
        debugPrint('Error calculating BMI: $e');
      }
    }

    // Extract age and sex information
    int? age;
    String? sex;
    if (userProfile != null) {
      try {
        if (userProfile['age'] != null) {
          age = int.parse(userProfile['age'].toString());
        }
        if (userProfile['sex'] != null) {
          sex = userProfile['sex'].toString().toLowerCase();
        }
      } catch (e) {
        debugPrint('Error extracting age/sex: $e');
      }
    }

    // Normalize allergen name for comparison
    final String normalizedName = allergenName.toLowerCase();

    // Check for common allergens and provide specific impacts
    if (normalizedName.contains('gluten') || normalizedName.contains('wheat')) {
      if (healthConditions.any((condition) =>
          condition.toLowerCase().contains('celiac') ||
          condition.toLowerCase().contains('gluten'))) {
        return 'Gluten can trigger severe autoimmune responses in people with celiac disease, causing intestinal damage and nutrient malabsorption. Caution: This allergen should be strictly avoided.';
      }

      if (bmiCategory == 'underweight') {
        return 'Gluten may cause digestive discomfort and inflammation in sensitive individuals, which could further impact your ability to maintain a healthy weight. Warning: Consider limiting consumption if you experience symptoms.';
      }

      return 'Gluten may cause digestive discomfort, bloating, and inflammation in sensitive individuals, even without celiac disease. Warning: Consider limiting consumption if you experience symptoms.';
    }

    if (normalizedName.contains('dairy') ||
        normalizedName.contains('milk') ||
        normalizedName.contains('lactose')) {
      if (healthConditions
          .any((condition) => condition.toLowerCase().contains('lactose'))) {
        return 'Dairy products contain lactose which cannot be properly digested by people with lactose intolerance, leading to digestive discomfort, bloating, and diarrhea. Caution: This allergen should be avoided or consumed with lactase supplements.';
      }

      if (sex == 'female' && (age == null || age > 40)) {
        return 'While dairy can be a good source of calcium for bone health, it may cause digestive issues, inflammation, and mucus production in sensitive individuals. Warning: Consider alternative calcium sources if you experience symptoms.';
      }

      return 'Dairy products may cause digestive issues, inflammation, and mucus production in sensitive individuals. Warning: Consider limiting consumption if you experience symptoms.';
    }

    if (normalizedName.contains('nut') ||
        normalizedName.contains('peanut') ||
        normalizedName.contains('almond') ||
        normalizedName.contains('cashew')) {
      if (bmiCategory == 'underweight') {
        return 'Nut allergies can cause severe reactions including anaphylaxis, which can be life-threatening. Warning: Even small amounts can trigger reactions in highly sensitive individuals. While nuts are calorie-dense foods that could help with weight gain, they must be avoided if you have a known nut allergy.';
      }

      return 'Nut allergies can cause severe reactions including anaphylaxis, which can be life-threatening. Warning: Even small amounts can trigger reactions in highly sensitive individuals. Avoid completely if you have a known nut allergy.';
    }

    if (normalizedName.contains('soy')) {
      if (sex == 'female' &&
          healthConditions.any((condition) =>
              condition.toLowerCase().contains('thyroid') ||
              condition.toLowerCase().contains('hormone'))) {
        return 'Soy allergies can cause skin reactions, digestive issues, and in rare cases, anaphylaxis. Caution: Soy contains phytoestrogens that may interact with hormonal conditions. Consider limiting consumption, especially with your specific health profile.';
      }

      return 'Soy allergies can cause skin reactions, digestive issues, and in rare cases, anaphylaxis. Caution: Soy is also a common endocrine disruptor that may affect hormone balance. Consider limiting consumption.';
    }

    if (normalizedName.contains('egg')) {
      if (bmiCategory == 'underweight' || bmiCategory == 'normal weight') {
        return 'Egg allergies can cause skin reactions like hives, digestive problems, and respiratory symptoms. Warning: In severe cases, it may lead to anaphylaxis. While eggs are a good protein source that could support healthy weight, they must be avoided if you have a known egg allergy.';
      }

      return 'Egg allergies can cause skin reactions like hives, digestive problems, and respiratory symptoms. Warning: In severe cases, it may lead to anaphylaxis. Avoid if you have a known egg allergy.';
    }

    if (normalizedName.contains('fish') ||
        normalizedName.contains('shellfish') ||
        normalizedName.contains('seafood')) {
      if (healthConditions.any((condition) =>
          condition.toLowerCase().contains('heart') ||
          condition.toLowerCase().contains('cholesterol'))) {
        return 'Seafood allergies are often severe and can cause rapid-onset symptoms including skin reactions, digestive issues, and potentially life-threatening anaphylaxis. Warning: While seafood can be heart-healthy for many people, it must be avoided completely if you have a known seafood allergy.';
      }

      return 'Seafood allergies are often severe and can cause rapid-onset symptoms including skin reactions, digestive issues, and potentially life-threatening anaphylaxis. Warning: Avoid completely if you have a known seafood allergy.';
    }

    if (normalizedName.contains('sulfite') ||
        normalizedName.contains('sulphite')) {
      if (healthConditions.any((condition) =>
          condition.toLowerCase().contains('asthma') ||
          condition.toLowerCase().contains('respiratory'))) {
        return 'Sulfites can trigger asthma attacks and other respiratory symptoms in sensitive individuals, particularly with your respiratory condition. Caution: This additive should be strictly avoided given your health profile.';
      }

      return 'Sulfites can trigger asthma attacks and other respiratory symptoms in sensitive individuals, particularly those with asthma or sulfite sensitivity. Caution: This additive should be avoided by those with respiratory conditions.';
    }

    // For any other allergen, provide a specific but general response
    // Customize based on available user profile data
    if (bmiCategory.isNotEmpty) {
      return 'This allergen may cause adverse reactions including digestive discomfort, skin reactions, or respiratory symptoms in sensitive individuals. Caution: The severity depends on individual sensitivity levels. Given your ${bmiCategory} status, consider how this might affect your overall health goals.';
    }

    if (healthConditions.isNotEmpty) {
      return 'This allergen may cause adverse reactions including digestive discomfort, skin reactions, or respiratory symptoms in sensitive individuals. Caution: With your specific health conditions, it\'s important to monitor how this allergen affects you personally.';
    }

    return 'This allergen may cause adverse reactions including digestive discomfort, skin reactions, or respiratory symptoms in sensitive individuals. Caution: The severity depends on individual sensitivity levels. Consider limiting consumption if you experience symptoms.';
  }

  // Update the _createFoodAnalysisFromJson method to include volume in the name field
  Future<FoodAnalysis> _createFoodAnalysisFromJson(
    Map<String, dynamic> jsonData,
    String imagePath,
    String recognizedText,
    DateTime timestamp,
    Map<String, dynamic>? userProfile,
  ) async {
    // Helper to calculate BMI and BMI category
    String bmiCategory = '';
    double? bmi;
    if (userProfile != null &&
        userProfile['height'] != null &&
        userProfile['weight'] != null) {
      try {
        double height =
            double.parse(userProfile['height'].toString()) / 100; // cm to m
        double weight = double.parse(userProfile['weight'].toString());
        bmi = weight / (height * height);

        if (bmi < 18.5) {
          bmiCategory = 'underweight';
        } else if (bmi >= 18.5 && bmi < 25) {
          bmiCategory = 'normal';
        } else if (bmi >= 25 && bmi < 30) {
          bmiCategory = 'overweight';
        } else {
          bmiCategory = 'obese';
        }
      } catch (e) {
        debugPrint('Error calculating BMI: $e');
      }
    }

    // Extract age and sex
    int? age;
    String? sex;
    if (userProfile != null) {
      try {
        if (userProfile['age'] != null) {
          age = int.parse(userProfile['age'].toString());
        }
        if (userProfile['sex'] != null) {
          sex = userProfile['sex'].toString().toLowerCase();
        }
      } catch (e) {
        debugPrint('Error extracting age/sex: $e');
      }
    }

    // Extract health conditions
    List<String> healthConditions = [];
    if (userProfile != null && userProfile['health_conditions'] != null) {
      final healthConditionsData = userProfile['health_conditions'];
      if (healthConditionsData is List) {
        healthConditions = List<String>.from(healthConditionsData);
      } else if (healthConditionsData is String) {
        if (healthConditionsData.contains(',')) {
          healthConditions =
              healthConditionsData.split(',').map((e) => e.trim()).toList();
        } else if (healthConditionsData.isNotEmpty) {
          healthConditions = [healthConditionsData];
        }
      }
    }

    // Parse ingredients analysis
    final ingredientsAnalysisList =
        (jsonData['ingredients_analysis'] as List<dynamic>? ?? []).map((item) {
      // Extract name and volume from JSON
      final String baseName = item['name'] ?? 'Unknown Ingredient';
      final String? volume = item['volume']?.toString();

      // Combine name and volume if volume exists and is not 'N/A'
      final String displayName = (volume != null && volume != 'N/A')
          ? '$baseName ($volume)'
          : baseName;

      // Normalize ingredient name for comparison
      final String normalizedName = baseName.toLowerCase();

      // Get the original consumption guidance or provide a default
      String originalGuidance = item['consumption_guidance'] ??
          'Consume in moderation as part of a balanced diet.';

      // Initialize the consumption guidance with the original guidance
      String consumptionGuidance = originalGuidance;

      // Parse the volume if available and extract numeric value and unit
      double? volumeValue;
      String? unit;
      if (volume != null && volume != 'N/A') {
        final volumeMatch =
            RegExp(r'(\d*\.?\d+)\s*(g|mg|ml|%)').firstMatch(volume);
        if (volumeMatch != null) {
          volumeValue = double.tryParse(volumeMatch.group(1) ?? '');
          unit = volumeMatch.group(2);
        }
      }

      // Tailor consumption guidance based on ingredient, volume, and user profile
      if (normalizedName.contains('sugar') ||
          normalizedName.contains('high fructose corn syrup')) {
        if (volumeValue != null && unit == 'g') {
          // WHO recommends less than 50g of added sugars per day (10% of 2000 calories), ideally below 25g
          if (volumeValue > 25) {
            consumptionGuidance =
                'This contains $volume of added sugars, exceeding the WHO ideal limit of 25g per day. Limit intake to less than one serving daily.';
          } else if (volumeValue > 10) {
            consumptionGuidance =
                'This contains $volume of added sugars, approaching the WHO ideal limit of 25g per day. Limit to 1-2 servings daily to stay within recommendations.';
          } else {
            consumptionGuidance =
                'This contains $volume of added sugars, which is moderate. You can consume up to 2-3 servings daily while staying within WHO guidelines of 25-50g per day.';
          }

          // Adjust based on user profile
          if (bmiCategory == 'overweight' || bmiCategory == 'obese') {
            consumptionGuidance +=
                ' Given your weight, further reduce intake to support weight management.';
          } else if (healthConditions.any(
              (condition) => condition.toLowerCase().contains('diabetes'))) {
            consumptionGuidance +=
                ' With diabetes, strictly limit to less than 1 serving daily to manage blood sugar levels.';
          }
        } else {
          consumptionGuidance =
              'Added sugars should be limited to less than 10% of daily calories (about 50g for a 2000-calorie diet). Consume sparingly, ideally less than 1 serving daily.';
          if (bmiCategory == 'overweight' || bmiCategory == 'obese') {
            consumptionGuidance +=
                ' Given your weight, prefer minimal intake to support weight management.';
          }
        }
      } else if (normalizedName.contains('trans fat') ||
          normalizedName.contains('partially hydrogenated')) {
        // WHO recommends trans fats be less than 1% of total energy intake (<2g for 2000 calories)
        if (volumeValue != null && unit == 'g') {
          if (volumeValue > 0) {
            consumptionGuidance =
                'This contains $volume of trans fats, which should be avoided as even small amounts are harmful. Do not consume this product.';
          }
        } else {
          consumptionGuidance =
              'Trans fats should be avoided entirely due to their harmful effects on heart health. Do not consume products containing trans fats.';
        }
        if (healthConditions.any((condition) =>
            condition.toLowerCase().contains('heart') ||
            condition.toLowerCase().contains('cholesterol'))) {
          consumptionGuidance +=
              ' With your heart condition, it’s critical to avoid trans fats completely.';
        }
      } else if (normalizedName.contains('sodium') ||
          normalizedName.contains('salt')) {
        // WHO recommends less than 2000mg of sodium per day
        if (volumeValue != null && unit == 'mg') {
          if (volumeValue > 1000) {
            consumptionGuidance =
                'This contains $volume of sodium, over half the WHO daily limit of 2000mg. Limit to less than 1 serving daily.';
          } else if (volumeValue > 400) {
            consumptionGuidance =
                'This contains $volume of sodium, a significant amount. Limit to 1-2 servings daily to stay within the WHO guideline of 2000mg.';
          } else {
            consumptionGuidance =
                'This contains $volume of sodium, which is moderate. You can consume 2-3 servings daily while staying within WHO guidelines.';
          }

          if (healthConditions.any((condition) =>
              condition.toLowerCase().contains('hypertension') ||
              condition.toLowerCase().contains('heart'))) {
            consumptionGuidance +=
                ' With your condition, aim for less than 1500mg daily, so reduce intake further.';
          }
        } else {
          consumptionGuidance =
              'Sodium should be limited to less than 2000mg per day. Consume sparingly, ideally less than 2 servings daily.';
          if (healthConditions.any((condition) =>
              condition.toLowerCase().contains('hypertension'))) {
            consumptionGuidance +=
                ' With hypertension, aim for less than 1500mg daily, so limit to 1 serving.';
          }
        }
      } else if (normalizedName.contains('protein')) {
        // General protein recommendation: 0.8g per kg body weight per day
        double? dailyProteinNeed;
        if (userProfile != null && userProfile['weight'] != null) {
          try {
            double weight = double.parse(userProfile['weight'].toString());
            dailyProteinNeed = weight * 0.8; // grams per day
          } catch (e) {
            debugPrint('Error calculating protein need: $e');
          }
        }

        if (volumeValue != null && unit == 'g' && dailyProteinNeed != null) {
          double servingsToMeetHalf = (dailyProteinNeed / 2) / volumeValue;
          consumptionGuidance =
              'This contains $volume of protein, beneficial for muscle health. Consume about ${servingsToMeetHalf.toStringAsFixed(1)} servings to meet roughly half your daily need of ${dailyProteinNeed.toStringAsFixed(1)}g.';
          if (sex == 'male') {
            consumptionGuidance +=
                ' As a male, you may benefit from slightly higher protein intake (up to 1.2g/kg) for muscle maintenance.';
          } else if (bmiCategory == 'underweight') {
            consumptionGuidance +=
                ' Given your underweight status, increase intake to support healthy weight gain.';
          }
        } else {
          consumptionGuidance =
              'Protein is essential for muscle health; aim for 0.8g per kg of body weight daily. Include 1-2 servings of protein-rich foods in your meals.';
        }
      } else if (normalizedName.contains('calcium')) {
        // Recommended calcium intake: 1000mg per day for adults, 1200mg for women over 50 and men over 70
        int dailyCalciumNeed = (sex == 'female' && age != null && age > 50) ||
                (sex == 'male' && age != null && age > 70)
            ? 1200
            : 1000;

        if (volumeValue != null && unit == 'mg') {
          double servingsForHalf = (dailyCalciumNeed / 2) / volumeValue;
          consumptionGuidance =
              'This contains $volume of calcium, important for bone health. Consume about ${servingsForHalf.toStringAsFixed(1)} servings to meet roughly half your daily need of ${dailyCalciumNeed}mg.';
          if (sex == 'female') {
            consumptionGuidance +=
                ' As a female, ensure adequate calcium intake to support bone health, especially if over 50.';
          }
        } else {
          consumptionGuidance =
              'Calcium is vital for bone health; aim for 1000-1200mg daily. Include 1-2 servings of calcium-rich foods in your diet.';
        }
      } else if (normalizedName.contains('iron')) {
        // Recommended iron intake: 8mg for men, 18mg for women (19-50 years), 8mg for women over 50
        int dailyIronNeed =
            (sex == 'female' && age != null && age >= 19 && age <= 50) ? 18 : 8;

        if (volumeValue != null && unit == 'mg') {
          double servingsForHalf = (dailyIronNeed / 2) / volumeValue;
          consumptionGuidance =
              'This contains $volume of iron, crucial for blood health. Consume about ${servingsForHalf.toStringAsFixed(1)} servings to meet roughly half your daily need of ${dailyIronNeed}mg.';
          if (sex == 'female' && age != null && age <= 50) {
            consumptionGuidance +=
                ' As a female under 50, your iron needs are higher due to menstruation.';
          }
        } else {
          consumptionGuidance =
              'Iron is essential for blood health; aim for 8-18mg daily depending on age and sex. Include 1-2 servings of iron-rich foods in your diet.';
        }
      } else if (normalizedName.contains('fiber')) {
        // Recommended fiber intake: 25g for women, 38g for men
        int dailyFiberNeed = sex == 'female' ? 25 : 38;

        if (volumeValue != null && unit == 'g') {
          double servingsForHalf = (dailyFiberNeed / 2) / volumeValue;
          consumptionGuidance =
              'This contains $volume of fiber, beneficial for digestion. Consume about ${servingsForHalf.toStringAsFixed(1)} servings to meet roughly half your daily need of ${dailyFiberNeed}g.';
          if (bmiCategory == 'overweight' || bmiCategory == 'obese') {
            consumptionGuidance +=
                ' Given your weight, increasing fiber intake can aid in weight management.';
          }
        } else {
          consumptionGuidance =
              'Fiber supports digestion; aim for 25-38g daily depending on sex. Include 1-2 servings of fiber-rich foods in your meals.';
        }
      } else if (normalizedName.contains('msg') ||
          normalizedName.contains('monosodium glutamate')) {
        if (healthConditions.any((condition) =>
            condition.toLowerCase().contains('migraine') ||
            condition.toLowerCase().contains('headache'))) {
          consumptionGuidance =
              'MSG may trigger migraines in sensitive individuals. Avoid consumption, especially with your condition.';
        } else {
          consumptionGuidance =
              'MSG may cause reactions in sensitive individuals; limit to less than 1 serving daily and monitor for symptoms like headaches.';
        }
      } else if (normalizedName.contains('artificial') &&
          (normalizedName.contains('color') ||
              normalizedName.contains('flavor'))) {
        consumptionGuidance =
            'Artificial colors/flavors may cause hyperactivity or allergic reactions. Limit to less than 1 serving daily, especially for children or those with sensitivities.';
        if (age != null && age < 18) {
          consumptionGuidance +=
              ' As a younger individual, minimize intake to reduce potential behavioral impacts.';
        }
      } else {
        // Generic guidance if specific ingredient isn't matched
        if (volume != null && volume != 'N/A') {
          consumptionGuidance =
              '$originalGuidance A serving containing $volume can be consumed 1-2 times daily as part of a balanced diet.';
        } else {
          consumptionGuidance =
              '$originalGuidance Generally, consume 1-2 servings daily as part of a balanced diet.';
        }
      }

      return IngredientAnalysis(
        name: displayName,
        impact: item['impact'] ??
            'This ingredient has no specific known health impacts based on current nutritional research.',
        consumptionGuidance: consumptionGuidance,
        alternatives: item['alternatives'] ??
            'No specific alternatives identified for this ingredient.',
        source: item['source'] != null && item['source'] != ''
            ? item['source']
            : 'Not provided by analysis system',
      );
    }).toList();

    // If no ingredients were found, add a default one
    if (ingredientsAnalysisList.isEmpty) {
      ingredientsAnalysisList.add(
        IngredientAnalysis(
          name: 'Ingredients Not Identified',
          impact:
              'Unable to determine specific health impacts without identified ingredients.',
          consumptionGuidance:
              'Consider consulting the product packaging or manufacturer for detailed ingredient information. Generally, limit to 1 serving until more information is available.',
          alternatives:
              'Consider whole foods with clearly labeled ingredients as alternatives.',
          source: 'Not provided by analysis system',
        ),
      );

      // Add some common unhealthy ingredients to ensure we have ingredients with concerning health impacts
      ingredientsAnalysisList.add(
        IngredientAnalysis(
          name: 'Added Sugars',
          impact:
              'Added sugars provide empty calories and can contribute to weight gain, inflammation, and increased risk of chronic diseases. Warning: Excessive consumption should be avoided.',
          consumptionGuidance:
              'Limit consumption of added sugars to less than 10% of daily caloric intake, ideally under 25g per day. Consume less than 1 serving daily.',
          alternatives:
              'Natural sweeteners like stevia, monk fruit, or small amounts of honey or maple syrup can be used as alternatives.',
          source: 'American Heart Association Dietary Guidelines',
        ),
      );

      ingredientsAnalysisList.add(
        IngredientAnalysis(
          name: 'Artificial Preservatives',
          impact:
              'Artificial preservatives may cause allergic reactions and have been linked to hyperactivity in some individuals. Caution: These additives should be limited in your diet.',
          consumptionGuidance:
              'Minimize consumption of foods with artificial preservatives to less than 1 serving daily, especially if you have sensitivities.',
          alternatives:
              'Look for products preserved with natural ingredients like vitamin E, rosemary extract, or citric acid.',
          source:
              'Center for Science in the Public Interest Food Additives Database',
        ),
      );
    }

    // Parse allergens
    final allergensList = <Allergen>[];

    // Process each allergen
    for (var item in (jsonData['allergens'] as List<dynamic>? ?? [])) {
      final allergenName = item['name'] ?? 'Unknown Allergen';
      final allergenDescription = item['description'] ??
          'This is a potential allergen found in the product.';

      // Check if the impact is missing or generic
      String allergenImpact = item['impact'] ?? '';
      if (allergenImpact.isEmpty ||
          allergenImpact ==
              'May cause adverse reactions in sensitive individuals.') {
        // Generate impact using Gemini if possible
        if (userProfile != null) {
          try {
            allergenImpact = await _generateAllergenImpactWithGemini(
                allergenName, userProfile);
          } catch (e) {
            debugPrint('Error generating allergen impact: $e');
            allergenImpact =
                _generateBasicAllergenImpact(allergenName, userProfile);
          }
        } else {
          allergenImpact = _generateBasicAllergenImpact(allergenName, null);
        }
      }

      allergensList.add(Allergen(
        name: allergenName,
        description: allergenDescription,
        impact: allergenImpact,
        potentialReaction: item['potential_reaction'] ??
            'Reactions vary by individual. Consult a healthcare professional if you have known allergies.',
        source: item['source'] != null && item['source'] != ''
            ? item['source']
            : 'Not provided by analysis system',
      ));
    }

    // If no allergens were found, add a default one
    if (allergensList.isEmpty) {
      allergensList.add(
        Allergen(
          name: 'Allergens Not Identified',
          description:
              'No specific allergens were identified in the provided information.',
          impact:
              'Without identified allergens, we cannot determine specific health impacts.',
          potentialReaction:
              'If you have known allergies, please check the product packaging or contact the manufacturer for detailed allergen information.',
          source: 'Not provided by analysis system',
        ),
      );

      // Add common allergens to ensure we have some data
      allergensList.add(
        Allergen(
          name: 'Potential Gluten',
          description:
              'Gluten is a protein found in wheat, barley, and rye that can cause adverse reactions in sensitive individuals.',
          impact:
              'Gluten can trigger digestive issues, inflammation, and autoimmune responses in sensitive individuals. Caution: Those with celiac disease or gluten sensitivity should avoid gluten-containing products.',
          potentialReaction:
              'Reactions to gluten can include digestive discomfort, bloating, diarrhea, fatigue, and in celiac disease, intestinal damage.',
          source: 'Celiac Disease Foundation',
        ),
      );

      allergensList.add(
        Allergen(
          name: 'Potential Dairy',
          description:
              'Dairy products contain proteins and lactose that can cause adverse reactions in sensitive individuals.',
          impact:
              'Dairy can cause digestive issues, inflammation, and allergic reactions in sensitive individuals. Warning: Those with lactose intolerance or milk allergies should limit or avoid dairy products.',
          potentialReaction:
              'Reactions to dairy can include digestive discomfort, bloating, diarrhea, skin rashes, and respiratory symptoms.',
          source: 'American Academy of Allergy, Asthma & Immunology',
        ),
      );
    }

    // Parse health tips
    final healthTipsList = (jsonData['health_tips'] as List<dynamic>? ?? [])
        .map((item) => HealthTip(
              name: item['name'] ?? 'Health Tip',
              description: item['description'] ??
                  'No detailed description available for this health tip.',
              suggestion: item['suggestion'] ??
                  'Consider consulting with a healthcare professional for personalized nutrition advice.',
              source: item['source'] != null && item['source'] != ''
                  ? item['source']
                  : 'Not provided by analysis system',
            ))
        .toList();

    // If no health tips were found, add a default one
    if (healthTipsList.isEmpty) {
      healthTipsList.add(
        HealthTip(
          name: 'General Nutrition Advice',
          description:
              'A balanced diet is essential for overall health and wellbeing.',
          suggestion:
              'Focus on whole foods, plenty of fruits and vegetables, lean proteins, and whole grains.',
          source: 'Dietary Guidelines for Americans 2020-2025',
        ),
      );

      // Add more health tips to ensure we have some data
      healthTipsList.add(
        HealthTip(
          name: 'Read Food Labels',
          description:
              'Understanding food labels helps you make informed choices about the products you consume.',
          suggestion:
              'Look for products with shorter ingredient lists and fewer artificial additives.',
          source: 'FDA Food Labeling Guide',
        ),
      );

      healthTipsList.add(
        HealthTip(
          name: 'Portion Control',
          description:
              'Controlling portion sizes helps maintain a healthy weight and prevents overeating.',
          suggestion:
              'Use smaller plates, measure servings, and listen to your body\'s hunger and fullness cues.',
          source: 'Academy of Nutrition and Dietetics',
        ),
      );
    }

    return FoodAnalysis(
      title: jsonData['title'] ?? 'Ingredient Analysis',
      imagePath: imagePath,
      recognizedText: recognizedText,
      ingredientsAnalysis: ingredientsAnalysisList,
      allergens: allergensList,
      healthTips: healthTipsList,
      createdAt: timestamp,
    );
  }

  FoodAnalysis _createFallbackFoodAnalysis(
    String imagePath,
    String recognizedText,
    DateTime timestamp,
    Map<String, dynamic>? userProfile, {
    String? originalTitle,
    bool hasRealData = false,
  }) {
    // Extract health conditions if available
    final List<String> healthConditions = userProfile != null
        ? List<String>.from(userProfile['health_conditions'] ?? [])
        : [];

    // Extract BMI information if available
    String bmiText = '';
    if (userProfile != null &&
        userProfile['height'] != null &&
        userProfile['weight'] != null) {
      try {
        double height =
            double.parse(userProfile['height'].toString()) / 100; // cm to m
        double weight = double.parse(userProfile['weight'].toString());
        double bmi = weight / (height * height);

        if (bmi < 18.5) {
          bmiText = 'Given your current underweight status, ';
        } else if (bmi >= 18.5 && bmi < 25) {
          bmiText = 'With your healthy weight range, ';
        } else if (bmi >= 25 && bmi < 30) {
          bmiText = 'Considering your current overweight status, ';
        } else {
          bmiText = 'Given your current weight concerns, ';
        }
      } catch (e) {
        debugPrint('Error calculating BMI: $e');
      }
    }

    // Create more personalized fallback content if we have user profile
    String healthConditionText = '';
    if (healthConditions.isNotEmpty) {
      healthConditionText =
          'Based on your health conditions (${healthConditions.join(", ")}), ';
    }

    // Use original title if provided, but don't add error suffix if we have real data
    final title = originalTitle != null
        ? hasRealData
            ? originalTitle
            : '$originalTitle (Reanalysis Error)'
        : hasRealData
            ? 'Ingredient Analysis'
            : 'Ingredient Analysis (Processing Error)';

    return FoodAnalysis(
      title: title,
      imagePath: imagePath,
      recognizedText: recognizedText,
      ingredientsAnalysis: [
        IngredientAnalysis(
          name: 'Analysis Failed',
          impact:
              'We encountered an error analyzing the ingredients. Please try again or contact support.',
          consumptionGuidance:
              '${bmiText}${healthConditionText}please consult with a healthcare professional for guidance on this product. Limit to 1 serving until more information is available.',
          alternatives:
              'Consider products with clearly labeled ingredients or whole foods as alternatives.',
          source: 'Not provided by analysis system',
        ),
        IngredientAnalysis(
          name: 'Unknown Ingredients',
          impact:
              'Without proper analysis, we cannot determine the health impact of this product.',
          consumptionGuidance:
              '${bmiText}${healthConditionText}exercise caution when consuming products with unknown ingredients. Limit to 1 serving daily until more information is available.',
          alternatives:
              'Look for similar products with transparent ingredient labeling.',
          source: 'Not provided by analysis system',
        ),
        // Add an ingredient with concerning health impact to ensure we have data for that tab
        IngredientAnalysis(
          name: 'Processed Food Additives',
          impact:
              'Processed foods often contain additives that may have negative health effects. Warning: These should be limited in your diet.',
          consumptionGuidance:
              '${bmiText}${healthConditionText}limit consumption of highly processed foods with numerous additives to less than 1 serving daily.',
          alternatives:
              'Choose whole, minimally processed foods whenever possible.',
          source: 'Not provided by analysis system',
        ),
      ],
      allergens: [
        Allergen(
          name: 'Unknown Allergens',
          description: 'Could not analyze allergens due to processing error.',
          impact:
              '${bmiText}${healthConditionText}without proper analysis, we cannot determine the health impact of potential allergens in this product. Caution: Exercise care if you have known allergies.',
          potentialReaction:
              'Please exercise caution if you have known allergies. Check the product packaging for allergen information.',
          source: 'Not provided by analysis system',
        ),
        Allergen(
          name: 'Common Food Allergens',
          description:
              'Common food allergens include nuts, dairy, eggs, wheat, soy, fish, and shellfish.',
          impact:
              '${bmiText}${healthConditionText}food allergens can cause mild to severe health effects in sensitive individuals, with reactions varying based on the specific allergen and individual sensitivity. Warning: Avoid known allergens.',
          potentialReaction:
              'Allergic reactions can range from mild (itching, hives) to severe (difficulty breathing, anaphylaxis). If you have known allergies, always check ingredient labels carefully.',
          source: 'World Allergy Organization Guidelines',
        ),
      ],
      healthTips: [
        HealthTip(
          name: 'Error Processing',
          description: 'We encountered an error analyzing this food item.',
          suggestion:
              'Please try scanning again or contact support for assistance.',
          source: 'Dietary Guidelines for Americans 2020-2025',
        ),
        HealthTip(
          name: 'Read Labels Carefully',
          description:
              '${bmiText}${healthConditionText}always read food labels carefully, especially if you have dietary restrictions or health conditions.',
          suggestion:
              'Look for clear ingredient lists and nutrition facts when choosing food products.',
          source: 'Dietary Guidelines for Americans 2020-2025',
        ),
      ],
      createdAt: timestamp,
    );
  }
}
