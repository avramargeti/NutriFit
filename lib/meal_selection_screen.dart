import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'meal_details_screen.dart';
import 'recipes_list_screen.dart';

class MealSelectionScreen extends StatefulWidget {
  final String category;
  final String dateString;
  final bool isExercise;

  const MealSelectionScreen({
    super.key,
    required this.category,
    required this.dateString,
    required this.isExercise,
  });

  @override
  State<MealSelectionScreen> createState() => _MealSelectionScreenState();
}

class _MealSelectionScreenState extends State<MealSelectionScreen> {
  String searchQuery = "";
  String selectedSearchType = "Όλα";
  String selectedMealTypeFilter = "Όλα";
  String selectedIngredientCategory = "Όλα";
  bool showAdvancedFilters = false;
  List<String> selectedFoodTypes = [];
  List<String> selectedDietaryTags = [];

  final List<String> searchTypes = const ["Όλα", "Συνταγές", "Τρόφιμα"];
  final List<String> mealTypes = const [
    "Όλα",
    "Πρωινό",
    "Σνακ",
    "Μεσημεριανό",
    "Βραδινό",
    "Επιδόρπιο",
    "Ροφήματα",
  ];
  final List<String> foodTypes = const [
    "Μακαρονάδες",
    "Σαλάτες",
    "Σούπες",
    "Λαδερά",
    "Φούρνου",
    "Ψητά",
    "Ριζότο",
    "Άλλο",
  ];
  final List<String> dietaryTags = const [
    "High Protein",
    "Dairy-Free",
    "Low Carb",
    "Γρήγορη",
    "Gluten-Free",
    "Vegan",
    "Vegetarian",
  ];
  final List<String> ingredientCategories = const [
    "Όλα",
    "Κρέας",
    "Ψάρια & Θαλασσινά",
    "Γαλακτοκομικά",
    "Φρούτα",
    "Λαχανικά",
    "Δημητριακά & Ζυμαρικά",
    "Όσπρια",
    "Ξηροί Καρποί",
    "Vegan/Vegeterian",
    "Μπαχαρικά",
    "Λοιπά",
  ];

  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);

  bool get _hasRecipeFilters {
    return selectedMealTypeFilter != "Όλα" ||
        selectedFoodTypes.isNotEmpty ||
        selectedDietaryTags.isNotEmpty ||
        selectedIngredientCategory != "Όλα" ||
        selectedSearchType != "Όλα";
  }

  bool get _hasActiveRecipeFilters {
    return selectedMealTypeFilter != "Όλα" ||
        selectedFoodTypes.isNotEmpty ||
        selectedDietaryTags.isNotEmpty;
  }

  void _clearFilters() {
    setState(() {
      selectedSearchType = "Όλα";
      selectedMealTypeFilter = "Όλα";
      selectedIngredientCategory = "Όλα";
      selectedFoodTypes.clear();
      selectedDietaryTags.clear();
    });
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
        child: RecipeDetailsSheet(
          recipeId: recipeId,
          data: data,
          diaryCategory: widget.category,
          diaryDateString: widget.dateString,
        ),
      ),
    );
  }

  Widget _buildSearchResults(List<QueryDocumentSnapshot> docs) {
    var filtered = docs.where((doc) {
      var data = doc.data() as Map<String, dynamic>;
      var title = removeAccents(
        (data['title'] ?? data['name'] ?? '').toString(),
      );
      final isRecipe =
          data.containsKey('ingredients') || data.containsKey('steps');
      final matchesSearch = title.contains(removeAccents(searchQuery));

      if (!matchesSearch) return false;
      if (widget.isExercise) return true;
      if (selectedSearchType == "Συνταγές" && !isRecipe) return false;
      if (selectedSearchType == "Τρόφιμα" && isRecipe) return false;

      if (!isRecipe) {
        if (selectedSearchType != "Τρόφιμα" && _hasActiveRecipeFilters) {
          return false;
        }
        final category = (data['category'] ?? "Λοιπά").toString();
        return selectedIngredientCategory == "Όλα" ||
            category == selectedIngredientCategory;
      }

      final recipeCategories = _recipeCategories(data);
      final recipeTags = List<String>.from(data['tags'] ?? []);

      if (selectedMealTypeFilter != "Όλα" &&
          !recipeCategories.contains(selectedMealTypeFilter)) {
        return false;
      }
      if (selectedFoodTypes.isNotEmpty &&
          !selectedFoodTypes.any((type) => recipeCategories.contains(type))) {
        return false;
      }
      if (selectedDietaryTags.isNotEmpty &&
          !selectedDietaryTags.every((tag) => recipeTags.contains(tag))) {
        return false;
      }

      return true;
    }).toList();

    if (filtered.isEmpty) {
      return const Center(child: Text("Δεν βρέθηκαν αποτελέσματα."));
    }

    return ListView.builder(
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        var data = filtered[index].data() as Map<String, dynamic>;
        var docId = filtered[index].id;
        String title = data['title'] ?? data['name'] ?? 'Άγνωστο';
        String imageUrl = data['imageUrl'] ?? '';
        bool isRecipe =
            data.containsKey('ingredients') || data.containsKey('steps');
        int servings = (data['servings'] as num?)?.toInt() ?? 1;
        int caloriesPerServing =
            (data['caloriesPerServing'] as num?)?.toInt() ?? 0;

        return ListTile(
          leading: imageUrl.isNotEmpty
              ? ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(
                    imageUrl,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                  ),
                )
              : Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: sageGreen.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    widget.isExercise ? Icons.fitness_center : Icons.restaurant,
                    color: sageGreen,
                  ),
                ),
          title: Text(
            title,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          subtitle: widget.isExercise
              ? null
              : Text(
                  isRecipe
                      ? 'Συνταγή • $servings μερίδες • $caloriesPerServing kcal/μερίδα'
                      : 'Υλικό / Τρόφιμο',
                  style: TextStyle(color: slateGrey, fontSize: 12),
                ),
          trailing: const Icon(Icons.add_circle_outline),
          onTap: () {
            if (isRecipe) {
              _showRecipeDetails(docId, data);
              return;
            }

            showDialog(
              context: context,
              builder: (context) => MealDetailsScreen(
                itemData: data,
                category: widget.category,
                dateString: widget.dateString,
                isExercise: widget.isExercise,
                title: title,
              ),
            );
          },
        );
      },
    );
  }

  List<String> _recipeCategories(Map<String, dynamic> data) {
    if (data['categories'] != null) {
      return List<String>.from(data['categories']);
    }
    if (data['category'] != null) {
      return [data['category'].toString()];
    }
    return [];
  }

  Widget _buildRecipeFilters() {
    if (widget.isExercise) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children: searchTypes.map((type) {
              final isSelected = selectedSearchType == type;
              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(type),
                  selected: isSelected,
                  selectedColor: sageGreen,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : slateGrey,
                    fontWeight: isSelected
                        ? FontWeight.bold
                        : FontWeight.normal,
                  ),
                  onSelected: (_) {
                    setState(() {
                      selectedSearchType = type;
                      if (type == "Τρόφιμα") {
                        selectedMealTypeFilter = "Όλα";
                        selectedFoodTypes.clear();
                        selectedDietaryTags.clear();
                      } else {
                        selectedIngredientCategory = "Όλα";
                      }
                    });
                  },
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 8),
        if (selectedSearchType == "Τρόφιμα")
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
            child: Text(
              'Κατηγορίες τροφίμων',
              style: TextStyle(
                color: slateGrey,
                fontSize: 13,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: Row(
            children:
                (selectedSearchType == "Τρόφιμα"
                        ? ingredientCategories
                        : mealTypes)
                    .map((type) {
                      final isSelected = selectedSearchType == "Τρόφιμα"
                          ? selectedIngredientCategory == type
                          : selectedMealTypeFilter == type;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(type),
                          selected: isSelected,
                          selectedColor: sageGreen,
                          labelStyle: TextStyle(
                            color: isSelected ? Colors.white : slateGrey,
                            fontWeight: isSelected
                                ? FontWeight.bold
                                : FontWeight.normal,
                          ),
                          onSelected: (_) {
                            setState(() {
                              if (selectedSearchType == "Τρόφιμα") {
                                selectedIngredientCategory = type;
                              } else {
                                selectedMealTypeFilter = type;
                              }
                            });
                          },
                        ),
                      );
                    })
                    .toList(),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Row(
            children: [
              if (selectedSearchType != "Τρόφιμα")
                TextButton.icon(
                  onPressed: () {
                    setState(() => showAdvancedFilters = !showAdvancedFilters);
                  },
                  icon: Icon(
                    showAdvancedFilters ? Icons.expand_less : Icons.tune,
                    size: 18,
                  ),
                  label: const Text('Φίλτρα'),
                  style: TextButton.styleFrom(foregroundColor: slateGrey),
                ),
              const Spacer(),
              if (_hasRecipeFilters)
                TextButton(
                  onPressed: _clearFilters,
                  child: const Text(
                    'Καθαρισμός',
                    style: TextStyle(color: Colors.redAccent),
                  ),
                ),
            ],
          ),
        ),
        if (showAdvancedFilters && selectedSearchType != "Τρόφιμα")
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFilterWrap('Είδος φαγητού', foodTypes, selectedFoodTypes),
                const SizedBox(height: 10),
                _buildFilterWrap(
                  'Διατροφικές επιλογές',
                  dietaryTags,
                  selectedDietaryTags,
                ),
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildFilterWrap(
    String title,
    List<String> options,
    List<String> selectedValues,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TextStyle(
            color: slateGrey,
            fontSize: 13,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 2,
          children: options.map((option) {
            final selected = selectedValues.contains(option);
            return FilterChip(
              label: Text(option),
              selected: selected,
              selectedColor: sageGreen.withValues(alpha: 0.25),
              checkmarkColor: sageGreen,
              onSelected: (value) {
                setState(() {
                  if (value) {
                    selectedValues.add(option);
                  } else {
                    selectedValues.remove(option);
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Αναζήτηση: ${widget.category}'),
        backgroundColor: Colors.white,
        foregroundColor: slateGrey,
        elevation: 0,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              decoration: InputDecoration(
                hintText: "Αναζήτηση...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                ),
              ),
              onChanged: (val) => setState(() => searchQuery = val),
            ),
          ),
          _buildRecipeFilters(),
          Expanded(
            child: widget.isExercise
                ? StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('exercises')
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(child: CircularProgressIndicator());
                      }
                      return _buildSearchResults(snapshot.data!.docs);
                    },
                  )
                : StreamBuilder<QuerySnapshot>(
                    stream: FirebaseFirestore.instance
                        .collection('recipes')
                        .snapshots(),
                    builder: (context, recipeSnap) {
                      return StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instance
                            .collection('ingredients')
                            .snapshots(),
                        builder: (context, ingSnap) {
                          if (!recipeSnap.hasData || !ingSnap.hasData) {
                            return const Center(
                              child: CircularProgressIndicator(),
                            );
                          }
                          List<QueryDocumentSnapshot> combinedDocs = [
                            ...recipeSnap.data!.docs,
                            ...ingSnap.data!.docs,
                          ];
                          return _buildSearchResults(combinedDocs);
                        },
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}