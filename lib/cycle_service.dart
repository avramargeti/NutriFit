import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class CycleService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  Stream<DocumentSnapshot> getUserCycleProfile() {
    final user = _auth.currentUser;
    if (user == null) throw Exception("Δεν βρέθηκε συνδεδεμένος χρήστης");

    return _db
        .collection('users')
        .doc(user.uid)
        .collection('cycleProfile')
        .doc('settings')
        .snapshots();
  }

  Future<void> saveInitialSettings({
    required DateTime lastPeriodStart,
    required int cycleLength,
    required int periodDuration,
    required String regularity,
    required List<String> typicalSymptoms,
    bool usesDefaultSettings = false,
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    DateTime nextPeriodPredicted = lastPeriodStart.add(Duration(days: cycleLength));
    DateTime ovulationDate = nextPeriodPredicted.subtract(const Duration(days: 14));
    DateTime fertilityStart = ovulationDate.subtract(const Duration(days: 5));
    DateTime fertilityEnd = ovulationDate.add(const Duration(days: 1));

    await _db.collection('users').doc(user.uid).collection('cycleProfile').doc('settings').set({
      'lastPeriodStart': lastPeriodStart,
      'cycleLength': cycleLength,
      'periodDuration': periodDuration,
      'nextPeriodPredicted': nextPeriodPredicted,
      'fertilityWindowStart': fertilityStart,
      'fertilityWindowEnd': fertilityEnd,
      'regularity': regularity,
      'typicalSymptoms': typicalSymptoms,
      'usesDefaultSettings': usesDefaultSettings,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> markProfileAsUsingDefaultSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).collection('cycleProfile').doc('settings').update({'usesDefaultSettings': true});
  }

  Future<DocumentSnapshot?> getEntryForDate(DateTime date) async {
    final user = _auth.currentUser;
    if (user == null) return null;

    DateTime start = DateTime(date.year, date.month, date.day, 0, 0, 0);
    DateTime end = DateTime(date.year, date.month, date.day, 23, 59, 59);

    final snap = await _db.collection('users').doc(user.uid)
        .collection('cycleProfile').doc('settings')
        .collection('cycleHistory')
        .where('entryDate', isGreaterThanOrEqualTo: start)
        .where('entryDate', isLessThanOrEqualTo: end)
        .limit(1).get();

    return snap.docs.isNotEmpty ? snap.docs.first : null;
  }

  Future<void> deleteCycleEntry(String docId) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final settingsRef = _db.collection('users').doc(user.uid).collection('cycleProfile').doc('settings');
    await settingsRef.collection('cycleHistory').doc(docId).delete();

    await _recalculateProfile(user.uid, settingsRef);
  }

  Future<void> logCycleEntry({
    required DateTime entryDate,
    required String flowIntensity,
    required List<String> symptoms,
    required String mood,
    required bool isPeriodStart,
    required int cycleLength,
    required int periodDuration,
    required DateTime? currentLastPeriodStart,
    String? existingDocId, 
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final settingsRef = _db.collection('users').doc(user.uid).collection('cycleProfile').doc('settings');
    
    final historyRef = existingDocId != null 
        ? settingsRef.collection('cycleHistory').doc(existingDocId)
        : settingsRef.collection('cycleHistory').doc();
    
    final latestPreviousEntry = await settingsRef.collection('cycleHistory')
        .where('entryDate', isLessThan: entryDate).orderBy('entryDate', descending: true).limit(1).get();

    final previousData = latestPreviousEntry.docs.isEmpty ? null : latestPreviousEntry.docs.first.data();
    final previousEntryDate = (previousData?['entryDate'] as Timestamp?)?.toDate();
    final previousHadFlow = _hasRecordedFlow(previousData?['flowIntensity'] as String?);
    final previousWasYesterday = previousEntryDate != null && _dateOnly(entryDate).difference(_dateOnly(previousEntryDate)).inDays == 1;
    
    final hadFlowPreviousDay = previousHadFlow && previousWasYesterday;
    final currentHasFlow = _hasRecordedFlow(flowIntensity);
    
    final startsNewCycle = isPeriodStart; 
    final endsCurrentPeriod = !currentHasFlow && hadFlowPreviousDay && !startsNewCycle;
    
    final cycleEvent = startsNewCycle ? 'periodStart' : endsCurrentPeriod ? 'periodEnd' : 'cycleLog';

    final entryData = {
      'entryDate': entryDate,
      'flowIntensity': flowIntensity,
      'hasFlow': currentHasFlow,
      'cycleEvent': cycleEvent,
      'symptoms': symptoms,
      'mood': mood,
      'createdAt': FieldValue.serverTimestamp(),
    };

    final batch = _db.batch();
    batch.set(historyRef, entryData, SetOptions(merge: true));
    
    batch.update(settingsRef, {
      'periodIsActive': currentHasFlow,
      'cycleLength': cycleLength, 
      'updatedAt': FieldValue.serverTimestamp(),
    });
    
    await batch.commit();

    await _recalculateProfile(user.uid, settingsRef);
  }

  Future<void> _recalculateProfile(String uid, DocumentReference settingsRef) async {
    final settingsSnap = await settingsRef.get();
    if (!settingsSnap.exists) return;
    final settingsData = settingsSnap.data() as Map<String, dynamic>;
    int cycleLength = settingsData['cycleLength'] ?? 30;
    int periodDuration = settingsData['periodDuration'] ?? 6;

    final latestPeriodStartSnap = await settingsRef.collection('cycleHistory')
        .where('cycleEvent', isEqualTo: 'periodStart')
        .orderBy('entryDate', descending: true)
        .limit(1).get();

    DateTime? lastPeriodStart;
    if (latestPeriodStartSnap.docs.isNotEmpty) {
      lastPeriodStart = (latestPeriodStartSnap.docs.first.data()['entryDate'] as Timestamp).toDate();
    }

    final allPeriodStartsSnap = await settingsRef.collection('cycleHistory')
        .where('cycleEvent', isEqualTo: 'periodStart')
        .orderBy('entryDate', descending: true)
        .get();

    List<Map<String, dynamic>> pastPeriods = [];
    for (int i = 1; i < allPeriodStartsSnap.docs.length; i++) {
      final data = allPeriodStartsSnap.docs[i].data();
      pastPeriods.add({
        'start': data['entryDate'],
        'duration': periodDuration,
      });
    }

    if (lastPeriodStart != null) {
      final nextPeriodPredicted = lastPeriodStart.add(Duration(days: cycleLength));
      final ovulationDate = nextPeriodPredicted.subtract(const Duration(days: 14));
      final fertilityWindowStart = ovulationDate.subtract(const Duration(days: 5));
      final fertilityWindowEnd = ovulationDate.add(const Duration(days: 1));
      
      final recommendation = _buildRecommendation(
        flowIntensity: settingsData['lastCycleLog']?['flowIntensity'] ?? 'Καμία ροή',
        symptoms: List<String>.from(settingsData['lastCycleLog']?['symptoms'] ?? []),
        mood: settingsData['lastCycleLog']?['mood'] ?? 'Ουδέτερη'
      );

      await settingsRef.update({
        'lastPeriodStart': lastPeriodStart,
        'nextPeriodPredicted': nextPeriodPredicted,
        'fertilityWindowStart': fertilityWindowStart,
        'fertilityWindowEnd': fertilityWindowEnd,
        'pastPeriods': pastPeriods,
        'lastRecommendation': recommendation,
      });
    }
  }

  bool _hasRecordedFlow(String? flowIntensity) => flowIntensity != null && flowIntensity.isNotEmpty && flowIntensity != 'Καμία ροή';

  String _buildRecommendation({required String flowIntensity, required List<String> symptoms, required String mood}) {
    List<String> tips = [];
    if (flowIntensity == 'Βαριά') tips.add('🩸 Έντονη Ροή: Φροντίστε να καταναλώνετε τροφές πλούσιες σε σίδηρο και ξεκουραστείτε.');
    else if (flowIntensity == 'Καμία ροή') return 'Η περίοδός σας φαίνεται να ολοκληρώθηκε. Μην ξεχνάτε να καταγράφετε καθημερινά τη διάθεσή σας!';
    if (symptoms.contains('Κράμπες') || symptoms.contains('Πόνος στη μέση')) tips.add('🧘‍♀️ Πόνος & Κράμπες: Μια θερμοφόρα μπορεί να ανακουφίσει τον πόνο.');
    if (symptoms.contains('Ατονία') || symptoms.contains('Κόπωση')) tips.add('😴 Κόπωση: Αποφύγετε την έντονη γυμναστική σήμερα και κοιμηθείτε καλά.');
    if (symptoms.contains('Πονοκέφαλος')) tips.add('💧 Πονοκέφαλος: Η καλή ενυδάτωση μπορεί να βοηθήσει.');
    if (symptoms.contains('Φούσκωμα')) tips.add('🎈 Φούσκωμα: Μειώστε το αλάτι στα γεύματά σας σήμερα.');
    if (mood == 'Κακή' || symptoms.contains('Αλλαγές Διάθεσης')) tips.add('🍫 Διάθεση: Λίγη μαύρη σοκολάτα ίσως σας φτιάξει τη μέρα.');
    return tips.isEmpty ? '💡 Η καταγραφή σας αποθηκεύτηκε επιτυχώς!' : tips.join('\n\n');
  }

  DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);
}