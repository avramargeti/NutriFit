import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'user_profile_screen.dart';

class MemberSearchScreen extends StatefulWidget {
  const MemberSearchScreen({super.key});

  @override
  State<MemberSearchScreen> createState() => _MemberSearchScreenState();
}

class _MemberSearchScreenState extends State<MemberSearchScreen> {
  final TextEditingController _searchController = TextEditingController();
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final Color sageGreen = const Color(0xFFA6B39E);

  String? _selectedGoal; 
  String? _selectedDietType;

  List<DocumentSnapshot> _searchResults = [];
  bool _isLoading = false;
  bool _hasSearched = false;

  final List<String> _goalsList = [
    'Όλα τα μέλη',
    'Απώλεια Βάρους (Λίπους)',
    'Απώλεια Βάρους (Επιλογή Χρήστη)',
    'Αύξηση Βάρους & Μυϊκής Μάζας',
    'Διατήρηση & Ευεξία'
  ];

  final List<String> _dietList = [
    'Όλα (Χωρίς περιορισμούς)',
    'Vegetarian',
    'Vegan',
    'Pescatarian',
    'Keto / Low Carb'
  ];

  Future<void> _searchMembers() async {

    final scaffoldMessenger = ScaffoldMessenger.of(context);

    setState(() {
      _isLoading = true;
      _hasSearched = true;
      _searchResults.clear();
    });

    try {
      Query query = FirebaseFirestore.instance.collection('users');

      String searchText = _searchController.text.trim().toLowerCase();
      
      if (searchText.isNotEmpty) {
        query = query.where('username', isEqualTo: searchText);
      } 
      else {
        if (_selectedGoal != null && _selectedGoal != 'Όλα τα μέλη') {
          query = query.where('mainGoal', isEqualTo: _selectedGoal);
        }
        if (_selectedDietType != null && _selectedDietType != 'Όλα (Χωρίς περιορισμούς)') {
          query = query.where('dietType', isEqualTo: _selectedDietType);
        }
      }

      QuerySnapshot querySnapshot = await query.get();
      
      setState(() {
        _searchResults = querySnapshot.docs.where((doc) => doc.id != currentUser?.uid).toList();
      });
    } catch (e) {
      if (mounted) {
        scaffoldMessenger.showSnackBar(
          SnackBar(content: Text('Σφάλμα αναζήτησης: $e')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Αναζήτηση Μελών', style: TextStyle(color: Colors.blueGrey)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.blueGrey),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _searchController,
              decoration: InputDecoration(
                labelText: 'Αναζήτηση με Username',
                prefixIcon: const Icon(Icons.person_search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(15),
                  borderSide: BorderSide(color: sageGreen, width: 2),
                ),
              ),
              onChanged: (value) {
                if (value.isNotEmpty) {
                  setState(() {
                    _selectedGoal = null;
                    _selectedDietType = null;
                  });
                }
              },
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _selectedGoal,
              decoration: InputDecoration(
                labelText: 'Φίλτρο με βάση τον Στόχο',
                prefixIcon: const Icon(Icons.track_changes),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
              items: _goalsList.map((String goal) {
                return DropdownMenuItem<String>(value: goal, child: Text(goal));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedGoal = value;
                  _searchController.clear();
                });
              },
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              initialValue: _selectedDietType,
              decoration: InputDecoration(
                labelText: 'Φίλτρο με βάση τη Διατροφή',
                prefixIcon: const Icon(Icons.restaurant_menu),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15)),
              ),
              items: _dietList.map((String diet) {
                return DropdownMenuItem<String>(value: diet, child: Text(diet));
              }).toList(),
              onChanged: (value) {
                setState(() {
                  _selectedDietType = value;
                  _searchController.clear();
                });
              },
            ),
            const SizedBox(height: 16),

            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: sageGreen,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: _isLoading ? null : _searchMembers,
                icon: const Icon(Icons.search, color: Colors.white),
                label: const Text('ΑΝΑΖΗΤΗΣΗ', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(height: 24),

            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _searchResults.isEmpty && _hasSearched
                      ? const Center(
                          child: Text(
                            'Δεν βρέθηκαν μέλη με αυτά τα κριτήρια.\nΔοκιμάστε κάτι διαφορετικό!',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey),
                          ),
                        )
                      : ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, index) {
                            var userData = _searchResults[index].data() as Map<String, dynamic>;
                            String username = userData['username'] ?? 'Άγνωστος';
                            String fullName = userData['fullName'] ?? '';
                            String mainGoal = userData['mainGoal'] ?? '';
                            String dietType = userData['dietType'] ?? 'Όλα';
                            String userId = _searchResults[index].id;

                            return Card(
                              elevation: 2,
                              margin: const EdgeInsets.only(bottom: 12),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: Colors.blueGrey.shade100,
                                  child: const Icon(Icons.person, color: Colors.blueGrey),
                                ),
                                title: Text('@$username', style: const TextStyle(fontWeight: FontWeight.bold)),
                                subtitle: Text('$fullName\nΣτόχος: $mainGoal\nΔιατροφή: $dietType', style: const TextStyle(fontSize: 12)),
                                isThreeLine: true,
                                trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(builder: (context) => UserProfileScreen(targetUserId: userId)),
                                  );
                                },
                              ),
                            );
                          },
                        ),
            ),
          ],
        ),
      ),
    );
  }
}