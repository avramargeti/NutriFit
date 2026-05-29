class SmartInsightsService {
  
  static int calculateProgramScore({
    required Map<String, dynamic> programData,
    required Map<String, String>? userPreferences,
    required Map<String, dynamic>? userData,
  }) {
    int score = 0;
    if (userPreferences == null) return score;

    String category = programData['category'] ?? '';
    String intensity = programData['intensity'] ?? '';
    double bmi = (userData?['bmi'] as num?)?.toDouble() ?? 0.0;
    String activity = userData?['dailyActivity'] ?? '';
    List<dynamic> healthIssues = userData?['healthIssues'] ?? [];

    if (programData['location'] == userPreferences['location']) score += 3;
    if (programData['intensity'] == userPreferences['intensity']) score += 3;
    if (programData['duration'] == userPreferences['duration']) score += 3;
    
    // Έλεγχος προφίλ BMI
    if (bmi >= 26.0 && intensity == 'Υψηλή') score -= 3;
    if (bmi < 18.5 && bmi > 0 && (category.contains('Βάρη') || category.contains('Ενδυνάμωση'))) score += 2;

    // Έλεγχος καθημερινότητας
    if (activity.contains('Καθιστική') && (category == 'Ευεξία' || category == 'Yoga')) score += 2;

    // Έλεγχος παθήσεων
    if (healthIssues.contains('Υπέρταση') && intensity == 'Υψηλή') score -= 6;
    if (healthIssues.contains('Διαβήτης') && category.contains('Cardio')) score += 1;

    return score;
  }

  static List<String> generateSmartInsights({
    required bool noExactMatch,
    required Map<String, dynamic>? userData,
  }) {
    List<String> insights = [];

    if (userData == null) return insights;

    double bmi = (userData['bmi'] as num?)?.toDouble() ?? 0.0;
    String activity = userData['dailyActivity'] ?? '';
    String eatingOut = userData['eatingOutFrequency'] ?? '';
    int waterIntake = userData['dailyWaterIntake'] ?? 2; // 1-5 κλίμακα από το registration
    List<dynamic> healthIssues = userData['healthIssues'] ?? [];

    // 1. Έλεγχοι BMI
    if (bmi > 26) {
      insights.add('💡 Λόγω του BMI σας ($bmi), δώσαμε προτεραιότητα σε ασκήσεις χαμηλότερης καταπόνησης για τις αρθρώσεις.');
    } else if (bmi < 21 && bmi > 0) {
      insights.add('💪 Το BMI σας δείχνει ανάγκη για μυϊκή ανάπτυξη. Τα προγράμματα με αντιστάσεις έλαβαν υψηλότερη βαθμολογία.');
    }

    // 2. Έλεγχος Δραστηριότητας
    if (activity.contains('Καθιστική')) {
      insights.add('🧘‍♂️ Λόγω της καθιστικής σας καθημερινότητας, προκρίναμε προγράμματα κινητικότητας & ευεξίας.');
    }

    // 3. Έλεγχος Υγείας
    if (healthIssues.contains('Υπέρταση')) {
      insights.add('❤️ Για την προστασία σας λόγω υπέρτασης, αποκλείσαμε αυστηρά τα προγράμματα υψηλής έντασης.');
    }

    // 4. Έλεγχος Διατροφής
    if (eatingOut == 'Καθημερινά' || eatingOut == '3-5 φορές την εβδομάδα') {
      insights.add('🥗 Λόγω συχνών γευμάτων εκτός σπιτιού, προτείνουμε επιλογές που ενισχύουν τον μεταβολικό ρυθμό.');
    } else if (eatingOut == 'Σπάνια / Ποτέ') {
      insights.add('🥗 Η καλή σπιτική διατροφή που ακολουθείτε θα μεγιστοποιήσει τα αποτελέσματα των προπονήσεών σας!');
    }

    if (waterIntake <= 2) {
      insights.add('💧 Προσοχή! Η ημερήσια κατανάλωση νερού σας είναι χαμηλή. Φροντίστε να ενυδατώνεστε καλά πριν και μετά την άσκηση.');
    } else if (waterIntake >= 4) {
      insights.add('💧 Η εξαιρετική σας ενυδάτωση (2+ Λίτρα) θα σας βοηθήσει σημαντικά στην ταχύτερη μυϊκή αποκατάσταση!');
    }

    if (insights.isEmpty) {
      insights.add('🎯 Το προφίλ σας είναι εξαιρετικά ισορροπημένο! Θυμηθείτε πως η συνέπεια είναι το κλειδί για την επίτευξη των στόχων σας.');
    }

    return insights;
  }
}