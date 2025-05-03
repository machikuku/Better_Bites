class HealthConditions {
  /// A mapping of valid health conditions and their alternative inputs.
  static const Map<String, List<String>> conditionMap = {
    // Metabolic & Endocrine Disorders
    'diabetes': ['diabetes'],
    'high cholesterol': ['high cholesterol', 'cholesterol'],
    'thyroid disorder': ['thyroid disorder', 'thyroid'],
    'pcos (polycystic ovary syndrome)': ['pcos', 'polycystic ovary syndrome'],
    'gout': ['gout'],

    // Cardiovascular & Blood Disorders
    'hypertension': ['hypertension', 'high blood pressure', 'hbp'],
    'heart disease': ['heart disease', 'cardiovascular disease', 'cvd'],
    'anemia': ['anemia', 'low iron'],
    'stroke risk': ['stroke risk', 'stroke'],

    // Allergies & Food Intolerances
    'nut allergy': ['nut allergy', 'tree nut allergy'],
    'peanut allergy': ['peanut allergy', 'peanut sensitivity'],
    'shellfish allergy': ['shellfish allergy', 'seafood allergy'],
    'soy allergy': ['soy allergy', 'soy sensitivity'],
    'egg allergy': ['egg allergy', 'egg sensitivity'],
    'wheat allergy': ['wheat allergy', 'gluten allergy'],
    'milk allergy': ['milk allergy', 'dairy allergy'],
    'lactose intolerance': ['lactose intolerance', 'lactose sensitive'],
    'gluten intolerance': ['gluten intolerance', 'gluten sensitive'],
    'celiac disease': ['celiac disease', 'celiac'],

    // Respiratory Conditions
    'asthma': ['asthma'],

    // Digestive & Gastrointestinal Disorders
    'ibs (irritable bowel syndrome)': ['ibs', 'irritable bowel syndrome'],
    'gerd (gastroesophageal reflux disease)': ['gerd', 'acid reflux'],
    'crohn\'s disease': ['crohn\'s disease', 'crohn\'s'],
    'ulcerative colitis': ['ulcerative colitis', 'colitis'],

    // Kidney & Liver Diseases
    'kidney disease': ['kidney disease', 'renal disease'],
    'liver disease': ['liver disease'],
    'fatty liver disease': ['fatty liver disease', 'fatty liver'],

    // Neurological & Autoimmune Disorders
    'migraine': ['migraine', 'chronic headache'],
    'epilepsy': ['epilepsy', 'seizures'],
    'multiple sclerosis': ['multiple sclerosis', 'ms'],
    'rheumatoid arthritis': ['rheumatoid arthritis', 'ra'],
    'lupus': ['lupus', 'sle'],

    // Others
    'osteoporosis': ['osteoporosis', 'bone loss'],
    'cancer': ['cancer', 'tumor'],
    'immune deficiency disorders': ['immune deficiency disorders', 'weakened immune system'],
  };

  /// Checks if the provided condition is valid, allowing alternative names.
  static bool isValidCondition(String condition) {
    final normalizedCondition = condition.trim().toLowerCase();
    return conditionMap.values.any((alternatives) => alternatives.contains(normalizedCondition));
  }

  /// Returns a list of recognized conditions based on user input (suggestions).
  static List<String> getSuggestions(String query) {
    final normalizedQuery = query.trim().toLowerCase();
    if (normalizedQuery.isEmpty) {
      return conditionMap.keys.toList();
    }
    return conditionMap.entries
        .where((entry) => entry.value.any((alt) => alt.contains(normalizedQuery)))
        .map((entry) => entry.key)
        .toList();
  }
}
