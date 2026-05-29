import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math';
import 'registration_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  bool isLoading = true;
  Map<String, dynamic>? userData;
  
  double bmi = 0;
  double baseTdee = 0; 
  int targetCalories = 0;
  String proposedMainGoal = "";
  
  final List<String> secondaryOptions = [
    'Απώλεια Βάρους', 
    'Αύξηση Βάρους', 
    'Βελτίωση αντοχής', 
    'Ενυδάτωση', 
    'Μείωση Άγχους', 
    'Καλύτερος Ύπνος', 
    'Αποχή από άσκηση' 
  ];
  List<String> selectedSecondary = [];

  final Color primaryColor = const Color(0xFFA8B3A0); 
  final Color darkPrimaryColor = const Color(0xFF8C9DA6); 
  final Color accentColor = const Color(0xFFA8B3A0); 
  final Color lightBeige = const Color(0xFFF8F6F1); 

  @override
  void initState() {
    super.initState();
    _fetchUserDataAndCalculate();
  }

  Future<void> _fetchUserDataAndCalculate() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists) {
        setState(() {
          userData = doc.data() as Map<String, dynamic>;
          
          if (userData!['secondaryGoals'] != null) {
            selectedSecondary = List<String>.from(userData!['secondaryGoals']);
          }

          _calculateMetrics();
        });

        // ΕΛΕΓΧΟΣ ΑΚΡΑΙΟΥ BMI 
        if (bmi > 0 && (bmi < 15 || bmi > 45)) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showBMIRestrictionDialog();
          });
          setState(() { isLoading = false; });
          return; 
        }

        setState(() {
          isLoading = false;
        });
      }
    }
  }

  // Εναλλακτική Ροή 4
  void _showBMIRestrictionDialog() {
    showDialog(
      context: context,
      barrierDismissible: false, 
      builder: (context) => AlertDialog(
        title: const Text('Σημαντική Ενημέρωση', style: TextStyle(color: Colors.red)),
        content: const Text(
          'Σας ευχαριστούμε που επιλέξατε την εφαρμογή μας για να κάνετε ένα θετικό βήμα για την υγεία σας! Η πλατφόρμα μας είναι σχεδιασμένη για γενικούς στόχους ευεξίας. Με βάση τα στοιχεία σας, πιστεύουμε πως σας αξίζει μια πιο εξατομικευμένη και ιατρικά καθοδηγούμενη προσέγγιση, την οποία δεν μπορούμε να σας παρέχουμε με απόλυτη ασφάλεια. Σας προτείνουμε να συμβουλευτείτε τον γιατρό ή τον διατροφολόγο σας για να ξεκινήσετε το ταξίδι σας με τον καλύτερο δυνατό τρόπο. Σας ευχόμαστε ολόψυχα καλή επιτυχία!',
          style: TextStyle(fontSize: 15),
          textAlign: TextAlign.justify,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        actionsAlignment: MainAxisAlignment.spaceBetween,
        actions: [
          // Επιλογή 1: Επιστροφή στη φόρμα (αν έγινε λάθος πληκτρολόγηση)
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.pushReplacement(
                context,
                MaterialPageRoute(builder: (context) => const RegistrationScreen(initialStep: 1)),
              );
            },
            child: Text('ΕΠΙΣΤΡΟΦΗ & ΔΙΟΡΘΩΣΗ', style: TextStyle(color: darkPrimaryColor, fontWeight: FontWeight.bold)),
          ),
          // Επιλογή 2: Διαγραφή Λογαριασμού
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _deleteProfileAndExit();
            },
            child: const Text('ΔΙΑΓΡΑΦΗ ΠΡΟΦΙΛ', style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Συνάρτηση Διαγραφής (Βήμα 5.δ.4)
  Future<void> _deleteProfileAndExit() async {
    setState(() => isLoading = true);
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        // Διαγραφή δεδομένων από το Firestore
        await FirebaseFirestore.instance.collection('users').doc(user.uid).delete();
        // Διαγραφή λογαριασμού από το Authentication
        await user.delete();
      }
    } catch (e) {
      debugPrint("Σφάλμα κατά τη διαγραφή προφίλ: $e");
    } finally {
      if (mounted) {
        // Επιστροφή στην αρχική οθόνη 
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _calculateMetrics() {
    double w = (userData!['weight'] as num?)?.toDouble() ?? 0.0;
    double h = (userData!['height'] as num?)?.toDouble() ?? 0.0;
    int age = 25; // Προεπιλογή
    if (userData!['dateOfBirth'] != null) {
      DateTime dob = (userData!['dateOfBirth'] as Timestamp).toDate();
      DateTime today = DateTime.now();
      age = today.year - dob.year;
      
      if (today.month < dob.month || (today.month == dob.month && today.day < dob.day)) {
        age--;
      }
    } else if (userData!['age'] != null) {
      age = (userData!['age'] as num).toInt();
    } 
    String gender = userData!['gender'] ?? 'Άνδρας';
    String freq = userData!['exerciseFreq'] ?? '1-2 φορές/εβδομάδα';

    if (h <= 0 || w <= 0) {
      bmi = 0;
      targetCalories = 0;
      proposedMainGoal = "Λείπουν σωματικά στοιχεία.";
      return; 
    }

    bmi = w / pow(h / 100, 2);

    double bmr = (10 * w) + (6.25 * h) - (5 * age);
    bmr = (gender == 'Άνδρας') ? bmr + 5 : bmr - 161;

    double multiplier = 1.2;
    if (freq == '1-2 φορές/εβδομάδα') multiplier = 1.375;
    if (freq == '3-4 φορές/εβδ') multiplier = 1.55;
    if (freq == 'Καθημερινά') multiplier = 1.725;

    baseTdee = bmr * multiplier;

    if (bmi < 18.5) {
      proposedMainGoal = "Αύξηση Βάρους & Μυϊκής Μάζας";
    } else if (bmi > 25) {
      proposedMainGoal = "Απώλεια Βάρους (Λίπους)";
    } else {
      proposedMainGoal = "Διατήρηση & Ευεξία";
    }
    if (proposedMainGoal.contains('Απώλεια')) selectedSecondary.remove('Απώλεια Βάρους');
    if (proposedMainGoal.contains('Αύξηση')) selectedSecondary.remove('Αύξηση Βάρους');
    _updateDynamicCalories();
  }

  void _updateDynamicCalories() {
    double tempCalories = baseTdee;

    if (proposedMainGoal.contains('Απώλεια') || selectedSecondary.contains('Απώλεια Βάρους')) {
      tempCalories -= 500;
    } else if (proposedMainGoal.contains('Αύξηση') || selectedSecondary.contains('Αύξηση Βάρους')) {
      tempCalories += 400;
    }

    setState(() {
      targetCalories = tempCalories.toInt();
    });
  }

  bool _checkIncompatibility() {
    String errorMsg = '';

    if (selectedSecondary.contains('Αποχή από άσκηση') && 
        selectedSecondary.contains('Βελτίωση αντοχής')) {
      errorMsg = 'Η αποχή από την άσκηση έρχεται σε αντίθεση με τη βελτίωση αντοχής.';
    }
    else if (selectedSecondary.contains('Απώλεια Βάρους') && 
             selectedSecondary.contains('Αύξηση Βάρους')) {
      errorMsg = 'Δεν μπορείτε να επιλέξετε ταυτόχρονα την απώλεια και την αύξηση βάρους.';
    }
    else if (proposedMainGoal.contains('Αύξηση Βάρους') && 
             selectedSecondary.contains('Απώλεια Βάρους')) {
      errorMsg = 'Έχετε επιλέξει "Απώλεια Βάρους", αλλά ο κύριος ιατρικός σας στόχος βάσει BMI είναι η "Αύξηση Βάρους".';
    }
    else if (proposedMainGoal.contains('Απώλεια Βάρους') && 
             selectedSecondary.contains('Αύξηση Βάρους')) {
      errorMsg = 'Έχετε επιλέξει "Αύξηση Βάρους", αλλά ο κύριος ιατρικός σας στόχος βάσει BMI είναι η "Απώλεια Βάρους".';
    }

    if (errorMsg.isNotEmpty) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Ασυμβατότητα Στόχων', style: TextStyle(color: Colors.red)),
          content: Text(errorMsg, style: const TextStyle(fontSize: 16)),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: Text('ΔΙΟΡΘΩΣΗ', style: TextStyle(color: darkPrimaryColor, fontWeight: FontWeight.bold))
            )
          ],
        )
      );
      return true;
    }
    return false; 
  }

  Future<void> _saveFinalPlan() async {
    if (_checkIncompatibility()) return;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(child: CircularProgressIndicator(color: primaryColor)),
    );

    try {
      String finalMainGoal = proposedMainGoal;
      if (selectedSecondary.contains('Απώλεια Βάρους')) {
        finalMainGoal = "Απώλεια Βάρους (Επιλογή Χρήστη)";
      } else if (selectedSecondary.contains('Αύξηση Βάρους')) {
        finalMainGoal = "Αύξηση Βάρους & Μυϊκής Μάζας";
      }

      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'mainGoal': finalMainGoal,
          'secondaryGoals': selectedSecondary,
          'targetCalories': targetCalories,
          'bmi': double.parse(bmi.toStringAsFixed(1)),
          'hasSetGoals': true,
        }, SetOptions(merge: true));
      }

      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    } catch (e) {
      if (mounted) {
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Σφάλμα αποθήκευσης: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return Scaffold(body: Center(child: CircularProgressIndicator(color: primaryColor)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Οι Στόχοι Μου', style: TextStyle(fontWeight: FontWeight.bold)), 
        backgroundColor: Colors.transparent, 
        foregroundColor: darkPrimaryColor,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // BMI
            Card(
              color: lightBeige, 
              elevation: 3,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Row(
                  children: [
                    Icon(Icons.monitor_heart_outlined, color: darkPrimaryColor, size: 30),
                    const SizedBox(width: 15),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Το BMI σας:', style: TextStyle(fontSize: 16, color: darkPrimaryColor)), 
                        Text(bmi.toStringAsFixed(1), style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: darkPrimaryColor)),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Κάρτα Πρότασης NutriFit
            Text('Πρόταση NutriFit:', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: darkPrimaryColor)), 
            const SizedBox(height: 8),
            Card(
              color: Colors.white,
              elevation: 4,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.flag_circle_outlined, color: accentColor, size: 30),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            proposedMainGoal, 
                            style: TextStyle(fontSize: 20, color: darkPrimaryColor, fontWeight: FontWeight.bold), 
                            textAlign: TextAlign.center
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 15),
                    const Divider(),
                    const SizedBox(height: 15),
                    Text('Προτεινόμενες Θερμίδες:', style: TextStyle(fontSize: 16, color: Colors.grey.shade700)),
                    Text(
                      '$targetCalories kcal', 
                      style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: accentColor)
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Δευτερεύοντες Στόχοι
            Text(
              'Θέλετε να προσθέσετε δευτερεύοντες στόχους;', 
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600, color: darkPrimaryColor) 
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: secondaryOptions.where((opt) {
                if (proposedMainGoal.contains('Απώλεια') && opt == 'Απώλεια Βάρους') return false;
                if (proposedMainGoal.contains('Αύξηση') && opt == 'Αύξηση Βάρους') return false;
                return true; 
              }).map((opt) {
                final isSelected = selectedSecondary.contains(opt);
                return FilterChip(
                  label: Text(opt, style: TextStyle(color: isSelected ? Colors.white : darkPrimaryColor, fontSize: 15)), 
                  selected: isSelected,
                  selectedColor: darkPrimaryColor,
                  backgroundColor: Colors.white,
                  checkmarkColor: Colors.white,
                  shape: const StadiumBorder(),
                  onSelected: (val) {
                    setState(() {
                      if (val) {
                        selectedSecondary.add(opt);
                      } else {
                        selectedSecondary.remove(opt);
                      }
                      _updateDynamicCalories();
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 32),

            // Κουμπί Αποθήκευσης
            Container(
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [primaryColor, darkPrimaryColor]),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: darkPrimaryColor.withValues(alpha: 0.3), spreadRadius: 1, blurRadius: 6, offset: const Offset(0, 3))
                ]
              ),
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent, 
                  foregroundColor: Colors.white, 
                  shadowColor: Colors.transparent,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))
                ),
                onPressed: _saveFinalPlan,
                child: const Text('ΑΠΟΔΟΧΗ & ΑΠΟΘΗΚΕΥΣΗ ΠΛΑΝΟΥ', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
            ),
            
            const SizedBox(height: 15),
            TextButton(
              onPressed: () {
                Navigator.pushReplacement(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegistrationScreen(initialStep: 1),
                  ),
                );
              }, 
              child: Text(
                'Επαναπροσδιορισμός Στοιχείων', 
                style: TextStyle(
                  color: Colors.grey.shade600, 
                  decoration: TextDecoration.underline, 
                  fontSize: 16
                )
              )
            )
          ],
        ),
      ),
    );
  }
}