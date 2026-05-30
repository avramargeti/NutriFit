import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CycleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<DocumentSnapshot> getUserCycleProfile() {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Δεν βρέθηκε συνδεδεμένος χρήστης");

    return _db.collection('users').doc(user.uid).collection('cycleProfile').doc('settings').snapshots();
  }

  // Προστέθηκαν τα 2 νέα πεδία
  Future<void> saveInitialSettings({
    required DateTime lastPeriodStart,
    required int cycleLength,
    required int periodDuration,
    required String regularity, 
    required List<String> typicalSymptoms,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    DateTime nextPeriodPredicted = lastPeriodStart.add(Duration(days: cycleLength));

    // Αποθήκευση όλων στη βάση δεδομένων
    await _db.collection('users').doc(user.uid).collection('cycleProfile').doc('settings').set({
      'lastPeriodStart': lastPeriodStart,
      'cycleLength': cycleLength,
      'periodDuration': periodDuration,
      'nextPeriodPredicted': nextPeriodPredicted,
      'regularity': regularity,           // <-- ΝΕΟ
      'typicalSymptoms': typicalSymptoms, // <-- ΝΕΟ
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}