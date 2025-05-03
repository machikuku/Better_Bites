import 'dart:io';
import 'package:animated_notch_bottom_bar/animated_notch_bottom_bar/animated_notch_bottom_bar.dart';
import 'package:betterbitees/colors.dart';
import 'package:betterbitees/models/food_analysis.dart';
import 'package:betterbitees/repositories/food_analysis_repo.dart';
import 'package:betterbitees/repositories/profiling_repo.dart';
import 'package:betterbitees/screens/edit_profiling.dart';
import 'package:betterbitees/screens/profile.dart';
import 'package:betterbitees/services/food_analysis_service.dart';
import 'package:betterbitees/services/profiling_service.dart';
import 'package:betterbitees/screens/history.dart';
import 'package:betterbitees/services/text_recognition_service.dart';
import 'package:betterbitees/screens/camera.dart';
import 'package:flutter_expandable_fab/flutter_expandable_fab.dart';
import 'package:flutter/material.dart';
import 'package:typewritertext/typewritertext.dart';
import 'package:lottie/lottie.dart';
import 'package:betterbitees/models/profiling.dart';
import 'dart:async';
import 'dart:math';

class AfterScan extends StatefulWidget {
  final File? imageFile;
  final FoodAnalysis? foodAnalysis;
  final DateTime? timestamp;

  const AfterScan({
    super.key,
    this.imageFile,
    this.foodAnalysis,
    this.timestamp,
  });

  @override
  _AfterScanState createState() => _AfterScanState();
}

class _AfterScanState extends State<AfterScan> {
  late FoodAnalysisService foodAiService;
  final TextRecognitionService textRecognition = TextRecognitionService();
  late NotchBottomBarController _controller;
  int _selectedIndex = 0;
  bool _isLoading = true;
  bool isMenuOpen = false;
  final ProfilingService _profilingService =
      ProfilingService(profilingRepo: ProfilingRepo());
  final ScrollController mainScrollController = ScrollController();

  // User profile information
  Map<String, dynamic>? userProfile;

  // BMI calculation properties
  double? _userBmi;
  String _bmiCategory = '';
  Color _bmiColor = Colors.green;

  FoodAnalysis foodAnalysisResponse = FoodAnalysis(
    title: '',
    ingredientsAnalysis: [],
    allergens: [],
    healthTips: [],
    createdAt: DateTime.now(),
  );

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
    },
    {
      "title": "Energy Boost",
      "fact": "Snacking on nuts or seeds provides a quick source of healthy fats and protein."
    },
    {
      "title": "Heart Health",
      "fact": "Omega-3 fatty acids found in fish like salmon can reduce the risk of heart disease."
    },
    {
      "title": "Digestive Health",
      "fact": "Fermented foods like yogurt and kefir contain probiotics that support gut health."
    },
    {
      "title": "Antioxidant Power",
      "fact": "Berries such as blueberries and strawberries are rich in antioxidants that combat inflammation."
    },
    {
      "title": "Iron Intake",
      "fact": "Pairing iron-rich foods like spinach with vitamin C sources like oranges boosts absorption."
    }
  ];

  @override
  void initState() {
    super.initState();
    foodAiService = FoodAnalysisService(
      foodAnalysisRepo: FoodAnalysisRepo(),
      profilingRepo: ProfilingRepo(),
    );
    _controller = NotchBottomBarController(index: 0);

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      debugPrint('Initial timestamp in AfterScan: ${widget.timestamp}');

      // Load user profile first
      await _loadUserProfile();

      if (widget.foodAnalysis != null) {
        setState(() {
          foodAnalysisResponse = widget.foodAnalysis!;
          _isLoading = false;
        });
      } else if (widget.imageFile != null) {
        setState(() => _isLoading = true);
        _startLoadingAnimation();
        await _performDirectImageAnalysis();
      } else {
        setState(() => _isLoading = false);
      }

      // Calculate BMI after loading the food analysis
      await _calculateBmi();
    });
  }

  Future<void> _loadUserProfile() async {
    try {
      final profile = await _profilingService.getProfile();
      if (profile != null) {
        setState(() {
          userProfile = profile.toJson();
        });
        debugPrint('User profile loaded: $userProfile');
      }
    } catch (e) {
      debugPrint('Error loading user profile: $e');
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
          _isLoading = false;
        });
      }
    });
  }

  void _stopLoadingAnimation() {
    _loadingTimer?.cancel();
    _factRotationTimer?.cancel();
  }

  @override
  void dispose() {
    _controller.dispose();
    _loadingTimer?.cancel();
    _factRotationTimer?.cancel();
    mainScrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const Color prime = Color(0xFF0d522c);
    return PopScope(
      canPop: false,
      onPopInvoked: _onPopInvoked,
      child: Scaffold(
        backgroundColor: const Color(0xFFD6EFD8),
        appBar: AppBar(
          backgroundColor: const Color(0xFFD6EFD8),
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
        ),
        body: _isLoading
            ? Center(
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
                      'Analyzing ingredients... $_loadingPercentage%',
                      style: const TextStyle(
                        fontFamily: 'Poppins',
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: prime,
                      ),
                    ),
                  ],
                ),
              )
            : Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        foodAnalysisResponse.title.isNotEmpty
                            ? foodAnalysisResponse.title
                            : 'Ingredient Analysis',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: prime,
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
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
                            Text(
                              'BMI: ${_userBmi!.toStringAsFixed(1)} ($_bmiCategory)',
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: _bmiColor,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(
                        _getTitleForIndex(_selectedIndex)['title'],
                        style: TextStyle(
                          color: _getTitleForIndex(_selectedIndex)['color'],
                          fontFamily: 'Poppins',
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    Expanded(child: _buildBody()),
                  ],
                ),
              ),
        bottomNavigationBar: _isLoading
            ? null
            : AnimatedNotchBottomBar(
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
                    _selectedIndex = index;
                    _controller.jumpTo(index);
                  });
                },
                kIconSize: 22.0,
                kBottomRadius: 10.0,
              ),
        floatingActionButtonLocation: ExpandableFab.location,
        floatingActionButton: _isLoading
            ? null
            : Theme(
                data: Theme.of(context).copyWith(
                  floatingActionButtonTheme:
                      const FloatingActionButtonThemeData(
                    backgroundColor: prime,
                    foregroundColor: Colors.white,
                  ),
                ),
                child: ExpandableFab(
                  type: ExpandableFabType.fan,
                  distance: 70.0,
                  children: [
                    FloatingActionButton.small(
                      heroTag: 'scan-again',
                      backgroundColor: prime,
                      onPressed: () async {
                        toggleMenu();
                        bool? rescan = await showDialog<bool>(
                          context: context,
                          builder: (BuildContext context) {
                            return AlertDialog(
                              title: Row(
                                children: [
                                  const Icon(Icons.question_answer,
                                      color: prime),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'Rescan Confirmation',
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
                                'Do you want to scan again?',
                                style: TextStyle(
                                  fontFamily: 'Poppins',
                                  fontSize: 14,
                                  color: Colors.black87,
                                ),
                              ),
                              actions: [
                                TextButton(
                                  onPressed: () =>
                                      Navigator.pop(context, false),
                                  child: const Text(
                                    'No',
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
                                    'Yes',
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      color: prime,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                              shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12)),
                              backgroundColor: Colors.white,
                              elevation: 8,
                            );
                          },
                        );

                        if (rescan == true && mounted) {
                          final profile = await _profilingService.getProfile();
                          if (profile != null) {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) =>
                                    Camera(userProfile: profile.toJson()),
                              ),
                            );
                          } else {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) =>
                                      const ProfilingQuestionsPage()),
                            );
                          }
                        }
                      },
                      child: const Icon(Icons.camera, color: Colors.white),
                    ),
                    FloatingActionButton.small(
                      heroTag: 'profiling-questions',
                      backgroundColor: prime,
                      onPressed: () {
                        toggleMenu();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const EditProfiling(),
                          ),
                        );
                      },
                      child: const Icon(Icons.person, color: Colors.white),
                    ),
                    FloatingActionButton.small(
                      heroTag: 'history',
                      backgroundColor: prime,
                      onPressed: () {
                        toggleMenu();
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                const HistoryStackedCarousel(),
                          ),
                        );
                      },
                      child: const Icon(Icons.history, color: Colors.white),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

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
    debugPrint("Building body with foodAnalysisResponse: ${foodAnalysisResponse.toJson()}");

    bool hasOnlyErrorData = foodAnalysisResponse.ingredientsAnalysis.every((item) =>
        item.name.contains('Analysis Failed') ||
        item.name.contains('Unknown Ingredients') ||
        item.name.contains('Processing Error'));

    if (foodAnalysisResponse.title.contains('Error') && !hasOnlyErrorData) {
      foodAnalysisResponse.title = foodAnalysisResponse.title.replaceAll('(Processing Error)', '').trim();
    }

    switch (_selectedIndex) {
      case 0:
        return _buildIngredientsList(
            foodAnalysisResponse.ingredientsAnalysis
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
            Colors.green.shade700);
      case 1:
        return _buildIngredientsList(
            foodAnalysisResponse.allergens
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
            Colors.red.shade700);
      case 2:
        return _buildHealthTips(
          foodAnalysisResponse.healthTips
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
            foodAnalysisResponse.ingredientsAnalysis
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
            Colors.green.shade700);
    }
  }

  Widget _buildIngredientsList(List<Map<String, String>> items, [String? thirdField, Color? accentColor]) {
    const Color prime = Color(0xFF0d522c);
    final Color titleColor = accentColor ?? prime;
    debugPrint("Building ingredients list with ${items.length} items");

    for (var i = 0; i < items.length; i++) {
      debugPrint("Item $i: ${items[i]}");
    }

    bool hasRealData = items.any((item) =>
        !item['name']!.contains('Analysis Failed') &&
        !item['name']!.contains('Unknown Ingredients') &&
        !item['name']!.contains('Processing Error'));

    if (items.isEmpty || !hasRealData) {
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
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
                  padding: const EdgeInsets.all(20.0),
                  constraints: const BoxConstraints(minWidth: double.infinity),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Flexible(
                            child: Text(
                              (item['name'] ?? 'NO NAME').toUpperCase(),
                              style: TextStyle(
                                fontFamily: 'Poppins',
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: titleColor,
                              ),
                              textAlign: TextAlign.justify,
                              softWrap: true,
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
                              if (_selectedIndex == 0)
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
                              if (_selectedIndex == 0)
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
                              if (thirdField != null && _selectedIndex > 0)
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
    debugPrint("Building health tips with ${healthTips.length} items");

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
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
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
                  padding: const EdgeInsets.all(20.0),
                  constraints: const BoxConstraints(minWidth: double.infinity),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
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
                              softWrap: true,
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
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
                          padding: const EdgeInsets.only(top: 8.0, left: 8.0, right: 8.0),
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

  Future<void> _onPopInvoked(didPop) async {
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

  Future<void> _performDirectImageAnalysis() async {
    if (widget.imageFile == null || widget.timestamp == null) {
      setState(() => _isLoading = false);
      _stopLoadingAnimation();
      return;
    }

    setState(() => _isLoading = true);

    try {
      final profile = await _profilingService.getProfile();
      if (profile == null) {
        throw Exception('No profile found.');
      }

      final formattedUserProfile = {
        'age': profile.age,
        'sex': profile.sex.toLowerCase(),
        'height': profile.height.toString(),
        'weight': profile.weight.toString(),
        'health_conditions': profile.healthConditions,
      };

      debugPrint('Fetched userProfile for analysis: $formattedUserProfile');

      await foodAiService.analyzeImageDirectly(
        widget.imageFile!,
        formattedUserProfile,
        (foodAnalysisResponse) {
          if (mounted) {
            debugPrint('Food analysis response received: ${foodAnalysisResponse.toJson()}');
            setState(() {
              this.foodAnalysisResponse = foodAnalysisResponse;
              _isLoading = false;
            });
            _stopLoadingAnimation();
          }
        },
        timestamp: widget.timestamp,
      );
    } catch (e) {
      _stopLoadingAnimation();
      if (mounted) {
        await showDialog(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: Row(
                children: [
                  const Icon(Icons.error, color: Colors.red),
                  const SizedBox(width: 8),
                  const Text(
                    'Food Analysis Error',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.red,
                    ),
                  ),
                ],
              ),
              content: Text(
                'Food analysis failed: $e',
                style: const TextStyle(
                  fontFamily: 'Poppins',
                  fontSize: 14,
                  color: Colors.black87,
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.pushReplacement(
                      context,
                      MaterialPageRoute(
                        builder: (context) => Camera(userProfile: {}),
                      ),
                    );
                  },
                  child: const Text(
                    'Scan Again',
                    style: TextStyle(
                      fontFamily: 'Poppins',
                      color: prime,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12)),
              backgroundColor: Colors.white,
              elevation: 8,
            );
          },
        );
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _calculateBmi() async {
    try {
      final profile = await _profilingService.getProfile();
      if (profile != null && profile.height > 0 && profile.weight > 0) {
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

        if (mounted) {
          setState(() {
            _userBmi = bmi;
            _bmiCategory = category;
            _bmiColor = color;
          });
        }
      }
    } catch (e) {
      debugPrint('Error calculating BMI: $e');
    }
  }

  void toggleMenu() {
    setState(() {
      isMenuOpen = !isMenuOpen;
    });
  }
}
