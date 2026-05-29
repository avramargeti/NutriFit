import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ingredients_list_screen.dart';

class SuperMarketListScreen extends StatefulWidget {
  const SuperMarketListScreen({super.key});

  @override
  State<SuperMarketListScreen> createState() => _SuperMarketListScreenState();
}

class _SuperMarketListScreenState extends State<SuperMarketListScreen> {
  // Ίδια χρωματική παλέτα για ομοιομορφία
  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);

  User? get currentUser => FirebaseAuth.instance.currentUser;

  // 1. Αλλαγή κατάστασης (τικ / ξε-τίκ)
  Future<void> _toggleItem(String docId, bool currentVal) async {
    if (currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('shoppingList')
        .doc(docId)
        .update({'isChecked': !currentVal});
  }

  // 2. Οριστική διαγραφή υλικού
  Future<void> _deleteItem(String docId) async {
    if (currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('shoppingList')
        .doc(docId)
        .delete();
  }

  // 3A. Προσθήκη Custom Προϊόντος (Χειροκίνητα)
  void _showAddCustomItemDialog() {
    final TextEditingController nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Νέο Προϊόν'),
        content: TextField(
          controller: nameController,
          decoration: const InputDecoration(
            hintText: 'π.χ. Χαρτί Κουζίνας',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ΑΚΥΡΟ', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: sageGreen),
            onPressed: () async {
              String name = nameController.text.trim();
              if (name.isNotEmpty && currentUser != null) {
                await FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser!.uid)
                    .collection('shoppingList')
                    .doc(name) // Το όνομα γίνεται το ID
                    .set({
                  'name': name,
                  'amount': 0, // 0 σημαίνει ότι δεν έχει συγκεκριμένη ποσότητα
                  'isChecked': false,
                  'addedAt': FieldValue.serverTimestamp(),
                });
                if (mounted) Navigator.pop(context);
              }
            },
            child: const Text('ΠΡΟΣΘΗΚΗ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // 3Β. Προσθήκη Προϊόντος από τη Βιβλιοθήκη (επαναχρησιμοποίηση Components)
  Future<void> _addItemFromLibrary() async {
    final selectedIngredientData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const IngredientsListScreen(isSelectionMode: true),
      ),
    );

    if (selectedIngredientData != null && selectedIngredientData is Map<String, dynamic>) {
      String ingName = selectedIngredientData['name'];
      
      if (currentUser != null) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('shoppingList')
            .doc(ingName)
            .set({
          'name': ingName,
          'amount': 0,
          'isChecked': false,
          'addedAt': FieldValue.serverTimestamp(),
        });
      }
    }
  }

  // 4. Μενού Επιλογής (Bottom Sheet) για τον τρόπο προσθήκης
  void _showAddOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[300], borderRadius: BorderRadius.circular(10))),
            const SizedBox(height: 20),
            const Text('Προσθήκη στη λίστα', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            ListTile(
              leading: CircleAvatar(backgroundColor: sageGreen, child: const Icon(Icons.inventory_2_outlined, color: Colors.white)),
              title: const Text('Από Βιβλιοθήκη Υλικών'),
              subtitle: const Text('Επιλογή από τα διαθέσιμα υλικά'),
              onTap: () {
                Navigator.pop(context);
                _addItemFromLibrary();
              },
            ),
            ListTile(
              leading: CircleAvatar(backgroundColor: slateGrey, child: const Icon(Icons.edit, color: Colors.white)),
              title: const Text('Χειροκίνητη Προσθήκη'),
              subtitle: const Text('Γράψτε το δικό σας προϊόν'),
              onTap: () {
                Navigator.pop(context);
                _showAddCustomItemDialog();
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Λίστα Super Market')),
        body: const Center(child: Text('Πρέπει να συνδεθείτε.')),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text('Λίστα Αγορών', style: TextStyle(color: Colors.white)),
        backgroundColor: sageGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .doc(currentUser!.uid)
            .collection('shoppingList')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) return const Center(child: Text('Σφάλμα φόρτωσης.'));
          if (!snapshot.hasData) return Center(child: CircularProgressIndicator(color: sageGreen));

          final items = snapshot.data!.docs;

          if (items.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
                  const SizedBox(height: 16),
                  const Text(
                    'Η λίστα σας είναι άδεια.\nΠροσθέστε υλικά από τις συνταγές!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          // Έξυπνη ταξινόμηση: Τα επιλεγμένα (checked) πάνε στο τέλος της λίστας
          final sortedItems = items.toList()..sort((a, b) {
            bool aChecked = (a.data() as Map<String, dynamic>)['isChecked'] ?? false;
            bool bChecked = (b.data() as Map<String, dynamic>)['isChecked'] ?? false;
            if (aChecked == bChecked) return 0;
            return aChecked ? 1 : -1;
          });

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80), // Χώρος για το Floating Button
            itemCount: sortedItems.length,
            itemBuilder: (context, index) {
              final doc = sortedItems[index];
              final data = doc.data() as Map<String, dynamic>;
              final String docId = doc.id;
              final String name = data['name'] ?? '';
              final int amount = data['amount'] ?? 0;
              final bool isChecked = data['isChecked'] ?? false;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: isChecked ? 0 : 2,
                color: isChecked ? Colors.grey.shade200 : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  leading: Checkbox(
                    value: isChecked,
                    activeColor: sageGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => _toggleItem(docId, isChecked),
                  ),
                  title: Text(
                    amount > 0 ? '$name (${amount}g)' : name,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: isChecked ? FontWeight.normal : FontWeight.bold,
                      color: isChecked ? Colors.grey : slateGrey,
                      decoration: isChecked ? TextDecoration.lineThrough : TextDecoration.none,
                    ),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.close, color: Colors.red[300]),
                    onPressed: () => _deleteItem(docId),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddOptions,
        backgroundColor: slateGrey,
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text('Προσθήκη', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }
}