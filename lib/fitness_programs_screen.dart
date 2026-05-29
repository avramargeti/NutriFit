import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'add_fitness_programs_screen.dart';
import 'fitness_quiz_screen.dart';
import 'smart_insights_service.dart'; 

class FitnessProgramsScreen extends StatefulWidget {
  final bool viewAll;
  final Map<String, String>? userPreferences;

  const FitnessProgramsScreen({super.key, required this.viewAll, this.userPreferences});

  @override
  State<FitnessProgramsScreen> createState() => _FitnessProgramsScreenState();
}

class _FitnessProgramsScreenState extends State<FitnessProgramsScreen> {
  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);
  final String currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  final String currentUserEmail = FirebaseAuth.instance.currentUser?.email ?? '';
  final List<String> adminEmails = [
    'avramargeti@gmail.com',
    'bokosdimitris@gmail.com',
    'adonopoulouifigeneia@icloud.com'
  ];
  bool get isAdmin => adminEmails.contains(currentUserEmail);

  Map<String, dynamic>? userData;
  bool isLoadingUser = true;
  bool _isShowingAll = true; 
  Map<String, String>? _currentPreferences;

  @override
  void initState() {
    super.initState();
    _isShowingAll = widget.viewAll;
    _currentPreferences = widget.userPreferences;
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() {
          userData = doc.data();
          if (userData!.containsKey('fitnessPreferences')) {
            _currentPreferences = Map<String, String>.from(userData!['fitnessPreferences']);
          }
          isLoadingUser = false;
        });
      } else {
        if (mounted) setState(() => isLoadingUser = false);
      }
    } else {
      if (mounted) setState(() => isLoadingUser = false);
    }
  }

  void _showQuiz() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom + 24,
          left: 24, right: 24, top: 24,
        ),
        child: BasicFitnessQuiz(
          onCompleted: () {
            _loadUserData(); 
          },
        ),
      ),
    );
  }

  void _retakeQuizWithWarning() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Επανάληψη Κουίζ'),
        content: const Text('Θέλετε να επαναλάβετε το κουίζ; Τα προτεινόμενα προγράμματά σας θα αλλάξουν βάσει των νέων απαντήσεων.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('ΑΚΥΡΩΣΗ')),
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              _showQuiz(); 
            },
            child: const Text('ΣΥΝΕΧΕΙΑ', style: TextStyle(color: Colors.red)),
          ),
        ],
      )
    );
  }

  Future<void> _addToPlan(Map<String, dynamic> programData) async {
    int baseCalories = programData['estimatedCalories'] ?? 0;
    int baseDuration = 30; 

    String name = programData['name']?.toString().toLowerCase() ?? '';
    RegExp titleRegExp = RegExp(r"(\d+)\s*(?:'|λεπτά|λεπτα|min)");
    Match? titleMatch = titleRegExp.firstMatch(name);

    if (titleMatch != null) {
      baseDuration = int.tryParse(titleMatch.group(1) ?? '30') ?? 30;
    } else {
      String durationStr = programData['duration']?.toString() ?? '';
      if (durationStr == '< 30 λεπτά') {
        baseDuration = 25; 
      } else if (durationStr == '30-45 λεπτά') {
        baseDuration = 40; 
      } else if (durationStr == '> 45 λεπτά') {
        baseDuration = 50; 
      } else {
        RegExp numRegExp = RegExp(r'(\d+)');
        Match? numMatch = numRegExp.firstMatch(durationStr);
        if (numMatch != null) {
          baseDuration = int.tryParse(numMatch.group(1) ?? '30') ?? 30;
        }
      }
    }

    if (baseDuration <= 0) baseDuration = 30;

    int selectedMinutes = baseDuration;
    int calculatedCalories = baseCalories;

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: Row(
                children: [
                  Icon(Icons.calendar_today, color: sageGreen),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Προσθήκη στο Πλάνο', style: TextStyle(fontSize: 18))),
                ],
              ),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Πρόγραμμα: ${programData['name']}', 
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)
                  ),
                  const SizedBox(height: 20),
                  Text('Επίλεξε διάρκεια: $selectedMinutes λεπτά', style: TextStyle(color: slateGrey, fontWeight: FontWeight.bold)),
                  Slider(
                    value: selectedMinutes.toDouble(),
                    min: 10,
                    max: 120,
                    divisions: 11,
                    activeColor: sageGreen,
                    inactiveColor: sageGreen.withValues(alpha: 0.3),
                    onChanged: (val) {
                      setState(() {
                        selectedMinutes = val.toInt();
                        calculatedCalories = ((baseCalories / baseDuration) * selectedMinutes).round();
                      });
                    },
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withValues(alpha: 0.5))
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.local_fire_department, color: Colors.orange),
                        const SizedBox(width: 8),
                        Text(
                          'Θα κάψεις ~ $calculatedCalories kcal',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('ΑΚΥΡΩΣΗ', style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold)),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: sageGreen,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onPressed: () async {
                    final user = FirebaseAuth.instance.currentUser;
                    if (user != null) {
                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(user.uid)
                            .collection('my_plan')
                            .add({
                          'programName': programData['name'],
                          'category': programData['category'],
                          'durationMinutes': selectedMinutes,
                          'expectedCalories': calculatedCalories,
                          'addedAt': FieldValue.serverTimestamp(),
                          'status': 'Εκκρεμεί', 
                        });
                        
                        if (!context.mounted) return;
                          Navigator.pop(context, true); 
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Επιτυχής προσθήκη στο προσωπικό πλάνο!'),
                              backgroundColor: sageGreen,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        
                      } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Σφάλμα αποθήκευσης: $e')));
                      }
                    }
                  },
                  child: const Text('ΕΠΙΒΕΒΑΙΩΣΗ', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteMyProgram(String programId) async {
    bool confirm = await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Διαγραφή'),
        content: const Text('Θέλετε να διαγράψετε το πρόγραμμά σας;'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('ΑΚΥΡΩΣΗ')),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('ΔΙΑΓΡΑΦΗ', style: TextStyle(color: Colors.red))),
        ],
      ),
    ) ?? false;
    if (confirm) await FirebaseFirestore.instance.collection('fitness_programs').doc(programId).delete();
  }


  @override
  Widget build(BuildContext context) {
    bool hasQuiz = userData != null && userData!.containsKey('fitnessPreferences');

    return Scaffold(
      appBar: AppBar(
        title: Text(_isShowingAll ? 'Όλα τα Προγράμματα' : 'Για Εσάς'),
        actions: [
          if (!hasQuiz)
            IconButton(
              icon: const Icon(Icons.psychology_alt),
              tooltip: 'Βρες τι σου ταιριάζει',
              onPressed: () => _showQuiz()
            )
          else ...[
            IconButton(
              icon: Icon(_isShowingAll ? Icons.auto_awesome : Icons.list),
              tooltip: _isShowingAll ? 'Δες τα Προτεινόμενα' : 'Δες Όλα',
              onPressed: () => setState(() => _isShowingAll = !_isShowingAll),
            ),
            IconButton(
              icon: const Icon(Icons.refresh),
              tooltip: 'Επανάληψη Κουίζ',
              onPressed: _retakeQuizWithWarning,
            ),
          ],
        ],
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: sageGreen,
        onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddFitnessProgramScreen(isAdmin: isAdmin))),
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: isLoadingUser
          ? Center(child: CircularProgressIndicator(color: sageGreen))
          : StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance.collection('fitness_programs').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return Center(child: CircularProgressIndicator(color: sageGreen));
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) return const Center(child: Text('Δεν βρέθηκαν προγράμματα.'));

                List<QueryDocumentSnapshot> allDocs = snapshot.data!.docs;
                List<QueryDocumentSnapshot> finalDocs = [];
                List<String> activeInsights = [];

                if (_isShowingAll || _currentPreferences == null) {
                  finalDocs = allDocs;
                } else {
                  List<Map<String, dynamic>> scoredPrograms = [];
                  bool noExactMatch = false;

                  for (var doc in allDocs) {
                    final data = doc.data() as Map<String, dynamic>;
                    
                    int score = SmartInsightsService.calculateProgramScore(
                      programData: data, 
                      userPreferences: _currentPreferences, 
                      userData: userData
                    );
                    
                    scoredPrograms.add({'doc': doc, 'score': score});
                  }

                  scoredPrograms.sort((a, b) => (b['score'] as int).compareTo(a['score'] as int));
                  
                  var topPrograms = scoredPrograms.where((p) => (p['score'] as int) > 2).toList();

                  if (topPrograms.isEmpty) {
                    noExactMatch = true; 
                    finalDocs = scoredPrograms.take(3).map((p) => p['doc'] as QueryDocumentSnapshot).toList();
                  } else {
                    finalDocs = topPrograms.take(4).map((p) => p['doc'] as QueryDocumentSnapshot).toList();
                  }

                  activeInsights = SmartInsightsService.generateSmartInsights(
                    noExactMatch: noExactMatch, 
                    userData: userData
                  );
                }

                return Column(
                  children: [
                    if (!_isShowingAll && activeInsights.isNotEmpty)
                      Container(
                        margin: const EdgeInsets.all(16),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(color: sageGreen.withValues(alpha: 0.15), border: Border.all(color: sageGreen.withValues(alpha: 0.5)), borderRadius: BorderRadius.circular(15)),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(children: [
                              Icon(Icons.auto_awesome, color: sageGreen), 
                              const SizedBox(width: 8), 
                              Text('Γιατί σας προτείνουμε αυτά;', style: TextStyle(fontWeight: FontWeight.bold, color: slateGrey))
                            ]),
                            const SizedBox(height: 10),
                            ...activeInsights.map((insight) => Padding(padding: const EdgeInsets.only(bottom: 6), child: Text(insight, style: const TextStyle(fontSize: 13)))),
                          ],
                        ),
                      ),
                    
                    Expanded(
                      child: ListView.builder(
                        padding: const EdgeInsets.all(16),
                        itemCount: finalDocs.length,
                        itemBuilder: (context, index) {
                          final doc = finalDocs[index];
                          final data = doc.data() as Map<String, dynamic>;
                          final isMyProgram = data['createdBy'] == currentUserId;
                          final canEditOrDelete = isMyProgram || isAdmin;

                          return Card(
                            margin: const EdgeInsets.only(bottom: 16),
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(child: Text(data['name'] ?? '', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slateGrey))),
                                      
                                      if (canEditOrDelete)
                                        Row(mainAxisSize: MainAxisSize.min, children: [
                                          IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue, size: 20), onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => AddFitnessProgramScreen(isAdmin: false, programData: data, programId: doc.id)))),
                                          IconButton(icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20), onPressed: () => _deleteMyProgram(doc.id)),
                                        ]),
                                      Chip(label: Text(data['category'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.white)), backgroundColor: sageGreen),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text('${data['location']} • ${data['duration']} • ${data['intensity']}', style: TextStyle(color: Colors.grey.shade600)),
                                  if (data['description'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(data['description'], style: const TextStyle(fontStyle: FontStyle.italic))),
                                  if (data['estimatedCalories'] != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text('🔥 ~${data['estimatedCalories']} kcal', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent))),
                                  const SizedBox(height: 12),
                                  ElevatedButton(onPressed: () => _addToPlan(data), child: const Text('Προσθήκη στο Πλάνο')),
                                ],
                              ),
                            ),
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
}