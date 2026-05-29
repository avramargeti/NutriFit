import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_edit_ingredient_screen.dart';
import 'recipes_list_screen.dart';

class IngredientsListScreen extends StatefulWidget {
  final bool isSelectionMode;
  const IngredientsListScreen({super.key, this.isSelectionMode = false});

  @override
  State<IngredientsListScreen> createState() => _IngredientsListScreenState();
}

class _IngredientsListScreenState extends State<IngredientsListScreen> {
  String searchQuery = "";
  String selectedCategory = "Όλα";

  final List<String> categories = [
    "Όλα", "Κρέας", "Ψάρια & Θαλασσινά", "Γαλακτοκομικά", 
    "Φρούτα", "Λαχανικά", "Δημητριακά & Ζυμαρικά", "Όσπρια","Ξηροί Καρποί", "Vegan/Vegeterian", "Μπαχαρικά", "Λοιπά"
  ];

  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);

  @override
  Widget build(BuildContext context) {
    final currentUser = FirebaseAuth.instance.currentUser;
    final List<String> adminEmails = [
      'avramargeti@gmail.com',
      'bokosdimitris@gmail.com',
      'adonopoulouifigeneia@icloud.com'
    ];
    final isAdmin = currentUser != null && adminEmails.contains(currentUser.email);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Βιβλιοθήκη Υλικών', style: TextStyle(color: Colors.white)),
        backgroundColor: sageGreen,
        iconTheme: const IconThemeData(color: Colors.white),
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(15, 15, 15, 5),
            child: TextField(
              decoration: InputDecoration(
                hintText: 'Αναζήτηση υλικού...',
                prefixIcon: Icon(Icons.search, color: slateGrey),
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
              onChanged: (value) => setState(() => searchQuery = removeAccents(value)),
            ),
          ),

          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
            child: Row(
              children: categories.map((cat) {
                final isSelected = selectedCategory == cat;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 5),
                  child: FilterChip(
                    label: Text(cat),
                    selected: isSelected,
                    onSelected: (val) => setState(() => selectedCategory = cat),
                    selectedColor: sageGreen,
                    checkmarkColor: Colors.white,
                    labelStyle: TextStyle(
                      color: isSelected ? Colors.white : slateGrey,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    ),
                    backgroundColor: Colors.white,
                    shape: StadiumBorder(side: BorderSide(color: sageGreen.withValues(alpha: 0.3))),
                  ),
                );
              }).toList(),
            ),
          ),

          const Divider(height: 1),

          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('ingredients').orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                
                final filteredDocs = snapshot.data!.docs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final rawName = data['name'].toString();
                  final searchName = removeAccents(rawName);
                  final category = data['category'] ?? "Λοιπά";
                  
                  return searchName.contains(searchQuery) && (selectedCategory == "Όλα" || category == selectedCategory);
                }).toList();

                if (filteredDocs.isEmpty) return Center(child: Text('Δεν βρέθηκαν υλικά', style: TextStyle(color: slateGrey)));

                return ListView.builder(
                  itemCount: filteredDocs.length,
                  itemBuilder: (context, index) {
                    final doc = filteredDocs[index];
                    final data = doc.data() as Map<String, dynamic>;

                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                      child: ListTile(
                        onTap: () {
                          if (widget.isSelectionMode) {
                            Navigator.pop(context, data);
                          } else {
                            _showIngredientDetails(context, data);
                          }
                        },
                        leading: Container(
                          width: 50, height: 50,
                          decoration: BoxDecoration(color: const Color(0xFFF8F6F1), borderRadius: BorderRadius.circular(8)),
                          child: data['imageUrl'] != "" 
                            ? Image.network(data['imageUrl'], fit: BoxFit.contain)
                            : Icon(Icons.restaurant, color: slateGrey),
                        ),
                        title: Text(data['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('${data['caloriesPer100g']} kcal | ${data['category'] ?? "Λοιπά"}'),
                        trailing: isAdmin ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: Icon(Icons.edit, color: slateGrey),
                              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AdminEditIngredientScreen(docId: doc.id, currentData: data))),
                            ),
                            IconButton(
                              icon: const Icon(Icons.delete, color: Colors.redAccent),
                              onPressed: () => _confirmDelete(context, doc.id, data['name']),
                            ),
                          ],
                        ) : null,
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _confirmDelete(BuildContext context, String id, String name) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Διαγραφή;'),
        content: Text('Είστε σίγουροι για τη διαγραφή του υλικού "$name";'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ΑΚΥΡΟ')),
          TextButton(
            onPressed: () async {
              await FirebaseFirestore.instance.collection('ingredients').doc(id).delete();
              if (context.mounted) Navigator.pop(context);
            }, 
            child: const Text('ΔΙΑΓΡΑΦΗ', style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
  }

  void _showIngredientDetails(BuildContext context, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) {
        return SingleChildScrollView(
          child: Padding(
            padding: EdgeInsets.only(
              left: 20.0, right: 20.0, top: 20.0,
              bottom: MediaQuery.of(context).viewInsets.bottom + 20.0,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: Container(width: 40, height: 5, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 20),
                Text(data['name'] ?? 'Άγνωστο Υλικό', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(height: 5),
                Text(data['category'] ?? "Λοιπά", style: const TextStyle(color: Colors.grey, fontSize: 16)),
                const SizedBox(height: 20),
                const Divider(),
                const SizedBox(height: 10),
                const Text('Διατροφική Αξία (ανά 100g)', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildMacroItem('Θερμίδες', '${data['caloriesPer100g'] ?? 0}', 'kcal', Colors.orange),
                    _buildMacroItem('Πρωτεΐνη', '${data['protein'] ?? 0}', 'g', Colors.redAccent),
                    _buildMacroItem('Υδατ/κες', '${data['carbs'] ?? 0}', 'g', Colors.blueAccent),
                    _buildMacroItem('Λιπαρά', '${data['fats'] ?? 0}', 'g', Colors.amber),
                  ],
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        );
      }
    );
  }

  Widget _buildMacroItem(String title, String value, String unit, Color color) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
          child: Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
        ),
        const SizedBox(height: 8),
        Text(title, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold)),
        Text(unit, style: const TextStyle(fontSize: 12, color: Colors.grey)),
      ],
    );
  }
}