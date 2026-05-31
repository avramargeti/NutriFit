import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'smart_insights_service.dart';

class ChatbotDataCache {
  static final ChatbotDataCache _instance = ChatbotDataCache._internal();
  factory ChatbotDataCache() => _instance;
  ChatbotDataCache._internal();

  bool isLoaded = false;
  List<Map<String, dynamic>> ingredients = [];
  List<Map<String, dynamic>> recipes = [];
  List<Map<String, dynamic>> programs = [];
  List<Map<String, dynamic>> cookingBook = [];
  List<Map<String, dynamic>> shoppingList = [];
  Map<String, dynamic>? userProfile;

  Future<void> loadData({bool forceRefresh = false}) async {
    if (isLoaded && !forceRefresh) return;

    try {
      final user = FirebaseAuth.instance.currentUser;
      Map<String, dynamic>? nextUserProfile;
      var nextCookingBook = <Map<String, dynamic>>[];
      var nextShoppingList = <Map<String, dynamic>>[];

      if (user != null) {
        final userDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (userDoc.exists) {
          nextUserProfile = _withId(userDoc);
        }

        final cookingBookRes = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('cookingBook')
            .get();
        nextCookingBook = cookingBookRes.docs.map(_withId).toList();

        final shoppingListRes = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('shoppingList')
            .get();
        nextShoppingList = shoppingListRes.docs.map(_withId).toList();
      }

      final ingRes = await FirebaseFirestore.instance
          .collection('ingredients')
          .get();
      final recRes = await FirebaseFirestore.instance
          .collection('recipes')
          .get();
      final progRes = await FirebaseFirestore.instance
          .collection('fitness_programs')
          .get();

      userProfile = nextUserProfile;
      cookingBook = nextCookingBook;
      shoppingList = nextShoppingList;
      ingredients = ingRes.docs.map(_withId).toList();
      recipes = recRes.docs.map(_withId).toList();
      programs = progRes.docs.map(_withId).toList();
      isLoaded = true;
      debugPrint("Τα δεδομένα του Chatbot ανανεώθηκαν επιτυχώς.");
    } catch (e) {
      debugPrint("Σφάλμα caching δεδομένων: $e");
    }
  }

  static Map<String, dynamic> _withId(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return {...?doc.data(), 'id': doc.id};
  }

  void clearCache() {
    isLoaded = false;
    ingredients.clear();
    recipes.clear();
    programs.clear();
    cookingBook.clear();
    shoppingList.clear();
    userProfile = null;
  }
}

class LocalDataRepository {
  LocalDataRepository({ChatbotDataCache? cache})
    : _cache = cache ?? ChatbotDataCache();

  final ChatbotDataCache _cache;
  final math.Random _random = math.Random();
  final List<String> _recentRecipeRecommendationIds = [];
  final List<String> _recentProgramRecommendationIds = [];

  Future<void> loadData({bool forceRefresh = false}) =>
      _cache.loadData(forceRefresh: forceRefresh);

  String normalize(String text) => _removeAccents(text.toLowerCase());

  bool isGibberish(String text) {
    final normalizedText = normalize(text);
    if (normalizedText.length < 3) return false;
    if (RegExp(r'(.)\1{3,}').hasMatch(normalizedText)) return true;

    final lettersOnly = normalizedText.replaceAll(RegExp(r'[^α-ωa-z]'), '');
    if (lettersOnly.length < 3) return false;

    final vowels = RegExp(r'[αεηιουωaeiou]');
    final matches = vowels.allMatches(lettersOnly);
    return matches.length < (lettersOnly.length * 0.1);
  }

  List<String> getUserAllergies() {
    final profile = _cache.userProfile;
    if (profile != null && profile['allergies'] is List) {
      return List<String>.from(profile['allergies']);
    }
    return [];
  }

  Future<String?> retrieveInformation(String normalizedText) async {
    await _cache.loadData();
    final userAllergies = getUserAllergies();
    final activeAllergies = _extractActiveAllergies(
      normalizedText,
      userAllergies,
    );

    // 1. Exact local app data first.
    final profileResponse = _answerUserProfile(normalizedText, userAllergies);
    if (profileResponse != null) return profileResponse;

    final cookingBookResponse = _answerCookingBook(normalizedText);
    if (cookingBookResponse != null) return cookingBookResponse;

    final shoppingListResponse = _answerShoppingList(normalizedText);
    if (shoppingListResponse != null) return shoppingListResponse;

    final recommendedProgramsResponse = _answerRecommendedFitnessPrograms(
      normalizedText,
    );
    if (recommendedProgramsResponse != null) return recommendedProgramsResponse;

    final dailyMealPlanResponse = _answerDailyMealPlan(
      normalizedText,
      activeAllergies,
    );
    if (dailyMealPlanResponse != null) return dailyMealPlanResponse;

    // 2. Nutrition calculations for specific ingredients remain local.
    final asksIngredientNutrition = _asksForNutrition(normalizedText);
    final looksLikeIngredientAmount =
        _extractGramAmount(normalizedText) != null;

    if ((asksIngredientNutrition || looksLikeIngredientAmount) &&
        !normalizedText.contains("συνταγ")) {
      final ingredientResponse = _findIngredientNutrition(
        normalizedText,
        activeAllergies,
      );
      if (ingredientResponse != null) return ingredientResponse;
    }

    // 3. Collection summaries remain local.
    if (_asksForCollectionSummary(normalizedText)) {
      return _collectionSummary(normalizedText);
    }

    final asksFitness = _asksForFitnessRecommendation(normalizedText);
    final asksRecipe = _asksForRecipeRecommendation(normalizedText);
    final asksSpecificLocalFoodData = _asksForSpecificLocalFoodData(
      normalizedText,
    );

    // 4. General wellness/nutrition/fitness questions should go to the proxy.
    // Example: "Γιατί η βιταμίνη C κάνει καλό;" or
    // "Δώσε μου συμβουλές αποκατάστασης μετά από προπόνηση".
    // These are not requests for a stored recipe/ingredient/program.
    if (_shouldUseExternalAiWithoutLocalSearch(
      normalizedText,
      asksFitness: asksFitness,
      asksRecipe: asksRecipe,
      asksSpecificLocalFoodData: asksSpecificLocalFoodData,
    )) {
      return null;
    }

    // 5. Fitness questions are checked before recipes so workout/recovery
    // queries do not accidentally match food records.
    if (asksFitness && !asksRecipe) {
      final programResponse = _findFitnessProgram(normalizedText);
      if (programResponse != null) return programResponse;

      final fitnessRecommendation = _recommendFitnessProgram(normalizedText);
      if (fitnessRecommendation != null) return fitnessRecommendation;

      return null;
    }

    // 6. Recipe logic only runs for actual recipe/meal requests.
    if (asksRecipe) {
      if (_asksForOpenRecipeRecommendation(normalizedText)) {
        final recommendation = _recommendRecipe(
          normalizedText,
          activeAllergies,
        );
        if (recommendation != null) return recommendation;
      }

      final recipeResponse = _findRecipe(normalizedText, activeAllergies);
      if (recipeResponse != null) return recipeResponse;

      final recommendation = _recommendRecipe(normalizedText, activeAllergies);
      if (recommendation != null) return recommendation;

      return null;
    }

    // 7. Ingredient lookup only runs when the user asks for a specific
    // food/ingredient, not for broad educational wellness questions.
    if (asksSpecificLocalFoodData) {
      final ingredientResponse = _findIngredient(
        normalizedText,
        activeAllergies,
      );
      if (ingredientResponse != null) return ingredientResponse;
    }

    if (asksFitness) {
      final fitnessRecommendation = _recommendFitnessProgram(normalizedText);
      if (fitnessRecommendation != null) return fitnessRecommendation;
      return null;
    }

    return null;
  }

  String? _answerUserProfile(String normalizedText, List<String> allergies) {
    final profile = _cache.userProfile;
    final asksProfile =
        normalizedText.contains("προφιλ") ||
        normalizedText.contains("στοιχεια μου") ||
        normalizedText.contains("ποιος ειμαι") ||
        normalizedText.contains("στοχοι μου") ||
        normalizedText.contains("θερμιδες μου") ||
        normalizedText.contains("bmi") ||
        normalizedText.contains("αλλεργι") ||
        normalizedText.contains("δυσανεξ") ||
        normalizedText.contains("νερο") ||
        normalizedText.contains("βαρος") ||
        normalizedText.contains("υψος");

    if (!asksProfile) return null;
    if (profile == null) {
      return "Δεν βρήκα αποθηκευμένα στοιχεία προφίλ για τον λογαριασμό σου.";
    }

    final secondaryGoals = _asStringList(profile['secondaryGoals']);
    final healthIssues = _asStringList(profile['healthIssues']);
    final fitnessPrefs = profile['fitnessPreferences'] is Map
        ? Map<String, dynamic>.from(profile['fitnessPreferences'])
        : <String, dynamic>{};

    return "Βάσει του προφίλ σου:\n"
        "Όνομα: ${profile['fullName'] ?? profile['username'] ?? '-'}\n"
        "Κύριος στόχος: ${profile['mainGoal'] ?? '-'}\n"
        "Δευτερεύοντες στόχοι: ${secondaryGoals.isEmpty ? '-' : secondaryGoals.join(', ')}\n"
        "Ημερήσιος στόχος: ${profile['targetCalories'] ?? '-'} kcal\n"
        "BMI: ${profile['bmi'] ?? '-'}\n"
        "Βάρος/Ύψος: ${profile['weight'] ?? '-'} kg / ${profile['height'] ?? '-'} cm\n"
        "Διατροφή: ${profile['dietType'] ?? '-'}\n"
        "Αλλεργίες/δυσανεξίες: ${allergies.isEmpty ? '-' : allergies.join(', ')}\n"
        "Θέματα υγείας: ${healthIssues.isEmpty ? '-' : healthIssues.join(', ')}\n"
        "Νερό: ${_waterText(profile['dailyWaterIntake'])}\n"
        "Προτιμήσεις άσκησης: ${_formatFitnessPreferences(fitnessPrefs)}.";
  }

  String? _answerCookingBook(String normalizedText) {
    if (!normalizedText.contains("cooking book") &&
        !normalizedText.contains("βιβλιο") &&
        !normalizedText.contains("αγαπημεν")) {
      return null;
    }

    if (_cache.cookingBook.isEmpty) {
      return "Δεν βρήκα συνταγές στο προσωπικό σου Cooking Book.";
    }

    final titles = _cache.cookingBook
        .map((r) => (r['title'] ?? 'Χωρίς τίτλο').toString())
        .take(8)
        .join(', ');
    return "Στο Cooking Book σου έχεις ${_cache.cookingBook.length} συνταγές. "
        "Ενδεικτικά: $titles.";
  }

  String? _answerShoppingList(String normalizedText) {
    if (!normalizedText.contains("λιστα αγορ") &&
        !normalizedText.contains("super market") &&
        !normalizedText.contains("σουπερ μαρκετ")) {
      return null;
    }

    if (_cache.shoppingList.isEmpty) {
      return "Η λίστα αγορών σου είναι άδεια.";
    }

    final pending = _cache.shoppingList
        .where((item) => item['isChecked'] != true)
        .map((item) {
          final name = item['name'] ?? '-';
          final quantity = (item['quantity'] ?? '').toString();
          final amount = (item['amount'] as num?)?.toInt() ?? 0;
          if (quantity.isNotEmpty) return "$name ($quantity)";
          if (amount > 0) return "$name (${amount}g)";
          return name.toString();
        })
        .toList();

    if (pending.isEmpty) {
      return "Έχεις ${_cache.shoppingList.length} προϊόντα στη λίστα αγορών και όλα φαίνονται ολοκληρωμένα.";
    }

    return "Στη λίστα αγορών σου απομένουν: ${pending.take(12).join(', ')}.";
  }

  String? _answerRecommendedFitnessPrograms(String normalizedText) {
    final asksRecommendedPrograms =
        normalizedText.contains("προτεινομενα προγραμματα") ||
        normalizedText.contains("προτεινομενες προπονησεις") ||
        (normalizedText.contains("προτεινομενα") &&
            (normalizedText.contains("γυμναστικ") ||
                normalizedText.contains("προγραμμα") ||
                normalizedText.contains("προπονηση")));

    if (!asksRecommendedPrograms) return null;
    if (_cache.programs.isEmpty) {
      return "Δεν υπάρχουν καταχωρημένα προγράμματα γυμναστικής αυτή τη στιγμή.";
    }

    final profile = _cache.userProfile;
    if (profile == null || profile['fitnessPreferences'] is! Map) {
      return "Δεν βρήκα απαντήσεις από το κουίζ γυμναστικής στο προφίλ σου. Συμπλήρωσε πρώτα το κουίζ για να σου εμφανίσω τα ίδια προτεινόμενα προγράμματα.";
    }

    final prefs = Map<String, String>.from(profile['fitnessPreferences']);
    final scoredPrograms = _cache.programs.map((program) {
      final score = SmartInsightsService.calculateProgramScore(
        programData: program,
        userPreferences: prefs,
        userData: profile,
      );
      return MapEntry(program, score);
    }).toList()..sort((a, b) => b.value.compareTo(a.value));

    var noExactMatch = false;
    var selected = scoredPrograms.where((entry) => entry.value > 2).toList();
    if (selected.isEmpty) {
      noExactMatch = true;
      selected = scoredPrograms.take(3).toList();
    } else {
      selected = selected.take(4).toList();
    }

    final insights = SmartInsightsService.generateSmartInsights(
      noExactMatch: noExactMatch,
      userData: profile,
    );
    final programLines = selected
        .map((entry) {
          final program = entry.key;
          return "- ${program['name'] ?? 'Χωρίς τίτλο'}: "
              "${program['category'] ?? '-'}, ${program['location'] ?? '-'}, "
              "ένταση ${program['intensity'] ?? program['difficulty'] ?? '-'}, "
              "διάρκεια ${program['duration'] ?? '-'}, "
              "~${program['estimatedCalories'] ?? '-'} kcal.";
        })
        .join('\n');
    final insightText = insights.isEmpty
        ? ""
        : "\n\nΓιατί ταιριάζουν:\n${insights.take(3).join('\n')}";

    return "Με βάση τις απαντήσεις σου στο κουίζ, σου προτείνω:\n"
        "$programLines$insightText";
  }

  String? _answerDailyMealPlan(
    String normalizedText,
    List<String> avoidAllergies,
  ) {
    final asksDailyPlan =
        normalizedText.contains("ημερησιο πλανο γευματων") ||
        normalizedText.contains("πλανο γευματων") ||
        (normalizedText.contains("πρωινο") &&
            normalizedText.contains("μεσημεριανο") &&
            normalizedText.contains("βραδινο"));

    if (!asksDailyPlan) return null;

    final breakfast = _chooseMealPlanRecipe(
      category: "Πρωινό",
      calorieShare: 0.25,
      avoidAllergies: avoidAllergies,
      selectedIds: <String>{},
    );
    final selectedIds = <String>{if (breakfast != null) _recipeId(breakfast)};
    final lunch = _chooseMealPlanRecipe(
      category: "Μεσημεριανό",
      calorieShare: 0.40,
      avoidAllergies: avoidAllergies,
      selectedIds: selectedIds,
    );
    if (lunch != null) selectedIds.add(_recipeId(lunch));
    final dinner = _chooseMealPlanRecipe(
      category: "Βραδινό",
      calorieShare: 0.35,
      avoidAllergies: avoidAllergies,
      selectedIds: selectedIds,
    );

    final meals = {
      "Πρωινό": breakfast,
      "Μεσημεριανό": lunch,
      "Βραδινό": dinner,
    };

    if (meals.values.every((recipe) => recipe == null)) {
      return "Δεν βρήκα αρκετές συνταγές που να ταιριάζουν με τις διατροφικές προτιμήσεις και τους στόχους σου.";
    }

    final profile = _cache.userProfile;
    final targetCalories = (profile?['targetCalories'] as num?)?.toDouble();
    final dietType = profile?['dietType'] ?? 'Όλα (Χωρίς περιορισμούς)';
    var totalCalories = 0.0;
    final mealLines = meals.entries
        .map((entry) {
          final recipe = entry.value;
          if (recipe == null) {
            return "${entry.key}: Δεν βρήκα διαθέσιμη συνταγή για αυτό το γεύμα.";
          }

          final calories = _toDouble(recipe['caloriesPerServing']);
          totalCalories += calories;
          return _formatMealPlanLine(entry.key, recipe);
        })
        .join('\n\n');
    final targetText = targetCalories == null || targetCalories <= 0
        ? ""
        : "\n\nΣτόχος ημέρας: ${_formatNumber(targetCalories)} kcal. "
              "Το πλάνο καλύπτει περίπου ${_formatNumber(totalCalories)} kcal.";

    return "Με βάση το προφίλ σου, τη διατροφή ($dietType) και τους στόχους σου:\n\n"
        "$mealLines$targetText";
  }

  String? _findRecipe(String normalizedText, List<String> activeAllergies) {
    final specificWords = _recipeSpecificQueryWords(normalizedText);
    final needsSpecificMatch =
        normalizedText.contains("συνταγ") && specificWords.isNotEmpty;
    final matches = _cache.recipes.where((rec) {
      if (needsSpecificMatch &&
          !_recordContainsAnyQueryWord(rec, specificWords)) {
        return false;
      }
      return _recordMatchesQuery(rec, normalizedText, [
        'title',
        'categories',
        'tags',
        'ingredients',
        'prepDescription',
      ]);
    }).toList();

    if (matches.isEmpty) return null;

    matches.sort(
      (a, b) => _scoreRecipe(
        b,
        normalizedText,
      ).compareTo(_scoreRecipe(a, normalizedText)),
    );
    return _formatRecipe(matches.first, activeAllergies);
  }

  Map<String, dynamic>? _chooseMealPlanRecipe({
    required String category,
    required double calorieShare,
    required List<String> avoidAllergies,
    required Set<String> selectedIds,
  }) {
    final profile = _cache.userProfile;
    final candidates = _cache.recipes.where((recipe) {
      final id = _recipeId(recipe);
      if (selectedIds.contains(id)) return false;
      if (!_recipeHasValue(recipe, category)) return false;
      if (_recipeContainsAny(recipe, avoidAllergies)) return false;
      return _recipeMatchesDietProfile(recipe, profile);
    }).toList();

    if (candidates.isEmpty) return null;

    candidates.sort(
      (a, b) => _mealPlanRecipeScore(
        b,
        calorieShare,
        profile,
      ).compareTo(_mealPlanRecipeScore(a, calorieShare, profile)),
    );

    final topCount = math.min(3, candidates.length);
    return candidates[_random.nextInt(topCount)];
  }

  int _mealPlanRecipeScore(
    Map<String, dynamic> recipe,
    double calorieShare,
    Map<String, dynamic>? profile,
  ) {
    var score = (((recipe['avgRating'] ?? 0) as num).toDouble() * 2).round();
    final targetCalories = (profile?['targetCalories'] as num?)?.toDouble();
    final recipeCalories = _toDouble(recipe['caloriesPerServing']);

    if (targetCalories != null && targetCalories > 0 && recipeCalories > 0) {
      final mealTarget = targetCalories * calorieShare;
      score += math
          .max(0, 14 - ((recipeCalories - mealTarget).abs() / 45))
          .round();
    }

    final mainGoal = _normalizeValue(profile?['mainGoal'] ?? '');
    final secondaryGoals = _normalizeValue(profile?['secondaryGoals'] ?? '');
    final goalText = "$mainGoal $secondaryGoals";
    final servings = math.max(1, (_toDouble(recipe['servings'])).round());
    final proteinPerServing =
        _recipeMacro(recipe, 'totalProtein', 'protein') / servings;

    if (goalText.contains("απωλεια") ||
        goalText.contains("χασ") ||
        goalText.contains("λιπο")) {
      if (recipeCalories > 0 && recipeCalories <= 500) score += 3;
      if (_recipeHasValue(recipe, "Low Carb")) score += 2;
    }
    if (goalText.contains("μυ") ||
        goalText.contains("ογκο") ||
        goalText.contains("δυναμ")) {
      score += math.min(6, (proteinPerServing / 8).round());
      if (_recipeHasValue(recipe, "High Protein")) score += 3;
    }

    return score;
  }

  bool _recipeMatchesDietProfile(
    Map<String, dynamic> recipe,
    Map<String, dynamic>? profile,
  ) {
    final dietType = _normalizeValue(profile?['dietType'] ?? '');
    if (dietType.isEmpty || dietType.contains("ολα")) return true;
    if (dietType.contains("vegan")) return _recipeHasValue(recipe, "Vegan");
    if (dietType.contains("vegetarian")) {
      return _recipeHasValue(recipe, "Vegetarian") ||
          _recipeHasValue(recipe, "Vegan");
    }
    if (dietType.contains("keto") || dietType.contains("low carb")) {
      return _recipeHasValue(recipe, "Low Carb");
    }
    if (dietType.contains("pescatarian")) {
      return !_recipeContainsAnyTerms(recipe, [
        "κρεας",
        "κοτοπουλο",
        "μοσχαρι",
        "χοιρινο",
        "κιμα",
        "γαλοπουλα",
        "μπεικον",
      ]);
    }
    return true;
  }

  bool _recipeContainsAnyTerms(
    Map<String, dynamic> recipe,
    List<String> terms,
  ) {
    final text = _normalizeValue(recipe);
    return terms.any(
      (term) => text.contains(_removeAccents(term.toLowerCase())),
    );
  }

  String _formatMealPlanLine(String mealName, Map<String, dynamic> recipe) {
    final servings = math.max(1, (_toDouble(recipe['servings'])).round());
    final protein = _recipeMacro(recipe, 'totalProtein', 'protein') / servings;
    final carbs = _recipeMacro(recipe, 'totalCarbs', 'carbs') / servings;
    final fats = _recipeMacro(recipe, 'totalFats', 'fats') / servings;

    return "$mealName: '${recipe['title'] ?? 'Χωρίς τίτλο'}'\n"
        "Θερμίδες: ${_formatNumber(_toDouble(recipe['caloriesPerServing']))} kcal ανά μερίδα\n"
        "Macros: Πρωτεΐνη ${_formatNumber(protein)}g, "
        "Υδατάνθρακες ${_formatNumber(carbs)}g, "
        "Λιπαρά ${_formatNumber(fats)}g\n"
        "Υλικά: ${_formatRecipeIngredients(recipe)}";
  }

  String? _findIngredient(String normalizedText, List<String> activeAllergies) {
    final matches = _cache.ingredients
        .where(
          (ing) =>
              _ingredientNameMatches(ing, normalizedText) ||
              (!_asksForNutrition(normalizedText) &&
                  _valueMatchesQuery(ing['category'], normalizedText)),
        )
        .toList();

    if (matches.isEmpty) return null;

    matches.sort(
      (a, b) => _scoreIngredient(
        b,
        normalizedText,
      ).compareTo(_scoreIngredient(a, normalizedText)),
    );
    return _formatIngredient(matches.first, normalizedText, activeAllergies);
  }

  String? _findIngredientNutrition(
    String normalizedText,
    List<String> activeAllergies,
  ) {
    final matches = _matchingIngredientsByName(normalizedText);
    if (matches.isEmpty) return null;

    if (matches.length == 1) {
      return _formatIngredient(matches.first, normalizedText, activeAllergies);
    }

    return _formatMultipleIngredients(matches, normalizedText, activeAllergies);
  }

  List<Map<String, dynamic>> _matchingIngredientsByName(String normalizedText) {
    final matches = _cache.ingredients
        .where((ing) => _ingredientNameMatches(ing, normalizedText))
        .toList();

    matches.sort(
      (a, b) => _scoreIngredient(
        b,
        normalizedText,
      ).compareTo(_scoreIngredient(a, normalizedText)),
    );
    return matches;
  }

  String _formatMultipleIngredients(
    List<Map<String, dynamic>> ingredients,
    String normalizedText,
    List<String> activeAllergies,
  ) {
    var totalCalories = 0.0;
    var totalProtein = 0.0;
    var totalCarbs = 0.0;
    var totalFats = 0.0;
    var hasAllAmounts = true;

    final lines = ingredients
        .map((ing) {
          final grams = _extractIngredientGramAmount(ing, normalizedText);
          final caloriesPer100g = _toDouble(ing['caloriesPer100g']);
          final proteinPer100g = _toDouble(ing['protein']);
          final carbsPer100g = _toDouble(ing['carbs']);
          final fatsPer100g = _toDouble(ing['fats']);
          final name = ing['name'] ?? '-';
          final warning = _ingredientMatchesAllergy(ing, activeAllergies)
              ? " Προσοχή: ταιριάζει με κάτι που θέλεις να αποφύγεις."
              : "";

          if (grams == null) {
            hasAllAmounts = false;
            return "- $name: ${_formatNumber(caloriesPer100g)} kcal ανά 100g, "
                "Πρωτεΐνη ${_formatNumber(proteinPer100g)}g, "
                "Υδατάνθρακες ${_formatNumber(carbsPer100g)}g, "
                "Λιπαρά ${_formatNumber(fatsPer100g)}g.$warning";
          }

          final calories = caloriesPer100g * grams / 100;
          final protein = proteinPer100g * grams / 100;
          final carbs = carbsPer100g * grams / 100;
          final fats = fatsPer100g * grams / 100;
          totalCalories += calories;
          totalProtein += protein;
          totalCarbs += carbs;
          totalFats += fats;

          return "- $name (${_formatNumber(grams)}g): "
              "${_formatNumber(calories)} kcal, "
              "Πρωτεΐνη ${_formatNumber(protein)}g, "
              "Υδατάνθρακες ${_formatNumber(carbs)}g, "
              "Λιπαρά ${_formatNumber(fats)}g.$warning";
        })
        .join('\n');

    final totalText = hasAllAmounts
        ? "\n\nΣύνολο: ${_formatNumber(totalCalories)} kcal, "
              "Πρωτεΐνη ${_formatNumber(totalProtein)}g, "
              "Υδατάνθρακες ${_formatNumber(totalCarbs)}g, "
              "Λιπαρά ${_formatNumber(totalFats)}g."
        : "\n\nΓια ακριβές σύνολο χρειάζομαι τα γραμμάρια για κάθε υλικό.";

    return "Βρήκα αυτά τα υλικά:\n$lines$totalText";
  }

  String _formatIngredient(
    Map<String, dynamic> ing,
    String normalizedText,
    List<String> activeAllergies,
  ) {
    final warningText = _ingredientMatchesAllergy(ing, activeAllergies)
        ? "Προσοχή: αυτό το υλικό ταιριάζει με κάτι που θέλεις να αποφύγεις.\n\n"
        : "";

    final grams = _extractGramAmount(normalizedText);
    final caloriesPer100g = _toDouble(ing['caloriesPer100g']);
    final proteinPer100g = _toDouble(ing['protein']);
    final carbsPer100g = _toDouble(ing['carbs']);
    final fatsPer100g = _toDouble(ing['fats']);
    final amountText = grams == null ? _inferAskedAmount(normalizedText) : null;
    final amountMacros = grams == null
        ? ""
        : "\n\nΓια ${_formatNumber(grams)}g:\n"
              "Θερμίδες: ${_formatNumber(caloriesPer100g * grams / 100)} kcal\n"
              "Πρωτεΐνη: ${_formatNumber(proteinPer100g * grams / 100)}g\n"
              "Υδατάνθρακες: ${_formatNumber(carbsPer100g * grams / 100)}g\n"
              "Λιπαρά: ${_formatNumber(fatsPer100g * grams / 100)}g";

    return "$warningTextΣχετικά με το υλικό '${ing['name']}':\n\n"
        "Ανά 100g:\n"
        "Θερμίδες: ${_formatNumber(caloriesPer100g)} kcal${amountText == null ? '' : ' ($amountText)'}\n"
        "Πρωτεΐνη: ${_formatNumber(proteinPer100g)}g\n"
        "Υδατάνθρακες: ${_formatNumber(carbsPer100g)}g\n"
        "Λιπαρά: ${_formatNumber(fatsPer100g)}g\n"
        "Κατηγορία: ${ing['category'] ?? '-'}.$amountMacros";
  }

  String? _findFitnessProgram(String normalizedText) {
    final matches = _cache.programs
        .where(
          (prog) => _recordMatchesQuery(prog, normalizedText, [
            'name',
            'description',
            'category',
            'location',
            'intensity',
            'duration',
          ]),
        )
        .toList();

    if (matches.isEmpty) return null;
    matches.sort(
      (a, b) => _scoreProgram(
        b,
        normalizedText,
      ).compareTo(_scoreProgram(a, normalizedText)),
    );
    return _formatProgram(matches.first);
  }

  String? _recommendRecipe(String normalizedText, List<String> avoidAllergies) {
    final targetCategory = _targetMealCategory(normalizedText);
    final wantedTags = _wantedTags(normalizedText);
    final quickPreferred = wantedTags.contains("Γρήγορη");
    final strictTags = wantedTags.where((tag) => tag != "Γρήγορη").toList();
    final specificWords = _recipeSpecificQueryWords(normalizedText);

    final categoryMatches = _cache.recipes.where((recipe) {
      if (targetCategory != null && !_recipeHasValue(recipe, targetCategory)) {
        return false;
      }
      for (final tag in strictTags) {
        if (!_recipeHasValue(recipe, tag)) return false;
      }
      if (specificWords.isNotEmpty &&
          !_recordContainsAnyQueryWord(recipe, specificWords)) {
        return false;
      }
      return !_recipeContainsAny(recipe, avoidAllergies);
    }).toList();
    final quickMatches = quickPreferred
        ? categoryMatches
              .where((recipe) => _recipeHasValue(recipe, "Γρήγορη"))
              .toList()
        : categoryMatches;
    final safeMatchingRecipes =
        quickPreferred && targetCategory != null && quickMatches.length <= 1
        ? categoryMatches
        : quickMatches;

    if (safeMatchingRecipes.isEmpty) return null;

    final selectedRecipe = _chooseRandomRecommendedRecipe(
      safeMatchingRecipes,
      normalizedText,
    );
    return _formatRecipeRecommendation(
      selectedRecipe,
      avoidAllergies,
      targetCategory,
    );
  }

  String? _recommendFitnessProgram(String normalizedText) {
    if (_cache.programs.isEmpty) return null;

    final profile = _cache.userProfile;
    final prefs = profile?['fitnessPreferences'] is Map
        ? Map<String, dynamic>.from(profile!['fitnessPreferences'])
        : <String, dynamic>{};
    final specificWords = _fitnessSpecificQueryWords(normalizedText);

    final matches = _cache.programs.where((program) {
      if (normalizedText.contains("σπιτι") &&
          !_programHasAny(program, ["σπιτι"])) {
        return false;
      }
      if (normalizedText.contains("γυμναστηριο") &&
          !_programHasAny(program, ["γυμναστηριο"])) {
        return false;
      }
      if (specificWords.isNotEmpty) {
        return _recordContainsAnyQueryWord(program, specificWords);
      }
      return _recordMatchesQuery(program, normalizedText, [
        'name',
        'description',
        'category',
        'location',
        'intensity',
        'duration',
      ]);
    }).toList();

    if (matches.isEmpty) return null;

    final selectedProgram = _chooseRandomRecommendedProgram(
      matches,
      prefs,
      normalizedText,
    );
    return _formatProgram(selectedProgram);
  }

  String? _collectionSummary(String normalizedText) {
    if (normalizedText.contains("υλικ")) {
      final byCategory = _groupCount(_cache.ingredients, 'category');
      return "Στη βάση υπάρχουν ${_cache.ingredients.length} υλικά. "
          "Κατηγορίες: ${_formatCounts(byCategory)}.";
    }
    if (normalizedText.contains("συνταγ")) {
      final byCategory = <String, int>{};
      for (final recipe in _cache.recipes) {
        for (final category in _recipeCategories(recipe)) {
          byCategory[category] = (byCategory[category] ?? 0) + 1;
        }
      }
      return "Στη βάση υπάρχουν ${_cache.recipes.length} συνταγές. "
          "Κατηγορίες: ${_formatCounts(byCategory)}.";
    }
    if (normalizedText.contains("προγραμμα") ||
        normalizedText.contains("γυμναστικ")) {
      final byCategory = _groupCount(_cache.programs, 'category');
      return "Στη βάση υπάρχουν ${_cache.programs.length} προγράμματα γυμναστικής. "
          "Κατηγορίες: ${_formatCounts(byCategory)}.";
    }
    return null;
  }

  List<String> _extractActiveAllergies(
    String normalizedText,
    List<String> userAllergies,
  ) {
    final activeAllergies = List<String>.from(userAllergies);

    if (normalizedText.contains("αλλεργι") ||
        normalizedText.contains("δυσανεξ") ||
        normalizedText.contains("χωρις") ||
        normalizedText.contains("οχι ")) {
      final commonCategories = [
        "οσπρια",
        "γαλακτοκομικα",
        "ξηροι καρποι",
        "ξηρους καρπους",
        "κρεας",
        "ψαρια",
        "θαλασσινα",
        "γλουτενη",
        "γαλα",
        "τυρι",
        "φετα",
        "γιαουρτι",
        "αυγο",
        "αυγα",
      ];

      for (final cat in commonCategories) {
        if (normalizedText.contains(cat)) {
          var normalizedCat = cat;
          if (cat == "ξηρους καρπους") normalizedCat = "ξηροι καρποι";
          if (cat == "αυγα") normalizedCat = "αυγο";
          if (cat == "ψαρια") normalizedCat = "ψαρι";
          if (["γαλα", "τυρι", "φετα", "γιαουρτι"].contains(cat)) {
            normalizedCat = "γαλακτοκομικα";
          }

          if (!activeAllergies.contains(normalizedCat)) {
            activeAllergies.add(normalizedCat);
          }
        }
      }

      for (final ing in _cache.ingredients) {
        final ingName = _normalizeValue(ing['name']);
        if (ingName.length > 3 && normalizedText.contains(ingName)) {
          if (!activeAllergies.contains(ingName)) {
            activeAllergies.add(ingName);
          }
        }
      }
    }

    return activeAllergies;
  }

  bool _shouldUseExternalAiWithoutLocalSearch(
    String normalizedText, {
    required bool asksFitness,
    required bool asksRecipe,
    required bool asksSpecificLocalFoodData,
  }) {
    if (asksRecipe || asksSpecificLocalFoodData) return false;

    final asksGeneralExplanation =
        normalizedText.contains("γιατι") ||
        normalizedText.contains("πως ") ||
        normalizedText.contains("πως να") ||
        normalizedText.contains("τι ειναι") ||
        normalizedText.contains("εξηγησε") ||
        normalizedText.contains("συμβουλη") ||
        normalizedText.contains("συμβουλες") ||
        normalizedText.contains("κανει καλο") ||
        normalizedText.contains("ωφελει") ||
        normalizedText.contains("βοηθα") ||
        normalizedText.contains("χρειαζεται") ||
        normalizedText.contains("πρεπει");

    final mentionsWellnessTopic =
        asksFitness ||
        normalizedText.contains("βιταμινη") ||
        normalizedText.contains("μεταλλο") ||
        normalizedText.contains("ιχνοστοιχει") ||
        normalizedText.contains("υπνος") ||
        normalizedText.contains("αγχος") ||
        normalizedText.contains("στρες") ||
        normalizedText.contains("ενεργεια") ||
        normalizedText.contains("ενυδατωση") ||
        normalizedText.contains("νερο") ||
        normalizedText.contains("αποκατασταση") ||
        normalizedText.contains("αναρρωση") ||
        normalizedText.contains("ξεκουραση") ||
        normalizedText.contains("ευεξια");

    return asksGeneralExplanation && mentionsWellnessTopic;
  }

  bool _asksForSpecificLocalFoodData(String normalizedText) {
    final asksSpecificNutrition =
        _asksForNutrition(normalizedText) ||
        _extractGramAmount(normalizedText) != null ||
        normalizedText.contains("ποσες θερμιδ") ||
        normalizedText.contains("ποση πρωτειν") ||
        normalizedText.contains("ποσους υδατανθρακ") ||
        normalizedText.contains("ποσα λιπαρ");

    final asksIngredient =
        normalizedText.contains("υλικο") ||
        normalizedText.contains("τροφ") ||
        normalizedText.contains("φαγητο") ||
        normalizedText.contains("ανα 100") ||
        normalizedText.contains("γραμμ") ||
        normalizedText.contains("g ");

    return asksSpecificNutrition || asksIngredient;
  }

  bool _asksForRecipeRecommendation(String normalizedText) {
    return _asksForOpenRecipeRecommendation(normalizedText) ||
        normalizedText.contains("συνταγη");
  }

  bool _asksForOpenRecipeRecommendation(String normalizedText) {
    return normalizedText.contains("προτεινε") ||
        normalizedText.contains("προταση") ||
        normalizedText.contains("τυχαι") ||
        normalizedText.contains("να φαω") ||
        normalizedText.contains("τι φαω") ||
        normalizedText.contains("ιδεα") ||
        normalizedText.contains("πρωινο") ||
        normalizedText.contains("μεσημεριανο") ||
        normalizedText.contains("βραδινο") ||
        normalizedText.contains("σνακ");
  }

  bool _asksForNutrition(String normalizedText) {
    return normalizedText.contains("θερμιδ") ||
        normalizedText.contains("kcal") ||
        normalizedText.contains("πρωτειν") ||
        normalizedText.contains("υδατανθρακ") ||
        normalizedText.contains("λιπαρ") ||
        normalizedText.contains("macro") ||
        normalizedText.contains("μακρο");
  }

  bool _asksForFitnessRecommendation(String normalizedText) {
    return normalizedText.contains("ασκηση") ||
        normalizedText.contains("ασκησεις") ||
        normalizedText.contains("γυμναστικη") ||
        normalizedText.contains("προπονηση") ||
        normalizedText.contains("προπονησεις") ||
        normalizedText.contains("προγραμμα") ||
        normalizedText.contains("stretching") ||
        normalizedText.contains("διαταση") ||
        normalizedText.contains("διατασεις") ||
        normalizedText.contains("αποκατασταση") ||
        normalizedText.contains("αναρρωση") ||
        normalizedText.contains("πιασιμο") ||
        normalizedText.contains("ποδια") ||
        normalizedText.contains("μυς") ||
        normalizedText.contains("μυικο") ||
        normalizedText.contains("μυικη") ||
        normalizedText.contains("ξεκουραση");
  }

  bool _asksForCollectionSummary(String normalizedText) {
    return normalizedText.contains("ποσα") ||
        normalizedText.contains("ποσες") ||
        normalizedText.contains("ποια") ||
        normalizedText.contains("τι υπαρχει");
  }

  String _formatRecipe(Map<String, dynamic> rec, List<String> activeAllergies) {
    final detectedAllergen = _firstRecipeAllergen(rec, activeAllergies);
    final warningText = detectedAllergen != null
        ? "Προσοχή: αυτή η συνταγή ενδέχεται να περιέχει $detectedAllergen, το οποίο θέλεις να αποφύγεις.\n\n"
        : "";
    final rating = ((rec['avgRating'] ?? 0) as num).toDouble();
    final reviews = _asList(rec['reviews']);
    final ingredients = _formatRecipeIngredients(rec);
    final steps = _asStringList(rec['steps']);
    final servings = math.max(1, (_toDouble(rec['servings'])).round());
    final totalCalories = _toDouble(rec['totalCalories']);
    final caloriesPerServing = _toDouble(rec['caloriesPerServing']);
    final totalProtein = _recipeMacro(rec, 'totalProtein', 'protein');
    final totalCarbs = _recipeMacro(rec, 'totalCarbs', 'carbs');
    final totalFats = _recipeMacro(rec, 'totalFats', 'fats');

    return "$warningTextΣυνταγή: '${rec['title'] ?? 'Χωρίς τίτλο'}'\n\n"
        "Κατηγορίες: ${_recipeCategories(rec).isEmpty ? '-' : _recipeCategories(rec).join(', ')}\n"
        "Θερμίδες ανά μερίδα: ${_formatNumber(caloriesPerServing)} kcal\n"
        "Macros ανά μερίδα: Πρωτεΐνη ${_formatNumber(totalProtein / servings)}g, Υδατάνθρακες ${_formatNumber(totalCarbs / servings)}g, Λιπαρά ${_formatNumber(totalFats / servings)}g\n"
        "Σύνολο συνταγής: ${_formatNumber(totalCalories)} kcal για $servings μερίδες\n"
        "Macros συνόλου: Πρωτεΐνη ${_formatNumber(totalProtein)}g, Υδατάνθρακες ${_formatNumber(totalCarbs)}g, Λιπαρά ${_formatNumber(totalFats)}g\n"
        "Υλικά: ${ingredients.isEmpty ? '-' : ingredients}\n"
        "Αξιολογήσεις: ${rating > 0 ? '${rating.toStringAsFixed(1)}/5' : 'Χωρίς βαθμολογία ακόμα'} (${rec['totalReviews'] ?? reviews.length})\n"
        "${steps.isEmpty ? '' : 'Πρώτο βήμα: ${steps.first}'}";
  }

  String _formatRecipeRecommendation(
    Map<String, dynamic> rec,
    List<String> avoidAllergies,
    String? targetCategory,
  ) {
    final prefix = targetCategory == null ? "Σου" : "Για $targetCategory σου";
    final filterMessage = avoidAllergies.isNotEmpty
        ? "Έχω εξαιρέσει συνταγές με: ${avoidAllergies.join(', ')}.\n"
        : "";
    final servings = math.max(1, (_toDouble(rec['servings'])).round());
    final totalProtein = _recipeMacro(rec, 'totalProtein', 'protein');
    final totalCarbs = _recipeMacro(rec, 'totalCarbs', 'carbs');
    final totalFats = _recipeMacro(rec, 'totalFats', 'fats');

    return "$filterMessage$prefix προτείνω τη συνταγή '${rec['title'] ?? 'Χωρίς τίτλο'}'.\n"
        "Αποδίδει ${rec['caloriesPerServing'] ?? '-'} kcal ανά μερίδα.\n"
        "Macros ανά μερίδα: Πρωτεΐνη ${_formatNumber(totalProtein / servings)}g, Υδατάνθρακες ${_formatNumber(totalCarbs / servings)}g, Λιπαρά ${_formatNumber(totalFats / servings)}g.\n"
        "Υλικά: ${_formatRecipeIngredients(rec)}";
  }

  String _formatProgram(Map<String, dynamic> prog) {
    return "Πρόγραμμα γυμναστικής: '${prog['name'] ?? 'Χωρίς τίτλο'}'\n\n"
        "Κατηγορία: ${prog['category'] ?? '-'}\n"
        "Τοποθεσία: ${prog['location'] ?? '-'}\n"
        "Ένταση: ${prog['intensity'] ?? prog['difficulty'] ?? '-'}\n"
        "Διάρκεια: ${prog['duration'] ?? '-'}\n"
        "Εκτιμώμενες θερμίδες καύσης: ${prog['estimatedCalories'] ?? '-'} kcal\n"
        "Περιγραφή: ${prog['description'] ?? '-'}";
  }

  bool _recordMatchesQuery(
    Map<String, dynamic> record,
    String normalizedText,
    List<String> fields,
  ) {
    for (final field in fields) {
      final value = record[field];
      if (_valueMatchesQuery(value, normalizedText)) return true;
    }
    return false;
  }

  bool _recordContainsAnyQueryWord(
    Map<String, dynamic> record,
    List<String> words,
  ) {
    final text = _normalizeValue(record);
    return words.any((word) => text.contains(word));
  }

  bool _valueMatchesQuery(dynamic value, String normalizedText) {
    if (value == null) return false;
    if (value is List) {
      return value.any((item) => _valueMatchesQuery(item, normalizedText));
    }
    if (value is Map) {
      return value.values.any(
        (item) => _valueMatchesQuery(item, normalizedText),
      );
    }

    final normalizedValue = _normalizeValue(value);
    if (normalizedValue.isEmpty) return false;
    if (normalizedText.contains(normalizedValue)) return true;

    final valueWords = _tokenize(
      normalizedValue,
    ).where((word) => word.length > 3).toList();
    final queryWords = _queryWords(normalizedText);

    return valueWords.any(
      (valueWord) => queryWords.any(
        (queryWord) =>
            valueWord == queryWord ||
            (queryWord.length > 4 && valueWord.contains(queryWord)) ||
            (valueWord.length > 4 && queryWord.contains(valueWord)) ||
            _levenshtein(valueWord, queryWord) <= 1,
      ),
    );
  }

  bool _ingredientNameMatches(
    Map<String, dynamic> ingredient,
    String normalizedText,
  ) {
    return _scoreIngredient(ingredient, normalizedText) > 0;
  }

  int _scoreIngredient(Map<String, dynamic> ingredient, String normalizedText) {
    final name = _normalizeValue(ingredient['name']);
    if (name.isEmpty) return 0;
    if (normalizedText.contains(name)) return 100;

    final nameWords = _tokenize(name).where((word) => word.length > 2).toList();
    final queryWords = _queryWords(normalizedText);
    if (nameWords.isEmpty || queryWords.isEmpty) return 0;

    final matchedNameWords = nameWords.where((nameWord) {
      return queryWords.any(
        (queryWord) =>
            nameWord == queryWord ||
            (queryWord.length > 4 && nameWord.contains(queryWord)) ||
            (nameWord.length > 4 && queryWord.contains(nameWord)) ||
            _levenshtein(nameWord, queryWord) <= 1,
      );
    }).length;

    if (matchedNameWords == nameWords.length) return 70;
    if (matchedNameWords > 0) return 35 + matchedNameWords;
    return 0;
  }

  int _scoreRecipe(Map<String, dynamic> recipe, String normalizedText) {
    var score = _scoreTextMatch(recipe['title'], normalizedText) * 4;
    score += _scoreRecord(recipe, normalizedText);
    score += (((recipe['avgRating'] ?? 0) as num).toDouble() * 2).round();
    return score;
  }

  int _scoreProgram(Map<String, dynamic> program, String normalizedText) {
    return (_scoreTextMatch(program['name'], normalizedText) * 4) +
        _scoreRecord(program, normalizedText);
  }

  int _scoreRecord(Map<String, dynamic> record, String normalizedText) {
    final text = _normalizeValue(record);
    return _queryWords(
      normalizedText,
    ).where((word) => word.length > 3 && text.contains(word)).length;
  }

  int _scoreTextMatch(dynamic value, String normalizedText) {
    final text = _normalizeValue(value);
    if (text.isEmpty) return 0;
    if (normalizedText.contains(text)) return 10;
    return _queryWords(normalizedText)
        .where(
          (word) =>
              text.contains(word) ||
              _tokenize(text).any((part) => _levenshtein(part, word) <= 1),
        )
        .length;
  }

  int _recommendationScore(Map<String, dynamic> recipe, String normalizedText) {
    var score = _scoreRecipe(recipe, normalizedText);
    final profile = _cache.userProfile;
    final targetCalories = (profile?['targetCalories'] as num?)?.toDouble();
    final recipeCalories = (recipe['caloriesPerServing'] as num?)?.toDouble();
    if (targetCalories != null && recipeCalories != null) {
      final mealTarget = targetCalories / 4;
      score += math
          .max(0, 10 - ((recipeCalories - mealTarget).abs() / 80))
          .round();
    }
    return score;
  }

  Map<String, dynamic> _chooseRandomRecommendedRecipe(
    List<Map<String, dynamic>> recipes,
    String normalizedText,
  ) {
    final scoredRecipes =
        recipes
            .map(
              (recipe) => MapEntry(
                recipe,
                _recommendationScore(recipe, normalizedText),
              ),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    final bestScore = scoredRecipes.first.value;
    final openRecommendation = _asksForOpenRecipeRecommendation(normalizedText);
    final candidateFloor = openRecommendation ? 0 : math.max(0, bestScore - 4);
    var candidates = scoredRecipes
        .where((entry) => entry.value >= candidateFloor)
        .map((entry) => entry.key)
        .toList();

    if (candidates.length > 1) {
      candidates = candidates
          .where(
            (recipe) =>
                !_recentRecipeRecommendationIds.contains(_recipeId(recipe)),
          )
          .toList();
      if (candidates.isEmpty) {
        _recentRecipeRecommendationIds.clear();
        candidates = scoredRecipes
            .where((entry) => entry.value >= candidateFloor)
            .map((entry) => entry.key)
            .toList();
      }
    }

    final selected = candidates[_random.nextInt(candidates.length)];
    _rememberRecipeRecommendation(selected);
    return selected;
  }

  void _rememberRecipeRecommendation(Map<String, dynamic> recipe) {
    final id = _recipeId(recipe);
    if (id.isEmpty) return;
    _recentRecipeRecommendationIds.remove(id);
    _recentRecipeRecommendationIds.insert(0, id);
    if (_recentRecipeRecommendationIds.length > 5) {
      _recentRecipeRecommendationIds.removeLast();
    }
  }

  String _recipeId(Map<String, dynamic> recipe) {
    final id = (recipe['id'] ?? '').toString();
    if (id.isNotEmpty) return id;
    return (recipe['title'] ?? '').toString();
  }

  Map<String, dynamic> _chooseRandomRecommendedProgram(
    List<Map<String, dynamic>> programs,
    Map<String, dynamic> prefs,
    String normalizedText,
  ) {
    final scoredPrograms =
        programs
            .map(
              (program) => MapEntry(
                program,
                _programPreferenceScore(program, prefs, normalizedText),
              ),
            )
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));

    var candidates = scoredPrograms.map((entry) => entry.key).toList();

    if (candidates.length > 1) {
      candidates = candidates
          .where(
            (program) =>
                !_recentProgramRecommendationIds.contains(_programId(program)),
          )
          .toList();
      if (candidates.isEmpty) {
        _recentProgramRecommendationIds.clear();
        candidates = scoredPrograms.map((entry) => entry.key).toList();
      }
    }

    final selected = candidates[_random.nextInt(candidates.length)];
    _rememberProgramRecommendation(selected);
    return selected;
  }

  void _rememberProgramRecommendation(Map<String, dynamic> program) {
    final id = _programId(program);
    if (id.isEmpty) return;
    _recentProgramRecommendationIds.remove(id);
    _recentProgramRecommendationIds.insert(0, id);
    if (_recentProgramRecommendationIds.length > 5) {
      _recentProgramRecommendationIds.removeLast();
    }
  }

  String _programId(Map<String, dynamic> program) {
    final id = (program['id'] ?? '').toString();
    if (id.isNotEmpty) return id;
    return (program['name'] ?? '').toString();
  }

  int _programPreferenceScore(
    Map<String, dynamic> program,
    Map<String, dynamic> prefs,
    String normalizedText,
  ) {
    var score = _scoreProgram(program, normalizedText);
    for (final value in prefs.values) {
      if (_valueMatchesQuery(value, _normalizeValue(program))) score += 3;
    }
    return score;
  }

  bool _programHasAny(Map<String, dynamic> program, List<String> terms) {
    final text = _normalizeValue(program);
    return terms.any((term) => text.contains(term));
  }

  bool _recipeHasValue(Map<String, dynamic> recipe, String value) {
    final target = _removeAccents(value.toLowerCase());
    return _normalizeValue(recipe).contains(target);
  }

  bool _recipeContainsAny(Map<String, dynamic> recipe, List<String> allergies) {
    return _firstRecipeAllergen(recipe, allergies) != null;
  }

  String? _firstRecipeAllergen(
    Map<String, dynamic> recipe,
    List<String> allergies,
  ) {
    if (allergies.isEmpty) return null;
    final text = _normalizeValue(recipe);
    final ingredientCategories = _recipeIngredientCategories(recipe);

    for (final allergy in allergies) {
      final normalizedAllergy = _removeAccents(allergy.toLowerCase());
      if (text.contains(normalizedAllergy)) return allergy;
      if (ingredientCategories.any((cat) => cat.contains(normalizedAllergy))) {
        return allergy;
      }
      if (normalizedAllergy == "γαλακτοκομικα" &&
          (text.contains("γαλα") ||
              text.contains("τυρι") ||
              text.contains("φετα") ||
              text.contains("γιαουρτι") ||
              ingredientCategories.any((cat) => cat.contains("γαλακτοκομ")))) {
        return allergy;
      }
    }
    return null;
  }

  List<String> _recipeIngredientCategories(Map<String, dynamic> recipe) {
    final recipeIngredientNames = _asList(recipe['ingredients'])
        .map(
          (ing) =>
              ing is Map ? _normalizeValue(ing['name']) : _normalizeValue(ing),
        )
        .where((name) => name.isNotEmpty)
        .toList();

    return _cache.ingredients
        .where(
          (ing) => recipeIngredientNames.any(
            (name) => _normalizeValue(ing['name']) == name,
          ),
        )
        .map((ing) => _normalizeValue(ing['category']))
        .where((category) => category.isNotEmpty)
        .toList();
  }

  String _formatRecipeIngredients(Map<String, dynamic> recipe) {
    return _asList(recipe['ingredients'])
        .map((ing) {
          if (ing is Map) {
            final name = ing['name'] ?? '-';
            final amount = ing['amount'];
            return amount == null || amount == 0
                ? name.toString()
                : "$name (${amount}g)";
          }
          return ing.toString();
        })
        .join(', ');
  }

  List<String> _recipeCategories(Map<String, dynamic> recipe) {
    final categories = <String>[];
    if (recipe['category'] != null) {
      categories.add(recipe['category'].toString());
    }
    categories.addAll(_asStringList(recipe['categories']));
    return categories.toSet().toList();
  }

  String? _targetMealCategory(String normalizedText) {
    if (normalizedText.contains("πρωινο") || normalizedText.contains("πρωι")) {
      return "Πρωινό";
    }
    if (normalizedText.contains("μεσημεριανο")) return "Μεσημεριανό";
    if (normalizedText.contains("βραδινο")) return "Βραδινό";
    if (normalizedText.contains("σνακ")) return "Σνακ";
    if (normalizedText.contains("επιδορπιο")) return "Επιδόρπιο";
    if (normalizedText.contains("ροφημα")) return "Ροφήματα";
    return null;
  }

  List<String> _wantedTags(String normalizedText) {
    final tags = <String>[];
    if (normalizedText.contains("protein") ||
        normalizedText.contains("πρωτειν")) {
      tags.add("High Protein");
    }
    if (normalizedText.contains("vegan")) tags.add("Vegan");
    if (normalizedText.contains("vegetarian")) tags.add("Vegetarian");
    if (normalizedText.contains("low carb") ||
        normalizedText.contains("λιγους υδατανθρακ")) {
      tags.add("Low Carb");
    }
    if (normalizedText.contains("γρηγορ")) tags.add("Γρήγορη");
    return tags;
  }

  String? _inferAskedAmount(String normalizedText) {
    if (normalizedText.contains("ανα 100") || normalizedText.contains("100g")) {
      return null;
    }
    if (normalizedText.contains("ενα ") ||
        normalizedText.contains("μια ") ||
        normalizedText.contains("1 ")) {
      return "αν εννοείς 1 τεμάχιο, χρειάζεται το βάρος του για ακριβή υπολογισμό";
    }
    return null;
  }

  bool _ingredientMatchesAllergy(
    Map<String, dynamic> ingredient,
    List<String> activeAllergies,
  ) {
    final name = _normalizeValue(ingredient['name']);
    return activeAllergies.any(
      (allergy) => name.contains(_removeAccents(allergy.toLowerCase())),
    );
  }

  double? _extractGramAmount(String normalizedText) {
    final match = RegExp(
      r'(\d+(?:[.,]\d+)?)\s*(?:g|gr|γραμ|γραμμα|γραμμαρια)',
    ).firstMatch(normalizedText);
    if (match == null) return null;
    return double.tryParse(match.group(1)!.replaceAll(',', '.'));
  }

  double? _extractIngredientGramAmount(
    Map<String, dynamic> ingredient,
    String normalizedText,
  ) {
    final ingredientWords = _tokenize(
      _normalizeValue(ingredient['name']),
    ).where((word) => word.length > 2).map(RegExp.escape).toList();
    if (ingredientWords.isEmpty) return null;

    final amountPattern = r'(\d+(?:[.,]\d+)?)\s*(?:g|gr|γραμ|γραμμα|γραμμαρια)';
    for (final word in ingredientWords) {
      final beforeIngredient = RegExp(
        '$amountPattern(?:\\s+\\S+){0,1}\\s+$word',
      ).firstMatch(normalizedText);
      if (beforeIngredient != null) {
        return double.tryParse(beforeIngredient.group(1)!.replaceAll(',', '.'));
      }

      final afterIngredient = RegExp(
        '$word(?:\\s+\\S+){0,1}\\s+$amountPattern',
      ).firstMatch(normalizedText);
      if (afterIngredient != null) {
        return double.tryParse(afterIngredient.group(1)!.replaceAll(',', '.'));
      }
    }

    return null;
  }

  double _recipeMacro(
    Map<String, dynamic> recipe,
    String totalKey,
    String legacyKey,
  ) {
    final totalValue = _toDouble(recipe[totalKey]);
    if (totalValue > 0) return totalValue;

    final legacyValue = _toDouble(recipe[legacyKey]);
    if (legacyValue > 0) return legacyValue;

    return _calculateRecipeMacroFromIngredients(recipe, legacyKey);
  }

  double _calculateRecipeMacroFromIngredients(
    Map<String, dynamic> recipe,
    String macroKey,
  ) {
    var total = 0.0;
    for (final ingredient in _asList(recipe['ingredients'])) {
      if (ingredient is! Map) continue;
      final amount = _toDouble(ingredient['amount']);
      if (amount <= 0) continue;

      final per100g = switch (macroKey) {
        'protein' => _toDouble(ingredient['proteinPer100g']),
        'carbs' => _toDouble(ingredient['carbsPer100g']),
        'fats' => _toDouble(ingredient['fatsPer100g']),
        _ => 0.0,
      };
      total += amount * per100g / 100;
    }
    return total;
  }

  double _toDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString().replaceAll(',', '.') ?? '') ?? 0;
  }

  String _formatNumber(double value) {
    if (value == 0) return "0";
    if (value == value.roundToDouble()) return value.round().toString();
    return value.toStringAsFixed(1);
  }

  Map<String, int> _groupCount(List<Map<String, dynamic>> records, String key) {
    final counts = <String, int>{};
    for (final record in records) {
      final value = (record[key] ?? '-').toString();
      counts[value] = (counts[value] ?? 0) + 1;
    }
    return counts;
  }

  String _formatCounts(Map<String, int> counts) {
    if (counts.isEmpty) return "-";
    final entries = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries.take(8).map((e) => "${e.key}: ${e.value}").join(', ');
  }

  String _formatFitnessPreferences(Map<String, dynamic> prefs) {
    if (prefs.isEmpty) return "-";
    final parts = <String>[];
    if (prefs['location'] != null) parts.add("χώρος ${prefs['location']}");
    if (prefs['intensity'] != null) parts.add("ένταση ${prefs['intensity']}");
    if (prefs['duration'] != null) parts.add("διάρκεια ${prefs['duration']}");
    return parts.isEmpty ? "-" : parts.join(', ');
  }

  String _waterText(dynamic value) {
    switch ((value as num?)?.toInt()) {
      case 1:
        return 'λιγότερο από 1 λίτρο';
      case 2:
        return 'περίπου 1 λίτρο';
      case 3:
        return '1.5 λίτρα';
      case 4:
        return '2 λίτρα';
      case 5:
        return 'πάνω από 2.5 λίτρα';
      default:
        return '-';
    }
  }

  List<dynamic> _asList(dynamic value) => value is List ? value : const [];

  List<String> _asStringList(dynamic value) =>
      value is List ? value.map((item) => item.toString()).toList() : [];

  List<String> _recipeSpecificQueryWords(String normalizedText) => _queryWords(
    normalizedText,
  ).where((word) => !_genericRecipeQueryWords.contains(word)).toList();

  List<String> _fitnessSpecificQueryWords(String normalizedText) =>
      _expandFitnessTerms(
        _queryWords(
          normalizedText,
        ).where((word) => !_genericFitnessQueryWords.contains(word)).toList(),
      );

  List<String> _queryWords(String normalizedText) => _tokenize(normalizedText)
      .where((word) => word.length > 2 && !_ignoredQueryWords.contains(word))
      .toList();

  List<String> _tokenize(String normalizedText) => normalizedText
      .split(RegExp(r'[^α-ωa-z0-9]+'))
      .where((word) => word.isNotEmpty)
      .toList();

  List<String> _expandFitnessTerms(List<String> words) {
    final expanded = <String>{};
    for (final word in words) {
      expanded.add(word);
      final aliases = _fitnessTermAliases[word];
      if (aliases != null) expanded.addAll(aliases);
    }
    return expanded.toList();
  }

  static const Set<String> _ignoredQueryWords = {
    'ποσες',
    'ποσοι',
    'ποσα',
    'ποση',
    'θερμιδες',
    'θερμιδων',
    'θερμιδ',
    'εχει',
    'εχουν',
    'ειναι',
    'ενα',
    'μια',
    'ενας',
    'στο',
    'στη',
    'στην',
    'στον',
    'του',
    'της',
    'των',
    'και',
    'για',
    'μου',
    'σου',
    'ανα',
    'ποια',
    'ποιο',
    'ποιος',
    'τι',
  };

  static const Set<String> _genericRecipeQueryWords = {
    'συνταγη',
    'συνταγες',
    'προτεινε',
    'προταση',
    'προτασεις',
    'τυχαιο',
    'τυχαια',
    'ιδεα',
    'ιδεες',
    'φαω',
    'φαγητο',
    'γευμα',
    'πρωινο',
    'πρωι',
    'μεσημεριανο',
    'βραδινο',
    'σνακ',
    'επιδορπιο',
    'ροφημα',
    'γρηγορο',
    'γρηγορη',
    'γρηγορα',
    'vegan',
    'vegetarian',
    'protein',
    'high',
    'low',
    'carb',
    'πρωτεινη',
    'πρωτεινικο',
    'πρωτεινικη',
    'λιγους',
    'υδατανθρακες',
    'θελω',
    'δωσε',
    'κανε',
    'κατι',
  };

  static const Set<String> _genericFitnessQueryWords = {
    'ασκηση',
    'ασκησεις',
    'ασκησεων',
    'γυμναστικη',
    'γυμναστικης',
    'προπονηση',
    'προπονησεις',
    'προγραμμα',
    'προγραμματα',
    'θελω',
    'κανω',
    'κανε',
    'δωσε',
    'προτεινε',
    'προταση',
    'καλο',
    'καλη',
    'σπιτι',
    'γυμναστηριο',
  };

  static const Map<String, List<String>> _fitnessTermAliases = {
    'πλατη': [
      'πλατη',
      'ραχη',
      'ραχιαι',
      'back',
      'lats',
      'ελξεις',
      'κωπηλατικη',
      'βαρη',
      'ενδυναμωση',
      'yoga',
      'pilates',
    ],
    'πλατης': [
      'πλατη',
      'ραχη',
      'ραχιαι',
      'back',
      'lats',
      'ελξεις',
      'κωπηλατικη',
      'βαρη',
      'ενδυναμωση',
      'yoga',
      'pilates',
    ],
    'δικεφαλα': ['δικεφαλ', 'biceps', 'curl', 'curls'],
    'δικεφαλων': ['δικεφαλ', 'biceps', 'curl', 'curls'],
    'τρικεφαλα': ['τρικεφαλ', 'triceps'],
    'τρικεφαλων': ['τρικεφαλ', 'triceps'],
    'στηθος': ['στηθος', 'chest', 'push', 'πιεσεις'],
    'ποδια': ['ποδια', 'legs', 'squat', 'καθισματα'],
    'κοιλιακοι': ['κοιλιακ', 'abs', 'core'],
    'ωμοι': ['ωμ', 'shoulder', 'shoulders'],
  };

  String _normalizeValue(dynamic value) =>
      _removeAccents(value.toString().toLowerCase());

  String _removeAccents(String text) {
    const withDia = 'άέήίϊΐόύϋΰώΆΈΉΊΪΌΎΫΏ';
    const withoutDia = 'αεηιιιουυυωΑΕΗΙΙΟΥΥΩ';
    var result = text;
    for (var i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result;
  }

  int _levenshtein(String s1, String s2) {
    final costs = List<int>.generate(s2.length + 1, (i) => i);
    for (var i = 1; i <= s1.length; i++) {
      var lastValue = i - 1;
      costs[0] = i;
      for (var j = 1; j <= s2.length; j++) {
        final newValue = (s1[i - 1] == s2[j - 1])
            ? lastValue
            : math.min(math.min(lastValue + 1, costs[j] + 1), costs[j - 1] + 1);

        lastValue = costs[j];
        costs[j] = newValue;
      }
    }
    return costs.last;
  }
}
