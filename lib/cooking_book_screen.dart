import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'recipes_list_screen.dart'; 

class CookingBookScreen extends StatefulWidget {
  const CookingBookScreen({super.key});

  @override
  State<CookingBookScreen> createState() => _CookingBookScreenState();
}

class _CookingBookScreenState extends State<CookingBookScreen> {
  String selectedMealTypeFilter = "Όλα";
  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);

  late Stream<QuerySnapshot> _recipesStream;
  Stream<QuerySnapshot>? _cookingBookStream;
  String? currentUserId;

  @override
  void initState() {
    super.initState();
    _recipesStream = FirebaseFirestore.instance.collection('recipes').snapshots();
    
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      currentUserId = user.uid;
      _cookingBookStream = FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('cookingBook')
          .snapshots();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUserId == null || _cookingBookStream == null) {
      return const Scaffold(
        body: Center(child: Text('Δεν είστε συνδεδεμένοι')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Cooking Book', style: TextStyle(color: Colors.white)),
        backgroundColor: sageGreen,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _cookingBookStream,
        builder: (context, savedSnapshot) {
          
          if (savedSnapshot.hasError) {
            return Center(child: Text('Σφάλμα: ${savedSnapshot.error}', style: const TextStyle(color: Colors.red)));
          }

          if (savedSnapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator(color: sageGreen));
          }

          if (!savedSnapshot.hasData || savedSnapshot.data!.docs.isEmpty) {
            return _buildEmptyState();
          }

          List<String> savedRecipeIds = [];
          Set<String> categoriesInBook = {"Όλα"};

          for (var doc in savedSnapshot.data!.docs) {
            savedRecipeIds.add(doc.id);
            var data = doc.data() as Map<String, dynamic>;
            
            if (data.containsKey('categories') && data['categories'] is List) {
              for (var cat in data['categories']) {
                categoriesInBook.add(cat.toString());
              }
            } else if (data.containsKey('category') && data['category'] != null) {
              categoriesInBook.add(data['category']);
            }
          }

          List<String> currentCategories = categoriesInBook.toList();
          String activeFilter = selectedMealTypeFilter;
          if (!currentCategories.contains(activeFilter)) {
            activeFilter = "Όλα";
          }

          return Column(
            children: [
              const SizedBox(height: 10),
              _buildDynamicFilterBar(currentCategories, activeFilter),
              const Divider(height: 20),

              Expanded(
                child: StreamBuilder<QuerySnapshot>(
                  stream: _recipesStream,
                  builder: (context, recipesSnapshot) {
                    
                    if (recipesSnapshot.hasError) {
                      return Center(child: Text('Σφάλμα συνταγών: ${recipesSnapshot.error}'));
                    }

                    if (!recipesSnapshot.hasData) {
                      return Center(child: CircularProgressIndicator(color: sageGreen));
                    }

                    List<QueryDocumentSnapshot> displayList = recipesSnapshot.data!.docs
                        .where((doc) => savedRecipeIds.contains(doc.id))
                        .toList();

                    if (activeFilter != "Όλα") {
                      displayList = displayList.where((doc) {
                        var savedData = savedSnapshot.data!.docs
                            .firstWhere((d) => d.id == doc.id)
                            .data() as Map<String, dynamic>;
                            
                        List<String> savedCats = [];
                        if (savedData.containsKey('categories')) {
                          savedCats = List<String>.from(savedData['categories']);
                        } else if (savedData.containsKey('category')) {
                          savedCats = [savedData['category']];
                        }
                        return savedCats.contains(activeFilter);
                      }).toList();
                    }

                    if (displayList.isEmpty) {
                      return const Center(child: Text("Δεν βρέθηκαν συνταγές σε αυτή την κατηγορία."));
                    }

                    return ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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

                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 6),
                          child: ListTile(
                            leading: _buildRecipeImage(data['imageUrl']),
                            title: Text(
                              data['title'] ?? 'Χωρίς Τίτλο',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            subtitle: Text(
                              "${recipeCats.join(", ")} • ${data['caloriesPerServing'] ?? 0} kcal",
                            ),
                            trailing: _buildTrailingSection(doc.id, data, currentUserId!),
                            onTap: () => _openRecipeDetails(doc.id, data),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildDynamicFilterBar(List<String> categories, String activeFilter) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: Row(
        children: categories.map((type) {
          final isSelected = activeFilter == type;
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: ChoiceChip(
              label: Text(type),
              selected: isSelected,
              onSelected: (val) {
                setState(() {
                  selectedMealTypeFilter = type;
                });
              },
              selectedColor: sageGreen,
              labelStyle: TextStyle(color: isSelected ? Colors.white : slateGrey),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildRecipeImage(String? imageUrl) {
    return Container(
      width: 50,
      height: 50,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
      child: (imageUrl != null && imageUrl.isNotEmpty)
          ? ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.network(imageUrl, fit: BoxFit.cover),
            )
          : Icon(Icons.restaurant_menu, color: sageGreen),
    );
  }

  Widget _buildTrailingSection(String recipeId, Map<String, dynamic> data, String uid) {
    List reviews = data['reviews'] ?? [];
    double avg = 0;
    if (reviews.isNotEmpty) {
      double sum = reviews.fold(0, (p, e) => p + (e['rating'] as num).toDouble());
      avg = sum / reviews.length;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (avg > 0) ...[
          Text(
            avg.toStringAsFixed(1),
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber),
          ),
          const Icon(Icons.star, color: Colors.amber, size: 18),
        ],
        IconButton(
          icon: const Icon(Icons.bookmark_remove, color: Colors.redAccent),
          onPressed: () => _deleteFromCookingBook(uid, recipeId),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.menu_book_outlined, size: 80, color: Colors.grey.shade300),
          const SizedBox(height: 16),
          Text(
            'Το Cooking Book σας είναι άδειο!',
            style: TextStyle(color: slateGrey, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteFromCookingBook(String uid, String docId) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('cookingBook')
        .doc(docId)
        .delete();
        
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Αφαιρέθηκε από το Cooking Book! 🗑️')),
      );
    }
  }

  void _openRecipeDetails(String recipeId, Map<String, dynamic> data) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Container(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(25)),
        ),
        child: RecipeDetailsSheet(recipeId: recipeId, data: data),
      ),
    );
  }
}