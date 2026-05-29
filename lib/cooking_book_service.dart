import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CookingBookService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final Color _sageGreen = const Color(0xFFA8B3A0);

  Future<void> promptAddToCookingBook(BuildContext context, String recipeId, Map<String, dynamic> recipeData) async {
    await showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          title: const Text('Cooking Book', style: TextStyle(fontWeight: FontWeight.bold)),
          content: const Text('Επιθυμείτε την προσθήκη της συνταγής στο προσωπικό βιβλίο συνταγών σας;'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext), 
              child: const Text('ΟΧΙ', style: TextStyle(color: Colors.grey)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: _sageGreen),
              onPressed: () {
                Navigator.pop(dialogContext); 
                if (context.mounted) {
                  showCategorySelection(context, recipeId, recipeData); 
                }
              },
              child: const Text('ΝΑΙ', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  Future<void> showCategorySelection(BuildContext mainContext, String recipeId, Map<String, dynamic> recipeData) async {
    final user = _auth.currentUser;
    if (user == null) return;

    Set<String> existingCategories = {
      "Πρωινό", "Σνακ", "Μεσημεριανό", "Βραδινό", "Επιδόρπιο", "Ροφήματα"
    };

    try {
      final querySnapshot = await _db.collection('users').doc(user.uid).collection('cookingBook').get();
      for (var doc in querySnapshot.docs) {
        if (doc.data().containsKey('categories')) {
          existingCategories.addAll(List<String>.from(doc.data()['categories']));
        } else if (doc.data().containsKey('category') && doc.data()['category'] != null) {
          existingCategories.add(doc.data()['category']);
        }
      }
    } catch (e) {
      debugPrint("Σφάλμα ανάγνωσης κατηγοριών: $e");
    }

    List<String> selectedCategories = ["Αγαπημένα"];
    final TextEditingController newCategoryController = TextEditingController();

    if (!mainContext.mounted) return;

    await showDialog(
      context: mainContext,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (sbContext, setDialogState) {
            return AlertDialog(
              title: const Text('Προσθήκη στο Cooking Book'),
              content: SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Επιλέξτε μία ή περισσότερες κατηγορίες:'),
                    const SizedBox(height: 10),
                    Flexible(
                      child: SingleChildScrollView(
                        child: Wrap(
                          spacing: 8.0, runSpacing: 4.0,
                          children: existingCategories.map((cat) {
                            final isSelected = selectedCategories.contains(cat);
                            return FilterChip(
                              label: Text(cat),
                              selected: isSelected,
                              selectedColor: _sageGreen.withValues(alpha: 0.3),
                              checkmarkColor: _sageGreen,
                              onSelected: (bool selected) {
                                setDialogState(() {
                                  if(selected){ 
                                    selectedCategories.add(cat);
                                  }else{
                                     selectedCategories.remove(cat);
                                  }
                                });
                              },
                            );
                          }).toList(),
                        ),
                      ),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: newCategoryController,
                            decoration: const InputDecoration(hintText: 'Νέα κατηγορία...', isDense: true),
                          ),
                        ),
                        IconButton(
                          icon: Icon(Icons.add_circle, color: _sageGreen),
                          onPressed: () {
                            String newCat = newCategoryController.text.trim();
                            if (newCat.isNotEmpty) {
                              setDialogState(() {
                                existingCategories.add(newCat);
                                selectedCategories.add(newCat);
                                newCategoryController.clear();
                              });
                            }
                          }
                        )
                      ],
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(dialogContext), child: const Text('ΑΚΥΡΟ', style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: _sageGreen),
                  onPressed: () async {
                    if (selectedCategories.isEmpty) selectedCategories = ["Αγαπημένα"]; // Default fallback
                    
                    Navigator.pop(dialogContext); 
                    
                    try {
                      await _db.collection('users').doc(user.uid).collection('cookingBook').doc(recipeId).set({
                        'recipeId': recipeId,
                        'title': recipeData['title'] ?? 'Χωρίς τίτλο',
                        'imageUrl': recipeData['imageUrl'] ?? '',
                        'categories': selectedCategories,
                        'addedAt': Timestamp.now(),
                      });

                      if (mainContext.mounted) {
                        ScaffoldMessenger.of(mainContext).showSnackBar(
                          const SnackBar(
                            content: Text('Προστέθηκε στο Cooking Book! 📚'), 
                            backgroundColor: Colors.green, 
                          )
                        );
                      }
                    } catch (e) {
                      debugPrint("ΣΦΑΛΜΑ FIREBASE: $e");
                    }
                  },
                  child: const Text('ΑΠΟΘΗΚΕΥΣΗ', style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
        );
      },
    );
  }
}