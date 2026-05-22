import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminEditIngredientScreen extends StatefulWidget {
  final String docId;
  final Map<String, dynamic> currentData;

  const AdminEditIngredientScreen({super.key, required this.docId, required this.currentData});

  @override
  State<AdminEditIngredientScreen> createState() => _AdminEditIngredientScreenState();
}

class _AdminEditIngredientScreenState extends State<AdminEditIngredientScreen> {
  late TextEditingController nameController;
  late TextEditingController caloriesController;
  late TextEditingController proteinController;
  late TextEditingController carbsController;
  late TextEditingController fatsController;
  late TextEditingController imageUrlController;

  String selectedCategory = "Λοιπά"; 
  // Λίστα κατηγοριών (ίδια με το Add Screen)
  final List<String> categories = [
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
    "Λοιπά"
  ];

  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    // Αρχικοποίηση των πεδίων με τα τρέχοντα δεδομένα
    nameController = TextEditingController(text: widget.currentData['name']);
    caloriesController = TextEditingController(text: widget.currentData['caloriesPer100g'].toString());
    proteinController = TextEditingController(text: widget.currentData['protein'].toString());
    carbsController = TextEditingController(text: widget.currentData['carbs'].toString());
    fatsController = TextEditingController(text: widget.currentData['fats'].toString());
    imageUrlController = TextEditingController(text: widget.currentData['imageUrl']);
    
    // Αρχικοποίηση της κατηγορίας: Αν δεν υπάρχει το πεδίο, βάζουμε "Λοιπά"
    if (widget.currentData['category'] != null && categories.contains(widget.currentData['category'])) {
      selectedCategory = widget.currentData['category'];
    } else {
      selectedCategory = "Λοιπά";
    }
  }

  Future<void> _updateIngredient() async {
    setState(() => isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('ingredients').doc(widget.docId).update({
        'name': nameController.text.trim(),
        'category': selectedCategory, 
        'caloriesPer100g': int.tryParse(caloriesController.text) ?? 0,
        'protein': double.tryParse(proteinController.text) ?? 0.0,
        'carbs': double.tryParse(carbsController.text) ?? 0.0,
        'fats': double.tryParse(fatsController.text) ?? 0.0,
        'imageUrl': imageUrlController.text.trim(),
      });
      
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Το υλικό ενημερώθηκε επιτυχώς!'), backgroundColor: Colors.green)
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: Colors.red)
        );
      }
    } finally {
      if (mounted) {
        setState(() => isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Επεξεργασία Υλικού'), 
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(controller: nameController, decoration: const InputDecoration(labelText: 'Όνομα', border: OutlineInputBorder())),
            const SizedBox(height: 15),

            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Κατηγορία',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: categories.map((String category) {
                return DropdownMenuItem(value: category, child: Text(category));
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedCategory = newValue!;
                });
              },
            ),
            const SizedBox(height: 15),

            TextField(controller: caloriesController, decoration: const InputDecoration(labelText: 'Θερμίδες (kcal/100g)', border: OutlineInputBorder()), keyboardType: TextInputType.number),
            const SizedBox(height: 15),
            
            Row(
              children: [
                Expanded(child: TextField(controller: proteinController, decoration: const InputDecoration(labelText: 'Πρωτεΐνη', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: carbsController, decoration: const InputDecoration(labelText: 'Υδατάνθρακες', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: fatsController, decoration: const InputDecoration(labelText: 'Λιπαρά', border: OutlineInputBorder()), keyboardType: TextInputType.number)),
              ],
            ),
            const SizedBox(height: 15),
            
            TextField(controller: imageUrlController, decoration: const InputDecoration(labelText: 'URL Εικόνας', border: OutlineInputBorder())),
            const SizedBox(height: 30),
            
            isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  onPressed: _updateIngredient, 
                  icon: const Icon(Icons.save),
                  label: const Text('ΕΝΗΜΕΡΩΣΗ ΥΛΙΚΟΥ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
          ],
        ),
      ),
    );
  }
}