import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ingredients_list_screen.dart';

class AddRecipeScreen extends StatefulWidget {
  const AddRecipeScreen({super.key});

  @override
  State<AddRecipeScreen> createState() => _AddRecipeScreenState();
}

class _AddRecipeScreenState extends State<AddRecipeScreen> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _prepController = TextEditingController();
  final TextEditingController _servingsController = TextEditingController(text: "1");
  final TextEditingController _imageUrlController = TextEditingController(); 
  
  List<String> steps = [""]; 
  List<Map<String, dynamic>> selectedIngredients = [];
  bool _hasAttemptedSave = false;

  List<String> selectedMealTypes = ["Μεσημεριανό"];
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
  void dispose() {
    _nameController.dispose();
    _prepController.dispose();
    _servingsController.dispose();
    _imageUrlController.dispose();
    super.dispose();
  }

  void _addStep() => setState(() => steps.add(""));

  void _showIngredientPicker() async {
    final selectedIngredientMap = await Navigator.push(
      context, 
      MaterialPageRoute(builder: (context) => const IngredientsListScreen(isSelectionMode: true))
    );
    if (selectedIngredientMap != null && selectedIngredientMap is Map<String, dynamic>) {
      _askForAmount(selectedIngredientMap);
    }
  }

  void _askForAmount(Map<String, dynamic> ingredientData) {
    TextEditingController amountController = TextEditingController();
    String ingName = ingredientData['name'] ?? 'Άγνωστο';
    
    showDialog(
      context: context, 
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
        title: Text('Ποσότητα για: $ingName'),
        content: TextField(
          controller: amountController, 
          keyboardType: TextInputType.number, 
          autofocus: true, 
          decoration: const InputDecoration(hintText: 'Γραμμάρια (g)', suffixText: 'g')
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('ΑΚΥΡΟ', style: TextStyle(color: Colors.grey))
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: sageGreen),
            onPressed: () {
              if (amountController.text.isNotEmpty) {
                setState(() {
                  selectedIngredients.add({
                    'name': ingName, 
                    'amount': int.tryParse(amountController.text) ?? 0,
                    'caloriesPer100g': ingredientData['caloriesPer100g'] ?? 0, 
                    'proteinPer100g': ingredientData['protein'] ?? 0, 
                    'carbsPer100g': ingredientData['carbs'] ?? 0, 
                    'fatsPer100g': ingredientData['fats'] ?? 0, 
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
      cals += ratio * (ing['caloriesPer100g'] ?? 0); 
      protein += ratio * (ing['proteinPer100g'] ?? 0);
      carbs += ratio * (ing['carbsPer100g'] ?? 0); 
      fats += ratio * (ing['fatsPer100g'] ?? 0);
    }
    return {
      'cals': cals.round(), 
      'protein': protein.round(), 
      'carbs': carbs.round(), 
      'fats': fats.round()
    };
  }

  Future<void> _saveRecipe() async {
    setState(() => _hasAttemptedSave = true);
    bool hasEmptySteps = steps.any((s) => s.trim().isEmpty);

    List<String> combinedCategories = [...selectedMealTypes, ...selectedFoodTypes];

    if (_nameController.text.trim().isEmpty || selectedIngredients.isEmpty || hasEmptySteps || combinedCategories.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Παρακαλώ συμπληρώστε όλα τα υποχρεωτικά πεδία!'), backgroundColor: Colors.redAccent)
      );
      return;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      int servings = int.tryParse(_servingsController.text) ?? 1;
      var totals = _calculateTotals();
      int calsPerServing = (totals['cals']! / servings).round();
      String? finalImageUrl = _imageUrlController.text.trim().isNotEmpty ? _imageUrlController.text.trim() : null;

      await FirebaseFirestore.instance.collection('recipes').add({
        'title': _nameController.text.trim(),
        'userId': user?.uid,
        'imageUrl': finalImageUrl, 
        'servings': servings,
        'categories': combinedCategories, 
        'tags': selectedTags, 
        'totalCalories': totals['cals'], 
        'totalProtein': totals['protein'], 
        'totalCarbs': totals['carbs'], 
        'totalFats': totals['fats'],
        'caloriesPerServing': calsPerServing,
        'prepDescription': _prepController.text.trim(),
        'ingredients': selectedIngredients,
        'steps': steps.where((s) => s.trim().isNotEmpty).toList(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Η συνταγή αποθηκεύτηκε! 🍳')));
      }
    } catch (e) { 
      debugPrint("Σφάλμα: $e"); 
    }
  }

  @override
  Widget build(BuildContext context) {
    bool nameError = _hasAttemptedSave && _nameController.text.trim().isEmpty;
    bool ingredientsError = _hasAttemptedSave && selectedIngredients.isEmpty;
    bool categoriesError = _hasAttemptedSave && selectedMealTypes.isEmpty && selectedFoodTypes.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Δημιουργία Συνταγής'), 
        backgroundColor: Colors.white, 
        foregroundColor: slateGrey, 
        elevation: 0, 
        actions: [
          IconButton(icon: const Icon(Icons.check, size: 28), onPressed: _saveRecipe)
        ]
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _imageUrlController, 
              decoration: InputDecoration(
                labelText: 'URL Φωτογραφίας (Προαιρετικό)', 
                prefixIcon: const Icon(Icons.link), 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
              ), 
              onChanged: (value) => setState(() {})
            ),
            const SizedBox(height: 15),
            
            if (_imageUrlController.text.trim().isNotEmpty) 
              ClipRRect(
                borderRadius: BorderRadius.circular(15), 
                child: Image.network(
                  _imageUrlController.text.trim(), 
                  height: 200, 
                  width: double.infinity, 
                  fit: BoxFit.cover, 
                  errorBuilder: (c, e, s) => Container(
                    height: 200, 
                    color: Colors.grey[200], 
                    child: const Center(child: Text('Μη έγκυρο URL', style: TextStyle(color: Colors.grey)))
                  )
                )
              ),
            const SizedBox(height: 20),

            TextField(
              controller: _nameController, 
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), 
              decoration: InputDecoration(
                labelText: 'Όνομα Συνταγής *', 
                errorText: nameError ? 'Αυτό το πεδίο είναι υποχρεωτικό' : null, 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)), 
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15), 
                  borderSide: BorderSide(color: nameError ? Colors.red : Colors.grey.shade400)
                ), 
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15), 
                  borderSide: BorderSide(color: nameError ? Colors.red : sageGreen, width: 2)
                )
              )
            ),
            const SizedBox(height: 20),

            TextField(
              controller: _servingsController, 
              keyboardType: TextInputType.number, 
              decoration: InputDecoration(
                labelText: 'Μερίδες', 
                prefixIcon: const Icon(Icons.people_outline), 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
              )
            ),
            const SizedBox(height: 30),

            Text('Τύπος Γεύματος *', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: categoriesError ? Colors.red : slateGrey)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0, runSpacing: -8.0,
              children: availableMealTypes.map((type) {
                final isSelected = selectedMealTypes.contains(type);
                return FilterChip(
                  label: Text(type), 
                  selected: isSelected, 
                  selectedColor: slateGrey, 
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : slateGrey, 
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                  ), 
                  backgroundColor: Colors.white, 
                  shape: StadiumBorder(side: BorderSide(color: slateGrey.withValues(alpha: 0.3))),
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
                  label: Text(cat), 
                  selected: isSelected, 
                  selectedColor: slateGrey, 
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : slateGrey, 
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                  ), 
                  backgroundColor: Colors.white, 
                  shape: StadiumBorder(side: BorderSide(color: slateGrey.withValues(alpha: 0.3))),
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
            if (categoriesError) 
              const Padding(
                padding: EdgeInsets.only(top: 8.0), 
                child: Text('Επιλέξτε τουλάχιστον ένα γεύμα ή είδος φαγητού.', style: TextStyle(color: Colors.red, fontSize: 12))
              ),
            const SizedBox(height: 30),

            Text('Ετικέτες (Tags)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slateGrey)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8.0, runSpacing: -8.0,
              children: availableTags.map((tag) {
                final isSelected = selectedTags.contains(tag);
                return FilterChip(
                  label: Text(tag), 
                  selected: isSelected, 
                  selectedColor: sageGreen, 
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : slateGrey, 
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal
                  ), 
                  backgroundColor: Colors.white, 
                  shape: StadiumBorder(side: BorderSide(color: sageGreen.withValues(alpha: 0.3))),
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

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween, 
              children: [
                Text('Υλικά *', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: ingredientsError ? Colors.red : slateGrey)), 
                TextButton.icon(
                  onPressed: _showIngredientPicker, 
                  icon: const Icon(Icons.add_circle_outline), 
                  label: const Text('Προσθήκη'), 
                  style: TextButton.styleFrom(foregroundColor: sageGreen)
                )
              ]
            ),
            Wrap(
              spacing: 8, 
              runSpacing: 4, 
              children: selectedIngredients.map((ing) => Chip(
                backgroundColor: sageGreen.withValues(alpha: 0.1), 
                label: Text("${ing['name']} (${ing['amount']}g)"), 
                onDeleted: () => setState(() => selectedIngredients.remove(ing)), 
                deleteIconColor: Colors.redAccent
              )).toList()
            ),
            if (ingredientsError) 
              const Padding(
                padding: EdgeInsets.only(top: 8.0), 
                child: Text('Πρέπει να προσθέσετε τουλάχιστον ένα υλικό.', style: TextStyle(color: Colors.red, fontSize: 12))
              ),
            const SizedBox(height: 30),

            Text('Προετοιμασία', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slateGrey)),
            const SizedBox(height: 10),
            TextField(
              controller: _prepController, 
              maxLines: 3, 
              decoration: InputDecoration(
                hintText: 'Περιγράψτε εν συντομία τη συνταγή...', 
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))
              )
            ),
            const SizedBox(height: 30),

            Text('Βήματα Εκτέλεσης *', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slateGrey)),
            const SizedBox(height: 10),
            ...List.generate(steps.length, (index) {
              bool stepError = _hasAttemptedSave && steps[index].trim().isEmpty;
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start, 
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 15), 
                      child: CircleAvatar(
                        radius: 12, 
                        backgroundColor: stepError ? Colors.red : sageGreen, 
                        child: Text('${index + 1}', style: const TextStyle(fontSize: 12, color: Colors.white))
                      )
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextField(
                        onChanged: (val) => steps[index] = val, 
                        maxLines: null, 
                        decoration: InputDecoration(
                          hintText: 'Περιγράψτε αυτό το βήμα...', 
                          errorText: stepError ? 'Μην αφήνετε κενά βήματα' : null
                        )
                      )
                    ),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline, color: Colors.grey), 
                      onPressed: () => setState(() => steps.removeAt(index))
                    )
                  ]
                ),
              );
            }),
            Center(
              child: ElevatedButton.icon(
                onPressed: _addStep, 
                icon: const Icon(Icons.add), 
                label: const Text('ΠΡΟΣΘΗΚΗ ΒΗΜΑΤΟΣ'), 
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white, 
                  foregroundColor: sageGreen, 
                  elevation: 0, 
                  side: BorderSide(color: sageGreen)
                )
              )
            ),
            const SizedBox(height: 50),
            
            SizedBox(
              width: double.infinity, 
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: sageGreen, 
                  padding: const EdgeInsets.symmetric(vertical: 18), 
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))
                ), 
                onPressed: _saveRecipe, 
                child: const Text('Αποθήκευση Συνταγής', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white))
              )
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}