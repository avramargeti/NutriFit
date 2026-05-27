import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AdminAddIngredientScreen extends StatefulWidget {
  const AdminAddIngredientScreen({super.key});

  @override
  State<AdminAddIngredientScreen> createState() => _AdminAddIngredientScreenState();
}

class _AdminAddIngredientScreenState extends State<AdminAddIngredientScreen> {
  final TextEditingController nameController = TextEditingController();
  final TextEditingController caloriesController = TextEditingController();
  final TextEditingController proteinController = TextEditingController();
  final TextEditingController carbsController = TextEditingController();
  final TextEditingController fatsController = TextEditingController();
  final TextEditingController imageUrlController = TextEditingController();

  String selectedCategory = "Κρέας"; 
    // Λίστα κατηγοριών (ίδια με το Edit Screen)
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

  Future<void> _saveIngredient() async {
    if (nameController.text.isEmpty || caloriesController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Το όνομα και οι θερμίδες είναι υποχρεωτικά!'), backgroundColor: Colors.red),
      );
      return;
    }

    setState(() => isLoading = true);

    try {
      // Αποθήκευση στο "ingredients" με την προσθήκη κατηγορίας
      await FirebaseFirestore.instance.collection('ingredients').add({
        'name': nameController.text.trim(),
        'category': selectedCategory, 
        'caloriesPer100g': int.tryParse(caloriesController.text) ?? 0,
        'protein': double.tryParse(proteinController.text) ?? 0.0,
        'carbs': double.tryParse(carbsController.text) ?? 0.0,
        'fats': double.tryParse(fatsController.text) ?? 0.0,
        'imageUrl': imageUrlController.text.trim(),
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Το υλικό προστέθηκε επιτυχώς!'), backgroundColor: Colors.green),
        );

        nameController.clear();
        caloriesController.clear();
        proteinController.clear();
        carbsController.clear();
        fatsController.clear();
        imageUrlController.clear();
        setState(() {
          selectedCategory = "Κρέας"; // Επαναφορά προεπιλογής
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      setState(() => isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Admin: Προσθήκη Υλικού'),
        backgroundColor: Colors.blueGrey,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Βάση Δεδομένων Υλικών',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.blueGrey),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),

            // Όνομα Υλικού
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Όνομα Υλικού', 
                border: OutlineInputBorder(), 
                prefixIcon: Icon(Icons.restaurant)
              ),
            ),
            const SizedBox(height: 15),

            // Dropdown για επιλογή κατηγορίας
            DropdownButtonFormField<String>(
              initialValue: selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Κατηγορία',
                border: OutlineInputBorder(),
                prefixIcon: Icon(Icons.category),
              ),
              items: categories.map((String category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category),
                );
              }).toList(),
              onChanged: (String? newValue) {
                setState(() {
                  selectedCategory = newValue!;
                });
              },
            ),
            const SizedBox(height: 15),

            // Θερμίδες
            TextField(
              controller: caloriesController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Θερμίδες (kcal ανά 100g)', 
                border: OutlineInputBorder(), 
                prefixIcon: Icon(Icons.local_fire_department, color: Colors.orange)
              ),
            ),
            const SizedBox(height: 15),

            // Μακροθρεπτικά
            Row(
              children: [
                Expanded(child: TextField(controller: proteinController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Πρωτεΐνη (g)', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: carbsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Υδατάνθρακες', border: OutlineInputBorder()))),
                const SizedBox(width: 10),
                Expanded(child: TextField(controller: fatsController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'Λιπαρά (g)', border: OutlineInputBorder()))),
              ],
            ),
            const SizedBox(height: 15),

            // Φωτογραφία
            TextField(
              controller: imageUrlController,
              decoration: const InputDecoration(
                labelText: 'URL Φωτογραφίας', 
                border: OutlineInputBorder(), 
                prefixIcon: Icon(Icons.image)
              ),
            ),
            const SizedBox(height: 30),

            // Κουμπί Αποθήκευσης
            isLoading 
              ? const Center(child: CircularProgressIndicator())
              : ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueGrey,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                  ),
                  icon: const Icon(Icons.save),
                  label: const Text('ΑΠΟΘΗΚΕΥΣΗ ΣΤΗ ΒΑΣΗ', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  onPressed: _saveIngredient,
                ),

          ],
        ),
      ),
    );
  }
}