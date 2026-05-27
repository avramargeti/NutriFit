import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'fitness_quiz_screen.dart';
import 'fitness_programs_screen.dart';

class FitnessScreen extends StatefulWidget {
  const FitnessScreen({super.key});

  @override
  State<FitnessScreen> createState() => _FitnessScreenState();
}

class _FitnessScreenState extends State<FitnessScreen> {
  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);

  bool hasCompletedQuiz = false;
  bool isCheckingState = true; 

  @override
  void initState() {
    super.initState();
    _checkQuizStatus(); 
  }

  Future<void> _checkQuizStatus() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists && doc.data()!.containsKey('fitnessPreferences')) {
          setState(() {
            hasCompletedQuiz = true;
          });
        }
      }
    } catch (e) {
      debugPrint("Σφάλμα κατά τον έλεγχο του προφίλ: $e");
    } finally {
      setState(() {
        isCheckingState = false; 
      });
    }
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
                    inactiveColor: sageGreen.withOpacity(0.3),
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
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.orange.withOpacity(0.5))
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
                        
                        if (mounted) {
                          Navigator.pop(context);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text('Επιτυχής προσθήκη στο προσωπικό πλάνο!'),
                              backgroundColor: sageGreen,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
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
            setState(() {
              hasCompletedQuiz = true;
            });
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const FitnessProgramsScreen(viewAll: false),
              ),
            );
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
        content: const Text(
            'Έχετε ήδη συμπληρώσει το κουίζ.\n\nΕίστε σίγουροι ότι θέλετε να το επαναλάβετε; Αν το κάνετε, τα προτεινόμενα προγράμματα γυμναστικής σας θα αλλάξουν βάσει των νέων απαντήσεων.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('ΑΚΥΡΩΣΗ', style: TextStyle(fontWeight: FontWeight.bold)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context); 
              _showQuiz(); 
            },
            child: const Text('ΣΥΝΕΧΕΙΑ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Fitness'),
        elevation: 0,
      ),
      body: isCheckingState 
          ? Center(child: CircularProgressIndicator(color: sageGreen)) 
          : SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Icon(Icons.sports_gymnastics, size: 80, color: sageGreen),
                  const SizedBox(height: 20),
                  
                  Text(
                    hasCompletedQuiz 
                        ? 'Έχετε ήδη βρει τα προγράμματα που σας ταιριάζουν!'
                        : 'Βρες το κατάλληλο πρόγραμμα γυμναστικής για εσένα!',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: slateGrey,
                    ),
                  ),
                  const SizedBox(height: 40),

                  if (hasCompletedQuiz) ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sageGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: const Icon(Icons.star, size: 26),
                      label: const Text(
                        'ΤΑ ΠΡΟΤΕΙΝΟΜΕΝΑ ΜΟΥ',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => const FitnessProgramsScreen(viewAll: false),
                          ),
                        );
                      },
                    ),
                    const SizedBox(height: 15),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: slateGrey,
                        side: BorderSide(color: slateGrey, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: const Icon(Icons.refresh, size: 26),
                      label: const Text(
                        'ΕΠΑΝΑΛΗΨΗ ΚΟΥΙΖ',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _retakeQuizWithWarning, 
                    ),
                  ] else ...[
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: sageGreen,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        elevation: 2,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15),
                        ),
                      ),
                      icon: const Icon(Icons.psychology_alt, size: 26),
                      label: const Text(
                        'ΒΡΕΣ ΤΙ ΣΟΥ ΤΑΙΡΙΑΖΕΙ',
                        style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
                      ),
                      onPressed: _showQuiz, 
                    ),
                  ],

                  const SizedBox(height: 15),

                  OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: slateGrey,
                      side: BorderSide(color: slateGrey, width: 2),
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(15),
                      ),
                    ),
                    icon: const Icon(Icons.list_alt, size: 26),
                    label: const Text(
                      'ΠΡΟΒΟΛΗ ΟΛΩΝ ΤΩΝ ΠΡΟΓΡΑΜΜΑΤΩΝ',
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const FitnessProgramsScreen(viewAll: true),
                        ),
                      );
                    },
                  ),
                  
                  const SizedBox(height: 40),
                  
                  Row(
                    children: [
                      Icon(Icons.local_fire_department, color: Colors.orange.shade700),
                      const SizedBox(width: 8),
                      Text(
                        'Top 10 (Καύση Θερμίδων)',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: slateGrey),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  
                  SizedBox(
                    height: 220, 
                    child: StreamBuilder<QuerySnapshot>(
                      stream: FirebaseFirestore.instance
                          .collection('fitness_programs')
                          .orderBy('estimatedCalories', descending: true)
                          .limit(10)
                          .snapshots(),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return Center(child: CircularProgressIndicator(color: sageGreen));
                        }

                        if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                          return Center(
                            child: Text(
                              'Δεν βρέθηκαν προγράμματα.',
                              style: TextStyle(color: Colors.grey.shade600),
                            ),
                          );
                        }

                        return ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: snapshot.data!.docs.length,
                          itemBuilder: (context, index) {
                            final data = snapshot.data!.docs[index].data() as Map<String, dynamic>;
                            return _buildTop10Card(data, index + 1);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _buildTop10Card(Map<String, dynamic> data, int rank) {
    return Container(
      width: 160,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: sageGreen.withOpacity(0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              CircleAvatar(
                radius: 12,
                backgroundColor: sageGreen,
                child: Text('#$rank', style: const TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              Icon(Icons.bolt, color: Colors.orange.shade400, size: 20),
            ],
          ),
          const Spacer(),
          Text(
            data['name'] ?? 'Χωρίς Τίτλο',
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 4),
          Text(
            data['category'] ?? '-',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade600),
          ),
          const SizedBox(height: 6),
          Text(
            '🔥 ${data['estimatedCalories'] ?? '0'} kcal',
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 13),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            height: 32,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: sageGreen,
                foregroundColor: Colors.white,
                padding: EdgeInsets.zero,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: () => _addToPlan(data),
              child: const Text('Προσθήκη', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }
}