import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'local_data_repository.dart';

class BasicFitnessQuiz extends StatefulWidget {
  final VoidCallback onCompleted;
  const BasicFitnessQuiz({super.key, required this.onCompleted});
  @override
  State<BasicFitnessQuiz> createState() => _BasicFitnessQuizState();
}

class _BasicFitnessQuizState extends State<BasicFitnessQuiz> {
  final Color sageGreen = const Color(0xFFA8B3A0);
  final Color slateGrey = const Color(0xFF8C9DA6);

  String? selectedLocation;
  String? selectedIntensity;
  String? selectedDuration;
  bool _isLoading = false;

  Future<void> _submitQuiz() async {
    if (selectedLocation == null || selectedIntensity == null || selectedDuration == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Παρακαλώ απαντήστε σε όλες τις ερωτήσεις.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance.collection('users').doc(user.uid).set({
          'fitnessPreferences': {
            'location': selectedLocation!,
            'intensity': selectedIntensity!,
            'duration': selectedDuration!,
          }
        }, SetOptions(merge: true));
        ChatbotDataCache().clearCache();
      }
      
      if (mounted) {
        Navigator.pop(context); 
        widget.onCompleted(); 
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Σφάλμα: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ας βρούμε τι σας ταιριάζει!', 
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: slateGrey)),
        const SizedBox(height: 20),

        const Text('Πού προτιμάτε να γυμνάζεστε;', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        Wrap(
          spacing: 8,
          children: ['Σπίτι', 'Γυμναστήριο', 'Εξωτερικός Χώρος'].map((loc) {
            return ChoiceChip(
              label: Text(loc),
              selected: selectedLocation == loc,
              onSelected: (val) => setState(() => selectedLocation = val ? loc : null),
              selectedColor: sageGreen,
              showCheckmark: false,
              labelStyle: TextStyle(color: selectedLocation == loc ? Colors.white : Colors.black87),
            );
          }).toList(),
        ),
        const SizedBox(height: 15),

        const Text('Τι ένταση προτιμάτε;', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        Wrap(
          spacing: 8,
          children: ['Χαμηλή', 'Μέτρια', 'Υψηλή'].map((intst) {
            return ChoiceChip(
              label: Text(intst),
              selected: selectedIntensity == intst,
              onSelected: (val) => setState(() => selectedIntensity = val ? intst : null),
              selectedColor: sageGreen,
              showCheckmark: false,
              labelStyle: TextStyle(color: selectedIntensity == intst ? Colors.white : Colors.black87),
            );
          }).toList(),
        ),
        const SizedBox(height: 15),

        const Text('Πόσο χρόνο διαθέτετε;', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
        Wrap(
          spacing: 8,
          children: ['< 30 λεπτά', '30-45 λεπτά', '> 45 λεπτά'].map((dur) {
            return ChoiceChip(
              label: Text(dur),
              selected: selectedDuration == dur,
              onSelected: (val) => setState(() => selectedDuration = val ? dur : null),
              selectedColor: sageGreen,
              showCheckmark: false,
              labelStyle: TextStyle(color: selectedDuration == dur ? Colors.white : Colors.black87),
            );
          }).toList(),
        ),
        const SizedBox(height: 30),

        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: slateGrey,
                  side: BorderSide(color: slateGrey),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text('ΑΚΥΡΩΣΗ', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              flex: 2,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: sageGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                onPressed: _isLoading ? null : _submitQuiz,
                child: _isLoading 
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text('ΟΛΟΚΛΗΡΩΣΗ', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ],
    );
  }
}