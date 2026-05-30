import 'dart:convert';

import 'package:http/http.dart' as http;

class AiApiClient {
  AiApiClient({
    http.Client? client,
    String? endpoint,
    String? apiKey,
  })  : _client = client ?? http.Client(),
        _endpoint =
            endpoint ?? const String.fromEnvironment('NUTRIFIT_AI_ENDPOINT'),
        _apiKey = apiKey ??
            const String.fromEnvironment('NUTRIFIT_AI_API_KEY');

  final http.Client _client;
  final String _endpoint;
  final String _apiKey;

  Future<String> ask(String query) async {
    if (_endpoint.trim().isEmpty) {
      return _offlineFallback(query);
    }

    final response = await _client.post(
      Uri.parse(_endpoint),
      headers: {
        'Content-Type': 'application/json',
        if (_apiKey.trim().isNotEmpty) 'Authorization': 'Bearer $_apiKey',
      },
      body: jsonEncode({
        'message': query,
        'system':
            'Απάντησε στα ελληνικά ως βοηθός διατροφής και γυμναστικής του NutriFit. '
                'Δώσε πρακτική, σύντομη και ασφαλή καθοδήγηση.',
      }),
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('AI API failed with status ${response.statusCode}');
    }

    final decoded = jsonDecode(utf8.decode(response.bodyBytes));
    if (decoded is Map<String, dynamic>) {
      final text = decoded['answer'] ??
          decoded['response'] ??
          decoded['text'] ??
          decoded['message'];
      if (text != null && text.toString().trim().isNotEmpty) {
        return text.toString().trim();
      }
    }

    if (decoded is String && decoded.trim().isNotEmpty) {
      return decoded.trim();
    }

    throw Exception('AI API returned an empty response');
  }

  String _offlineFallback(String query) {
    final normalized = _removeAccents(query.toLowerCase());

    if (normalized.contains('sushi') || normalized.contains('σουσι')) {
      return "Δεν βρήκα συνταγή για sushi στην τοπική βάση. Μια απλή εκδοχή: βράσε ρύζι για sushi, άφησέ το να κρυώσει με λίγο ξίδι ρυζιού, βάλε φύλλο nori, πρόσθεσε αγγούρι, αβοκάντο και σολομό ή τόνο, τύλιξε σφιχτά και κόψε σε ρολά. Για πιο ελαφριά επιλογή, κράτα μικρή ποσότητα ρυζιού και βάλε περισσότερα λαχανικά.";
    }

    if (normalized.contains('δικεφαλ') || normalized.contains('biceps')) {
      return "Δεν βρήκα πρόγραμμα για δικέφαλα στην τοπική βάση. Μπορείς να κάνεις 3 ασκήσεις: κάμψεις δικεφάλων με αλτήρες, hammer curls και κάμψεις με λάστιχο. Κράτα 3 σετ των 10-12 επαναλήψεων, αργή επιστροφή στην κίνηση και ξεκούραση 60-90 δευτερόλεπτα.";
    }

    if (normalized.contains('πλατη') || normalized.contains('ραχη')) {
      return "Δεν βρήκα αρκετά σχετικό πρόγραμμα πλάτης στην τοπική βάση. Δοκίμασε κωπηλατική, έλξεις ή lat pulldown και face pulls. Κάνε 3 σετ των 8-12 επαναλήψεων, με έλεγχο στην τεχνική και ουδέτερη μέση.";
    }

    if (normalized.contains('συνταγ') || normalized.contains('φαω')) {
      return "Δεν βρήκα σχετική συνταγή στην τοπική βάση. Μπορώ να σου προτείνω μια απλή ισορροπημένη επιλογή: πηγή πρωτεΐνης, λαχανικά, σύνθετο υδατάνθρακα και λίγο καλό λιπαρό, προσαρμοσμένα στον στόχο σου.";
    }

    if (normalized.contains('ασκ') ||
        normalized.contains('γυμνασ') ||
        normalized.contains('προπονη')) {
      return "Δεν βρήκα αντίστοιχο πρόγραμμα στην τοπική βάση. Μπορείς να ξεκινήσεις με 5-10 λεπτά ζέσταμα, 3 βασικές ασκήσεις για την περιοχή που σε ενδιαφέρει και ήπια αποθεραπεία. Αν έχεις πόνο ή τραυματισμό, προτίμησε καθοδήγηση ειδικού.";
    }

    return "Δεν βρήκα αρκετά δεδομένα στην τοπική βάση του NutriFit για αυτή την ερώτηση. Μπορώ όμως να σε καθοδηγήσω γενικά με πρακτικές προτάσεις διατροφής και άσκησης προσαρμοσμένες στον στόχο σου.";
  }

  String _removeAccents(String text) {
    const withDia = 'άέήίϊΐόύϋΰώΆΈΉΊΪΌΎΫΏ';
    const withoutDia = 'αεηιιιουυυωΑΕΗΙΙΟΥΥΩ';
    var result = text;
    for (var i = 0; i < withDia.length; i++) {
      result = result.replaceAll(withDia[i], withoutDia[i]);
    }
    return result;
  }
}
