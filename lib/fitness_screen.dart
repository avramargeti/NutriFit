import 'package:flutter/material.dart';

class FitnessScreen extends StatefulWidget {
  const FitnessScreen({super.key});

  @override
  State<FitnessScreen> createState() => _FitnessScreenState();
}

class _FitnessScreenState extends State<FitnessScreen> {
  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);

  // Προσθήκη τοπικού state για προσομοίωση της ολοκλήρωσης του κουίζ
  bool hasCompletedQuiz = false;

  void _showComingSoon(String featureName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Η λειτουργία "$featureName" θα είναι σύντομα διαθέσιμη! 🚀'),
        backgroundColor: sageGreen,
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // Προσθήκη του Pop-up από το άλλο αρχείο (προσαρμοσμένο χωρίς Navigator.push)
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
              Navigator.pop(context); // Κλείσιμο του Dialog
              _showComingSoon('Οθόνη Κουίζ'); // Προσομοίωση μετάβασης
              
              // Προαιρετικά: Επαναφορά του state για δοκιμή του UI
              setState(() {
                hasCompletedQuiz = false;
              });
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
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Icon(Icons.sports_gymnastics, size: 80, color: sageGreen),
            const SizedBox(height: 20),
            
            // Δυναμικό κείμενο βάσει του state
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

            // Δυναμική εμφάνιση κουμπιών
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
                onPressed: () => _showComingSoon('Προτεινόμενα Προγράμματα'),
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
                onPressed: _retakeQuizWithWarning, // Κλήση του Pop-up
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
                onPressed: () {
                  // Αλλάζουμε το state για να δεις πώς λειτουργεί το UI
                  setState(() {
                    hasCompletedQuiz = true;
                  });
                  _showComingSoon('Κουίζ Προτιμήσεων');
                },
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
              onPressed: () => _showComingSoon('Λίστα Προγραμμάτων'),
            ),

            const SizedBox(height: 50),

            Row(
              children: [
                Icon(Icons.local_fire_department, color: slateGrey),
                const SizedBox(width: 8),
                Text(
                  'Δημοφιλή Προγράμματα',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: slateGrey,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 15),

            _buildDummyProgramCard(
                title: 'Cardio Express',
                category: 'Cardio / Τρέξιμο',
                details: 'Σπίτι • < 30 λεπτά • Υψηλή',
                calories: '🔥 ~300 kcal'),
            _buildDummyProgramCard(
                title: 'Yoga Basics',
                category: 'Yoga',
                details: 'Σπίτι • 30-45 λεπτά • Χαμηλή',
                calories: '🔥 ~150 kcal'),
            _buildDummyProgramCard(
                title: 'Full Body Ενδυνάμωση',
                category: 'Βάρη / Ενδυνάμωση',
                details: 'Γυμναστήριο • > 45 λεπτά • Μέτρια',
                calories: '🔥 ~400 kcal'),
          ],
        ),
      ),
    );
  }

  Widget _buildDummyProgramCard({
    required String title,
    required String category,
    required String details,
    required String calories,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: slateGrey),
                  ),
                ),
                Chip(
                  label: Text(
                    category,
                    style: const TextStyle(fontSize: 11, color: Colors.white),
                  ),
                  backgroundColor: sageGreen,
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(details, style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(calories,
                style: const TextStyle(
                    fontWeight: FontWeight.bold, color: Colors.redAccent)),
            const SizedBox(height: 15),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: sageGreen,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  side: BorderSide(color: sageGreen.withOpacity(0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  elevation: 0,
                  minimumSize: const Size(double.infinity, 45),
                ),
                onPressed: () => _showComingSoon('Προσθήκη στο Πλάνο'),
                child: const Text('Προσθήκη στο Πλάνο',
                    style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}