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
    String experience = userData?['experienceLevel'] ?? 'Αρχάριος';
    List<dynamic> healthIssues = userData?['healthIssues'] ?? [];

    // Έλεγχος ταύτισης με απαντήσεις κουίζ
    if (programData['location'] == userPreferences['location']) score += 3;
    if (programData['intensity'] == userPreferences['intensity']) score += 3;
    if (programData['duration'] == userPreferences['duration']) score += 3;
    
    // Έλεγχος προφίλ υγείας (BMI)
    if (bmi >= 26.0 && intensity == 'Υψηλή') score -= 3;
    if (bmi < 18.5 && bmi > 0 && (category.contains('Βάρη') || category.contains('Ενδυνάμωση'))) score += 2;

    // Έλεγχος καθημερινότητας
    if (activity.contains('Καθιστική') && (category == 'Ευεξία' || category == 'Yoga')) score += 2;

    // Έλεγχος εμπειρίας
    if (experience == 'Αρχάριος' && (intensity == 'Υψηλή' || category.contains('CrossFit'))) score -= 5;
    else if (experience == 'Προχωρημένος' && intensity == 'Υψηλή') score += 2;

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

    if (noExactMatch) {
      insights.add('⚠️ Δεν βρέθηκε πρόγραμμα με απόλυτη ταύτιση με τις απαντήσεις σας στο κουίζ. Παρόλα αυτά, σας προτείνουμε τις παρακάτω κοντινές εναλλακτικές.');
    }

    if (userData == null) return insights;

    double bmi = (userData['bmi'] as num?)?.toDouble() ?? 0.0;
    String activity = userData['dailyActivity'] ?? '';
    String experience = userData['experienceLevel'] ?? 'Αρχάριος';
    String eatingOut = userData['eatingOutFrequency'] ?? '';
    List<dynamic> healthIssues = userData['healthIssues'] ?? [];

    if (bmi > 26) {
      insights.add('💡 Λόγω του BMI σας ($bmi), δώσαμε προτεραιότητα σε ασκήσεις χαμηλότερης καταπόνησης για τις αρθρώσεις.');
    } else if (bmi < 21 && bmi > 0) {
      insights.add('💪 Το BMI σας δείχνει ανάγκη για μυϊκή ανάπτυξη. Τα προγράμματα με αντιστάσεις έλαβαν υψηλότερη βαθμολογία.');
    }

    if (activity.contains('Καθιστική')) {
      insights.add('🧘‍♂️ Λόγω της καθιστικής σας καθημερινότητας, προκρίναμε προγράμματα κινητικότητας & ευεξίας.');
    }

    if (experience == 'Αρχάριος') {
      insights.add('🔰 Ως αρχάριος, αφαιρέσαμε από τις προτάσεις σας προγράμματα ακραίας έντασης (π.χ. CrossFit) για αποφυγή τραυματισμών.');
    }

    if (healthIssues.contains('Υπέρταση')) {
      insights.add('❤️ Για την προστασία σας λόγω υπέρτασης, αποκλείσαμε αυστηρά τα προγράμματα υψηλής έντασης.');
    }

    if (eatingOut == 'Καθημερινά' || eatingOut == '3-5 φορές/εβδομάδα') {
      insights.add('🥗 Λόγω συχνών γευμάτων εκτός σπιτιού, προτείνουμε επιλογές που ενισχύουν τον μεταβολικό ρυθμό.');
    }

    return insights;
  }
}