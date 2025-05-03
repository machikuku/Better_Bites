import 'dart:async';
import 'dart:io';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:flutter/material.dart';
import 'package:betterbitees/models/food_analysis.dart';
import 'package:betterbitees/repositories/profiling_repo.dart';
import 'package:typewritertext/typewritertext.dart';
import 'package:betterbitees/colors.dart';
import 'package:intl/intl.dart' as intl;
import 'package:betterbitees/services/food_analysis_service.dart';
import 'package:betterbitees/repositories/food_analysis_repo.dart' show FoodAnalysisRepo;
import 'package:betterbitees/screens/after_scan.dart';
import 'package:lottie/lottie.dart';
import 'package:betterbitees/models/profiling.dart';
import 'package:betterbitees/services/profiling_service.dart';
import 'package:betterbitees/screens/profile_view.dart';

class HistoryDetails extends StatefulWidget {
  final FoodAnalysis foodAnalysis;
  final String? title;

  const HistoryDetails({
    super.key,
    required this.foodAnalysis,
    this.title,
  });

  @override
  _HistoryDetailsState createState() => _HistoryDetailsState();
}

class _HistoryDetailsState extends State<HistoryDetails> {
  int _currentIndex = 0;
  late NotchBottomBarController _controller;
  Map<String, dynamic>? historicalProfile;
  Map<String, dynamic>? currentUserProfile;
  late ProfilingRepo profilingRepo;
  late ProfilingService profilingService;
  late FoodAnalysisService foodAnalysisService;
  bool isLoadingProfile = true;
  bool isReanalyzing = false;

  // BMI calculation properties
  double? _userBmi;
  String _bmiCategory = '';
  Color _bmiColor = Colors.green;

  // Loading screen properties
  int _loadingPercentage = 0;
  Timer? _loadingTimer;
  int _currentFactIndex = 0;
  Timer? _factRotationTimer;
  final List<Map<String, String>> _nutritionFacts = [
    {
      "title": "Did you know?",
      "fact": "Eating a rainbow of colorful fruits and vegetables ensures you get a wide variety of nutrients."
    },
    {
      "title": "Nutrition Tip",
      "fact": "Whole grains contain more fiber and nutrients than refined grains."
    },
    {
      "title": "Health Fact",
      "fact": "Processed foods often contain hidden sugars, sodium, and unhealthy fats."
    },
    {
      "title": "Food Safety",
      "fact": "Always wash your hands before handling food to prevent contamination."
    },
    {
      "title": "Hydration Tip",
      "fact": "Drinking water before meals can help control portion sizes and prevent overeating."
    },
    {
      "title": "Nutrient Fact",
      "fact": "Vitamin D and calcium work together to build and maintain strong bones."
    },
    {
      "title": "Healthy Eating",
      "fact": "Eating slowly helps your body recognize when it's full, preventing overeating."
    },
    {
      "title": "Food Label Tip",
      "fact": "Check ingredient lists - ingredients are listed in order of quantity from highest to lowest."
    },
    {
      "title": "Allergy Awareness",
      "fact": "The most common food allergens include milk, eggs, peanuts, tree nuts, fish, shellfish, soy, and wheat."
    },
    {
      "title": "Portion Control",
      "fact": "A serving of meat should be about the size of a deck of cards (3 oz)."
    }
  ];

  static const Color primeWithOpacity = Color(0xB30d522c);
  final ScrollController mainScrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    profilingRepo = ProfilingRepo();
    profilingService = ProfilingService(profilingRepo: profilingRepo);
    foodAnalysisService = FoodAnalysisService(
      foodAnalysisRepo: FoodAnalysisRepo(),
      profilingRepo: profilingRepo,
    );
    _loadHistoricalProfile();
    _loadCurrentUserProfile();

    _controller = NotchBottomBarController(index: _currentIndex);
  }

  Future<void> _loadHistoricalProfile() async {
    try {
      final profile = await profilingRepo.getProfileAtTimestamp(widget.foodAnalysis.createdAt);
      if (profile != null) {
        if (mounted) {
          setState(() {
            historicalProfile = profile.toJson();
            isLoadingProfile = false;
          });
          debugPrint('Historical profile loaded: $historicalProfile');

          // Calculate historical BMI
          _calculateHistoricalBmi(profile);
        }
      } else {
        if (mounted) {
          setState(() {
            historicalProfile = null;
            isLoadingProfile = false;
          });
          debugPrint('No historical profile found for timestamp: ${widget.foodAnalysis.createdAt}');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          historicalProfile = null;
          isLoadingProfile = false;
        });
        debugPrint('Error loading historical profile: $e');
      }
    }
  }

  Future<void> _loadCurrentUserProfile() async {
    try {
      final profile = await profilingService.getProfile();
      if (profile != null) {
        if (mounted) {
          setState(() {
            currentUserProfile = profile.toJson();
            isLoadingProfile = false;
          });
          debugPrint('Current user profile loaded: $currentUserProfile');
        }
      } else {
        if (mounted) {
          setState(() {
            currentUserProfile = null;
            isLoadingProfile = false;
          });
          debugPrint('No current user profile found');
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          currentUserProfile = null;
          isLoadingProfile = false;
        });
        debugPrint('Error loading current user profile: $e');
      }
    }
  }

  void _calculateHistoricalBmi(Profiling profile) {
    if (profile.height > 0 && profile.weight > 0) {
      // BMI = weight(kg) / (height(m))²
      final heightInMeters = profile.height / 100; // Convert cm to meters
      final bmi = profile.weight / (heightInMeters * heightInMeters);

      String category;
      Color color;

      // Determine BMI category and color
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

      if (mounted) {
        setState(() {
          _userBmi = bmi;
          _bmiCategory = category;
          _bmiColor = color;
        });
      }
    }
  }

  void _startLoadingAnimation() {
    // Start the percentage counter
    _loadingTimer = Timer.periodic(const Duration(milliseconds: 150), (timer) {
      if (mounted) {
        setState(() {
          if (_loadingPercentage < 95) {
            _loadingPercentage += 1;
          }
        });
      }
    });

    // Start rotating through nutrition facts
    _factRotationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (mounted) {
        setState(() {
          _currentFactIndex = (_currentFactIndex + 1) % _nutritionFacts.length;
        });
      }
    });

    // Set a timeout to ensure loading screen doesn't show indefinitely
    Future.delayed(const Duration(minutes: 2), () {
      if (mounted) {
        _stopLoadingAnimation();
        setState(() {
          isReanalyzing = false;
        });
      }
    });
  }

  void _stopLoadingAnimation() {
    _loadingTimer?.cancel();
    _factRotationTimer?.cancel();
  }

  Future<void> _reanalyzeIngredientList() async {
    try {
      // Show confirmation dialog
      final bool? confirmReanalysis = await showDialog<bool>(
        context: context,
        builder: (BuildContext context) {
          return AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.warning, color: prime),
                const SizedBox(width: 8),
                const Text(
                  'Confirm Reanalysis',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: prime,
                  ),
                ),
              ],
            ),
            content: const Text(
              'Are you sure you want to reanalyze this ingredient list with your current profile?',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                color: Colors.black87,
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'Cancel',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: prime,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text(
                  'Confirm',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: prime,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            backgroundColor: Colors.white,
            elevation: 8,
          );
        },
      );

      // If the user cancels, return early
      if (confirmReanalysis != true) return;

      // Check if we have the necessary data
      if (currentUserProfile == null) {
        // Try to refresh the current user profile
        try {
          final profile = await profilingService.getProfile();
          if (profile != null) {
            currentUserProfile = profile.toJson();
          } else {
            _showErrorSnackBar('Failed to load current user profile');
            return;
          }
        } catch (e) {
          _showErrorSnackBar('Failed to load current user profile: $e');
          return;
        }
      }

      // Get the recognized text from the food analysis
      String? recognizedText = widget.foodAnalysis.recognizedText;
      String? imagePath = widget.foodAnalysis.imagePath;
      String originalTitle = widget.foodAnalysis.title;

      // Debug the available data
      debugPrint('Reanalyzing with recognizedText: $recognizedText');
      debugPrint('Image path available: ${imagePath != null && imagePath.isNotEmpty}');
      debugPrint('Original title: $originalTitle');
      debugPrint('Current user profile: $currentUserProfile');

      // Check if we have either recognized text or an image to work with
      if ((recognizedText == null || recognizedText.isEmpty) && (imagePath == null || imagePath.isEmpty)) {
        _showErrorSnackBar('No ingredients or image available to reanalyze');
        return;
      }

      try {
        setState(() {
          isReanalyzing = true;
          _loadingPercentage = 0;
        });
        _startLoadingAnimation();

        // Ensure health_conditions is properly formatted
        Map<String, dynamic> sanitizedProfile = Map<String, dynamic>.from(currentUserProfile!);

        // Handle health_conditions specifically
        if (sanitizedProfile['health_conditions'] is String) {
          String healthCondStr = sanitizedProfile['health_conditions'] as String;
          if (healthCondStr.contains(',')) {
            sanitizedProfile['health_conditions'] = healthCondStr.split(',').map((e) => e.trim()).toList();
          } else if (healthCondStr.isNotEmpty) {
            sanitizedProfile['health_conditions'] = [healthCondStr];
          } else {
            sanitizedProfile['health_conditions'] = [];
          }
        } else if (sanitizedProfile['health_conditions'] == null) {
          sanitizedProfile['health_conditions'] = [];
        }

        // Create a comprehensive context for reanalysis
        String textToAnalyze = "IMPORTANT: This is a reanalysis of \"$originalTitle\". ";

        // Add the original recognized text if available
        if (recognizedText != null && recognizedText.isNotEmpty && recognizedText != "No OCR text available") {
          textToAnalyze += "Original ingredient text: $recognizedText\n\n";
        } else {
          textToAnalyze += "Original ingredient text not available.\n\n";
        }

        // Add detailed information about the original food analysis
        textToAnalyze += "ORIGINAL FOOD DETAILS:\n";
        textToAnalyze += "Food name: $originalTitle\n";

        // Add ingredient names and their impacts
        if (widget.foodAnalysis.ingredientsAnalysis.isNotEmpty) {
          textToAnalyze += "Ingredients:\n";
          for (var ingredient in widget.foodAnalysis.ingredientsAnalysis) {
            textToAnalyze += "- ${ingredient.name}: ${ingredient.impact}\n";
          }
        }

        // Add allergen information
        if (widget.foodAnalysis.allergens.isNotEmpty) {
          textToAnalyze += "\nAllergens:\n";
          for (var allergen in widget.foodAnalysis.allergens) {
            textToAnalyze += "- ${allergen.name}\n";
          }
        }

        // Add health tips summary
        if (widget.foodAnalysis.healthTips.isNotEmpty) {
          textToAnalyze += "\nHealth considerations:\n";
          for (var tip in widget.foodAnalysis.healthTips) {
            textToAnalyze += "- ${tip.name}\n";
          }
        }

        textToAnalyze += "\nPlease maintain the identity of this food item ($originalTitle) in your analysis.";

        debugPrint('Using enhanced text for reanalysis: $textToAnalyze');

        // Check if we have an image file to use
        File? imageFile;
        if (imagePath != null && imagePath.isNotEmpty) {
          try {
            imageFile = File(imagePath);
            if (!await imageFile.exists()) {
              debugPrint('Image file does not exist: $imagePath');
              imageFile = null;
            } else {
              debugPrint('Using image file for reanalysis: $imagePath');
            }
          } catch (e) {
            debugPrint('Error accessing image file: $e');
            imageFile = null;
          }
        }

        // Perform the reanalysis with the CURRENT user profile
        final newFoodAnalysis = await foodAnalysisService.reanalyzeFood(
          textToAnalyze,
          sanitizedProfile, // Using the current user profile
          DateTime.now(),
          originalTitle: originalTitle,
          imageFile: imageFile,
        );

        _stopLoadingAnimation();
        setState(() {
          isReanalyzing = false;
        });

        if (mounted) {
          // Navigate to AfterScan with the reanalyzed FoodAnalysis
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => AfterScan(
                foodAnalysis: newFoodAnalysis,
                timestamp: DateTime.now(), // Use current time for the reanalysis
              ),
            ),
          );
        }
      } catch (e) {
        _stopLoadingAnimation();
        setState(() {
          isReanalyzing = false;
        });
        debugPrint('Reanalysis failed: $e');
        _showErrorSnackBar('Reanalysis failed: ${e.toString()}');
      }
    } catch (e) {
      debugPrint('Error in _reanalyzeIngredientList: $e');
      _showErrorSnackBar('An unexpected error occurred: ${e.toString()}');
      setState(() {
        isReanalyzing = false;
      });
      _stopLoadingAnimation();
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          message,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
          textAlign: TextAlign.center,
        ),
        backgroundColor: Colors.red,
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    mainScrollController.dispose();
    _loadingTimer?.cancel();
    _factRotationTimer?.cancel();
    super.dispose();
  }

  String _capitalizeWords(String text) {
    if (text.isEmpty) return text;
    return text
        .split(' ')
        .map((word) => word.isEmpty
        ? word
        : word[0].toUpperCase() + word.substring(1).toLowerCase())
        .join(' ');
  }

  final Map<String, GlobalKey> sectionKeys = {
    'Ingredients': GlobalKey(),
    'Allergens': GlobalKey(),
    'Health Tips': GlobalKey(),
  };

  Map<String, dynamic> _getTitleForIndex(int index) {
    const Color prime = Color(0xFF0d522c);
    switch (index) {
      case 0:
        return {'title': 'INGREDIENTS', 'color': Colors.green.shade700};
      case 1:
        return {'title': 'ALLERGENS', 'color': Colors.red.shade700};
      case 2:
        return {'title': 'HEALTH TIPS', 'color': prime};
      default:
        return {'title': 'INGREDIENTS', 'color': Colors.green.shade700};
    }
  }

  Widget _buildBody() {
    if (isReanalyzing) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              decoration: const BoxDecoration(shape: BoxShape.circle),
              padding: const EdgeInsets.all(10.0),
              child: Lottie.asset(
                'assets/icons/loading_animation.json',
                width: 180,
                height: 180,
                fit: BoxFit.contain,
                repeat: true,
                animate: true,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: MediaQuery.of(context).size.width * 0.8,
              padding: const EdgeInsets.all(16.0),
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
                children: [
                  Text(
                    _nutritionFacts[_currentFactIndex]['title'] ?? 'Did you know?',
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: prime,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _nutritionFacts[_currentFactIndex]['fact'] ?? '',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 14,
                      color: Colors.black87,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Container(
              width: MediaQuery.of(context).size.width * 0.8,
              height: 10,
              decoration: BoxDecoration(
                color: Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Stack(
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width * 0.8 * _loadingPercentage / 100,
                    height: 10,
                    decoration: BoxDecoration(
                      color: prime,
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Reanalyzing ${widget.foodAnalysis.title} with your current profile... $_loadingPercentage%',
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: prime,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(15.0),
            child: Column(
              children: [
                Text(
                  _capitalizeWords(
                    widget.foodAnalysis.title.isNotEmpty
                        ? widget.foodAnalysis.title
                        : 'Ingredient Analysis',
                  ),
                  textAlign: TextAlign.center,
                  semanticsLabel: _capitalizeWords(widget.title ?? ''),
                  style: const TextStyle(
                    fontFamily: 'Poppins',
                    color: prime,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 9),
                Text(
                  'Scanned on: ${intl.DateFormat('yyyy-MM-dd HH:mm:ss').format(widget.foodAnalysis.createdAt.toLocal())}',
                  style: TextStyle(
                    fontFamily: 'Poppins',
                    color: primeWithOpacity,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    fontStyle: FontStyle.italic,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          // Add BMI display here
          if (_userBmi != null)
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
              padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 10.0),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(8.0),
                boxShadow: [
                  BoxShadow(
                    color: Colors.grey.withOpacity(0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.monitor_weight_outlined,
                    color: _bmiColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      'BMI: ${_userBmi!.toStringAsFixed(1)} ($_bmiCategory)',
                      style: TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: _bmiColor,
                      ),
                      overflow: TextOverflow.ellipsis,
                      maxLines: 1,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              _getTitleForIndex(_currentIndex)['title'],
              style: TextStyle(
                fontFamily: 'Poppins',
                color: _getTitleForIndex(_currentIndex)['color'],
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(child: _buildContent()),
        ],
      ),
    );
  }

  Widget _buildContent() {
    switch (_currentIndex) {
      case 0:
        return _buildIngredientsList(
            widget.foodAnalysis.ingredientsAnalysis
                .map((item) => {
              'name': item.name,
              'Impact': item.impact.isNotEmpty
                  ? item.impact
                  : 'No impact information available for this ingredient.',
              'Consumption Guidance': item.consumptionGuidance?.isNotEmpty == true
                  ? item.consumptionGuidance!
                  : 'No specific consumption guidance available for this ingredient.',
              'Alternatives': item.alternatives?.isNotEmpty == true
                  ? item.alternatives!
                  : 'No alternative options identified for this ingredient.',
              'Source': item.source ?? 'FDA, USDA, and nutritional research databases',
            })
                .toList(),
            'Consumption Guidance',
            Colors.green.shade700
        );
      case 1:
        return _buildIngredientsList(
            widget.foodAnalysis.allergens
                .map((item) => {
              'name': item.name,
              'Description': item.description.isNotEmpty
                  ? item.description
                  : 'This is a potential allergen found in the product.',
              'Impact': item.impact.isNotEmpty
                  ? item.impact
                  : 'May cause adverse reactions in sensitive individuals.',
              'Potential Reaction': item.potentialReaction?.isNotEmpty == true
                  ? item.potentialReaction!
                  : 'Reactions vary by individual. Consult a healthcare professional if you have known allergies.',
              'Source': item.source ?? 'FDA Allergen Database, WHO Guidelines',
            })
                .toList(),
            'Potential Reaction',
            Colors.red.shade700
        );
      case 2:
        return _buildHealthTips(
          widget.foodAnalysis.healthTips
              .map((item) => {
            'name': item.name,
            'Description': item.description.isNotEmpty
                ? item.description
                : 'No detailed description available for this health tip.',
            'Suggestion': item.suggestion?.isNotEmpty == true
                ? item.suggestion!
                : 'No specific suggestions available for this health tip.',
            'Source': item.source ?? 'Dietary Guidelines, Nutritional Research',
          })
              .toList(),
        );
      default:
        return _buildIngredientsList(
            widget.foodAnalysis.ingredientsAnalysis
                .map((item) => {
              'name': item.name,
              'Impact': item.impact.isNotEmpty
                  ? item.impact
                  : 'No impact information available for this ingredient.',
              'Consumption Guidance': item.consumptionGuidance?.isNotEmpty == true
                  ? item.consumptionGuidance!
                  : 'No specific consumption guidance available for this ingredient.',
              'Alternatives': item.alternatives?.isNotEmpty == true
                  ? item.alternatives!
                  : 'No alternative options identified for this ingredient.',
              'Source': item.source ?? 'FDA, USDA, and nutritional research databases',
            })
                .toList(),
            'Consumption Guidance',
            Colors.green.shade700
        );
    }
  }

  Widget _buildIngredientsList(List<Map<String, String>> items, [String? thirdField, Color? accentColor]) {
    const Color prime = Color(0xFF0d522c);
    final Color titleColor = accentColor ?? prime;

    if (items.isEmpty) {
      return Center(
        child: Text(
          'No items found.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: titleColor,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        bool isExpanded = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return GestureDetector(
              onTap: () => setState(() => isExpanded = !isExpanded),
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 6.0),
                  padding: const EdgeInsets.all(15.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 2,
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              item['name']!,
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: titleColor,
                              ),
                              textAlign: TextAlign.justify,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              color: titleColor,
                            ),
                            onPressed: () => setState(() => isExpanded = !isExpanded),
                          ),
                        ],
                      ),
                      if (isExpanded)
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TypeWriterText(
                                text: Text(
                                  'Impact:  ',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: titleColor,
                                    wordSpacing: 2,
                                  ),
                                  textAlign: TextAlign.justify,
                                ),
                                duration: const Duration(milliseconds: 1),
                                play: true,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                item['Impact'] ?? 'No impact information available.',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: titleColor,
                                ),
                                textAlign: TextAlign.justify,
                                softWrap: true,
                              ),
                              if (_currentIndex == 0) // Show Consumption Guidance for ingredients tab
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      child: TypeWriterText(
                                        text: Text(
                                          'Consumption Guidance:  ',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            fontStyle: FontStyle.italic,
                                            color: titleColor,
                                          ),
                                          textAlign: TextAlign.left,
                                          overflow: TextOverflow.visible,
                                        ),
                                        duration: const Duration(milliseconds: 1),
                                        play: true,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item['Consumption Guidance'] ?? 'No consumption guidance available.',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        fontStyle: FontStyle.italic,
                                        wordSpacing: -2,
                                        color: titleColor,
                                      ),
                                      textAlign: TextAlign.justify,
                                      softWrap: true,
                                    ),
                                  ],
                                ),
                              if (_currentIndex == 0) // Show Alternatives for ingredients tab
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 12),
                                    TypeWriterText(
                                      text: Text(
                                        'Alternatives:  ',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          fontStyle: FontStyle.italic,
                                          color: titleColor,
                                        ),
                                        textAlign: TextAlign.justify,
                                      ),
                                      duration: const Duration(milliseconds: 1),
                                      play: true,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item['Alternatives'] ?? 'No alternatives available.',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        fontStyle: FontStyle.italic,
                                        wordSpacing: -2,
                                        color: titleColor,
                                      ),
                                      textAlign: TextAlign.justify,
                                      softWrap: true,
                                    ),
                                  ],
                                ),
                              if (thirdField != null && _currentIndex > 0) // Show third field for non-ingredient tabs
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 12),
                                    Container(
                                      width: double.infinity,
                                      child: TypeWriterText(
                                        text: Text(
                                          '$thirdField:  ',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            fontWeight: FontWeight.bold,
                                            fontStyle: FontStyle.italic,
                                            color: titleColor,
                                          ),
                                          textAlign: TextAlign.left,
                                          overflow: TextOverflow.visible,
                                        ),
                                        duration: const Duration(milliseconds: 1),
                                        play: true,
                                      ),
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item[thirdField] ?? 'No information available.',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 11,
                                        fontWeight: FontWeight.w400,
                                        fontStyle: FontStyle.italic,
                                        wordSpacing: -2,
                                        color: titleColor,
                                      ),
                                      textAlign: TextAlign.justify,
                                      softWrap: true,
                                    ),
                                  ],
                                ),
                              // Add Source information
                              if (item['Source'] != null && item['Source']!.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 12),
                                    TypeWriterText(
                                      text: Text(
                                        'Source:  ',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          fontStyle: FontStyle.italic,
                                          color: titleColor.withOpacity(0.8),
                                        ),
                                        textAlign: TextAlign.justify,
                                      ),
                                      duration: const Duration(milliseconds: 1),
                                      play: true,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      item['Source']!,
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w400,
                                        fontStyle: FontStyle.italic,
                                        wordSpacing: -2,
                                        color: titleColor.withOpacity(0.8),
                                      ),
                                      textAlign: TextAlign.justify,
                                      softWrap: true,
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildHealthTips(List<Map<String, String>> healthTips) {
    const Color prime = Color(0xFF0d522c);
    if (healthTips.isEmpty) {
      return const Center(
        child: Text(
          'No health tips found.',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 16,
            color: prime,
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: healthTips.length,
      itemBuilder: (context, index) {
        final tip = healthTips[index];
        bool isExpanded = false;
        return StatefulBuilder(
          builder: (context, setState) {
            return GestureDetector(
              onTap: () {
                setState(() {
                  isExpanded = !isExpanded;
                });
              },
              child: AnimatedSize(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeInOut,
                child: Container(
                  margin: const EdgeInsets.symmetric(vertical: 5.0),
                  padding: const EdgeInsets.all(12.0),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.grey.withOpacity(0.3),
                        blurRadius: 2,
                        spreadRadius: 2,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              tip['name'] ?? 'No Name',
                              style: const TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: prime,
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 3,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isExpanded
                                  ? Icons.expand_less
                                  : Icons.expand_more,
                              color: prime,
                            ),
                            onPressed: () {
                              setState(() {
                                isExpanded = !isExpanded;
                              });
                            },
                          ),
                        ],
                      ),
                      if (isExpanded)
                        Padding(
                          padding: const EdgeInsets.only(
                              top: 8.0, left: 8.0, right: 8.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              TypeWriterText(
                                text: const Text(
                                  'Description:  ',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: prime,
                                    wordSpacing: 2,
                                  ),
                                  textAlign: TextAlign.justify,
                                ),
                                duration: const Duration(milliseconds: 1),
                                play: true,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                tip['Description'] ?? 'No description available.',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 12,
                                  fontWeight: FontWeight.w400,
                                  color: prime,
                                ),
                                textAlign: TextAlign.justify,
                                softWrap: true,
                              ),
                              const SizedBox(height: 12),
                              TypeWriterText(
                                text: const Text(
                                  'Suggestion:  ',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 11,
                                    fontWeight: FontWeight.bold,
                                    fontStyle: FontStyle.italic,
                                    color: prime,
                                  ),
                                  textAlign: TextAlign.justify,
                                ),
                                duration: const Duration(milliseconds: 1),
                                play: true,
                              ),
                              const SizedBox(height: 3),
                              Text(
                                tip['Suggestion'] ?? 'No specific suggestions available.',
                                style: const TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 11,
                                  fontWeight: FontWeight.w400,
                                  fontStyle: FontStyle.italic,
                                  wordSpacing: -2,
                                  color: prime,
                                ),
                                textAlign: TextAlign.justify,
                                softWrap: true,
                              ),
                              // Add Source information
                              if (tip['Source'] != null && tip['Source']!.isNotEmpty)
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const SizedBox(height: 12),
                                    TypeWriterText(
                                      text: const Text(
                                        'Source:  ',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          fontStyle: FontStyle.italic,
                                          color: Color(0xB30d522c),
                                        ),
                                        textAlign: TextAlign.justify,
                                      ),
                                      duration: const Duration(milliseconds: 1),
                                      play: true,
                                    ),
                                    const SizedBox(height: 3),
                                    Text(
                                      tip['Source']!,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 10,
                                        fontWeight: FontWeight.w400,
                                        fontStyle: FontStyle.italic,
                                        wordSpacing: -2,
                                        color: Color(0xB30d522c),
                                      ),
                                      textAlign: TextAlign.justify,
                                      softWrap: true,
                                    ),
                                  ],
                                ),
                              const SizedBox(height: 10),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _onPopInvoked(bool didPop, Object? result) async {
    debugPrint('Pop invoked: $didPop');
    if (didPop) return;
    final shouldPop = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        contentPadding: const EdgeInsets.all(16.0),
        title: const Text(
          'Confirm',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 17,
            fontWeight: FontWeight.bold,
            color: prime,
          ),
          textAlign: TextAlign.center,
        ),
        content: const Text(
          'Are you sure you want to go back?',
          style: TextStyle(
            fontFamily: 'Poppins',
            fontSize: 14,
            fontWeight: FontWeight.w400,
          ),
          textAlign: TextAlign.center,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text(
              'Cancel',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w400,
                color: Colors.grey,
              ),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text(
              'Confirm',
              style: TextStyle(
                fontFamily: 'Poppins',
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: prime,
              ),
            ),
          ),
        ],
      ),
    );
    if (shouldPop == true && mounted) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _onPopInvoked,
      child: Scaffold(
          backgroundColor: const Color(0xFFD6EFD8),
          appBar: AppBar(
            backgroundColor: thrd,
            automaticallyImplyLeading: false,
            title: Row(
              mainAxisAlignment: MainAxisAlignment.start,
              children: [
                Image.asset('assets/blogo.png', height: 35),
                const SizedBox(width: 10),
                const Text(
                  'BETTER BITES',
                  style: TextStyle(
                    color: prime,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    fontFamily: 'Poppins',
                  ),
                ),
              ],
            ),
            actions: [
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: prime),
                offset: const Offset(0, 40),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(4),
                ),
                color: const Color.fromARGB(76, 221, 233, 222),
                elevation: 1,
                onSelected: (String value) async {
                  if (value == 'analyze') {
                    _reanalyzeIngredientList();
                  } else if (value == 'view_profile') {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => ViewProfiling(
                          profile: historicalProfile ?? {},
                        ),
                      ),
                    );
                  }
                },
                itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                  PopupMenuItem<String>(
                    value: 'view_profile',
                    child: SizedBox(
                      width: 200,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(186, 255, 255, 255),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        child: Row(
                          children: [
                            Icon(Icons.person, color: prime, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'View Profile at Scan Time',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: prime,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  PopupMenuItem<String>(
                    value: 'analyze',
                    child: SizedBox(
                      width: 200,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(186, 255, 255, 255),
                          borderRadius: BorderRadius.circular(3),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                        child: Row(
                          children: [
                            Icon(Icons.analytics, color: prime, size: 20),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Reanalyze with Current Profile',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: prime,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          body: _buildBody(),
          bottomNavigationBar: AnimatedNotchBottomBar(
            notchBottomBarController: _controller,
            showLabel: true,
            notchColor: prime,
            durationInMilliSeconds: 300,
            itemLabelStyle: const TextStyle(
              color: prime,
              fontWeight: FontWeight.w600,
              fontSize: 9,
              fontFamily: 'Poppins',
            ),
            bottomBarWidth: 500.0,
            bottomBarHeight: 62.0,
            bottomBarItems: [
              BottomBarItem(
                inActiveItem: Icon(Icons.list_alt_outlined, color: Colors.blueGrey),
                activeItem: Icon(Icons.list_alt, color: Colors.white),
                itemLabel: 'Ingredients',
              ),
              BottomBarItem(
                inActiveItem: Icon(Icons.warning_amber_outlined, color: Colors.blueGrey),
                activeItem: Icon(Icons.warning_amber, color: Colors.white),
                itemLabel: 'Allergens',
              ),
              BottomBarItem(
                inActiveItem: Icon(Icons.health_and_safety_outlined, color: Colors.blueGrey),
                activeItem: Icon(Icons.health_and_safety, color: Colors.white),
                itemLabel: 'Health Tips',
              ),
            ],
            onTap: (index) {
              setState(() {
                _currentIndex = index;
                _controller.jumpTo(index);
              });
            },
            kIconSize: 22.0,
            kBottomRadius: 10.0,
          )
      ),
    );
  }
}
