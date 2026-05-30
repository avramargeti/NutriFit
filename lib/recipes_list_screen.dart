import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ingredients_list_screen.dart';
import 'edit_recipe_screen.dart';
import 'recipe_service.dart';
import 'review_recipe.dart';
import 'cooking_book_service.dart';

class RecipesListScreen extends StatefulWidget {
  const RecipesListScreen({super.key});

  @override
  State<RecipesListScreen> createState() => _RecipesListScreenState();
}

class _RecipesListScreenState extends State<RecipesListScreen> {
  String searchQuery = "";
  List<String> fridgeIngredients = [];

  String selectedMealTypeFilter = "Όλα";
  final List<String> mealTypes = [
    "Όλα",
    "Πρωινό",
    "Σνακ",
    "Μεσημεριανό",
    "Βραδινό",
    "Επιδόρπιο",
    "Ροφήματα",
  ];

  List<String> userAllergies = [];

  late Stream<QuerySnapshot> _recipesStream;

  List<String> selectedFoodTypes = [];
  List<String> selectedDietaryTags = [];

  List<String> tempFoodTypes = [];
  List<String> tempDietaryTags = [];

  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);

  @override
  void initState() {
    super.initState();
    _recipesStream = FirebaseFirestore.instance
        .collection('recipes')
        .snapshots();
    _loadUserAllergies();
  }

  Future<void> _loadUserAllergies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists && doc.data()!.containsKey('allergies')) {
          setState(() {
            userAllergies = List<String>.from(doc.data()!['allergies']);
          });
        }
      } catch (e) {
        debugPrint('Σφάλμα κατά τη φόρτωση αλλεργιών: $e');
      }
    }
  }

  void _addFridgeIngredient() async {
    final selectedIngredientData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) =>
            const IngredientsListScreen(isSelectionMode: true),
      ),
    );

    if (!mounted) return;

    if (selectedIngredientData != null &&
        selectedIngredientData is Map<String, dynamic>) {
      String ingName = selectedIngredientData['name'];
      String ingCategory = selectedIngredientData['category'] ?? "";
      List<String> ingredientAllergens = List<String>.from(
        selectedIngredientData['allergens'] ?? [],
      );

      bool hasAllergen =
          ingredientAllergens.any(
            (allergen) => userAllergies.contains(allergen),
          ) ||
          userAllergies.contains(ingName) ||
          userAllergies.contains(ingCategory);

      if (hasAllergen) {
        List<String> triggeredItems = [];
        triggeredItems.addAll(
          ingredientAllergens.where((a) => userAllergies.contains(a)),
        );
        if (userAllergies.contains(ingName)) {
          triggeredItems.add(ingName);
        }
        if (userAllergies.contains(ingCategory) &&
            !triggeredItems.contains(ingCategory)) {
          triggeredItems.add(ingCategory);
        }

        String warningText = triggeredItems.join(", ");

        bool? continueAnyway = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.orange),
                SizedBox(width: 8),
                Text('Προσοχή Αλλεργιογόνο!'),
              ],
            ),
            content: Text(
              'Το υλικό "$ingName" εμπίπτει στις αλλεργίες/δυσανεξίες σας ($warningText).\nΣυνέχεια;',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text(
                  'ΑΦΑΙΡΕΣΗ',
                  style: TextStyle(color: Colors.red),
                ),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('ΝΑΙ, ΣΥΝΕΧΕΙΑ'),
              ),
            ],
          ),
        );

        if (!mounted) return;

        if (continueAnyway != true) return;
      }

      if (!fridgeIngredients.contains(ingName)) {
        setState(() => fridgeIngredients.add(ingName));
      }
    }
  }

  Widget _buildFilterDrawer() {
    return Drawer(
      child: Column(
        children: [
          AppBar(
            title: const Text('Φίλτρα'),
            automaticallyImplyLeading: false,
            actions: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () {
                  setState(() {
                    tempFoodTypes = List.from(selectedFoodTypes);
                    tempDietaryTags = List.from(selectedDietaryTags);
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildFilterSection("Είδος Φαγητού", [
                  "Μακαρονάδες",
                  "Σούπες",
                  "Λαδερά",
                  "Φούρνου",
                  "Ψητά",
                  "Ριζότο",
                ], tempFoodTypes),
                const Divider(height: 30),
                _buildFilterSection("Διατροφικές Επιλογές", [
                  "High Protein",
                  "Dairy-Free",
                  "Low Carb",
                  "Γρήγορη",
                  "Gluten-Free",
                  "Vegan",
                  "Vegetarian",
                ], tempDietaryTags),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => setState(() {
                      tempFoodTypes.clear();
                      tempDietaryTags.clear();
                    }),
                    child: const Text('Καθαρισμός'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: sageGreen,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      setState(() {
                        selectedFoodTypes = List.from(tempFoodTypes);
                        selectedDietaryTags = List.from(tempDietaryTags);
                      });
                      Navigator.pop(context);
                    },
                    child: const Text('Εφαρμογή'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(
    String title,
    List<String> options,
    List<String> selectedList,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: options.map((opt) {
            final isSelected = selectedList.contains(opt);
            return FilterChip(
              label: Text(opt),
              selected: isSelected,
              onSelected: (val) => setState(
                () => val ? selectedList.add(opt) : selectedList.remove(opt),
              ),
              selectedColor: sageGreen.withValues(alpha: 0.3),
              checkmarkColor: sageGreen,
            );
          }).toList(),
        ),
      ],
    );
  }

  void _showRecipeDetails(String recipeId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: RecipeDetailsSheet(recipeId: recipeId, data: data),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Συνταγές', style: TextStyle(color: Colors.white)),
        backgroundColor: sageGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        actions: [
          Builder(
            builder: (context) => IconButton(
              icon: const Icon(Icons.tune),
              onPressed: () {
                setState(() {
                  tempFoodTypes = List.from(selectedFoodTypes);
                  tempDietaryTags = List.from(selectedDietaryTags);
                });
                Scaffold.of(context).openEndDrawer();
              },
            ),
          ),
        ],
      ),
      endDrawer: _buildFilterDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Αναζήτηση συνταγής...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onChanged: (val) =>
                  setState(() => searchQuery = removeAccents(val)),
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: mealTypes.map((type) {
                final isSelected = selectedMealTypeFilter == type;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(type),
                    selected: isSelected,
                    onSelected: (val) =>
                        setState(() => selectedMealTypeFilter = type),
                    selectedColor: sageGreen,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : slateGrey,
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),

          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Τι έχω στο ψυγείο μου;',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: slateGrey,
                      ),
                    ),
                    if (fridgeIngredients.isNotEmpty)
                      TextButton(
                        onPressed: () =>
                            setState(() => fridgeIngredients.clear()),
                        child: const Text(
                          'Καθαρισμός',
                          style: TextStyle(
                            color: Colors.redAccent,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    ...fridgeIngredients.map(
                      (ing) => InputChip(
                        label: Text(ing),
                        backgroundColor: sageGreen.withValues(alpha: 0.1),
                        onDeleted: () =>
                            setState(() => fridgeIngredients.remove(ing)),
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.add,
                        size: 16,
                        color: Colors.white,
                      ),
                      label: const Text(
                        'Προσθήκη',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: slateGrey,
                      onPressed: _addFridgeIngredient,
                    ),
                  ],
                ),
              ],
            ),
          ),
          const Divider(height: 20),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _recipesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(child: Text('Σφάλμα σύνδεσης'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }

                List<QueryDocumentSnapshot> displayList = [];

                for (var doc in snapshot.data!.docs) {
                  var data = doc.data() as Map<String, dynamic>;

                  String rawTitle = (data['title'] ?? '').toString();
                  String searchTitle = removeAccents(rawTitle);

                  List<String> recipeCats = [];
                  if (data['categories'] != null) {
                    recipeCats = List<String>.from(data['categories']);
                  } else if (data['category'] != null) {
                    recipeCats = [data['category']];
                  }

                  List<String> recipeTags = List<String>.from(
                    data['tags'] ?? [],
                  );
                  List ingredientsList = data['ingredients'] as List;

                  if (searchQuery.isNotEmpty &&
                      !searchTitle.contains(searchQuery)) {
                    continue;
                  }

                  if (selectedMealTypeFilter != "Όλα" &&
                      !recipeCats.contains(selectedMealTypeFilter)) {
                    continue;
                  }

                  if (selectedFoodTypes.isNotEmpty &&
                      !selectedFoodTypes.any((t) => recipeCats.contains(t))) {
                    continue;
                  }
                  if (selectedDietaryTags.isNotEmpty &&
                      !selectedDietaryTags.every(
                        (t) => recipeTags.contains(t),
                      )) {
                    continue;
                  }

                  if (fridgeIngredients.isEmpty) {
                    displayList.add(doc);
                  } else {
                    int matchCount = 0;
                    for (var recIng in ingredientsList) {
                      if (fridgeIngredients.contains(recIng['name'])) {
                        matchCount++;
                      }
                    }
                    if (matchCount >= 1) {
                      displayList.add(doc);
                    }
                  }
                }

                if (fridgeIngredients.isNotEmpty) {
                  displayList.sort((a, b) {
                    var aData = a.data() as Map<String, dynamic>;
                    var bData = b.data() as Map<String, dynamic>;
                    int aMissing = (aData['ingredients'] as List)
                        .where((i) => !fridgeIngredients.contains(i['name']))
                        .length;
                    int bMissing = (bData['ingredients'] as List)
                        .where((i) => !fridgeIngredients.contains(i['name']))
                        .length;
                    return aMissing.compareTo(bMissing);
                  });
                }

                if (displayList.isEmpty) {
                  return const Center(child: Text("Δεν βρέθηκαν συνταγές."));
                }

                return Column(
                  children: [
                    if (fridgeIngredients.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.all(12),
                        color: sageGreen.withValues(alpha: 0.1),
                        width: double.infinity,
                        child: Text(
                          'Συνταγές με βάση τα υλικά σας (${displayList.length})',
                          style: TextStyle(
                            color: sageGreen,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    Expanded(
                      child: ListView.builder(
                        itemCount: displayList.length,
                        itemBuilder: (context, index) {
                          var doc = displayList[index];
                          var data = doc.data() as Map<String, dynamic>;

                          List<String> recipeCats = [];
                          if (data['categories'] != null) {
                            recipeCats = List<String>.from(data['categories']);
                          } else if (data['category'] != null) {
                            recipeCats = [data['category']];
                          }

                          List ingredientsList = data['ingredients'] as List;
                          List<String> missingIngredients = [];

                          if (fridgeIngredients.isNotEmpty) {
                            for (var recIng in ingredientsList) {
                              if (!fridgeIngredients.contains(recIng['name'])) {
                                missingIngredients.add(recIng['name']);
                              }
                            }
                          }

                          return Card(
                            margin: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            child: ListTile(
                              leading:
                                  (data['imageUrl'] != null &&
                                      data['imageUrl'].toString().isNotEmpty)
                                  ? Image.network(
                                      data['imageUrl'],
                                      width: 50,
                                      height: 50,
                                      fit: BoxFit.cover,
                                      errorBuilder: (c, e, s) => Icon(
                                        Icons.restaurant_menu,
                                        color: sageGreen,
                                      ),
                                    )
                                  : Icon(
                                      Icons.restaurant_menu,
                                      color: sageGreen,
                                    ),
                              title: Text(
                                data['title'] ?? 'Χωρίς Τίτλο',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "${recipeCats.join(", ")} • ${data['caloriesPerServing'] ?? 0} kcal",
                                  ),
                                  if (missingIngredients.isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(top: 4.0),
                                      child: Text(
                                        missingIngredients.length == 1
                                            ? 'Λείπει: ${missingIngredients.first}'
                                            : 'Λείπουν: ${missingIngredients.join(", ")}',
                                        style: const TextStyle(
                                          color: Colors.redAccent,
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                ],
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  if (data['avgRating'] != null &&
                                      (data['avgRating'] as num) > 0)
                                    Row(
                                      children: [
                                        Text(
                                          (data['avgRating'] as num)
                                              .toStringAsFixed(1),
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.amber,
                                          ),
                                        ),
                                        const Icon(
                                          Icons.star,
                                          color: Colors.amber,
                                          size: 18,
                                        ),
                                        const SizedBox(width: 8),
                                      ],
                                    ),
                                  const Icon(Icons.arrow_forward_ios, size: 14),
                                ],
                              ),
                              onTap: () => _showRecipeDetails(doc.id, data),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class RecipeDetailsSheet extends StatefulWidget {
  final String recipeId;
  final Map<String, dynamic> data;
  final String? diaryCategory;
  final String? diaryDateString;

  const RecipeDetailsSheet({
    super.key,
    required this.recipeId,
    required this.data,
    this.diaryCategory,
    this.diaryDateString,
  });

  @override
  State<RecipeDetailsSheet> createState() => _RecipeDetailsSheetState();
}

class _RecipeDetailsSheetState extends State<RecipeDetailsSheet> {
  late int _selectedServings;
  late int _originalServings;
  final Set<String> _excludedIngredientKeys = {};
  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);
  final RecipeService _recipeService = RecipeService();

  final CookingBookService _cookingBookService = CookingBookService();

  bool get _isDiaryLogging =>
      widget.diaryCategory != null && widget.diaryDateString != null;

  @override
  void initState() {
    super.initState();
    _originalServings = _asInt(widget.data['servings']);
    if (_originalServings < 1) _originalServings = 1;
    _selectedServings = _originalServings;
  }

  int _asInt(dynamic value) {
    if (value is num) return value.round();
    return num.tryParse(value?.toString() ?? '')?.round() ?? 0;
  }

  int _totalValue(String totalKey, String perServingKey) {
    final total = _asInt(widget.data[totalKey]);
    if (total > 0) return total;

    return _asInt(widget.data[perServingKey]) * _originalServings;
  }

  double _asDouble(dynamic value) {
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0.0;
  }

  List<Map<String, dynamic>> _recipeIngredients() {
    final ingredients = widget.data['ingredients'];
    if (ingredients is! List) return [];

    return ingredients
        .whereType<Map>()
        .map((ingredient) => Map<String, dynamic>.from(ingredient))
        .toList();
  }

  String _ingredientKey(Map<String, dynamic> ingredient, int index) {
    return '${ingredient['name'] ?? 'ingredient'}-${ingredient['amount'] ?? 0}-$index';
  }

  Map<String, double> _ingredientTotals(
    Map<String, dynamic> ingredient,
    double multiplier,
  ) {
    final amount = _asDouble(ingredient['amount']) * multiplier;
    final ratio = amount / 100.0;

    return {
      'calories': ratio * _asDouble(ingredient['caloriesPer100g']),
      'protein': ratio * _asDouble(ingredient['proteinPer100g']),
      'carbs': ratio * _asDouble(ingredient['carbsPer100g']),
      'fats': ratio * _asDouble(ingredient['fatsPer100g']),
      'amount': amount,
    };
  }

  Map<String, int> _displayTotals(double multiplier) {
    final ingredients = _recipeIngredients();
    double calories = 0;
    double protein = 0;
    double carbs = 0;
    double fats = 0;

    for (final indexedIngredient in ingredients.asMap().entries) {
      final key = _ingredientKey(
        indexedIngredient.value,
        indexedIngredient.key,
      );
      if (_excludedIngredientKeys.contains(key)) continue;

      final totals = _ingredientTotals(indexedIngredient.value, multiplier);
      calories += totals['calories'] ?? 0;
      protein += totals['protein'] ?? 0;
      carbs += totals['carbs'] ?? 0;
      fats += totals['fats'] ?? 0;
    }

    final hasIngredientNutrition =
        calories > 0 || protein > 0 || carbs > 0 || fats > 0;
    if (!hasIngredientNutrition && _excludedIngredientKeys.isEmpty) {
      return {
        'calories':
            (_totalValue('totalCalories', 'caloriesPerServing') * multiplier)
                .round(),
        'protein':
            (_totalValue('totalProtein', 'proteinPerServing') * multiplier)
                .round(),
        'carbs': (_totalValue('totalCarbs', 'carbsPerServing') * multiplier)
            .round(),
        'fats': (_totalValue('totalFats', 'fatsPerServing') * multiplier)
            .round(),
      };
    }

    return {
      'calories': calories.round(),
      'protein': protein.round(),
      'carbs': carbs.round(),
      'fats': fats.round(),
    };
  }

  List<Map<String, dynamic>> _ingredientBreakdown(double multiplier) {
    return _recipeIngredients().asMap().entries.map((indexedIngredient) {
      final ingredient = indexedIngredient.value;
      final key = _ingredientKey(ingredient, indexedIngredient.key);
      final totals = _ingredientTotals(ingredient, multiplier);
      return {
        'name': ingredient['name'] ?? 'Υλικό',
        'amount': (totals['amount'] ?? 0).round(),
        'calories': (totals['calories'] ?? 0).round(),
        'protein': (totals['protein'] ?? 0).round(),
        'carbs': (totals['carbs'] ?? 0).round(),
        'fats': (totals['fats'] ?? 0).round(),
        'excluded': _excludedIngredientKeys.contains(key),
      };
    }).toList();
  }

  Future<void> _addRecipeToDiary() async {
    final user = FirebaseAuth.instance.currentUser;
    final diaryDateString = widget.diaryDateString;
    final diaryCategory = widget.diaryCategory;
    if (user == null || diaryDateString == null || diaryCategory == null) {
      return;
    }

    final multiplier = _selectedServings / _originalServings;
    final totals = _displayTotals(multiplier);
    final ingredientBreakdown = _ingredientBreakdown(multiplier);
    final usedIngredients = ingredientBreakdown
        .where((ingredient) => ingredient['excluded'] != true)
        .toList();
    final removedIngredients = ingredientBreakdown
        .where((ingredient) => ingredient['excluded'] == true)
        .toList();

    await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .collection('diary')
        .doc(diaryDateString)
        .set({
          'entries': FieldValue.arrayUnion([
            {
              'name': widget.data['title'] ?? 'Συνταγή',
              'category': diaryCategory,
              'isExercise': false,
              'isRecipe': true,
              'recipeId': widget.recipeId,
              'calories': totals['calories'],
              'protein': totals['protein'],
              'carbs': totals['carbs'],
              'fats': totals['fats'],
              'quantity': _selectedServings,
              'unit': 'μερίδες',
              'ingredientsUsed': usedIngredients,
              'ingredientsRemoved': removedIngredients,
              'loggedAt': Timestamp.now(),
              'imageUrl': widget.data['imageUrl'] ?? '',
            },
          ]),
        }, SetOptions(merge: true));

    if (!mounted) return;
    Navigator.of(context)
      ..pop()
      ..pop();
  }

  Future<void> _addIngredientsToShoppingList(
    List ingredientsList,
    double multiplier,
  ) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Πρέπει να συνδεθείτε για να προσθέσετε υλικά στη λίστα.',
          ),
        ),
      );
      return;
    }

    try {
      final shoppingListRef = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('shoppingList');

      for (var ing in ingredientsList) {
        int newAmount = ((ing['amount'] as num) * multiplier).round();
        String ingredientName = ing['name'];

        String normalizedId = generateIngredientId(ingredientName);

        final docSnapshot = await shoppingListRef.doc(normalizedId).get();

        if (docSnapshot.exists) {
          // Αν υπάρχει διαβάζουμε την παλιά ποσότητα σε γραμμάρια
          var data = docSnapshot.data() as Map<String, dynamic>;
          int existingAmount = data['amount'] ?? 0;

          if (existingAmount > 0) {
            // Αν είχε προέλθει από άλλη συνταγή δηλαδή έχει γραμμάρια αθροίζουμε
            await shoppingListRef.doc(normalizedId).update({
              'amount': existingAmount + newAmount,
              'isChecked': false,
            });
          } else {
            // Αν υπήρχε ως custom προϊόν ελέγχουμε τη λογική της ποσότητας
            String existingQuantity = data['quantity'] ?? '';

            if (existingQuantity.isNotEmpty) {
              String lowerQty = existingQuantity.toLowerCase();

              // Ελέγχουμε αν ο χρήστης αναφέρει ρητά κάποια μονάδα γραμμαρίων
              if (RegExp(
                r'γραμμάρια|γραμμάριο|γραμμαρια|γραμμαριο|γραμμ|γραμ|γρ|grams|gram|gr|g',
              ).hasMatch(lowerQty)) {
                String cleanedQty = lowerQty
                    .replaceAll(
                      RegExp(
                        r'γραμμάρια|γραμμάριο|γραμμαρια|γραμμαριο|γραμμ|γραμ|γρ|grams|gram|gr|g',
                      ),
                      '',
                    )
                    .trim();

                int? parsedGrams = int.tryParse(cleanedQty);

                if (parsedGrams != null) {
                  await shoppingListRef.doc(normalizedId).update({
                    'amount': parsedGrams + newAmount,
                    'quantity': '',
                    'isChecked': false,
                  });
                } else {
                  await shoppingListRef.doc(normalizedId).update({
                    'quantity': '$existingQuantity + ${newAmount}g',
                    'isChecked': false,
                  });
                }
              } else {
                await shoppingListRef.doc(normalizedId).update({
                  'quantity': '$existingQuantity + ${newAmount}g',
                  'isChecked': false,
                });
              }
            } else {
              await shoppingListRef.doc(normalizedId).update({
                'amount': newAmount,
                'isChecked': false,
              });
            }
          }
        } else {
          await shoppingListRef.doc(normalizedId).set({
            'name': ingredientName,
            'amount': newAmount,
            'quantity': '',
            'isChecked': false,
            'addedAt': FieldValue.serverTimestamp(),
          });
        }
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Τα υλικά προστέθηκαν στη Λίστα Super Market! 🛒'),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Σφάλμα κατά την προσθήκη: $e')));
      }
    }
  }

  Future<void> _deleteRecipe() async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Διαγραφή;'),
        content: const Text('Είστε σίγουροι;'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ΑΚΥΡΟ'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ΔΙΑΓΡΑΦΗ', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance
          .collection('recipes')
          .doc(widget.recipeId)
          .delete();
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildMacroBox(
    String title,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      width: 75,
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 14,
              color: color,
            ),
          ),
          Text(
            title,
            style: const TextStyle(fontSize: 10, color: Colors.black54),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    double multiplier = _selectedServings / _originalServings;
    final displayTotals = _displayTotals(multiplier);
    int displayCals = displayTotals['calories'] ?? 0;
    int displayProtein = displayTotals['protein'] ?? 0;
    int displayCarbs = displayTotals['carbs'] ?? 0;
    int displayFats = displayTotals['fats'] ?? 0;
    final ingredientBreakdown = _ingredientBreakdown(multiplier);

    final currentUser = FirebaseAuth.instance.currentUser;
    final List<String> adminEmails = [
      'avramargeti@gmail.com',
      'bokosdimitris@gmail.com',
      'adonopoulouifigeneia@icloud.com',
    ];
    final canEdit =
        currentUser != null &&
        (adminEmails.contains(currentUser.email) ||
            widget.data['userId'] == currentUser.uid);

    List<String> tags = List<String>.from(widget.data['tags'] ?? []);
    List<String> recipeCategories = [];
    if (widget.data['categories'] != null) {
      recipeCategories = List<String>.from(widget.data['categories']);
    } else if (widget.data['category'] != null) {
      recipeCategories = [widget.data['category']];
    }
    String categoryDisplay = recipeCategories.isNotEmpty
        ? recipeCategories.join(" • ")
        : "ΑΛΛΟ";

    return DraggableScrollableSheet(
      initialChildSize: 0.8,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController,
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(width: 40, height: 4, color: Colors.grey[300]),
            ),
            const SizedBox(height: 20),
            if (widget.data['imageUrl'] != null &&
                widget.data['imageUrl'].toString().isNotEmpty) ...[
              ClipRRect(
                borderRadius: BorderRadius.circular(15),
                child: Image.network(
                  widget.data['imageUrl'],
                  height: 200,
                  width: double.infinity,
                  fit: BoxFit.cover,
                  errorBuilder: (c, e, s) => const SizedBox(),
                ),
              ),
              const SizedBox(height: 15),
            ],

            Text(
              categoryDisplay.toUpperCase(),
              style: TextStyle(
                color: sageGreen,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2,
              ),
            ),

            Row(
              children: [
                Expanded(
                  child: Text(
                    widget.data['title'] ?? '',
                    style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: slateGrey,
                    ),
                  ),
                ),
                if (canEdit) ...[
                  IconButton(
                    icon: const Icon(
                      Icons.edit_document,
                      color: Colors.blueAccent,
                    ),
                    onPressed: () {
                      Navigator.pop(context);
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => EditRecipeScreen(
                            recipeId: widget.recipeId,
                            recipeData: widget.data,
                          ),
                        ),
                      );
                    },
                  ),
                  IconButton(
                    icon: const Icon(
                      Icons.delete_outline,
                      color: Colors.redAccent,
                    ),
                    onPressed: _deleteRecipe,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 6),
            Builder(
              builder: (context) {
                List reviews = widget.data['reviews'] ?? [];
                double avgRating = 0.0;
                if (reviews.isNotEmpty) {
                  double sum = reviews.fold(
                    0,
                    (p, e) => p + (e['rating'] as num).toDouble(),
                  );
                  avgRating = sum / reviews.length;
                }

                return InkWell(
                  onTap: () => _recipeService.showAllReviews(context, reviews),
                  borderRadius: BorderRadius.circular(5),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 4.0,
                      horizontal: 2.0,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (avgRating > 0) ...[
                          Text(
                            avgRating.toStringAsFixed(1),
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                              color: Colors.amber,
                            ),
                          ),
                          const Icon(Icons.star, color: Colors.amber, size: 18),
                          const SizedBox(width: 6),
                          Text(
                            '(${reviews.length} αξιολογήσεις)',
                            style: TextStyle(
                              color: Colors.grey.shade600,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ] else ...[
                          const Icon(
                            Icons.star_border,
                            color: Colors.grey,
                            size: 18,
                          ),
                          const SizedBox(width: 4),
                          const Text(
                            'Χωρίς βαθμολογία ακόμα',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 14,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                );
              },
            ),

            if (tags.isNotEmpty) ...[
              const SizedBox(height: 5),
              Wrap(
                spacing: 6,
                runSpacing: -8,
                children: tags
                    .map(
                      (tag) => Chip(
                        label: Text(
                          tag,
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        backgroundColor: sageGreen,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide.none,
                        ),
                      ),
                    )
                    .toList(),
              ),
            ],
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: slateGrey,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () async {
                      final currentUser = FirebaseAuth.instance.currentUser;
                      if (currentUser == null) return;

                      showDialog(
                        context: context,
                        barrierDismissible: false,
                        builder: (context) => const Center(
                          child: CircularProgressIndicator(color: Colors.white),
                        ),
                      );

                      Map<String, dynamic>? userPreviousReview;

                      try {
                        var freshRecipeData = await FirebaseFirestore.instance
                            .collection('recipes')
                            .doc(widget.recipeId)
                            .get();

                        if (freshRecipeData.exists &&
                            freshRecipeData.data()!.containsKey('reviews')) {
                          List reviews =
                              freshRecipeData.data()!['reviews'] as List;
                          for (var r in reviews) {
                            if (r['userId'] == currentUser.uid) {
                              userPreviousReview = Map<String, dynamic>.from(
                                r as Map,
                              );
                              break;
                            }
                          }
                        }
                      } catch (e) {
                        debugPrint("Σφάλμα ανάγνωσης αξιολόγησης: $e");
                      }

                      if (context.mounted) {
                        Navigator.pop(context);
                      }

                      if (context.mounted) {
                        showDialog(
                          context: context,
                          builder: (dialogContext) => ReviewDialog(
                            existingReview: userPreviousReview,
                            onUpdate:
                                (
                                  double general,
                                  double ease,
                                  double speed,
                                  double nutrition,
                                  double cost,
                                  double clarity,
                                  String comment,
                                ) async {
                                  await _recipeService.submitReview(
                                    widget.recipeId,
                                    general,
                                    ease,
                                    speed,
                                    nutrition,
                                    cost,
                                    clarity,
                                    comment,
                                  );

                                  if (!context.mounted) return;

                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(
                                      content: Text(
                                        'Η αξιολόγηση αποθηκεύτηκε! ⭐',
                                      ),
                                    ),
                                  );

                                  await _cookingBookService
                                      .promptAddToCookingBook(
                                        context,
                                        widget.recipeId,
                                        widget.data,
                                      );
                                },
                          ),
                        );
                      }
                    },
                    icon: const Icon(Icons.star_outline),
                    label: const Text('ΑΞΙΟΛΟΓΗΣΗ'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: StreamBuilder<DocumentSnapshot>(
                    stream: FirebaseAuth.instance.currentUser != null
                        ? FirebaseFirestore.instance
                              .collection('users')
                              .doc(FirebaseAuth.instance.currentUser!.uid)
                              .collection('cookingBook')
                              .doc(widget.recipeId)
                              .snapshots()
                        : null,
                    builder: (context, snapshot) {
                      bool isSaved = snapshot.hasData && snapshot.data!.exists;

                      return ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: sageGreen,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: () async {
                          if (isSaved) {
                            showDialog(
                              context: context,
                              builder: (BuildContext dialogContext) {
                                return AlertDialog(
                                  title: const Text(
                                    'Αφαίρεση Συνταγής',
                                    style: TextStyle(
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                  content: const Text(
                                    'Είστε σίγουροι ότι θέλετε να αφαιρέσετε αυτή τη συνταγή από το Cooking Book;',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(dialogContext),
                                      child: const Text(
                                        'ΟΧΙ',
                                        style: TextStyle(color: Colors.grey),
                                      ),
                                    ),
                                    ElevatedButton(
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.redAccent,
                                      ),
                                      onPressed: () async {
                                        Navigator.pop(dialogContext);

                                        await FirebaseFirestore.instance
                                            .collection('users')
                                            .doc(
                                              FirebaseAuth
                                                  .instance
                                                  .currentUser!
                                                  .uid,
                                            )
                                            .collection('cookingBook')
                                            .doc(widget.recipeId)
                                            .delete();

                                        if (context.mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                "Αφαιρέθηκε από το Cooking Book! 🗑️",
                                              ),
                                              backgroundColor: Colors.redAccent,
                                            ),
                                          );
                                        }
                                      },
                                      child: const Text(
                                        'ΝΑΙ',
                                        style: TextStyle(color: Colors.white),
                                      ),
                                    ),
                                  ],
                                );
                              },
                            );
                          } else {
                            _cookingBookService.showCategorySelection(
                              context,
                              widget.recipeId,
                              widget.data,
                            );
                          }
                        },
                        icon: Icon(
                          isSaved ? Icons.bookmark : Icons.bookmark_border,
                        ),
                        label: const Text('COOKING BOOK'),
                      );
                    },
                  ),
                ),
              ],
            ),
            const Divider(height: 40),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: sageGreen.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                children: [
                  const Text(
                    'Μερίδες:',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                  ),
                  const Spacer(),
                  IconButton(
                    icon: const Icon(Icons.remove_circle_outline),
                    onPressed: _selectedServings > 1
                        ? () => setState(() => _selectedServings--)
                        : null,
                  ),
                  Text(
                    '$_selectedServings',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.add_circle_outline),
                    onPressed: () => setState(() => _selectedServings++),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8.0, bottom: 20.0),
              child: Text(
                'Η συνολική συνταγή βγάζει $_originalServings μερίδες',
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                _buildMacroBox(
                  'Θερμίδες',
                  '$displayCals',
                  Colors.orange,
                  Icons.local_fire_department,
                ),
                _buildMacroBox(
                  'Πρωτεΐνη',
                  '${displayProtein}g',
                  Colors.red,
                  Icons.fitness_center,
                ),
                _buildMacroBox(
                  'Υδατάνθ.',
                  '${displayCarbs}g',
                  Colors.blue,
                  Icons.grass,
                ),
                _buildMacroBox(
                  'Λιπαρά',
                  '${displayFats}g',
                  Colors.amber,
                  Icons.water_drop,
                ),
              ],
            ),

            if (_isDiaryLogging) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sageGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                  ),
                  onPressed: _addRecipeToDiary,
                  icon: const Icon(Icons.add),
                  label: Text(
                    _selectedServings == 1
                        ? 'ΚΑΤΑΧΩΡΗΣΗ 1 ΜΕΡΙΔΑΣ'
                        : 'ΚΑΤΑΧΩΡΗΣΗ $_selectedServings ΜΕΡΙΔΩΝ',
                  ),
                ),
              ),
            ],

            const Divider(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'ΥΛΙΚΑ',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                if (!_isDiaryLogging)
                  TextButton.icon(
                    onPressed: () => _addIngredientsToShoppingList(
                      widget.data['ingredients'] as List,
                      multiplier,
                    ),
                    icon: const Icon(Icons.add_shopping_cart, size: 18),
                    label: const Text(
                      'Λίστα Αγορών',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    style: TextButton.styleFrom(foregroundColor: sageGreen),
                  ),
              ],
            ),
            if (_isDiaryLogging)
              Padding(
                padding: const EdgeInsets.only(top: 4, bottom: 8),
                child: Text(
                  'Αφαίρεσε όσα υλικά δεν χρησιμοποιήθηκαν σε αυτό το γεύμα.',
                  style: TextStyle(color: Colors.grey.shade600, fontSize: 13),
                ),
              ),
            const SizedBox(height: 12),
            ...ingredientBreakdown.asMap().entries.map((entry) {
              final index = entry.key;
              final ingredient = entry.value;
              final excluded = ingredient['excluded'] == true;

              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: excluded
                      ? Colors.redAccent.withValues(alpha: 0.06)
                      : sageGreen.withValues(alpha: 0.07),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: excluded
                        ? Colors.redAccent.withValues(alpha: 0.18)
                        : sageGreen.withValues(alpha: 0.18),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      excluded
                          ? Icons.remove_circle_outline
                          : Icons.check_circle_outline,
                      size: 20,
                      color: excluded ? Colors.redAccent : sageGreen,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${ingredient['name']} (${ingredient['amount']}g)',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: excluded ? Colors.grey : Colors.black87,
                              decoration: excluded
                                  ? TextDecoration.lineThrough
                                  : TextDecoration.none,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${ingredient['calories']} kcal • Π ${ingredient['protein']}g • Υ ${ingredient['carbs']}g • Λ ${ingredient['fats']}g',
                            style: TextStyle(
                              color: excluded
                                  ? Colors.grey
                                  : Colors.grey.shade700,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (_isDiaryLogging)
                      IconButton(
                        tooltip: excluded
                            ? 'Επαναφορά υλικού'
                            : 'Αφαίρεση υλικού',
                        icon: Icon(
                          excluded ? Icons.undo : Icons.close,
                          color: excluded ? slateGrey : Colors.redAccent,
                        ),
                        onPressed: () {
                          final ingredients = _recipeIngredients();
                          final key = _ingredientKey(ingredients[index], index);
                          setState(() {
                            if (excluded) {
                              _excludedIngredientKeys.remove(key);
                            } else {
                              _excludedIngredientKeys.add(key);
                            }
                          });
                        },
                      ),
                  ],
                ),
              );
            }),

            if (widget.data['prepDescription'] != null &&
                widget.data['prepDescription'].toString().isNotEmpty) ...[
              const Divider(height: 40),
              const Text(
                'ΠΕΡΙΓΡΑΦΗ',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 12),
              Text(
                widget.data['prepDescription'],
                style: const TextStyle(fontSize: 16),
              ),
            ],

            const Divider(height: 40),
            const Text(
              'ΕΚΤΕΛΕΣΗ',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            ...(widget.data['steps'] as List).asMap().entries.map(
              (entry) => Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    CircleAvatar(
                      radius: 12,
                      backgroundColor: sageGreen,
                      child: Text(
                        '${entry.key + 1}',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        entry.value,
                        style: const TextStyle(fontSize: 16),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

String removeAccents(String text) {
  String normalized = text.toLowerCase();
  const withAccents = 'άέήίϊΐόύϋΰώ';
  const withoutAccents = 'αεηιιιουυυω';
  for (int i = 0; i < withAccents.length; i++) {
    normalized = normalized.replaceAll(withAccents[i], withoutAccents[i]);
  }
  return normalized;
}

String generateIngredientId(String text) {
  String id = removeAccents(text);

  id = id
      .replaceAll('ς', 'σ')
      .replaceAll('a', 'α')
      .replaceAll('e', 'ε')
      .replaceAll('i', 'ι')
      .replaceAll('o', 'ο')
      .replaceAll('u', 'υ')
      .replaceAll('x', 'χ');

  id = id.replaceAll(RegExp(r'[\u0300-\u036f]'), '');

  return id;
}
