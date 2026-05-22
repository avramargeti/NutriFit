import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'ingredients_list_screen.dart';

class EditRecipeScreen extends StatefulWidget {
  final String recipeId;
  final Map<String, dynamic> recipeData;
  const EditRecipeScreen({super.key, required this.recipeId, required this.recipeData});

  @override
  State<EditRecipeScreen> createState() => _EditRecipeScreenState();
}

class _EditRecipeScreenState extends State<EditRecipeScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _prepController = TextEditingController();
  final TextEditingController _servingsController = TextEditingController();
  final TextEditingController _imageUrlController = TextEditingController(); 
  
  List<String> steps = []; 
  List<Map<String, dynamic>> selectedIngredients = [];
  bool _hasAttemptedSave = false;

  List<String> selectedMealTypes = [];
  final List<String> availableMealTypes = [
    "Πρωινό", "Σνακ", "Μεσημεριανό", "Βραδινό", "Επιδόρπιο", "Ροφήματα"
  ];

  List<String> selectedFoodTypes = [];
  final List<String> availableFoodTypes = [
    "Μακαρονάδες", "Σαλάτες", "Σούπες", "Λαδερά", "Φούρνου", "Ψητά", "Ριζότο", "Άλλο"
  ];

  List<String> selectedTags = [];
  final List<String> availableTags = [
    "High Protein", "Dairy-Free", "Low Carb", "Γρήγορη", 
    "Gluten-Free", "Vegan", "Vegetarian"
  ];

  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);

  @override
  void initState() {
    super.initState();
    _nameController.text = widget.recipeData['title'] ?? '';
    _prepController.text = widget.recipeData['prepDescription'] ?? '';
    _servingsController.text = (widget.recipeData['servings'] ?? 1).toString();
    _imageUrlController.text = widget.recipeData['imageUrl'] ?? ''; 

    List<String> loadedCategories = [];
    if (widget.recipeData['categories'] != null) {
      loadedCategories = List<String>.from(widget.recipeData['categories']);
    } else if (widget.recipeData['category'] != null) {
      loadedCategories = [widget.recipeData['category']]; 
    }

    selectedMealTypes = loadedCategories.where((c) => availableMealTypes.contains(c)).toList();
    selectedFoodTypes = loadedCategories.where((c) => availableFoodTypes.contains(c)).toList();

    for (var c in loadedCategories) {
      if (!availableMealTypes.contains(c) && !availableFoodTypes.contains(c)) {
        if (!selectedFoodTypes.contains("Άλλο")) {
          selectedFoodTypes.add("Άλλο");
        }
      }
    }

    if (widget.recipeData['tags'] != null) {
      selectedTags = List<String>.from(widget.recipeData['tags']);
    }
    if (widget.recipeData['steps'] != null) {
      steps = List<String>.from(widget.recipeData['steps']);
    }
    if (widget.recipeData['ingredients'] != null) {
      selectedIngredients = List<Map<String, dynamic>>.from(widget.recipeData['ingredients']);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _prepController.dispose();
    _servingsController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _addStep() => setState(() => steps.add(""));

  void _showIngredientPicker() async {
    final selectedIngredientMap = await Navigator.push(context, MaterialPageRoute(builder: (context) => const IngredientsListScreen(isSelectionMode: true)));
    if (selectedIngredientMap != null && selectedIngredientMap is Map<String, dynamic>) {
      _askForAmount(selectedIngredientMap);
    }
  }

  void _askForAmount(Map<String, dynamic> ingredientData) {
    TextEditingController amountController = TextEditingController();
    showDialog(
      context: context, barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text('Ποσότητα για: ${ingredientData['name']}'),
        content: TextField(controller: amountController, keyboardType: TextInputType.number, autofocus: true, decoration: const InputDecoration(hintText: 'Γραμμάρια (g)', suffixText: 'g')),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ΑΚΥΡΟ', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: sageGreen),
            onPressed: () {
              if (amountController.text.isNotEmpty) {
                setState(() {
                  selectedIngredients.add({
                    'name': ingredientData['name'], 'amount': int.tryParse(amountController.text) ?? 0,
                    'caloriesPer100g': ingredientData['caloriesPer100g'] ?? 0, 'proteinPer100g': ingredientData['protein'] ?? 0, 
                    'carbsPer100g': ingredientData['carbs'] ?? 0, 'fatsPer100g': ingredientData['fats'] ?? 0,
                  });
                });
                Navigator.pop(context);
              }
            },
            child: const Text('ΠΡΟΣΘΗΚΗ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Map<String, int> _calculateTotals() {
    double cals = 0, protein = 0, carbs = 0, fats = 0;
    for (var ing in selectedIngredients) {
      double ratio = (ing['amount'] as num) / 100.0;
      cals += ratio * (ing['caloriesPer100g'] ?? 0); protein += ratio * (ing['proteinPer100g'] ?? 0);
      carbs += ratio * (ing['carbsPer100g'] ?? 0); fats += ratio * (ing['fatsPer100g'] ?? 0);
    }
    return {'cals': cals.round(), 'protein': protein.round(), 'carbs': carbs.round(), 'fats': fats.round()};
  }

  Future<void> _updateRecipe() async {
    setState(() => _hasAttemptedSave = true);
    int servings = int.tryParse(_servingsController.text) ?? 1;

    List<String> combinedCategories = [...selectedMealTypes, ...selectedFoodTypes];

    if (_nameController.text.trim().isEmpty || selectedIngredients.isEmpty || steps.any((s) => s.trim().isEmpty) || combinedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Συμπληρώστε όλα τα υποχρεωτικά πεδία!'), backgroundColor: Colors.redAccent));
      return;
    }

    try {
      var totals = _calculateTotals();
      int calsPerServing = (totals['cals']! / servings).round();
      String? finalImageUrl = _imageUrlController.text.trim().isNotEmpty ? _imageUrlController.text.trim() : null;

      await FirebaseFirestore.instance.collection('recipes').doc(widget.recipeId).update({
        'title': _nameController.text.trim(), 'servings': servings, 'imageUrl': finalImageUrl, 
        'categories': combinedCategories, 
        'tags': selectedTags, 
        'totalCalories': totals['cals'], 'totalProtein': totals['protein'], 'totalCarbs': totals['carbs'], 'totalFats': totals['fats'],
        'caloriesPerServing': calsPerServing, 'prepDescription': _prepController.text.trim(),
        'ingredients': selectedIngredients, 'steps': steps.where((s) => s.trim().isNotEmpty).toList(), 'updatedAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Η συνταγή ενημερώθηκε επιτυχώς! ✏️')));
      }
    } catch (e) { debugPrint("Error: $e"); }
  }

  @override
  Widget build(BuildContext context) {
    bool nameError = _hasAttemptedSave && _nameController.text.trim().isEmpty;
    bool categoriesError = _hasAttemptedSave && selectedMealTypes.isEmpty && selectedFoodTypes.isEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Επεξεργασία Συνταγής'), backgroundColor: Colors.white, foregroundColor: slateGrey, elevation: 0, actions: [IconButton(icon: const Icon(Icons.save, size: 28), onPressed: _updateRecipe)]),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _imageUrlController, decoration: InputDecoration(labelText: 'URL Φωτογραφίας (Προαιρετικό)', prefixIcon: const Icon(Icons.link), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))), onChanged: (value) => setState(() {})),
            const SizedBox(height: 15),
            if (_imageUrlController.text.trim().isNotEmpty) ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(_imageUrlController.text.trim(), height: 200, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c, e, s) => Container(height: 200, color: Colors.grey[200], child: const Center(child: Text('Μη έγκυρο URL', style: TextStyle(color: Colors.grey)))))),
            const SizedBox(height: 20),

            TextField(controller: _nameController, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), decoration: InputDecoration(labelText: 'Όνομα Συνταγής *', errorText: nameError ? 'Υποχρεωτικό' : null, border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 20),

            TextField(controller: _servingsController, keyboardType: TextInputType.number, decoration: InputDecoration(labelText: 'Μερίδες', prefixIcon: const Icon(Icons.people_outline), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 30),

            Text('Τύπος Γεύματος *', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: categoriesError ? Colors.red : slateGrey)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0, runSpacing: -8.0,
              children: availableMealTypes.map((type) {
                final isSelected = selectedMealTypes.contains(type);
                return FilterChip(
                  label: Text(type), selected: isSelected, selectedColor: slateGrey, checkmarkColor: Colors.white,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : slateGrey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), backgroundColor: Colors.white, shape: StadiumBorder(side: BorderSide(color: slateGrey.withValues(alpha: 0.3))),
                  onSelected: (bool selected) { 
                    setState(() { 
                      if (selected) {
                        selectedMealTypes.add(type); 
                      } else {
                        selectedMealTypes.remove(type); 
                      }
                    }); 
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            Text('Είδος Φαγητού', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slateGrey)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0, runSpacing: -8.0,
              children: availableFoodTypes.map((cat) {
                final isSelected = selectedFoodTypes.contains(cat);
                return FilterChip(
                  label: Text(cat), selected: isSelected, selectedColor: slateGrey, checkmarkColor: Colors.white,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : slateGrey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), backgroundColor: Colors.white, shape: StadiumBorder(side: BorderSide(color: slateGrey.withValues(alpha: 0.3))),
                  onSelected: (bool selected) { 
                    setState(() { 
                      if (selected) {
                        selectedFoodTypes.add(cat); 
                      } else {
                        selectedFoodTypes.remove(cat); 
                      }
                    }); 
                  },
                );
              }).toList(),
            ),
            if (categoriesError) const Padding(padding: EdgeInsets.only(top: 8.0), child: Text('Επιλέξτε τουλάχιστον ένα γεύμα ή είδος φαγητού.', style: TextStyle(color: Colors.red, fontSize: 12))),
            const SizedBox(height: 30),

            Text('Ετικέτες (Tags)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slateGrey)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0, runSpacing: -8.0,
              children: availableTags.map((tag) {
                final isSelected = selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag), selected: isSelected, selectedColor: sageGreen, checkmarkColor: Colors.white,
                  labelStyle: TextStyle(color: isSelected ? Colors.white : slateGrey, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal), backgroundColor: Colors.white, shape: StadiumBorder(side: BorderSide(color: sageGreen.withValues(alpha: 0.3))),
                  onSelected: (bool selected) { 
                    setState(() { 
                      if (selected) {
                        selectedTags.add(tag); 
                      } else {
                        selectedTags.remove(tag); 
                      }
                    }); 
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 30),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Υλικά *', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slateGrey)), TextButton.icon(onPressed: _showIngredientPicker, icon: const Icon(Icons.add_circle_outline), label: const Text('Προσθήκη'), style: TextButton.styleFrom(foregroundColor: sageGreen))]),
            Wrap(spacing: 8, children: selectedIngredients.map((ing) => Chip(backgroundColor: sageGreen.withValues(alpha: 0.1), label: Text("${ing['name']} (${ing['amount']}g)"), onDeleted: () => setState(() => selectedIngredients.remove(ing)), deleteIconColor: Colors.redAccent)).toList()),
            if (_hasAttemptedSave && selectedIngredients.isEmpty) const Padding(padding: EdgeInsets.only(top: 8), child: Text('Προσθέστε τουλάχιστον ένα υλικό.', style: TextStyle(color: Colors.red, fontSize: 12))),
            const SizedBox(height: 30),

            Text('Προετοιμασία / Περιγραφή', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slateGrey)),
            const SizedBox(height: 10),
            TextField(controller: _prepController, maxLines: 3, decoration: InputDecoration(hintText: 'Λίγα λόγια για τη συνταγή...', border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)))),
            const SizedBox(height: 30),

            Text('Βήματα Εκτέλεσης *', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slateGrey)),
            const SizedBox(height: 10),
            ...List.generate(steps.length, (index) {
              bool stepError = _hasAttemptedSave && steps[index].trim().isEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Padding(padding: const EdgeInsets.only(top: 15), child: CircleAvatar(radius: 12, backgroundColor: stepError ? Colors.red : sageGreen, child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Colors.white)))),
                  const SizedBox(width: 12),
                  Expanded(child: TextField(onChanged: (val) => steps[index] = val, controller: TextEditingController.fromValue(TextEditingValue(text: steps[index], selection: TextSelection.collapsed(offset: steps[index].length))), maxLines: null, decoration: InputDecoration(hintText: 'Περιγραφή βήματος...', errorText: stepError ? 'Μην αφήνετε κενά βήματα' : null))),
                  IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.grey), onPressed: () => setState(() => steps.removeAt(index)))
                ]),
              );
            }),
            Center(child: ElevatedButton.icon(onPressed: _addStep, icon: const Icon(Icons.add), label: const Text('ΠΡΟΣΘΗΚΗ ΒΗΜΑΤΟΣ'), style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: sageGreen, elevation: 0, side: BorderSide(color: sageGreen)))),
            const SizedBox(height: 40),
            
            SizedBox(width: double.infinity, child: ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: sageGreen, padding: const EdgeInsets.symmetric(vertical: 18), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))), onPressed: _updateRecipe, child: const Text('Αποθήκευση Αλλαγών', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)))),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}