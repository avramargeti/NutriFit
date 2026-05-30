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

    DateTime nextPeriodPredicted = lastPeriodStart.add(
      Duration(days: cycleLength),
    );

    await _db
        .collection('users')
        .doc(user.uid)
        .collection('cycleProfile')
        .doc('settings')
        .set({
          'lastPeriodStart': lastPeriodStart,
          'cycleLength': cycleLength,
          'periodDuration': periodDuration,
          'nextPeriodPredicted': nextPeriodPredicted,
          'fertilityWindowStart': nextPeriodPredicted
              .subtract(const Duration(days: 14))
              .subtract(const Duration(days: 5)),
          'fertilityWindowEnd': nextPeriodPredicted
              .subtract(const Duration(days: 14))
              .add(const Duration(days: 1)),
          'regularity': regularity,
          'typicalSymptoms': typicalSymptoms,
          'usesDefaultSettings': usesDefaultSettings,
          'createdAt': FieldValue.serverTimestamp(),
        });
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
  }) async {
    final user = _auth.currentUser;
    if (user == null) return;

    final settingsRef = _db.collection('users').doc(user.uid).collection('cycleProfile').doc('settings');
    final historyRef = settingsRef.collection('cycleHistory').doc();
    
    final latestPreviousEntry = await settingsRef.collection('cycleHistory')
        .where('entryDate', isLessThan: entryDate)
        .orderBy('entryDate', descending: true)
        .limit(1)
        .get();

    final previousData = latestPreviousEntry.docs.isEmpty ? null : latestPreviousEntry.docs.first.data();
    final previousEntryDate = (previousData?['entryDate'] as Timestamp?)?.toDate();
    final previousHadFlow = _hasRecordedFlow(previousData?['flowIntensity'] as String?);
    final previousWasYesterday = previousEntryDate != null && _dateOnly(entryDate).difference(_dateOnly(previousEntryDate)).inDays == 1;
    
    final hadFlowPreviousDay = previousHadFlow && previousWasYesterday;
    final currentHasFlow = _hasRecordedFlow(flowIntensity);
    
    final startsNewCycle = isPeriodStart; 
    
    final endsCurrentPeriod = !currentHasFlow && hadFlowPreviousDay && !startsNewCycle;
    
    final effectiveLastPeriodStart = startsNewCycle ? entryDate : (currentLastPeriodStart ?? entryDate);
    final previousFlowDate = previousEntryDate ?? entryDate;
    final calculatedPeriodDuration = previousFlowDate.difference(effectiveLastPeriodStart).inDays + 1;
    
    final effectivePeriodDuration = endsCurrentPeriod ? (calculatedPeriodDuration < 1 ? 1 : calculatedPeriodDuration) : periodDuration;
    
    final nextPeriodPredicted = effectiveLastPeriodStart.add(Duration(days: cycleLength));
    final ovulationDate = nextPeriodPredicted.subtract(const Duration(days: 14));
    final fertilityWindowStart = ovulationDate.subtract(const Duration(days: 5));
    final fertilityWindowEnd = ovulationDate.add(const Duration(days: 1));
    final recommendation = _buildRecommendation(flowIntensity: flowIntensity, symptoms: symptoms, mood: mood);
    
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
    
    final lastCycleLog = {
      'entryDate': entryDate,
      'flowIntensity': flowIntensity,
      'hasFlow': currentHasFlow,
      'cycleEvent': cycleEvent,
      'symptoms': symptoms,
      'mood': mood,
    };

    final batch = _db.batch();
    batch.set(historyRef, entryData);
    
    final settingsUpdate = <String, dynamic>{
      'periodIsActive': currentHasFlow,
      'nextPeriodPredicted': nextPeriodPredicted,
      'fertilityWindowStart': fertilityWindowStart,
      'fertilityWindowEnd': fertilityWindowEnd,
      'lastCycleLog': lastCycleLog,
      'lastRecommendation': recommendation,
      'updatedAt': FieldValue.serverTimestamp(),
    };
    
    if (startsNewCycle) {
      settingsUpdate['lastPeriodStart'] = entryDate;
      settingsUpdate['lastPeriodEnd'] = null; 
      settingsUpdate['periodDuration'] = effectivePeriodDuration; 
      
      if (currentLastPeriodStart != null && !_isSameDay(entryDate, currentLastPeriodStart)) {
        settingsUpdate['pastPeriods'] = FieldValue.arrayUnion([
          {
            'start': currentLastPeriodStart,
            'duration': periodDuration,
          }
        ]);
      }
    }
    
    if (endsCurrentPeriod) {
      settingsUpdate['lastPeriodEnd'] = previousFlowDate;
      settingsUpdate['periodDuration'] = effectivePeriodDuration;
    }
    
    batch.update(settingsRef, settingsUpdate);
    await batch.commit();
  }

  Future<void> markProfileAsUsingDefaultSettings() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _db.collection('users').doc(user.uid).collection('cycleProfile').doc('settings').update({'usesDefaultSettings': true});
  }


  bool _hasRecordedFlow(String? flowIntensity) {
    return flowIntensity != null && flowIntensity.isNotEmpty && flowIntensity != 'Καμία ροή';
  }

  String _buildRecommendation({
    required String flowIntensity,
    required List<String> symptoms,
    required String mood,
  }) {
    List<String> tips = [];

    if (flowIntensity == 'Βαριά') {
      tips.add('🩸 Έντονη Ροή: Φροντίστε να καταναλώνετε τροφές πλούσιες σε σίδηρο, πίνετε άφθονο νερό και δώστε χρόνο στο σώμα σας να ξεκουραστεί.');
    } else if (flowIntensity == 'Καμία ροή') {
      return 'Η περίοδός σας φαίνεται να ολοκληρώθηκε. Μην ξεχνάτε να καταγράφετε καθημερινά τη διάθεσή σας!';
    }

    if (symptoms.contains('Κράμπες') || symptoms.contains('Πόνος στη μέση')) {
      tips.add('🧘‍♀️ Πόνος & Κράμπες: Μια θερμοφόρα στην κοιλιά ή στη μέση, σε συνδυασμό με ένα ζεστό χαμομήλι και ήπιες διατάσεις, μπορεί να ανακουφίσει τον πόνο.');
    }
    
    if (symptoms.contains('Ατονία') || symptoms.contains('Κόπωση')) {
      tips.add('😴 Κόπωση: Το σώμα σας ζητάει ενέργεια. Αποφύγετε την έντονη γυμναστική σήμερα και προσπαθήστε να κοιμηθείτε τουλάχιστον 8 ώρες.');
    }

    if (symptoms.contains('Πονοκέφαλος')) {
      tips.add('💧 Πονοκέφαλος: Η καλή ενυδάτωση και η μείωση της έκθεσης σε οθόνες μπορούν να βοηθήσουν στην αντιμετώπιση του πονοκεφάλου.');
    }
    
    if (symptoms.contains('Φούσκωμα')) {
      tips.add('🎈 Φούσκωμα: Προσπαθήστε να μειώσετε το αλάτι στα γεύματά σας σήμερα και προτιμήστε τροφές πλούσιες σε κάλιο, όπως η μπανάνα.');
    }

    if (mood == 'Κακή' || symptoms.contains('Αλλαγές Διάθεσης')) {
      tips.add('🍫 Διάθεση: Είναι απόλυτα φυσιολογικό να νιώθετε πεσμένη λόγω των ορμονών. Λίγη μαύρη σοκολάτα ή μια βόλτα στον καθαρό αέρα ίσως σας φτιάξουν τη μέρα.');
    }

    if (tips.isEmpty) {
      return '💡 Η καταγραφή σας αποθηκεύτηκε επιτυχώς! Συνεχίστε την καθημερινή παρακολούθηση για να γνωρίσετε καλύτερα το σώμα σας.';
    }

    return tips.join('\n\n');
  }

  DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  bool _isSameDay(DateTime first, DateTime second) {
    return first.year == second.year && first.month == second.month && first.day == second.day;
  }
}