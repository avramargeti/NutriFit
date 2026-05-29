import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ingredients_list_screen.dart';
import 'edit_recipe_screen.dart';

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
    "Όλα", "Πρωινό", "Σνακ", "Μεσημεριανό", "Βραδινό", "Επιδόρπιο", "Ροφήματα"
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
    _recipesStream = FirebaseFirestore.instance.collection('recipes').snapshots();
    _loadUserAllergies(); 
  }

  Future<void> _loadUserAllergies() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
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
      MaterialPageRoute(builder: (context) => const IngredientsListScreen(isSelectionMode: true))
    );

    if (!mounted) return; 

    if (selectedIngredientData != null && selectedIngredientData is Map<String, dynamic>) {
      String ingName = selectedIngredientData['name'];
      String ingCategory = selectedIngredientData['category'] ?? "";
      List<String> ingredientAllergens = List<String>.from(selectedIngredientData['allergens'] ?? []);

      bool hasAllergen = ingredientAllergens.any((allergen) => userAllergies.contains(allergen)) ||
                         userAllergies.contains(ingName) ||
                         userAllergies.contains(ingCategory);

      if (hasAllergen) {
        List<String> triggeredItems = [];
        triggeredItems.addAll(ingredientAllergens.where((a) => userAllergies.contains(a)));
        if (userAllergies.contains(ingName)) triggeredItems.add(ingName);
        if (userAllergies.contains(ingCategory) && !triggeredItems.contains(ingCategory)) triggeredItems.add(ingCategory);
        
        String warningText = triggeredItems.join(", ");

        bool? continueAnyway = await showDialog<bool>(
          context: context, 
          builder: (context) => AlertDialog(
            title: const Row(children: [Icon(Icons.warning, color: Colors.orange), SizedBox(width: 8), Text('Προσοχή Αλλεργιογόνο!')]),
            content: Text('Το υλικό "$ingName" εμπίπτει στις αλλεργίες/δυσανεξίες σας ($warningText).\nΣυνέχεια;'),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ΑΦΑΙΡΕΣΗ', style: TextStyle(color: Colors.red))),
              TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ΝΑΙ, ΣΥΝΕΧΕΙΑ')),
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
              IconButton(icon: const Icon(Icons.close), onPressed: () {
                setState(() {
                  tempFoodTypes = List.from(selectedFoodTypes);
                  tempDietaryTags = List.from(selectedDietaryTags);
                });
                Navigator.pop(context);
              })
            ],
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildFilterSection("Είδος Φαγητού", ["Μακαρονάδες", "Σούπες", "Λαδερά", "Φούρνου", "Ψητά", "Ριζότο"], tempFoodTypes),
                const Divider(height: 30),
                _buildFilterSection("Διατροφικές Επιλογές", ["High Protein", "Dairy-Free", "Low Carb", "Γρήγορη", "Gluten-Free", "Vegan", "Vegetarian"], tempDietaryTags),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                Expanded(child: OutlinedButton(onPressed: () => setState(() { tempFoodTypes.clear(); tempDietaryTags.clear(); }), child: const Text('Καθαρισμός'))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: sageGreen, foregroundColor: Colors.white),
                  onPressed: () {
                  setState(() {
                    selectedFoodTypes = List.from(tempFoodTypes);
                    selectedDietaryTags = List.from(tempDietaryTags);
                  });
                  Navigator.pop(context);
                }, child: const Text('Εφαρμογή'))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(String title, List<String> options, List<String> selectedList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        const SizedBox(height: 12),
        Wrap(spacing: 8, runSpacing: 4, children: options.map((opt) {
          final isSelected = selectedList.contains(opt);
          return FilterChip(
            label: Text(opt), selected: isSelected,
            onSelected: (val) => setState(() => val ? selectedList.add(opt) : selectedList.remove(opt)),
            selectedColor: sageGreen.withValues(alpha: 0.3), checkmarkColor: sageGreen,
          );
        }).toList()),
      ],
    );
  }

  void _showRecipeDetails(String recipeId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (context) => Container(decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(25))), child: RecipeDetailsSheet(recipeId: recipeId, data: data)),
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
          Builder(builder: (context) => IconButton(icon: const Icon(Icons.tune), onPressed: () {
            setState(() {
              tempFoodTypes = List.from(selectedFoodTypes);
              tempDietaryTags = List.from(selectedDietaryTags);
            });
            Scaffold.of(context).openEndDrawer();
          })),
        ],
      ),
      endDrawer: _buildFilterDrawer(),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12.0),
            child: TextField(
              decoration: InputDecoration(hintText: "Αναζήτηση συνταγής...", prefixIcon: const Icon(Icons.search), border: OutlineInputBorder(borderRadius: BorderRadius.circular(15))),
              onChanged: (val) => setState(() => searchQuery = removeAccents(val)),
            ),
          ),
          
          SingleChildScrollView(
            scrollDirection: Axis.horizontal, padding: const EdgeInsets.symmetric(horizontal: 10),
            child: Row(
              children: mealTypes.map((type) {
                final isSelected = selectedMealTypeFilter == type;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: ChoiceChip(
                    label: Text(type), selected: isSelected,
                    onSelected: (val) => setState(() => selectedMealTypeFilter = type),
                    selectedColor: sageGreen, labelStyle: TextStyle(color: isSelected ? Colors.white : slateGrey),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 10),
          
          Container(
            width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                  Text('Τι έχω στο ψυγείο μου;', style: TextStyle(fontWeight: FontWeight.bold, color: slateGrey)),
                  if (fridgeIngredients.isNotEmpty) TextButton(onPressed: () => setState(() => fridgeIngredients.clear()), child: const Text('Καθαρισμός', style: TextStyle(color: Colors.redAccent, fontSize: 12))),
                ]),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  ...fridgeIngredients.map((ing) => InputChip(label: Text(ing), backgroundColor: sageGreen.withValues(alpha: 0.1), onDeleted: () => setState(() => fridgeIngredients.remove(ing)))),
                  ActionChip(avatar: const Icon(Icons.add, size: 16, color: Colors.white), label: const Text('Προσθήκη', style: TextStyle(color: Colors.white)), backgroundColor: slateGrey, onPressed: _addFridgeIngredient),
                ]),
              ],
            ),
          ),
          const Divider(height: 20),
          
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _recipesStream,
              builder: (context, snapshot) {
                if (snapshot.hasError) return const Center(child: Text('Σφάλμα σύνδεσης'));
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

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
                  
                  List<String> recipeTags = List<String>.from(data['tags'] ?? []);
                  List ingredientsList = data['ingredients'] as List;

                  if (searchQuery.isNotEmpty && !searchTitle.contains(searchQuery)) continue;
                  
                  if (selectedMealTypeFilter != "Όλα" && !recipeCats.contains(selectedMealTypeFilter)) continue;
                  
                  if (selectedFoodTypes.isNotEmpty && !selectedFoodTypes.any((t) => recipeCats.contains(t))) continue;
                  if (selectedDietaryTags.isNotEmpty && !selectedDietaryTags.every((t) => recipeTags.contains(t))) continue;

                  if (fridgeIngredients.isEmpty) {
                     displayList.add(doc);
                  } else {
                    int matchCount = 0;
                    for (var recIng in ingredientsList) {
                      if (fridgeIngredients.contains(recIng['name'])) matchCount++;
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
                    int aMissing = (aData['ingredients'] as List).where((i) => !fridgeIngredients.contains(i['name'])).length;
                    int bMissing = (bData['ingredients'] as List).where((i) => !fridgeIngredients.contains(i['name'])).length;
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
                        padding: const EdgeInsets.all(12), color: sageGreen.withValues(alpha: 0.1), width: double.infinity,
                        child: Text('Συνταγές με βάση τα υλικά σας (${displayList.length})', style: TextStyle(color: sageGreen, fontWeight: FontWeight.bold)),
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
                              if (!fridgeIngredients.contains(recIng['name'])) missingIngredients.add(recIng['name']);
                            }
                          }
                          
                          return Card(
                            margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                            child: ListTile(
                              leading: (data['imageUrl'] != null && data['imageUrl'].toString().isNotEmpty)
                                  ? Image.network(data['imageUrl'], width: 50, height: 50, fit: BoxFit.cover, errorBuilder: (c,e,s) => Icon(Icons.restaurant_menu, color: sageGreen))
                                  : Icon(Icons.restaurant_menu, color: sageGreen),
                              title: Text(data['title'] ?? 'Χωρίς Τίτλο', style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("${recipeCats.join(", ")} • ${data['caloriesPerServing'] ?? 0} kcal"),
                                  if (missingIngredients.isNotEmpty)
                                    Padding(padding: const EdgeInsets.only(top: 4.0), child: Text(missingIngredients.length == 1 ? 'Λείπει: ${missingIngredients.first}' : 'Λείπουν: ${missingIngredients.join(", ")}', style: const TextStyle(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold), maxLines: 2, overflow: TextOverflow.ellipsis)),
                                ],
                              ),
                              trailing: const Icon(Icons.arrow_forward_ios, size: 14),
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
  const RecipeDetailsSheet({super.key, required this.recipeId, required this.data});

  @override
  State<RecipeDetailsSheet> createState() => _RecipeDetailsSheetState();
}

class _RecipeDetailsSheetState extends State<RecipeDetailsSheet> {
  late int _selectedServings;
  late int _originalServings;
  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);

  @override
  void initState() {
    super.initState();
    _originalServings = widget.data['servings'] ?? 1;
    _selectedServings = _originalServings; 
  }

  Future<void> _addIngredientsToShoppingList(List ingredientsList, double multiplier) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Πρέπει να συνδεθείτε για να προσθέσετε υλικά στη λίστα.')),
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

        String normalizedId = removeAccents(ingredientName);

        // Έλεγχος αν το υλικό υπάρχει ήδη στη λίστα
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
              if (RegExp(r'γραμμάρια|γραμμάριο|γραμμαρια|γραμμαριο|γραμμ|γραμ|γρ|grams|gram|gr|g').hasMatch(lowerQty)) {
                
                String cleanedQty = lowerQty
                    .replaceAll(RegExp(r'γραμμάρια|γραμμάριο|γραμμαρια|γραμμαριο|γραμμ|γραμ|γρ|grams|gram|gr|g'), '')
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
                // δεν είχε μονάδα βάρους πχ 3 τεμάχια
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
          const SnackBar(content: Text('Τα υλικά προστέθηκαν στη Λίστα Super Market! 🛒')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα κατά την προσθήκη: $e')),
        );
      }
    }
  }

  Future<void> _deleteRecipe() async {
    bool? confirm = await showDialog<bool>(
      context: context, builder: (context) => AlertDialog(title: const Text('Διαγραφή;'), content: const Text('Είστε σίγουροι;'), actions: [TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ΑΚΥΡΟ')), TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ΔΙΑΓΡΑΦΗ', style: TextStyle(color: Colors.red)))]),
    );
    if (confirm == true) {
      await FirebaseFirestore.instance.collection('recipes').doc(widget.recipeId).delete();
      if (mounted) Navigator.pop(context);
    }
  }

  Widget _buildMacroBox(String title, String value, Color color, IconData icon) {
    return Container(width: 75, padding: const EdgeInsets.symmetric(vertical: 8), decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withValues(alpha: 0.3))), child: Column(children: [Icon(icon, size: 20, color: color), const SizedBox(height: 4), Text(value, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: color)), Text(title, style: const TextStyle(fontSize: 10, color: Colors.black54))]));
  }

  @override
  Widget build(BuildContext context) {
    double multiplier = _selectedServings / _originalServings;
    int displayCals = ((widget.data['totalCalories'] ?? 0) * multiplier).round();
    int displayProtein = ((widget.data['totalProtein'] ?? 0) * multiplier).round();
    int displayCarbs = ((widget.data['totalCarbs'] ?? 0) * multiplier).round();
    int displayFats = ((widget.data['totalFats'] ?? 0) * multiplier).round();

    final currentUser = FirebaseAuth.instance.currentUser;
    final List<String> adminEmails = ['avramargeti@gmail.com', 'bokosdimitris@gmail.com', 'adonopoulouifigeneia@icloud.com'];
    final canEdit = currentUser != null && (adminEmails.contains(currentUser.email) || widget.data['userId'] == currentUser.uid);

    List<String> tags = List<String>.from(widget.data['tags'] ?? []);
    List<String> recipeCategories = [];
    if (widget.data['categories'] != null) {
      recipeCategories = List<String>.from(widget.data['categories']);
    } else if (widget.data['category'] != null) {
      recipeCategories = [widget.data['category']];
    }
    String categoryDisplay = recipeCategories.isNotEmpty ? recipeCategories.join(" • ") : "ΑΛΛΟ";

    return DraggableScrollableSheet(
      initialChildSize: 0.8, minChildSize: 0.5, maxChildSize: 0.95, expand: false,
      builder: (context, scrollController) => SingleChildScrollView(
        controller: scrollController, padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(child: Container(width: 40, height: 4, color: Colors.grey[300])),
            const SizedBox(height: 20),
            if (widget.data['imageUrl'] != null && widget.data['imageUrl'].toString().isNotEmpty) ...[
              ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(widget.data['imageUrl'], height: 200, width: double.infinity, fit: BoxFit.cover, errorBuilder: (c,e,s) => const SizedBox())),
              const SizedBox(height: 15),
            ],

            Text(categoryDisplay.toUpperCase(), style: TextStyle(color: sageGreen, fontWeight: FontWeight.bold, letterSpacing: 1.2)),

            Row(children: [
              Expanded(child: Text(widget.data['title'] ?? '', style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold, color: slateGrey))),
              if (canEdit) ...[
                IconButton(icon: const Icon(Icons.edit_document, color: Colors.blueAccent), onPressed: () { Navigator.pop(context); Navigator.push(context, MaterialPageRoute(builder: (context) => EditRecipeScreen(recipeId: widget.recipeId, recipeData: widget.data))); }),
                IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent), onPressed: _deleteRecipe),
              ]
            ]),
            
            if (tags.isNotEmpty) ...[
              const SizedBox(height: 5),
              Wrap(spacing: 6, runSpacing: -8, children: tags.map((tag) => Chip(label: Text(tag, style: const TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.bold)), backgroundColor: sageGreen, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide.none))).toList()),
            ],
const SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8), decoration: BoxDecoration(color: sageGreen.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(15)),
              child: Row(
                children: [
                  const Text('Μερίδες:', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)), const Spacer(),
                  IconButton(icon: const Icon(Icons.remove_circle_outline), onPressed: _selectedServings > 1 ? () => setState(() => _selectedServings--) : null),
                  Text('$_selectedServings', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.add_circle_outline), onPressed: () => setState(() => _selectedServings++)),
                ],
              ),
            ),
            Padding(padding: const EdgeInsets.only(top: 8.0, bottom: 20.0), child: Text('Η συνολική συνταγή βγάζει $_originalServings μερίδες', style: const TextStyle(color: Colors.grey, fontSize: 12, fontStyle: FontStyle.italic))),

            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              _buildMacroBox('Θερμίδες', '$displayCals', Colors.orange, Icons.local_fire_department),
              _buildMacroBox('Πρωτεΐνη', '${displayProtein}g', Colors.red, Icons.fitness_center),
              _buildMacroBox('Υδατάνθ.', '${displayCarbs}g', Colors.blue, Icons.grass),
              _buildMacroBox('Λιπαρά', '${displayFats}g', Colors.amber, Icons.water_drop),
            ]),
            
            const Divider(height: 40),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text('ΥΛΙΚΑ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                TextButton.icon(
                  onPressed: () => _addIngredientsToShoppingList(widget.data['ingredients'] as List, multiplier),
                  icon: const Icon(Icons.add_shopping_cart, size: 18),
                  label: const Text('Λίστα Αγορών', style: TextStyle(fontWeight: FontWeight.bold)),
                  style: TextButton.styleFrom(
                    foregroundColor: sageGreen,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...(widget.data['ingredients'] as List).map((i) {
              int displayAmount = ((i['amount'] as num) * multiplier).round();
              return Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [const Icon(Icons.check_circle_outline, size: 18, color: Colors.orangeAccent), const SizedBox(width: 10), Text('${i['name']} (${displayAmount}g)', style: const TextStyle(fontSize: 16))]));
            }),
            
            if (widget.data['prepDescription'] != null && widget.data['prepDescription'].toString().isNotEmpty) ...[
              const Divider(height: 40), const Text('ΠΕΡΙΓΡΑΦΗ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)), const SizedBox(height: 12),
              Text(widget.data['prepDescription'], style: const TextStyle(fontSize: 16)),
            ],

            const Divider(height: 40),
            const Text('ΕΚΤΕΛΕΣΗ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            ...(widget.data['steps'] as List).asMap().entries.map((entry) => Padding(padding: const EdgeInsets.only(bottom: 16), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [CircleAvatar(radius: 12, backgroundColor: sageGreen, child: Text('${entry.key + 1}', style: const TextStyle(fontSize: 12, color: Colors.white))), const SizedBox(width: 12), Expanded(child: Text(entry.value, style: const TextStyle(fontSize: 16)))]))),
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