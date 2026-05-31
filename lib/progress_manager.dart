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
    String? previousMainGoal;

    if (historySnapshot.docs.isNotEmpty) {
      var lastDoc = historySnapshot.docs.first.data();
      var lastDate = lastDoc['date'] as Timestamp?;
      var lastReport = lastDoc['report'] as Map<String, dynamic>? ?? {};
      
      previousMainGoal = lastReport['mainGoal'];

      if (lastDate != null) {
        int daysSinceLast = today.difference(lastDate.toDate()).inDays;
        if (daysSinceLast < 6) {
          isMidWeek = true;
        }
      }
    }

    int totalNetCalories = 0;
    int daysLogged = 0;
    
    int totalExerciseMinutes = 0;
    int totalSnackCalories = 0;
    int totalConsumedCalories = 0;
    
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
          int dailyConsumed = 0, dailyBurned = 0;
          for (var entry in entries) {
            if (entry['isExercise'] == true) {
              dailyBurned += _asInt(entry['calories']);
              totalExerciseMinutes += _asInt(entry['quantity']); 
            } else {
              int cals = _asInt(entry['calories']);
              dailyConsumed += cals;
              totalConsumedCalories += cals;
              
              if (entry['category'] == 'Σνακ') {
                totalSnackCalories += cals;
              }
            }
          }
          totalNetCalories += (dailyConsumed - dailyBurned);
        }
      }
    }

    DocumentSnapshot userDoc = await FirebaseFirestore.instance.collection('users').doc(userId).get();
    var userData = userDoc.data() as Map<String, dynamic>;
    int targetDailyCalories = _asInt(userData['targetCalories']);
    String currentMainGoal = userData['mainGoal'] ?? 'Συντήρηση';
    
    int weeklyTargetCalories = targetDailyCalories * daysLogged;
    double performanceRatio = weeklyTargetCalories > 0 ? (totalNetCalories / weeklyTargetCalories) : 0;

    List<String> extraAchievements = [];
    if (daysLogged == 7) {
      extraAchievements.add('Απόλυτη Καταγραφή 📝');
    }
    if (totalExerciseMinutes >= 150) {
      extraAchievements.add('Γυμναστηριακός Τύπος 🏋️');
    }

    if (!isMidWeek && previousMainGoal != null && previousMainGoal != currentMainGoal) {
      if (currentMainGoal == 'Διατήρηση & Ευεξία') {
        return {
          'status': 'long_term_goal_met',
          'daysLogged': daysLogged,
          'mainGoal': currentMainGoal,
          'message': 'Εντοπίσαμε ότι άλλαξες το πλάνο σου σε "Διατήρηση & Ευεξία". Αυτό σημαίνει ότι ολοκλήρωσες τον τελικό σου στόχο. Η μεταμόρφωσή σου είναι έμπνευση!',
          'achievement': 'Απόλυτος Νικητής 🏆',
        };
      } 
      else if (currentMainGoal == 'Απώλεια Βάρους (Λίπους)') {
        return {
          'status': 'plan_changed_setback',
          'daysLogged': daysLogged,
          'mainGoal': currentMainGoal,
          'message': 'Είδαμε ότι ξεκίνησες πλάνο "Απώλειας Βάρους". Οι διακυμάνσεις είναι απόλυτα φυσιολογικές στο ταξίδι. Είμαστε εδώ για να σε βοηθήσουμε να τα καταφέρεις!',
        };
      }
      else if (currentMainGoal == 'Αύξηση Βάρους & Μυϊκής Μάζας') {
        return {
          'status': 'plan_changed_setback',
          'daysLogged': daysLogged,
          'mainGoal': currentMainGoal,
          'message': 'Ώρα για χτίσιμο! Ξεκίνησες πλάνο για "Αύξηση Μυϊκής Μάζας". Δώσε στο σώμα σου τη σωστή ενέργεια, μείνε συνεπής στις προπονήσεις και πάμε δυνατά για νέα ρεκόρ!',
        };
      }
      else if (currentMainGoal == 'Απώλεια Βάρους (Επιλογή Χρήστη)') {
        return {
          'status': 'plan_changed_setback',
          'daysLogged': daysLogged,
          'mainGoal': currentMainGoal,
          'message': 'Είδαμε ότι ξεκίνησες πλάνο "Απώλειας Βάρους". Είτε κάνεις μια νέα αρχή, είτε αλλάζεις στρατηγική, είμαστε εδώ για να σε βοηθήσουμε να τα καταφέρεις!',
        };
      }
    }

    if (isMidWeek) {
      return {
        'status': 'mid_week_review',
        'daysLogged': daysLogged,
        'mainGoal': currentMainGoal,
        'avgDailyCalories': daysLogged > 0 ? (totalNetCalories / daysLogged).round() : 0,
        'targetDailyCalories': targetDailyCalories,
        'message': performanceRatio > 1.10 
            ? 'Ενδιάμεσος έλεγχος: Είσαι λίγο πάνω από τον στόχο σου. Πρόσεχε λίγο τις επόμενες μέρες!'
            : 'Ενδιάμεσος έλεγχος: Είσαι ακριβώς μέσα στον στόχο σου! Συνέχισε έτσι.',
      };
    }

    if (daysLogged < 3) {
      return {
        'status': 'insufficient_data',
        'daysLogged': daysLogged,
        'mainGoal': currentMainGoal,
        'message': 'Έχεις καταγράψει μόνο $daysLogged ημέρες αυτή την εβδομάδα. Χρειαζόμαστε περισσότερα δεδομένα.'
      };
    }
    
    if (performanceRatio > 1.10) {
      String smartMessage = 'Δυσκολεύτηκες λίγο αυτή την εβδομάδα. Προτείνουμε μια μικρή αύξηση θερμίδων (+150 kcal) για να γίνει ο στόχος σου πιο εφικτός.';
      
      if (totalExerciseMinutes < 60) {
        smartMessage += '\n\n💡 Tip: Παρατηρήσαμε ότι η άσκησή σου ήταν κάτω από 1 ώρα αυτή την εβδομάδα. Δοκίμασε να προσθέσεις 15-20 λεπτά χαλαρό περπάτημα τη μέρα για να πετύχεις τον στόχο σου!';
      } 
      else if (totalConsumedCalories > 0 && (totalSnackCalories / totalConsumedCalories) > 0.25) {
        smartMessage += '\n\n💡 Tip: Πάνω από το 25% των θερμίδων σου προήλθε από Σνακ. Προσπάθησε να αυξήσεις τις μερίδες στα κυρίως γεύματα για να πετύχεις τον στόχο σου!';
      }

      return {
        'status': 'goal_not_met',
        'daysLogged': daysLogged,
        'mainGoal': currentMainGoal,
        'avgDailyCalories': (totalNetCalories / daysLogged).round(),
        'targetDailyCalories': targetDailyCalories,
        'message': smartMessage,
        'proposedAdjustment': targetDailyCalories + 150, 
        'extraAchievements': extraAchievements,
      };
    }

    return {
      'status': 'goal_met',
      'daysLogged': daysLogged,
      'mainGoal': currentMainGoal,
      'avgDailyCalories': (totalNetCalories / daysLogged).round(),
      'targetDailyCalories': targetDailyCalories,
      'message': 'Συγχαρητήρια! Πέτυχες τον στόχο σου αυτή την εβδομάδα.',
      'achievement': 'Συνεπής Διατροφή',
      'extraAchievements': extraAchievements,
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
    if (report.containsKey('achievement')) {
      await _awardAchievement(report['achievement']);
    }

    if (report.containsKey('extraAchievements')) {
      List<dynamic> extras = report['extraAchievements'];
      for (var title in extras) {
        await _awardAchievement(title.toString());
      }
    }
  }

  Future<void> _awardAchievement(String title) async {
    await FirebaseFirestore.instance
        .collection('users')
        .doc(userId)
        .collection('achievements')
        .add({
      'title': title,
      'earnedAt': FieldValue.serverTimestamp(),
    });
  }
}