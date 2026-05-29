import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'ingredients_list_screen.dart';
import 'recipes_list_screen.dart';

class SuperMarketListScreen extends StatefulWidget {
  const SuperMarketListScreen({super.key});

  @override
  State<SuperMarketListScreen> createState() => _SuperMarketListScreenState();
}

class _SuperMarketListScreenState extends State<SuperMarketListScreen> {
  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);

  User? get currentUser => FirebaseAuth.instance.currentUser;

  Future<void> _toggleItem(String docId, bool currentVal) async {
    if (currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('shoppingList')
        .doc(docId)
        .update({'isChecked': !currentVal});
  }

  Future<void> _deleteItem(String docId) async {
    if (currentUser == null) return;
    await FirebaseFirestore.instance
        .collection('users')
        .doc(currentUser!.uid)
        .collection('shoppingList')
        .doc(docId)
        .delete();
  }

  void _showEditItemDialog(String docId, String currentName, String currentQuantity, int currentAmount) {
    final TextEditingController nameController = TextEditingController(text: currentName);
    
    // Αν δεν έχει quantity από χρήστη αλλά έχει amount από συνταγή βάλτο ως αρχικό κείμενο
    String initialQty = currentQuantity.isNotEmpty 
        ? currentQuantity 
        : (currentAmount > 0 ? '${currentAmount}g' : '');
    final TextEditingController qtyController = TextEditingController(text: initialQty);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Επεξεργασία Προϊόντος'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Όνομα προϊόντος', border: OutlineInputBorder()),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(labelText: 'Ποσότητα (Προαιρετικό)', border: OutlineInputBorder()),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ΑΚΥΡΟ', style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: sageGreen),
            onPressed: () async {
              String newName = nameController.text.trim();
              String newQty = qtyController.text.trim();
              if (newName.isEmpty || currentUser == null) return;

              String newDocId = generateIngredientId(newName);

              final collectionRef = FirebaseFirestore.instance
                  .collection('users')
                  .doc(currentUser!.uid)
                  .collection('shoppingList');

              if (newDocId == docId) {
                await collectionRef.doc(docId).update({
                  'name': newName,
                  'quantity': newQty,
                  'amount': 0,
                });
              } else {
                final existingDoc = await collectionRef.doc(newDocId).get();
                if (existingDoc.exists) {
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Υπάρχει ήδη προϊόν με αυτό το όνομα στη λίστα!')),
                    );
                  }
                  return;
                }

                // Αν δεν υπάρχει, φτιάχνουμε νέο αρχείο και σβήνουμε το παλιό
                final oldDoc = await collectionRef.doc(docId).get();
                bool isChecked = oldDoc.exists ? (oldDoc.data()?['isChecked'] ?? false) : false;
                
                await collectionRef.doc(newDocId).set({
                  'name': newName,
                  'amount': 0, 
                  'quantity': newQty,
                  'isChecked': isChecked,
                  'addedAt': FieldValue.serverTimestamp(),
                });
                await collectionRef.doc(docId).delete();
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('ΑΠΟΘΗΚΕΥΣΗ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  // Προσθήκη Custom Προϊόντος
  void _showAddCustomItemDialog() {
    final TextEditingController nameController = TextEditingController();
    final TextEditingController qtyController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Νέο Προϊόν'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: 'Όνομα προϊόντος *',
                hintText: 'π.χ. Χαρτί Κουζίνας',
                border: OutlineInputBorder(),
              ),
              autofocus: true,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: qtyController,
              decoration: const InputDecoration(
                labelText: 'Ποσότητα (Προαιρετικό)',
                hintText: 'π.χ. 2 ρολά, 500g',
                border: OutlineInputBorder(),
              ),
            ),
          ],
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
              String qty = qtyController.text.trim();
              if (name.isNotEmpty && currentUser != null) {

                String normalizedId = generateIngredientId(name);

                final docRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser!.uid)
                    .collection('shoppingList')
                    .doc(normalizedId);

                final docSnapshot = await docRef.get();
                if (docSnapshot.exists) {
                  if (mounted) {
                    Navigator.pop(context);

                    var data = docSnapshot.data() as Map<String, dynamic>;
                    String existingName = data['name'] ?? name;
                    String existingQty = data['quantity'] ?? '';
                    int existingAmount = data['amount'] ?? 0;
                    String existingId = docSnapshot.id;
                    
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        title: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Text('Ενημέρωση'),
                          ],
                        ),
                        content: const Text('Το προϊόν υπάρχει ήδη στη λίστα σας.\nΘέλετε να επεξεργαστείτε την ποσότητά του;'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('ΑΚΥΡΟ', style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                              _showEditItemDialog(existingId, existingName, existingQty, existingAmount);
                            },
                            child: const Text('ΕΠΕΞΕΡΓΑΣΙΑ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                          ),
                        ],
                      ),
                    );
                  }
                  return;
                }

                await docRef.set({
                  'name': name,
                  'amount': 0, 
                  'quantity': qty, 
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

  Future<void> _showQuantityForLibraryItem(String ingName) async {
    final TextEditingController qtyController = TextEditingController();
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Ποσότητα για: $ingName'),
        content: TextField(
          controller: qtyController,
          decoration: const InputDecoration(
            labelText: 'Ποσότητα (Προαιρετικό)',
            hintText: 'π.χ. 2 τεμάχια, 1kg',
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
              String qty = qtyController.text.trim();
              if (currentUser != null) {

                String normalizedId = generateIngredientId(ingName);
                
                final docRef = FirebaseFirestore.instance
                    .collection('users')
                    .doc(currentUser!.uid)
                    .collection('shoppingList')
                    .doc(normalizedId);

                final docSnapshot = await docRef.get();
                if (docSnapshot.exists) {
                  if (mounted) {
                    Navigator.pop(context);

                     var data = docSnapshot.data() as Map<String, dynamic>;
                    String existingName = data['name'] ?? ingName;
                    String existingQty = data['quantity'] ?? '';
                    int existingAmount = data['amount'] ?? 0;
                    String existingId = docSnapshot.id;
                    
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                        title: const Row(
                          children: [
                            Icon(Icons.info_outline, color: Colors.blueAccent),
                            SizedBox(width: 8),
                            Text('Ενημέρωση'),
                          ],
                        ),
                        content: const Text('Το προϊόν υπάρχει ήδη στη λίστα σας.\nΘέλετε να επεξεργαστείτε την ποσότητά του;'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('ΑΚΥΡΟ', style: TextStyle(color: Colors.grey)),
                          ),
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context); 
                              _showEditItemDialog(existingId, existingName, existingQty, existingAmount);
                            },
                            child: const Text('ΕΠΕΞΕΡΓΑΣΙΑ', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
                          ),
                        ],
                      ),
                    );
                  }
                  return; 
                }

                await docRef.set({
                  'name': ingName,
                  'amount': 0,
                  'quantity': qty, 
                  'isChecked': false,
                  'addedAt': FieldValue.serverTimestamp(),
                });
              }
              if (mounted) Navigator.pop(context);
            },
            child: const Text('ΠΡΟΣΘΗΚΗ', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
  
  // Προσθήκη Προϊόντος από τη Βιβλιοθήκη
  Future<void> _addItemFromLibrary() async {
    final selectedIngredientData = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => const IngredientsListScreen(isSelectionMode: true),
      ),
    );

    if (selectedIngredientData != null && selectedIngredientData is Map<String, dynamic>) {
      String ingName = selectedIngredientData['name'];
      
      if (mounted) {
        await _showQuantityForLibraryItem(ingName);
      }
    }
  }

  Future<void> _clearAllItems() async {
    if (currentUser == null) return;

    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.warning_amber_rounded, color: Colors.redAccent),
            SizedBox(width: 8),
            Text('Εκκαθάριση Λίστας'),
          ],
        ),
        content: const Text('Είστε σίγουροι ότι θέλετε να αδειάσετε τη λίστα αγορών σας;'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('ΑΚΥΡΟ', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('ΕΚΚΑΘΑΡΙΣΗ', style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      final batch = FirebaseFirestore.instance.batch();
      final collectionRef = FirebaseFirestore.instance
          .collection('users')
          .doc(currentUser!.uid)
          .collection('shoppingList');

      final snapshots = await collectionRef.get();
      for (var doc in snapshots.docs) {
        batch.delete(doc.reference);
      }
      await batch.commit();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Η λίστα αγορών εκκαθαρίστηκε επιτυχώς.')),
        );
      }
    }
  }

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
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            tooltip: 'Εκκαθάριση όλων',
            onPressed: _clearAllItems,
          ),
        ],
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
                    'Η λίστα σας είναι άδεια.\nΠροσθέστε προϊόντα!',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            );
          }

          final sortedItems = items.toList()..sort((a, b) {
            bool aChecked = (a.data() as Map<String, dynamic>)['isChecked'] ?? false;
            bool bChecked = (b.data() as Map<String, dynamic>)['isChecked'] ?? false;
            if (aChecked == bChecked) return 0;
            return aChecked ? 1 : -1;
          });

          return ListView.builder(
            padding: const EdgeInsets.only(bottom: 80),
            itemCount: sortedItems.length,
            itemBuilder: (context, index) {
              final doc = sortedItems[index];
              final data = doc.data() as Map<String, dynamic>;
              final String docId = doc.id;
              final String name = data['name'] ?? '';
              final int amount = data['amount'] ?? 0;
              final String quantity = data['quantity'] ?? '';
              final bool isChecked = data['isChecked'] ?? false;

              String displaySuffix = '';
              if (quantity.isNotEmpty) {
                displaySuffix = ' ($quantity)';
              } else if (amount > 0) {
                displaySuffix = ' (${amount}g)';
              }

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                elevation: isChecked ? 0 : 2,
                color: isChecked ? Colors.grey.shade200 : Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                child: ListTile(
                  onTap: () => _showEditItemDialog(docId, name, quantity, amount),
                  leading: Checkbox(
                    value: isChecked,
                    activeColor: sageGreen,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                    onChanged: (val) => _toggleItem(docId, isChecked),
                  ),
                  title: Text(
                    '$name$displaySuffix',
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