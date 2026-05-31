import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class ProgressManager {
  final String userId;

  ProgressManager({required this.userId});

  int _asInt(dynamic value) {
    if (value is num) return value.round();
    return num.tryParse(value?.toString() ?? '')?.round() ?? 0;
  }

  Future<Map<String, dynamic>> generateWeeklyReview() async {
    DateTime today = DateTime.now();

    var historySnapshot = await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('progress_history')
        .orderBy('date', descending: true)
        .limit(1)
        .get();

    bool isMidWeek = false;
    if (historySnapshot.docs.isNotEmpty) {
      var lastDate = historySnapshot.docs.first.data()['date'] as Timestamp?;
      if (lastDate != null) {
        int daysSinceLast = today.difference(lastDate.toDate()).inDays;
        if (daysSinceLast < 6) {
          isMidWeek = true;
        }
      }
    }

    int totalNetCalories = 0;
    int daysLogged = 0;
    
    for (int i = 0; i < 7; i++) {
      DateTime targetDate = today.subtract(Duration(days: i));
      String dateString = DateFormat('yyyy-MM-dd').format(targetDate);

      DocumentSnapshot doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('diary')
          .doc(dateString)
          .get();

      if (doc.exists) {
        var data = doc.data() as Map<String, dynamic>;
        List entries = data['entries'] ?? [];
        
        if (entries.isNotEmpty) {
          daysLogged++; 
          int dailyConsumed = 0;
          int dailyBurned = 0;
          
          for (var entry in entries) {
            if (entry['isExercise'] == true) {
              dailyBurned += _asInt(entry['calories']);
            } else {
              dailyConsumed += _asInt(entry['calories']);
            }
          }
          totalNetCalories += (dailyConsumed - dailyBurned);
        }
      }
    }

    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    var userData = userDoc.data() as Map<String, dynamic>;
    int targetDailyCalories = _asInt(userData['targetCalories']);
    int weeklyTargetCalories = targetDailyCalories * daysLogged;
    double performanceRatio = weeklyTargetCalories > 0 ? (totalNetCalories / weeklyTargetCalories) : 0;

    if (isMidWeek) {
      return {
        'status': 'mid_week_review',
        'daysLogged': daysLogged,
        'avgDailyCalories': daysLogged > 0 ? (totalNetCalories / daysLogged).round() : 0,
        'targetDailyCalories': targetDailyCalories,
        'message': performanceRatio > 1.10 
            ? 'Ενδιάμεσος έλεγχος: Είσαι λίγο πάνω από τον στόχο σου αυτή τη βδομάδα. Προσπάθησε να μαζέψεις τη διαφορά τις επόμενες μέρες!'
            : 'Ενδιάμεσος έλεγχος: Είσαι ακριβώς μέσα στον στόχο σου! Συνέχισε την καλή δουλειά μέχρι την επίσημη ανασκόπηση.',
      };
    }

    if (daysLogged < 3) {
      return {
        'status': 'insufficient_data',
        'daysLogged': daysLogged,
        'message': 'Έχεις καταγράψει δεδομένα μόνο για $daysLogged ημέρες αυτή την εβδομάδα. Προσπάθησε να είσαι πιο συνεπής για να βγάλουμε ασφαλή συμπεράσματα!'
      };
    }
    
    if (performanceRatio > 1.10) {
       return {
        'status': 'goal_not_met',
        'daysLogged': daysLogged,
        'avgDailyCalories': (totalNetCalories / daysLogged).round(),
        'targetDailyCalories': targetDailyCalories,
        'message': 'Φαίνεται πως αυτή την εβδομάδα δυσκολεύτηκες λίγο. Για να βρεις τον ρυθμό σου, προτείνουμε μια μικρή αύξηση των ημερήσιων θερμίδων ώστε ο στόχος να είναι πιο ρεαλιστικός.',
        'proposedAdjustment': targetDailyCalories + 150, 
      };
    }

    return {
      'status': 'goal_met',
      'daysLogged': daysLogged,
      'avgDailyCalories': (totalNetCalories / daysLogged).round(),
      'targetDailyCalories': targetDailyCalories,
      'message': 'Συγχαρητήρια! Πέτυχες τον στόχο σου αυτή την εβδομάδα. Η συνέπειά σου είναι εξαιρετική!',
      'achievement': 'Συνεπής Διατροφή' 
    };
  }

  Future<void> updateGoals(int newCalorieTarget) async {
    await FirebaseFirestore.instance.collection('users').doc(userId).update({
      'targetCalories': newCalorieTarget,
    });
  }

  Future<void> saveReportToHistory(Map<String, dynamic> report) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('progress_history')
        .add({
      'date': FieldValue.serverTimestamp(),
      'report': report,
    });
  }
}